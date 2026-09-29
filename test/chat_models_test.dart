import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/models.dart';

void main() {
  test('AgentInfo.fromJson reads the handlers_agents.go:256 shape', () {
    final a = AgentInfo.fromJson({
      'id': 'agt_1',
      'name': 'Claw',
      'description': 'main',
      'model': 'gpt-x',
      'avatarUrl': '/api/agents/agt_1/files/avatar.png',
      'createdAt': 1,
      'userId': 'u1',
      'role': 'owner',
    });
    expect(a.id, 'agt_1');
    expect(a.name, 'Claw');
    expect(a.model, 'gpt-x');
  });

  test('ChatSessionInfo.fromJson tolerates omitted omitempty fields', () {
    final s = ChatSessionInfo.fromJson({'id': 'web-ui', 'title': 't', 'preview': 'p', 'createdAt': 5, 'updatedAt': 6});
    expect(s.id, 'web-ui');
    expect(s.chatOnly, isFalse);
    expect(s.projectId, '');
    final full = ChatSessionInfo.fromJson({
      'id': 's-1',
      'title': '',
      'preview': '',
      'chatOnly': true,
      'projectId': 'pj',
      'thumbnailUrl': 'https://x/y.png',
      'createdAt': 1,
      'updatedAt': 2,
    });
    expect(full.chatOnly, isTrue);
    expect(full.thumbnailUrl, 'https://x/y.png');
  });

  test('TodoData.fromJson parses items and ignores junk', () {
    final t = TodoData.fromJson({
      'items': [
        {'text': 'step 1', 'done': true},
        {'text': 'step 2'},
        {'text': 'step 3', 'cancelled': true},
        {'done': true}, // no text → skipped
        'junk',
      ],
      'raw': '- [x] step 1',
    });
    expect(t.items.length, 3);
    expect(t.items[0].done, isTrue);
    expect(t.items[2].cancelled, isTrue);
    expect(t.raw, '- [x] step 1');
  });

  test('HistoryPage.fromJson reads the handlers.go:1834 response', () {
    final p = HistoryPage.fromJson({
      'history': [
        {'role': 'user', 'content': 'q', 'seq': 3, 'timestamp': 10, 'imageUrls': ['data:a']},
        {
          'role': 'assistant',
          'content': '',
          'seq': 4,
          'toolCalls': [
            {'id': 'c1', 'name': 'exec', 'arguments': '{}'}
          ],
        },
        {'role': 'tool', 'content': 'out', 'name': 'exec', 'toolCallId': 'c1', 'seq': 5},
        {'role': 'assistant', 'kind': 'compaction_notice', 'content': 'shrunk'},
        {'role': 'user', 'kind': 'turn_aborted_notice', 'content': 'stopped mid-tool'},
      ],
      'earliestSeq': 3,
      'hasMore': true,
      'latestEventSeq': 42,
    });
    expect(p.messages.length, 5);
    expect(p.messages[0].imageUrls, ['data:a']);
    expect(p.messages[1].toolCalls.single.name, 'exec');
    expect(p.messages[2].toolCallId, 'c1');
    expect(p.messages[3].kind, 'compaction_notice');
    expect(p.messages[4].seq, isNull);
    expect(p.hasMore, isTrue);
    expect(p.latestSeq, 42);
  });
}
