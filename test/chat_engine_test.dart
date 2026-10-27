import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/chat/models.dart';

ChatEngine _primed({int seq = -1}) {
  final e = ChatEngine();
  if (seq >= 0) {
    e.loadHistory(HistoryPage(messages: [], earliestSeq: 0, hasMore: false, latestSeq: seq),
        older: false);
  }
  return e;
}

void main() {
  group('streaming turns', () {
    test('deltas accumulate, content commits the segment', () {
      final e = ChatEngine();
      e.beginSend('hi', const []);
      e.applyFrame(null, {'seq': 1, 'type': 'content_delta', 'data': {'delta': 'Hel'}});
      e.applyFrame(null, {'seq': -1, 'type': 'content_delta', 'data': {'delta': 'lo'}});
      var state = e.snapshot();
      expect(state.phase, TurnPhase.streaming);
      expect(state.entries.last, isA<AssistantEntry>());
      expect((state.entries.last as AssistantEntry).text, 'Hello');
      expect((state.entries.last as AssistantEntry).streaming, isTrue);

      e.applyFrame(2, {'seq': 2, 'type': 'content', 'data': {'content': 'Hello world'}});
      state = e.snapshot();
      final last = state.entries.last as AssistantEntry;
      expect(last.text, 'Hello world');
      expect(last.streaming, isFalse);
    });

    test('multi-iteration turns: second delta batch opens a new segment', () {
      final e = _primed(seq: 2);
      e.beginSend('q', const []);
      e.applyFrame(3, {'seq': 3, 'type': 'content', 'data': {'content': 'part 1'}});
      e.applyFrame(null, {'seq': -1, 'type': 'content_delta', 'data': {'delta': 'part 2'}});
      e.applyFrame(4, {'seq': 4, 'type': 'content', 'data': {'content': 'part 2 final'}});
      e.applyFrame(5, {'seq': 5, 'type': 'done'});
      final state = e.snapshot();
      final assistants = state.entries.whereType<AssistantEntry>().toList();
      expect(assistants.length, 2);
      expect(assistants[0].text, 'part 1');
      expect(assistants[1].text, 'part 2 final');
      expect(state.phase, TurnPhase.idle);
    });

    test('done commits a still-streaming bubble', () {
      final e = _primed();
      e.beginSend('q', const []);
      e.applyFrame(null, {'seq': -1, 'type': 'content_delta', 'data': {'delta': 'partial'}});
      final effects = e.applyFrame(9, {'seq': 9, 'type': 'done'});
      expect(effects.turnDone, isTrue);
      final last = e.snapshot().entries.last as AssistantEntry;
      expect(last.text, 'partial');
      expect(last.streaming, isFalse);
      expect(e.snapshot().phase, TurnPhase.idle);
    });
  });

  group('seq dedup', () {
    test('replayed frames (seq <= lastSeq) are skipped', () {
      final e = _primed(seq: 10);
      e.applyFrame(5, {'seq': 5, 'type': 'content', 'data': {'content': 'old'}});
      e.applyFrame(10, {'seq': 10, 'type': 'content', 'data': {'content': 'also old'}});
      expect(e.snapshot().entries.whereType<AssistantEntry>(), isEmpty);
      e.applyFrame(11, {'seq': 11, 'type': 'content', 'data': {'content': 'new'}});
      expect((e.snapshot().entries.last as AssistantEntry).text, 'new');
    });

    test('content_delta (seq -1) is never treated as a replay', () {
      final e = _primed(seq: 100);
      e.beginSend('q', const []);
      e.applyFrame(null, {'seq': -1, 'type': 'content_delta', 'data': {'delta': 'x'}});
      expect((e.snapshot().entries.last as AssistantEntry).text, 'x');
    });

    test('id line dedups frames whose JSON seq is missing', () {
      final e = _primed(seq: 3);
      e.applyFrame(3, {'type': 'content', 'data': {'content': 'dupe'}});
      expect(e.snapshot().entries.whereType<AssistantEntry>(), isEmpty);
      e.applyFrame(4, {'type': 'content', 'data': {'content': 'live'}});
      expect((e.snapshot().entries.last as AssistantEntry).text, 'live');
    });
  });

  group('tools', () {
    test('tool_call then tool_result pair by id', () {
      final e = _primed();
      e.beginSend('q', const []);
      e.applyFrame(1, {'seq': 1, 'type': 'tool_call', 'data': {'id': 'c1', 'name': 'search', 'arguments': '{"q":"x"}'}});
      e.applyFrame(2, {'seq': 2, 'type': 'tool_result', 'data': {'id': 'c1', 'name': 'search', 'result': 'hits'}});
      final tools = e.snapshot().entries.whereType<ToolEntry>().toList();
      expect(tools.length, 1);
      expect(tools[0].result, 'hits');
      expect(tools[0].arguments, '{"q":"x"}');
    });

    test('orphan tool_result becomes a standalone card', () {
      final e = _primed();
      e.applyFrame(1, {'seq': 1, 'type': 'tool_result', 'data': {'id': 'zz', 'name': 'exec', 'result': 'out'}});
      final tools = e.snapshot().entries.whereType<ToolEntry>().toList();
      expect(tools.length, 1);
      expect(tools[0].result, 'out');
    });

    test('nameless tool_call frames (dirty session_events replays) are dropped',
        () {
      // Real-world dirty row shape replayed from the server's event log:
      // early synthetic memory_search events were persisted without a
      // name — they used to render as a "工具调用" card stuck running.
      final e = _primed();
      e.applyFrame(1, {
        'seq': 1,
        'type': 'tool_call',
        'data': {'id': 'synth-memory_search', 'arguments': '[object Object]'},
      });
      expect(e.snapshot().entries.whereType<ToolEntry>(), isEmpty);

      e.applyFrame(2, {
        'seq': 2,
        'type': 'tool_call',
        'data': {
          'id': 'synth-memory_search',
          'name': 'memory_search',
          'arguments': '{"query":"好","limit":3}',
        },
      });
      final tools = e.snapshot().entries.whereType<ToolEntry>().toList();
      expect(tools.single.name, 'memory_search');
      expect(tools.single.arguments, '{"query":"好","limit":3}');
    });

    test('toggleTool flips expanded', () {
      final e = _primed();
      e.applyFrame(1, {'seq': 1, 'type': 'tool_call', 'data': {'id': 'c1', 'name': 'n'}});
      e.toggleTool('tc-c1');
      expect((e.snapshot().entries.whereType<ToolEntry>().single).expanded, isTrue);
    });
  });

  group('steer / auth / notices', () {
    test('steer echo dedups the optimistic pending bubble', () {
      final e = _primed();
      e.beginSend('q', const []);
      e.beginSteer('more input');
      e.applyFrame(1, {'seq': 1, 'type': 'steer', 'data': {'content': 'more input'}});
      final users = e.snapshot().entries.whereType<UserEntry>().toList();
      expect(users.where((u) => u.text == 'more input').length, 1);
      expect(users.where((u) => u.text == 'more input').single.pendingSteer, isFalse);
    });

    test('unmatched steer echo appends a user bubble', () {
      final e = _primed();
      e.applyFrame(1, {'seq': 1, 'type': 'steer', 'data': {'content': 'from web tab'}});
      expect(e.snapshot().entries.whereType<UserEntry>().single.text, 'from web tab');
    });

    test('dropSteer removes only the matching pending bubble', () {
      final e = _primed();
      e.beginSend('q', const []);
      e.beginSteer('x');
      e.dropSteer('x');
      expect(e.snapshot().entries.where((u) => u is UserEntry && u.pendingSteer), isEmpty);
    });

    test('auth_prompt parses options and markAuthAnswered flags it', () {
      final e = _primed();
      e.applyFrame(1, {
        'seq': 1,
        'type': 'auth_prompt',
        'data': {
          'description': 'run rm -rf',
          'options': [
            {'cmd': '/yes', 'label_zh': '授权执行', 'label_en': 'Approve'},
            {'cmd': '/no', 'label_zh': '拒绝', 'label_en': 'Deny'},
          ],
        },
      });
      final card = e.snapshot().entries.whereType<AuthPromptEntry>().single;
      expect(card.options.length, 2);
      expect(card.options.first.label('zh'), '授权执行');
      expect(card.options.first.label('en'), 'Approve');
      e.markAuthAnswered();
      expect((e.snapshot().entries.whereType<AuthPromptEntry>().single).answered, isTrue);
    });

    test('error event → serverError notice; session_title → effect', () {
      final e = _primed();
      e.applyFrame(1, {'seq': 1, 'type': 'error', 'data': {'message': 'boom'}});
      final notice = e.snapshot().entries.whereType<NoticeEntry>().single;
      expect(notice.kind, NoticeKind.serverError);
      expect(notice.text, 'boom');

      final fx = e.applyFrame(2,
          {'seq': 2, 'type': 'session_title', 'data': {'sessionKey': 's-1', 'title': 'New title'}});
      expect(fx.titleChanged, isTrue);
    });

    test('legacy bus frames (no type) are ignored, not rendered', () {
      final e = _primed();
      e.applyFrame(null, {'text': '616852424:1727714683780-0; Typing...', 'parseMode': 'text'});
      e.applyFrame(null, {'text': '', 'parseMode': 'text'});
      expect(e.snapshot().entries, isEmpty);
    });
  });

  group('send lifecycle', () {
    test('failLastSend flags the bubble for resend; takeFailedUser reclaims it', () {
      final e = _primed();
      e.beginSend('hello', const []);
      e.failLastSend();
      var user = e.snapshot().entries.whereType<UserEntry>().single;
      expect(user.failed, isTrue);
      expect(e.snapshot().phase, TurnPhase.idle);

      final reclaimed = e.takeFailedUser();
      expect(reclaimed!.text, 'hello');
      expect(e.snapshot().entries.whereType<UserEntry>(), isEmpty);
    });

    test('takeLastUserForRegenerate returns the last non-steer user turn', () {
      final e = _primed();
      e.beginSend('first', const []);
      e.applyFrame(1, {'seq': 1, 'type': 'done'});
      e.beginSteer('mid');
      final last = e.takeLastUserForRegenerate();
      expect(last!.text, 'first');
    });

    test('disconnect never settles a turn: markReconnecting keeps it active', () {
      final e = _primed();
      e.beginSend('q', const []);
      e.applyFrame(null, {'seq': -1, 'type': 'content_delta', 'data': {'delta': 'partial'}});
      e.markReconnecting();
      final state = e.snapshot();
      expect(state.phase, TurnPhase.reconnecting);
      expect(state.turnActive, isTrue);
      // Finish arrives over subscribe with a later seq.
      e.applyFrame(7, {'seq': 7, 'type': 'done'});
      expect(e.snapshot().phase, TurnPhase.idle);
    });

    test('progress frames recover streaming after reconnecting', () {
      final e = _primed();
      e.beginSend('q', const []);
      e.applyFrame(null, {'seq': -1, 'type': 'content_delta', 'data': {'delta': 'partial'}});
      e.markReconnecting();
      // Server's own reconnecting tier (upstream retries) only refreshes
      // the hint; the banner is a client-disconnect marker.
      e.applyFrame(null, {'seq': -1, 'type': 'reconnecting', 'data': {'attempt': 3}});
      expect(e.snapshot().statusHint, '3');
      // Subscribe re-anchor delivers progress: the banner clears (web
      // parity, chat-screen.tsx:1098) instead of sticking until done.
      e.applyFrame(null, {'seq': -1, 'type': 'content_delta', 'data': {'delta': ' more'}});
      final state = e.snapshot();
      expect(state.phase, TurnPhase.streaming);
      expect(state.statusHint, isEmpty);
      e.applyFrame(7, {'seq': 7, 'type': 'done'});
      expect(e.snapshot().phase, TurnPhase.idle);
    });

    test('explicit stop settles locally', () {
      final e = _primed();
      e.beginSend('q', const []);
      e.applyFrame(null, {'seq': -1, 'type': 'content_delta', 'data': {'delta': 'partial'}});
      e.markStopping();
      e.addLocalNotice(NoticeKind.stopped, '', NoticeTone.warn);
      e.settleStopped();
      final state = e.snapshot();
      expect(state.phase, TurnPhase.idle);
      expect((state.entries.whereType<AssistantEntry>().single).text, 'partial');
    });
  });

  group('history', () {
    test('maps roles, pairs tool results, notices carry no seq', () {
      final e = ChatEngine();
      e.loadHistory(
        HistoryPage(
          latestSeq: 30,
          earliestSeq: 2,
          hasMore: true,
          messages: const [
            HistoryMessage(role: 'user', content: 'q1', seq: 2, timestamp: 1),
            HistoryMessage(role: 'assistant', content: '', seq: 3, toolCalls: [
              ToolCallData(id: 'c1', name: 'search', arguments: '{}'),
            ]),
            HistoryMessage(role: 'tool', content: 'hits', name: 'search', toolCallId: 'c1', seq: 4),
            HistoryMessage(role: 'assistant', content: 'answer', seq: 5),
            HistoryMessage(role: 'assistant', kind: 'compaction_notice', content: 'compressed'),
            HistoryMessage(role: 'user', kind: 'turn_aborted_notice', content: 'turn aborted'),
          ],
        ),
        older: false,
      );
      final state = e.snapshot();
      // user, tool card, assistant, compaction notice, abort notice
      expect(state.entries.length, 5);
      final tool = state.entries.whereType<ToolEntry>().single;
      expect(tool.result, 'hits');
      expect(state.entries.whereType<NoticeEntry>().map((n) => n.kind),
          containsAll([NoticeKind.compaction, NoticeKind.turnAborted]));
      expect(state.historyHasMore, isTrue);
      expect(state.earliestSeq, 2);
      // Resume cursor comes from latestEventSeq (30), not the message max (5).
      expect(state.lastSeq, 30);
    });

    test('nameless toolCalls in history are skipped (dirty-row defense)', () {
      final e = ChatEngine();
      e.loadHistory(
        HistoryPage(
          earliestSeq: 1,
          hasMore: false,
          messages: const [
            HistoryMessage(role: 'assistant', content: '', toolCalls: [
              ToolCallData(id: 'synth-memory_search', name: '', arguments: '[object Object]'),
              ToolCallData(id: 'c2', name: 'exec', arguments: '{}'),
            ]),
          ],
        ),
        older: false,
      );
      final tools = e.snapshot().entries.whereType<ToolEntry>().toList();
      expect(tools.single.name, 'exec');
    });

    test('pagination prepends older pages', () {
      final e = ChatEngine();
      e.loadHistory(
        const HistoryPage(
          messages: [HistoryMessage(role: 'user', content: 'new', seq: 10)],
          earliestSeq: 10,
          hasMore: true,
        ),
        older: false,
      );
      e.loadHistory(
        const HistoryPage(
          messages: [HistoryMessage(role: 'user', content: 'old', seq: 5)],
          earliestSeq: 5,
          hasMore: false,
        ),
        older: true,
      );
      final state = e.snapshot();
      expect(state.entries.length, 2);
      expect((state.entries.first as UserEntry).text, 'old');
      expect(state.historyHasMore, isFalse);
      expect(state.earliestSeq, 5);
    });

    test('multimodal user history keeps imageUrls', () {
      final e = ChatEngine();
      e.loadHistory(
        const HistoryPage(
          messages: [HistoryMessage(role: 'user', content: 'look', imageUrls: ['data:image/png;base64,AA'])],
          earliestSeq: 1,
          hasMore: false,
        ),
        older: false,
      );
      expect((e.snapshot().entries.single as UserEntry).imageUrls.single, startsWith('data:'));
    });
  });
}
