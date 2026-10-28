import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/api_client.dart';
import '../api/sse.dart';
import '../auth/auth_state.dart';
import '../auth/auth_controller.dart';
import 'notification_poll_worker.dart' show notifyPollTask;
import 'notify_hub.dart';
import 'server_notifications.dart';

/// Foreground half of the server-notification channel (contract §11):
/// on login, drain the queue once (polling endpoint), then hold the SSE
/// stream open for sub-second delivery while resumed. Backgrounded, the
/// stream is torn down — the WorkManager poll task owns delivery then
/// (notification_poll_worker.dart).
///
/// Cursor discipline: advance the LOCAL cursor before acking. An ack that
/// fails (network flap) strands rows server-side until the 7-day retention
/// sweep — they can't re-fire client-side because list(since=cursor) never
/// returns them again.
final serverNotificationsServiceProvider = Provider<ServerNotificationsService>((ref) {
  final s = ServerNotificationsService(ref);
  ref.onDispose(s.dispose);
  return s;
});

class ServerNotificationsService {
  ServerNotificationsService(this._ref) : _hub = _ref.read(localNotifyHubProvider) {
    _ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      next == AuthStatus.loggedIn ? _activate() : _deactivate();
    }, fireImmediately: true);
  }

  static const _cursorKey = 'notify.cursor';
  static const _channelId = 'server_notifications';

  final Ref _ref;
  final LocalNotifyHub _hub;

  bool _active = false;
  bool _draining = false;
  int _cursor = 0;
  CancelToken? _cancel;
  Timer? _reconnect;
  bool _resumed = true;
  AppLifecycleListener? _lifecycle;

  bool get _zh => _hub.localeIsZh;

  Future<void> _activate() async {
    if (_active) return;
    _active = true;
    final prefs = await SharedPreferences.getInstance();
    _cursor = prefs.getInt(_cursorKey) ?? 0;
    // Background delivery: a 15-min-floor periodic task (OS-deferred under
    // Doze; battery-optimization exemption keeps the cadence honest).
    // Registered on login and never unregistered — the worker no-ops
    // without a stored session.
    unawaited(Workmanager().registerPeriodicTask(
      notifyPollTask,
      notifyPollTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    ));
    // First drain waits for the permission prompt's verdict: a show()
    // racing an unanswered POST_NOTIFICATIONS prompt is silently dropped
    // by the OS (the login-drain bug the emulator e2e caught).
    unawaited(_hub.requestPermission().then((_) => _drainOnce()));
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _resumed = true;
        unawaited(_drainOnce());
        unawaited(_connect());
      },
      onPause: () {
        _resumed = false;
        _teardownStream(); // the OS background poller owns delivery now
      },
    );
    _resumed = WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;
    unawaited(_drainOnce());
    if (_resumed) unawaited(_connect());
  }

  void _deactivate() {
    _active = false;
    _lifecycle?.dispose();
    _lifecycle = null;
    _teardownStream();
  }

  void dispose() => _deactivate();

  /// One polling page: notify every row, advance the cursor, ack the
  /// watermark. Also the SSE reconnect path's bootstrap (rows that landed
  /// while no stream was open).
  Future<void> _drainOnce() async {
    if (_draining || !_active) return;
    _draining = true;
    try {
      final dio = _ref.read(apiClientProvider);
      final repo = ServerNotificationsRepo(dio);
      var page = await repo.list(since: _cursor);
      while (page.rows.isNotEmpty) {
        for (final n in page.rows) {
          await _notify(n);
        }
        await _advance(page.lastId, repo);
        if (page.rows.length < 50) break;
        page = await repo.list(since: _cursor);
      }
    } catch (_) {
      // Network flap: the SSE reconnect / next resume retries.
    } finally {
      _draining = false;
    }
  }

  /// Foreground live channel. The stream replays everything past the
  /// cursor, so connecting IS the catch-up — no separate drain needed.
  Future<void> _connect() async {
    if (!_active || !_resumed || _cancel != null) return;
    _reconnect?.cancel();
    _reconnect = null;
    final cancel = CancelToken();
    _cancel = cancel;
    final dio = _ref.read(apiClientProvider);
    final repo = ServerNotificationsRepo(dio);
    try {
      await for (final frame in SseClient(dio, idleTimeout: const Duration(seconds: 90))
          .get('/api/notifications/stream', {'since': _cursor}, cancelToken: cancel)) {
        if (frame.data.isEmpty) continue;
        final SrvNotification n;
        try {
          n = SrvNotification.fromJson(Map<String, dynamic>.from(jsonDecode(frame.data) as Map));
        } catch (_) {
          continue;
        }
        if (n.id <= _cursor) continue; // replay dup across reconnects
        await _notify(n);
        await _advance(n.id, repo);
      }
      // Server closed the stream politely — reconnect after a beat.
      _streamEnded();
    } catch (_) {
      _streamEnded();
    }
  }

  /// Watchdog tripped (90s silence), server close, or auth death: back off
  /// and re-open while resumed. A cancel-token teardown lands here too —
  /// guarded by the same checks, so a deliberate stop doesn't resurrect.
  void _streamEnded() {
    _cancel = null;
    if (!_active || !_resumed) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 30), () => unawaited(_connect()));
  }

  void _teardownStream() {
    _reconnect?.cancel();
    _reconnect = null;
    _cancel?.cancel();
    _cancel = null;
  }

  Future<void> _notify(SrvNotification n) async {
    await _hub.show(
      id: n.id & 0x7fffffff,
      channelId: _channelId,
      channelName: _zh ? '网关通知' : 'Gateway notifications',
      channelDescription: _zh ? '待办提醒、卡片摘要、搁浅话题与日记盲点' : 'Todo reminders, cards digest, shelved topics and diary blindspots',
      title: n.title,
      body: n.body,
      payload: appRouteForDeepLink(n.deepLink),
    );
  }

  /// Local cursor first, ack second — see class doc.
  Future<void> _advance(int lastId, ServerNotificationsRepo repo) async {
    _cursor = lastId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cursorKey, lastId);
    try {
      await repo.ack(lastId);
    } catch (_) {}
  }
}
