import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import '../router.dart';
import 'notifications_service.dart';
import 'server_notifications.dart' show appRouteForDeepLink;

/// Opt-in always-on delivery (Gotify-style): a foreground service holds
/// the gateway's SSE stream, so notifications arrive in seconds instead
/// of the 15-minute WorkManager floor.
///
/// The service does the delivery natively (NotifyForegroundService.kt);
/// Dart only owns the toggle and the two things the service cannot know:
/// the credentials (baseUrl from DataStore, session from secure storage)
/// and where a tap should navigate.
///
/// While this mode is ON the Dart-side stream and the periodic poller must
/// stay OFF — two consumers share one cursor-then-ack queue and would
/// double-post. NotificationsService enforces that split.
const notifyServiceModeKey = 'notify.foregroundService';

final notifyServiceControllerProvider =
    Provider<NotifyServiceController>((ref) => NotifyServiceController(ref));

/// The switch state in the profile settings. Mirrors the persisted flag;
/// [NotifyServiceModeController.set] only flips on when the service
/// actually started (no session / platform refusal keeps it off).
final notifyServiceModeProvider =
    NotifierProvider<NotifyServiceModeController, bool>(NotifyServiceModeController.new);

class NotifyServiceModeController extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    final on = await ref.read(notifyServiceControllerProvider).isEnabled();
    if (on) state = true;
  }

  /// Returns whether the requested state was applied.
  Future<bool> set(bool on) async {
    final applied = await ref.read(notifyServiceControllerProvider).setEnabled(on);
    state = applied;
    // Hand delivery over (or take it back) immediately: the two halves
    // share one cursor, so leaving both attached double-rings.
    try {
      await ref.read(serverNotificationsServiceProvider).reconfigureForMode();
    } catch (_) {
      // Not logged in / service not mounted: the next login re-evaluates.
    }
    return on == applied;
  }
}

class NotifyServiceController {
  NotifyServiceController(this._ref) {
    _channel.setMethodCallHandler(_onCall);
    unawaited(_pullPendingRoute());
  }

  final Ref _ref;
  final MethodChannel _channel = const MethodChannel('fluctio/notify');

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notifyServiceModeKey) ?? false;
  }

  /// Turns the mode on or off and persists the choice. Returns the
  /// effective state (starting can fail — no session yet, OEM blocking
  /// foreground services — in which case the flag stays as it was).
  Future<bool> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    if (!on) {
      await _channel.invokeMethod<void>('stop');
      await prefs.setBool(notifyServiceModeKey, false);
      return false;
    }
    final config = _ref.read(configStoreProvider);
    final (base, insecure) = await (config.baseUrl(), config.allowSelfSigned()).wait;
    final sid = await _ref.read(credentialsStoreProvider).sessionId();
    if (base.isEmpty || sid == null || sid.isEmpty) {
      return false; // not configured yet; caller keeps the switch off
    }
    await _channel.invokeMethod<void>('start', {
      'base': base,
      'cookie': sid,
      'insecure': insecure,
    });
    await prefs.setBool(notifyServiceModeKey, true);
    return true;
  }

  /// Re-applies a persisted mode after login/app start, returning the
  /// effective state so the caller does not re-read the same pref.
  Future<bool> syncEnabled() async {
    if (!await isEnabled()) return false;
    return setEnabled(true);
  }

  Future<void> _pullPendingRoute() async {
    try {
      final route = await _channel.invokeMethod<String>('consumeRoute');
      if (route != null && route.isNotEmpty) _go(route);
    } catch (_) {
      // Channel missing (tests / unsupported platform): inert.
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method == 'open') {
      final route = call.arguments as String?;
      if (route != null && route.isNotEmpty) _go(route);
    }
  }

  void _go(String route) {
    try {
      _ref.read(routerProvider).go(appRouteForDeepLink(route));
    } catch (_) {
      // Router not mounted yet (cold-start race) — land on chat.
    }
  }
}
