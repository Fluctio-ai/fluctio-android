import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/chat/models.dart';
import 'package:fluctio_android/chat/slash_commands.dart';

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
    expect(s.channel, '');
    expect(s.isImChannel, isFalse);
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

  test('ChatSessionInfo channel marks IM sessions read-only', () {
    // Empty and 'web' compose normally; anything else is an IM channel
    // (web parity, chat-screen.tsx:1408).
    expect((const ChatSessionInfo(id: 'a')).isImChannel, isFalse);
    expect((const ChatSessionInfo(id: 'a', channel: 'web')).isImChannel, isFalse);
    expect((const ChatSessionInfo(id: 'a', channel: 'wechat')).isImChannel, isTrue);
    expect(ChatSessionInfo.fromJson(
            {'id': 'b', 'channel': 'telegram', 'accountId': 'u1', 'chatId': 'c1'}).channel,
        'telegram');
  });

  test('channelLabel mirrors the web channelLabel map', () {
    expect(channelLabel('wechat'), 'WeChat');
    expect(channelLabel('qq'), 'QQ');
    expect(channelLabel('feishu'), 'Feishu');
    expect(channelLabel('telegram'), 'Telegram');
    expect(channelLabel('discord'), 'Discord');
    expect(channelLabel('slack'), 'Slack');
    expect(channelLabel('line'), 'LINE');
    expect(channelLabel(''), 'Web');
    expect(channelLabel('web'), 'Web');
    expect(channelLabel('mystery'), 'Web');
  });

  test('read-only slash gate matches the web READ_ONLY_SLASH_COMMANDS', () {
    // Web parity (chat-screen.tsx:155, 987-993): status queries pass in
    // an IM-channel session, mutating commands don't.
    expect(isReadOnlySafeSlashCommand('/help'), isTrue);
    expect(isReadOnlySafeSlashCommand('/status'), isTrue);
    expect(isReadOnlySafeSlashCommand('/usage today'), isTrue);
    expect(isReadOnlySafeSlashCommand('/insights'), isTrue);
    expect(isReadOnlySafeSlashCommand('/version'), isTrue);
    expect(isReadOnlySafeSlashCommand('/new'), isFalse);
    expect(isReadOnlySafeSlashCommand('/model'), isFalse);
    expect(isReadOnlySafeSlashCommand('hello'), isFalse);
    expect(isReadOnlySafeSlashCommand(''), isFalse);
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

  test('PendingAttachment round-trips the API.md §4 wire shape', () {
    const a = PendingAttachment(name: 'report.pdf', url: 'data:application/pdf;base64,AA==');
    expect(a.toJson(), {'url': 'data:application/pdf;base64,AA==', 'name': 'report.pdf'});
    final back = PendingAttachment.fromJson(a.toJson());
    expect(back.name, 'report.pdf');
    expect(back.url, 'data:application/pdf;base64,AA==');
    // Cache-replayed entries carry the name only (v3 migration drops the
    // bytes); fromJson must still read that back without a url.
    final nameOnly = PendingAttachment.fromJson({'name': 'notes.txt'});
    expect(nameOnly.name, 'notes.txt');
    expect(nameOnly.url, isEmpty);
  });

  test('UserEntry.beginSend carries attachments for resend/regenerate', () {
    final engine = ChatEngine();
    engine.beginSend('check this', const [],
        attachments: const [PendingAttachment(name: 'a.zip', url: 'data:application/zip;base64,AA==')]);
    final last = engine.takeLastUserForRegenerate();
    expect(last, isNotNull);
    expect(last!.attachments.single.name, 'a.zip');
    // The engine hands the raw list back; filtering empty urls (cache
    // replay) is the controller's job.
    expect(last.attachments.single.url, isNotEmpty);
  });

  test('attachmentBreadcrumb matches the web [Attached: /workspace/X] lines', () {
    expect(attachmentBreadcrumb(const []), isEmpty);
    const files = [
      PendingAttachment(name: 'report.pdf', url: 'data:application/pdf;base64,AA=='),
      PendingAttachment(name: '数据.zip', url: 'data:application/zip;base64,AA=='),
    ];
    expect(attachmentBreadcrumb(files),
        '[Attached: /workspace/report.pdf]\n[Attached: /workspace/数据.zip]');
  });
}
