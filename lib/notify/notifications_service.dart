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

  final Ref _ref;
  final LocalNotifyHub _hub;

  bool _active = false;
  bool _draining = false;
  int _cursor = 0;
  SharedPreferences? _prefs;
  CancelToken? _cancel;
  Timer? _reconnect;
  AppLifecycleListener? _lifecycle;

  // Everything except `paused` counts as foreground — the OS pause is the
  // handoff point to the background poller.
  bool get _resumed => WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;

  bool get _zh => _hub.localeIsZh;

  Future<void> _activate() async {
    if (_active) return;
    _active = true;
    final prefs = _prefs = await SharedPreferences.getInstance();
    _cursor = prefs.getInt(notifyCursorKey) ?? 0;
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
    _lifecycle = AppLifecycleListener(
      // Back to foreground: the stream replays everything past the cursor,
      // so connecting IS the catch-up.
      onResume: () => unawaited(_connect()),
      onPause: () => _teardownStream(), // the OS background poller owns delivery now
    );
    // Login catch-up, one path: the hub gates its own show() on the
    // memoized permission verdict, so nothing here can race the prompt.
    if (_resumed) {
      unawaited(_connect());
    } else {
      unawaited(_drainOnce());
    }
  }

  void _deactivate() {
    _active = false;
    _lifecycle?.dispose();
    _lifecycle = null;
    _teardownStream();
  }

  void dispose() => _deactivate();

  /// One polling drain (the login path while backgrounded, and the resume
  /// bootstrap before the stream replays). Paging, cursor-then-ack, and
  /// the ack-error policy live in drainQueue, shared with the worker.
  Future<void> _drainOnce() async {
    if (_draining || !_active) return;
    _draining = true;
    try {
      await drainQueue(
        ServerNotificationsRepo(_ref.read(apiClientProvider)),
        since: _cursor,
        onCursor: (lastId) async {
          _cursor = lastId;
          await _prefs!.setInt(notifyCursorKey, lastId);
        },
        notify: _notify,
      );
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
      await for (final frame
          in SseClient(dio).get('/api/notifications/stream', {'since': _cursor}, cancelToken: cancel)) {
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
      channelId: notifyChannelId,
      channelName: notifyChannelName(_zh),
      channelDescription: notifyChannelDescription(_zh),
      title: n.title,
      body: n.body,
      payload: appRouteForDeepLink(n.deepLink),
    );
  }

  /// Local cursor first, ack second — see class doc.
  Future<void> _advance(int lastId, ServerNotificationsRepo repo) async {
    _cursor = lastId;
    await _prefs!.setInt(notifyCursorKey, lastId);
    try {
      await repo.ack(lastId);
    } catch (_) {}
  }
}
