import 'dart:async';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../router.dart';

/// The single owner of the FlutterLocalNotificationsPlugin instance.
/// Two plugin instances in one app fight over the native tap callback
/// (last initialize wins) and cancelAll is app-scoped, not
/// instance-scoped — every notification feature (todo reminders,
/// background turn alerts) must go through this hub.
///
/// Tap routing is payload-as-route: every notification carries its
/// destination route as the payload (`/kb/todos`, `/c/<sid>`), and the
/// hub go()es there — no per-feature tap handlers.
final localNotifyHubProvider = Provider<LocalNotifyHub>((ref) => LocalNotifyHub(ref));

class LocalNotifyHub {
  LocalNotifyHub(this._ref) {
    unawaited(_init());
  }

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final Completer<void> _initDone = Completer<void>();

  bool _ready = false;

  /// True once the platform plugin is initialized (never in unit tests —
  /// the plugin-less init throws and every call stays inert).
  bool get isReady => _ready;

  /// System-locale zh check, shared by every notification feature's
  /// copy (todo reminders, turn alerts) — one definition here.
  bool get localeIsZh => PlatformDispatcher.instance.locale.languageCode == 'zh';

  /// Completes when init finished (success or failure — check [isReady]).
  Future<void> get ready => _initDone.future;

  /// Raw plugin access for features with platform calls of their own
  /// (todo reminders' zonedSchedule exact-alarm fallback). Guard with
  /// [isReady] — in tests the instance exists but every call throws.
  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> _init() async {
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onTap,
      );
      // Cold start from a notification: the callback above only fires for
      // an already-running app; the launch tap is reported here.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final payload =
          (launch?.didNotificationLaunchApp ?? false) ? launch?.notificationResponse?.payload : null;
      _ready = true;
      if (payload != null) _go(payload);
    } catch (_) {
      // No platform implementation (unit tests): stay inert.
    } finally {
      if (!_initDone.isCompleted) _initDone.complete();
    }
  }

  void _onTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('/')) _go(payload);
  }

  void _go(String route) {
    try {
      _ref.read(routerProvider).go(route);
    } catch (_) {
      // Router not mounted yet (cold start race) — land on chat.
    }
  }

  /// Instant heads-up notification. [payload] is the tap destination
  /// route (see class doc).
  Future<void> show({
    required int id,
    required String channelId,
    required String channelName,
    String? channelDescription,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  /// POST_NOTIFICATIONS runtime prompt (Android 13+); no-op when granted.
  void requestPermission() {
    try {
      // Errors surface on the returned Future — swallow those too.
      _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission()
          .catchError((_) => null);
    } catch (_) {} // plugin-less environments (tests)
  }
}
