import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../auth/auth_state.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_controller.dart';
import '../kb/kb_models.dart';
import '../kb/kb_repo.dart';
import '../router.dart';
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
  TodoReminderService(this._ref) {
    _initPlugin();
    // Lazy-build catch-up (same contract as the chat controllers): this
    // provider first builds inside FluctioApp long after auth restored, so
    // the listeners below must also check the current state.
    _ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      next == AuthStatus.loggedIn ? _activate() : _deactivate();
    }, fireImmediately: true);
    _ref.listen(agentsProvider.select((a) => a.selectedId), (prev, next) {
      if (_active && next != null && next != prev) _syncNow();
    });
  }

  static const _todosRoute = '/kb/todos'; // payload AND tap destination
  static const _channelId = 'todo_reminders';

  final Ref _ref;
  final _plugin = FlutterLocalNotificationsPlugin();

  bool _active = false;
  bool _ready = false;
  bool _syncing = false;
  DateTime _lastSync = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _debounce;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  bool get _zh => PlatformDispatcher.instance.locale.languageCode == 'zh';

  /// Re-sync after a todo mutation (the repo's onTodoWrite callback and the
  /// todos page refresh). Trailing-debounced so a burst of mutations
  /// collapses into one fetch; sparse triggers use [_syncNow] directly.
  void sync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), _syncNow);
  }

  Future<void> _syncNow() async {
    final agentId = _ref.read(agentsProvider).selectedId;
    if (agentId == null || _syncing || !_ready) return;
    _syncing = true;
    try {
      final todos = await _ref.read(kbRepoProvider).todos(agentId);
      final now = DateTime.now();
      await _plugin.cancelAll();
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

  Future<void> _initPlugin() async {
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      // Cold start from a notification: the callback above only fires for an
      // already-running app; the launch tap is reported via launchDetails.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _openTodos();
      }
    } catch (_) {
      // No platform implementation (unit tests): stay inert, _ready stays
      // false and every sync becomes a no-op.
      return;
    }
    _ready = true;
    if (_active) _syncNow();
  }

  void _activate() {
    if (_active) return;
    _active = true;
    // POST_NOTIFICATIONS runtime prompt (Android 13+); no-op when granted.
    try {
      // Errors surface on the returned Future — swallow those too.
      _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission()
          .catchError((_) => null);
    } catch (_) {} // plugin-less environments (tests)
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
    if (_ready) _syncNow();
  }

  Future<void> _deactivate() async {
    _active = false;
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    _debounce = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    // Logged out: no one else's todos may ring. Guarded the same way as
    // _initPlugin for plugin-less environments — and awaited, since the
    // platform call reports errors through the returned Future.
    try {
      await _plugin.cancelAll();
    } catch (_) {}
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
    // Only stable within a run: every sync starts with cancelAll, so ids
    // never need to outlive the process.
    final id = t.id.hashCode & 0x7fffffff;
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
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

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == _todosRoute) _openTodos();
  }

  void _openTodos() {
    try {
      _ref.read(routerProvider).go(_todosRoute);
    } catch (_) {
      // Router not mounted yet (cold start race) — the user lands on chat.
    }
  }
}
