import 'dart:io' show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../auth/credentials_store.dart';
import '../auth/session_cookie.dart';
import '../core/config_store.dart';
import 'notify_hub.dart' show LocalNotifyHub, isZhLocale;
import 'server_notifications.dart';

/// Background half of the server-notification channel (contract §11):
/// a WorkManager periodic task (15-min floor, OS-deferred under Doze —
/// morning-digest traffic doesn't care) drains the queue through its own
/// bare Dio, exactly the "different trust domain" pattern lib/update/
/// uses: no Riverpod, no session-cookie interceptor, no global-401 side
/// effects. A 401 here (session revoked server-side) just skips the tick.
///
/// Taps land via cold start: the headless engine has no UI, so this
/// worker's notification payload routes through the main engine's
/// launch-details handling (notify_hub.dart _init).
const notifyPollTask = 'fluctio-notify-poll';

@pragma('vm:entry-point')
void notificationPollDispatcher() => Workmanager().executeTask((task, inputData) async {
      try {
        await _drain();
      } catch (_) {
        // Bad network / revoked session: the next periodic tick retries.
      }
      return true;
    });

Future<void> _drain() async {
  final prefs = await SharedPreferences.getInstance();
  final config = ConfigStore(SharedPreferencesAsync());
  final base = await config.baseUrl();
  final sid = await CredentialsStore(defaultSecureStorage()).sessionId();
  // No server / logged out: nothing to poll (the task stays registered so
  // the next login doesn't have to re-register).
  if (base.isEmpty || sid == null || sid.isEmpty) return;

  final dio = Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'accept': 'application/json', 'cookie': sessionCookieHeader(sid)},
  ));
  if (await config.allowSelfSigned()) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..badCertificateCallback = (_, _, _) => true,
    );
  }
  final zh = isZhLocale();
  // Headless engine: a private plugin instance, initialized without a tap
  // callback (the main engine's launch-details path owns tap routing) —
  // and only once a row actually arrives, so empty ticks stay free.
  final plugin = FlutterLocalNotificationsPlugin();
  var pluginReady = false;
  await drainQueue(
    ServerNotificationsRepo(dio),
    since: prefs.getInt(notifyCursorKey) ?? 0,
    onCursor: (lastId) => prefs.setInt(notifyCursorKey, lastId),
    notify: (n) async {
      if (!pluginReady) {
        pluginReady = true;
        await plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
      }
      await plugin.show(
        id: n.id & 0x7fffffff,
        title: n.title,
        body: n.body,
        payload: appRouteForDeepLink(n.deepLink),
        notificationDetails: LocalNotifyHub.messageDetails(
          notifyChannelId,
          notifyChannelName(zh),
          channelDescription: notifyChannelDescription(zh),
        ),
      );
    },
  );
}
