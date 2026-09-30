import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:fluctio_android/api/api_client.dart';
import 'package:fluctio_android/auth/auth_controller.dart';
import 'package:fluctio_android/chat/chat_controller.dart';
import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/core/config_store.dart';

/// In-memory ConfigStore — keeps the test off platform channels (mirrors
/// chat_integration_test.dart).
class _MemConfigStore extends ConfigStore {
  _MemConfigStore() : super(SharedPreferencesAsync());

  final Map<String, Object> values = {};

  @override
  Future<String> baseUrl() async => values['server.baseUrl'] as String? ?? '';

  @override
  Future<bool> allowSelfSigned() async => values['server.allowSelfSigned'] as bool? ?? false;

  @override
  Future<void> setServer(String baseUrl, {required bool allowSelfSigned}) async {
    values['server.baseUrl'] = baseUrl;
    values['server.allowSelfSigned'] = allowSelfSigned;
  }

  @override
  Future<void> clearServer() async => values.remove('server.baseUrl');

  @override
  Future<String?> chatAgentId() async => values['chat.agentId'] as String?;

  @override
  Future<void> setChatAgentId(String id) async => values['chat.agentId'] = id;

  @override
  Future<String> chatSession(String agentId) async =>
      values['chat.session.$agentId'] as String? ?? '';

  @override
  Future<void> setChatSession(String agentId, String sessionId) async =>
      values['chat.session.$agentId'] = sessionId;
}

/// Conversation-entry regression suite for the "bubbles vanished"
/// symptom class: a fresh conversation on entry (web parity), full
/// transcripts when (re-)entering an existing session, and transcripts
/// surviving a chatStoreProvider rebuild (any agentsProvider state
/// write — agent switch, reload), which used to wipe engines and kill
/// subscribe forever.
void main() {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

  late HttpServer server;
  late ProviderContainer container;

  Future<void> until(String label, bool Function() cond,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('[$label] not met; store=${container.read(chatStoreProvider)}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path;
      if (path == '/api/agents' && req.method == 'GET') {
        _json(req, {
          'agents': [
            {'id': 'agt_test', 'name': 'Test', 'model': 'm1'}
          ]
        });
      } else if (path == '/api/chat/sessions' && req.method == 'GET') {
        _json(req, {
          'sessions': [
            {'id': 's-old', 'title': '老会话', 'preview': 'hi', 'updatedAt': 2}
          ]
        });
      } else if (path == '/api/chat/history' && req.method == 'GET') {
        final sid = req.uri.queryParameters['sessionId'] ?? '';
        if (sid == 's-old') {
          _json(req, {
            'history': [
              {'role': 'user', 'content': 'q1', 'timestamp': 1, 'seq': 2},
              {
                'role': 'assistant',
                'timestamp': 1,
                'seq': 3,
                'toolCalls': [
                  {'id': 'c1', 'name': 'search', 'arguments': '{}'}
                ]
              },
              {
                'role': 'tool',
                'content': 'hits',
                'name': 'search',
                'toolCallId': 'c1',
                'timestamp': 1,
                'seq': 4
              },
              {'role': 'assistant', 'content': 'the answer', 'timestamp': 1, 'seq': 5},
            ],
            'earliestSeq': 2,
            'hasMore': false,
            'latestEventSeq': 5,
          });
        } else {
          _json(req, {'history': [], 'earliestSeq': 0, 'hasMore': false});
        }
      } else if (path == '/api/chat/subscribe' && req.method == 'GET') {
        req.response.headers.set('Content-Type', 'text/event-stream');
        req.response.write(': ok\n\n');
        await req.response.flush();
        await req.response.done.whenComplete(() {});
        unawaited(req.response.close());
      } else {
        _json(req, {'error': 'no route $path'}, status: 404);
      }
    });

    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(
        Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}')),
      ),
      configStoreProvider.overrideWithValue(_MemConfigStore()
        ..values['chat.agentId'] = 'agt_test'
        ..values['chat.session.agt_test'] = 's-old'),
    ]);
    addTearDown(container.dispose);
    addTearDown(() => server.close(force: true));
  });

  test('entry opens a fresh conversation, not the remembered session', () async {
    final chat = container.read(chatStoreProvider.notifier);
    await container.read(agentsProvider.notifier).load();
    await until('active', () => container.read(chatStoreProvider).activeKey != null);

    final store = container.read(chatStoreProvider);
    expect(store.activeSessionId, isNot('s-old'),
        reason: 'entry must land on a new conversation (web /agents/<id>/chat/ parity)');
    expect(store.active!.entries, isEmpty);
    expect(chat, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('entering an existing session renders user/assistant bubbles from history',
      () async {
    await container.read(agentsProvider.notifier).load();
    await until('active', () => container.read(chatStoreProvider).activeKey != null);
    await container
        .read(chatStoreProvider.notifier)
        .openSession('agt_test', 's-old');
    await until('history',
        () => container.read(chatStoreProvider).active!.historyLoading == false);

    final s = container.read(chatStoreProvider).active!;
    expect(s.entries.whereType<UserEntry>().map((e) => e.text), ['q1']);
    expect(s.entries.whereType<AssistantEntry>().map((e) => e.text), ['the answer']);
    expect(s.entries.whereType<ToolEntry>().single.name, 'search');
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('agents re-emit while viewing keeps the open session and transcript',
      () async {
    await container.read(agentsProvider.notifier).load();
    await until('active', () => container.read(chatStoreProvider).activeKey != null);
    await container
        .read(chatStoreProvider.notifier)
        .openSession('agt_test', 's-old');
    await until('history',
        () => container.read(chatStoreProvider).active!.historyLoading == false);

    // Any agentsProvider state write re-runs chatStoreProvider.build —
    // the open session must survive it (no yank-back, no wiped engines,
    // subscribe stays alive).
    await container.read(agentsProvider.notifier).load();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final store = container.read(chatStoreProvider);
    expect(store.activeSessionId, 's-old',
        reason: 'rebuild yanked the user back to another session');
    final s = store.active!;
    expect(s.entries.whereType<UserEntry>().map((e) => e.text), ['q1'],
        reason: 'user bubble vanished after agentsProvider re-emit');
    expect(s.entries.whereType<AssistantEntry>().map((e) => e.text), ['the answer'],
        reason: 'assistant bubble vanished after agentsProvider re-emit');
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('opening another session then returning shows full transcript', () async {
    final chat = container.read(chatStoreProvider.notifier);
    await container.read(agentsProvider.notifier).load();
    await until('active', () => container.read(chatStoreProvider).activeKey != null);

    // Tap "new chat" then go back to s-old through openSession.
    await chat.newChat();
    await until('new chat active',
        () => container.read(chatStoreProvider).activeSessionId != 's-old');
    await chat.openSession('agt_test', 's-old');
    await until('back on s-old',
        () => container.read(chatStoreProvider).activeSessionId == 's-old');

    final s = container.read(chatStoreProvider).active!;
    expect(s.entries.whereType<UserEntry>().map((e) => e.text), ['q1'],
        reason: 'user bubble vanished on re-enter');
    expect(s.entries.whereType<AssistantEntry>().map((e) => e.text), ['the answer'],
        reason: 'assistant bubble vanished on re-enter');
  }, timeout: const Timeout(Duration(seconds: 20)));
}

void _json(HttpRequest req, Map<String, dynamic> body, {int status = 200}) {
  req.response.statusCode = status;
  req.response.headers.contentType = ContentType.json;
  req.response.write(jsonEncode(body));
  req.response.close();
}
