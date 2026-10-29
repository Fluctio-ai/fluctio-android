import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../auth/auth_state.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_controller.dart';
import '../kb/kb_models.dart';
import '../kb/kb_repo.dart';
import '../notify/notify_hub.dart';
import '../util/dates.dart';

/// Local todo reminders: while the gateway's due sweep pushes to external
/// channels (wechat — gateway_due_todo.go), the app schedules OS-level
/// notifications for active todos with a future `start_at`, so reminders
/// fire even when the app is backgrounded or its process is gone.
///
/// Sync triggers: login, agent switch, todo writes (todos page calls
/// [sync] after every mutation), app resume, and a 15-min timer. Each sync
/// fetches the full list first — a failed fetch keeps the previous alarms —
/// then cancels everything and reschedules (AlarmManager sets are cheap;
/// same-id reschedule also refreshes title/time of edited todos).
final todoReminderServiceProvider =
    Provider<TodoReminderService>((ref) => TodoReminderService(ref));

class TodoReminderService {
  TodoReminderService(this._ref) : _hub = _ref.read(localNotifyHubProvider) {
    // Lazy-build catch-up (same contract as the chat controllers): this
    // provider first builds inside FluctioApp long after auth restored, so
    // the listeners below must also check the current state. The hub's
    // async plugin init may finish after activation — sync once it lands.
    unawaited(_hub.ready.then((_) {
      if (_active && _hub.isReady) _syncNow();
    }));
    _ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      next == AuthStatus.loggedIn ? _activate() : _deactivate();
    }, fireImmediately: true);
    _ref.listen(agentsProvider.select((a) => a.selectedId), (prev, next) {
      if (_active && next != null && next != prev) _syncNow();
    });
  }

  static const _todosRoute = '/kb/todos'; // notification tap destination
  static const _channelId = 'todo_reminders';

  final Ref _ref;
  final LocalNotifyHub _hub;

  bool _active = false;
  bool _syncing = false;
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _debounce;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  // Alarm ids this service currently has scheduled — the cancel set for
  // _syncNow (never cancelAll: app-scoped, would clear other features'
  // live notifications).
  final Set<int> _scheduledIds = {};

  bool get _zh => _hub.localeIsZh;

  /// Re-sync after a todo mutation (the repo's onTodoWrite callback and the
  /// todos page refresh). Trailing-debounced so a burst of mutations
  /// collapses into one fetch; sparse triggers use [_syncNow] directly.
  void sync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), _syncNow);
  }

  Future<void> _syncNow() async {
    final agentId = _ref.read(agentsProvider).selectedId;
    if (agentId == null || _syncing || !_hub.isReady) return;
    _syncing = true;
    try {
      final todos = await _ref.read(kbRepoProvider).todos(agentId);
      final now = DateTime.now();
      // Cancel only OUR alarm ids — hub cancelAll is app-scoped and would
      // wipe live server notifications too (the emulator-e2e catch: the
      // todo reschedule raced the notification drain and cleared it).
      for (final id in _scheduledIds) {
        await _hub.plugin.cancel(id: id);
      }
      _scheduledIds.clear();
      for (final t in todos) {
        if (t.status == 'done' || t.status == 'cancelled') continue;
        final start = t.startAt?.toLocal();
        if (start == null || !start.isAfter(now)) continue;
        await _schedule(t);
      }
      _lastSync = DateTime.now();
    } catch (_) {
      // Keep the previously scheduled alarms on a failed fetch.
    } finally {
      _syncing = false;
    }
  }

  void _activate() {
    if (_active) return;
    _active = true;
    // POST_NOTIFICATIONS runtime prompt (Android 13+); no-op when granted.
    _hub.requestPermission();
    _lifecycle = AppLifecycleListener(onResume: () {
      // Back to foreground: server-side edits since we were last seen.
      if (DateTime.now().difference(_lastSync) > const Duration(minutes: 5)) {
        _syncNow();
      }
    });
    _timer = Timer.periodic(const Duration(minutes: 15), (_) {
      // Foreground-only pick-up of remote edits while the app sits open —
      // a backgrounded isolate must not wake the radio (the OS alarms are
      // already scheduled; resume covers whatever changed meanwhile).
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _syncNow();
      }
    });
    if (_hub.isReady) _syncNow();
  }

  Future<void> _deactivate() async {
    _active = false;
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    _debounce = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    // Logged out: no one else's todos may ring. Deliberately the ONE
    // app-scoped cancelAll — the logout boundary clears every feature's
    // posts (privacy: a borrowed phone shows nothing), unlike _syncNow's
    // own-ids-only cancellation above.
    await _hub.cancelAll();
  }

  Future<void> _schedule(KbSource t) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _zh ? '待办提醒' : 'Todo reminders',
        channelDescription: _zh ? '按开始时间提醒待办事项' : 'Todo reminders at their start time',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    );
    final start = t.startAt!.toLocal();
    // An ISO instant is timezone-independent; mapping through UTC keeps the
    // absolute fire time correct without resolving the device's tz name.
    final when = tz.TZDateTime.from(start, tz.UTC);
    // Same start-time rendering policy as the todos page (lib/util/dates.dart).
    final time = formatSessionTime(start.millisecondsSinceEpoch);
    final body = _zh ? '开始时间 $time' : 'Starts at $time';
    // Only stable within a run: every sync cancels this set, so ids never
    // need to outlive the process.
    final id = t.id.hashCode & 0x7fffffff;
    _scheduledIds.add(id);
    Future<void> schedule(AndroidScheduleMode mode) => _hub.plugin.zonedSchedule(
          id: id,
          title: t.title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: _todosRoute,
        );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // No exact-alarm grant (e.g. USE_EXACT_ALARM refused): a few minutes
      // of Doze slack beats no reminder at all.
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }
}
