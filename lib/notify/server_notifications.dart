import 'package:dio/dio.dart';

/// Shared plumbing for the two delivery halves of the notification
/// channel (contract §11): the foreground service (notifications_service
/// .dart) and the headless WorkManager worker (notification_poll_worker
/// .dart). Single-sourced here so the halves can't drift — a cursor-key
/// or channel mismatch desyncs them invisibly.

/// SharedPreferences cursor key: both halves MUST advance the same key.
const notifyCursorKey = 'notify.cursor';

/// Channel identity — system settings shows whichever half creates the
/// channel first, so both must register it identically.
const notifyChannelId = 'server_notifications';
String notifyChannelName(bool zh) => zh ? '网关通知' : 'Gateway notifications';
String notifyChannelDescription(bool zh) =>
    zh ? '待办提醒、卡片摘要、搁浅话题与日记盲点' : 'Todo reminders, cards digest, shelved topics and diary blindspots';

/// Repo page size — also the drain loop's "full page → keep paging" bound.
const notifyPageLimit = 50;

/// One row from the gateway's notification queue (contract §11): the
/// proactive sweeps (due todos / cards digest / shelved ledger / diary
/// blindspots) enqueue; the app drains them by polling (backgrounded) or
/// the SSE stream (foreground). Delivery is cursor+delete — acking a
/// watermark deletes server-side, so the client's `since` cursor is the
/// dedup source of truth.
class SrvNotification {
  const SrvNotification({
    required this.id,
    required this.agentId,
    required this.kind,
    required this.title,
    required this.body,
    required this.deepLink,
  });

  final int id;
  final String agentId;
  final String kind; // todo_reminder | cards_digest | shelved_nudge | blindspot
  final String title;
  final String body;
  final String deepLink; // web-relative path — map via appRouteForDeepLink

  factory SrvNotification.fromJson(Map<String, dynamic> j) => SrvNotification(
        id: (j['id'] as num).toInt(),
        agentId: j['agentId'] as String? ?? '',
        kind: j['kind'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        deepLink: j['deepLink'] as String? ?? '',
      );
}

/// Maps the server's web-shaped deep link to an in-app route (the
/// notification tap payload). The app is single-agent-perspective, so the
/// agent id segment is dropped; unknown paths land on chat. Keep in sync
/// with the sweeps' deepLink values (gateway_due_todo.go / cards_push.go /
/// shelved_push.go / blindspot_push.go / handlers_push.go chat replies)
/// and router.dart.
String appRouteForDeepLink(String deepLink) {
  final path = deepLink.split('?').first;
  if (path.endsWith('/knowledge/todos')) return '/kb/todos';
  if (path.endsWith('/knowledge/cards')) {
    return deepLink.contains('review=1') ? '/kb/cards/review' : '/kb/cards';
  }
  if (path.endsWith('/knowledge/diary')) return '/kb/diary';
  final chatIdx = path.indexOf('/chat/');
  if (chatIdx >= 0) {
    final sid = path.substring(chatIdx + '/chat/'.length);
    if (sid.isNotEmpty) return '/c/$sid';
  }
  return '/';
}

/// Thin gateway client for the notification queue. All calls ride the
/// authenticated business Dio (apiClientProvider) in the foreground; the
/// background worker builds its own bare Dio (see notification_poll_worker).
class ServerNotificationsRepo {
  ServerNotificationsRepo(this._dio);

  final Dio _dio;

  /// One polling page: rows with id > [since], plus the page's high-water
  /// mark (== [since] when empty) so the caller advances its cursor in one
  /// round-trip. An off-shape payload reads as an empty page — the cursor
  /// stays put and the next tick retries.
  Future<({List<SrvNotification> rows, int lastId})> list({
    required int since,
    int limit = notifyPageLimit,
  }) async {
    final res = await _dio.get('/api/notifications', queryParameters: {
      'since': since,
      'limit': limit,
    });
    final data = res.data;
    if (data is! Map) return (rows: const <SrvNotification>[], lastId: since);
    return (
      rows: [
        for (final r in (data['notifications'] as List? ?? const []))
          if (r is Map) SrvNotification.fromJson(Map<String, dynamic>.from(r)),
      ],
      lastId: (data['lastId'] as num?)?.toInt() ?? since,
    );
  }

  /// Cursor watermark ack: the server deletes everything up to [lastId].
  Future<void> ack(int lastId) async {
    await _dio.post('/api/notifications/ack', data: {'lastId': lastId});
  }
}

/// The drain loop both halves run: page through rows past [since], hand
/// each row to [notify], advance the local cursor via [onCursor] BEFORE
/// acking the watermark (the §11 invariant — a failed ack must not
/// re-deliver), and swallow ack errors (the 7-day server retention bounds
/// the strand). A full page keeps paging.
Future<void> drainQueue(
  ServerNotificationsRepo repo, {
  required int since,
  required Future<void> Function(int lastId) onCursor,
  required Future<void> Function(SrvNotification n) notify,
}) async {
  var page = await repo.list(since: since);
  while (page.rows.isNotEmpty) {
    for (final n in page.rows) {
      await notify(n);
    }
    await onCursor(page.lastId);
    try {
      await repo.ack(page.lastId);
    } catch (_) {}
    if (page.rows.length < notifyPageLimit) break;
    page = await repo.list(since: page.lastId);
  }
}
