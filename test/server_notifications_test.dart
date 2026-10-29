import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/notify/server_notifications.dart';

void main() {
  group('SrvNotification.fromJson', () {
    test('parses a full row', () {
      final n = SrvNotification.fromJson({
        'id': 7,
        'agentId': 'agt_x',
        'kind': 'blindspot',
        'title': '🔍 可能漏了的事',
        'body': '…',
        'deepLink': '/agents/agt_x/knowledge/diary',
        'createdAt': '2026-10-29T00:00:00Z',
      });
      expect(n.id, 7);
      expect(n.kind, 'blindspot');
      expect(n.title, '🔍 可能漏了的事');
      expect(n.agentId, 'agt_x');
    });

    test('missing optional fields fall back to empty strings', () {
      final n = SrvNotification.fromJson({'id': 1});
      expect(n.title, '');
      expect(n.deepLink, '');
    });
  });

  group('appRouteForDeepLink', () {
    test('maps every sweep deep link to its app route', () {
      // Keep in sync with the gateway sweeps' deepLink values.
      expect(appRouteForDeepLink('/agents/agt_x/knowledge/todos'), '/kb/todos');
      expect(appRouteForDeepLink('/agents/agt_x/knowledge/cards?review=1'), '/kb/cards/review');
      expect(appRouteForDeepLink('/agents/agt_x/knowledge/cards'), '/kb/cards');
      expect(appRouteForDeepLink('/agents/agt_x/knowledge/diary'), '/kb/diary');
    });

    test('chat replies land on their session', () {
      expect(appRouteForDeepLink('/agents/agt_x/chat/web-sess'), '/c/web-sess');
    });

    test('unknown paths land on chat', () {
      expect(appRouteForDeepLink('/agents/agt_x/somewhere/else'), '/');
      expect(appRouteForDeepLink(''), '/');
    });
  });
}
