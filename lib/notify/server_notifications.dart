import 'package:dio/dio.dart';

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
/// shelved_push.go / blindspot_push.go) and router.dart.
String appRouteForDeepLink(String deepLink) {
  final path = deepLink.split('?').first;
  if (path.endsWith('/knowledge/todos')) return '/kb/todos';
  if (path.endsWith('/knowledge/cards')) {
    return deepLink.contains('review=1') ? '/kb/cards/review' : '/kb/cards';
  }
  if (path.endsWith('/knowledge/diary')) return '/kb/diary';
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
  /// round-trip.
  Future<({List<SrvNotification> rows, int lastId})> list({required int since, int limit = 50}) async {
    final res = await _dio.get('/api/notifications', queryParameters: {
      'since': since,
      'limit': limit,
    });
    final data = res.data;
    if (data is! Map) {
      throw DioException.badResponse(
        statusCode: 0,
        requestOptions: RequestOptions(path: '/api/notifications'),
        response: Response(requestOptions: RequestOptions(path: '/api/notifications'), data: data),
      );
    }
    final rows = [
      for (final r in (data['notifications'] as List? ?? const []))
        if (r is Map) SrvNotification.fromJson(Map<String, dynamic>.from(r)),
    ];
    final lastId = (data['lastId'] as num?)?.toInt() ?? since;
    return (rows: rows, lastId: lastId);
  }

  /// Cursor watermark ack: the server deletes everything up to [lastId].
  Future<void> ack(int lastId) async {
    await _dio.post('/api/notifications/ack', data: {'lastId': lastId});
  }
}
