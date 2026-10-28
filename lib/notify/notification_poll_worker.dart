import 'dart:io' show HttpClient;
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

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
const _cursorKey = 'notify.cursor'; // same key as the foreground service
const _channelId = 'server_notifications';

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
  final base = prefs.getString('server.baseUrl') ?? '';
  final sid = await const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ).read(key: 'auth.session_sid');
  // No server / logged out: nothing to poll (the task stays registered so
  // the next login doesn't have to re-register).
  if (base.isEmpty || sid == null || sid.isEmpty) return;

  final dio = Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'accept': 'application/json', 'cookie': 'fluctio_session=$sid'},
  ));
  if (prefs.getBool('server.allowSelfSigned') ?? false) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..badCertificateCallback = (_, _, _) => true,
    );
  }
  final repo = ServerNotificationsRepo(dio);
  var since = prefs.getInt(_cursorKey) ?? 0;
  var page = await repo.list(since: since);
  if (page.rows.isEmpty) return;

  // Headless engine: a private plugin instance, initialized without a tap
  // callback (the main engine's launch-details path owns tap routing).
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
  final zh = PlatformDispatcher.instance.locale.languageCode == 'zh';
  while (page.rows.isNotEmpty) {
    for (final n in page.rows) {
      await plugin.show(
        id: n.id & 0x7fffffff,
        title: n.title,
        body: n.body,
        payload: appRouteForDeepLink(n.deepLink),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            zh ? '网关通知' : 'Gateway notifications',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
          ),
        ),
      );
    }
    since = page.lastId;
    await prefs.setInt(_cursorKey, since);
    try {
      await repo.ack(since);
    } catch (_) {}
    if (page.rows.length < 50) break;
    page = await repo.list(since: since);
  }
}
