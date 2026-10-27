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

/// In-memory ConfigStore — keeps the test off platform channels so no
/// binding is needed and real sockets stay available. The wrapped
/// SharedPreferencesAsync is never called: every method is overridden.
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

/// End-to-end drive of ChatStoreController against a real local HTTP/SSE
/// server: agents → history → send over POST /api/chat/stream → entries
/// published. Reproduces the device symptom class (sends that never
/// render) without any device in the loop.
void main() {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

  late HttpServer server;
  late ProviderContainer container;
  final postedBodies = <Map<String, dynamic>>[];
  // 'ok' — stream frames normally. 'fail-first' — kill the next
  // failKillsLeft POSTs at the socket level (network-class death before
  // any frame). 'http-error' — 500 with an error body; 'http-plain' —
  // 502 with a body that has no error field (unreadable for
  // sseErrorText, but still an HTTP-layer rejection).
  var postMode = 'ok';
  var failKillsLeft = 0;

  Future<void> until(String label, bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('[$label] not met within $timeout; '
            'agents=${container.read(agentsProvider)} '
            'store=${container.read(chatStoreProvider)} '
            'posted=${postedBodies.length}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Boots the container into an open session the way ChatPage's first
  /// frame does (chat store alive before agents load) and returns the
  /// active session key.
  Future<String> boot() async {
    container.read(chatStoreProvider.notifier);
    await container.read(agentsProvider.notifier).load();
    await until('agents', () => container.read(agentsProvider).selectedId == 'agt_test');
    await until('activeKey', () => container.read(chatStoreProvider).activeKey != null);
    final key = container.read(chatStoreProvider).activeKey!;
    await until('history', () => !container.read(chatStoreProvider).chats[key]!.historyLoading);
    return key;
  }

  setUp(() async {
    postedBodies.clear();
    postMode = 'ok';
    failKillsLeft = 0;
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
        _json(req, {'sessions': []});
      } else if (path == '/api/chat/history' && req.method == 'GET') {
        _json(req, {'history': [], 'earliestSeq': 0, 'hasMore': false, 'latestEventSeq': 10});
      } else if (path == '/api/chat/stream' && req.method == 'POST') {
        final body = jsonDecode(await utf8.decoder.bind(req).join());
        postedBodies.add(Map<String, dynamic>.from(body as Map));
        if (postMode == 'fail-first' && failKillsLeft-- > 0) {
          // Abrupt socket death, zero response bytes: a network-class
          // DioException with no HTTP response at all.
          final socket = await req.response.detachSocket();
          socket.destroy();
          return;
        }
        if (postMode == 'http-error') {
          _json(req, {'error': 'server says no'}, status: 500);
          return;
        }
        if (postMode == 'http-plain') {
          _json(req, {'oops': 'no error field'}, status: 502);
          return;
        }
        req.response.headers.set('Content-Type', 'text/event-stream');
        await req.response.flush();
        await _sseFrame(req.response, 11, {'seq': 11, 'type': 'content_delta', 'data': {'delta': 'Hel'}});
        await _sseFrame(req.response, 12, {'seq': 12, 'type': 'content', 'data': {'content': 'Hello!'}});
        await _sseFrame(req.response, 13, {'seq': 13, 'type': 'done'});
        await req.response.close();
      } else if (path == '/api/chat/subscribe' && req.method == 'GET') {
        req.response.headers.set('Content-Type', 'text/event-stream');
        req.response.write(': ok\n\n');
        await req.response.flush();
        // Hold open until the client goes away.
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
      configStoreProvider.overrideWithValue(_MemConfigStore()),
    ]);
    addTearDown(container.dispose);
    addTearDown(() => server.close(force: true));
  });

  test('send streams through POST /api/chat/stream into the transcript',
      () async {
    // Real-app ordering: the chat store is alive (ChatPage's first frame)
    // before agents load, so build()'s listener catches the transition.
    final key = await boot();
    expect(key.startsWith('agt_test|'), isTrue);

    await container.read(chatStoreProvider.notifier).send('hi');
    await until('assistant', () {
      final s = container.read(chatStoreProvider).chats[key]!;
      return s.entries.any((e) => e is AssistantEntry && e.text == 'Hello!');
    });

    final s = container.read(chatStoreProvider).chats[key]!;
    expect(s.phase, TurnPhase.idle);
    expect(s.lastSeq, 13);
    final user = s.entries.whereType<UserEntry>().single;
    expect(user.text, 'hi');
    expect(postedBodies.single['message'], 'hi');
    expect(postedBodies.single['agentId'], 'agt_test');
    expect(postedBodies.single['sessionId'], key.split('|')[1]);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('network death before the first frame auto-retries with rollback instead of failing',
      () async {
    // Phantom-failure symptom on mobile: the POST dies before any frame
    // (lock-screen blip, WiFi↔cellular switch) while the server may
    // already hold the message. The controller must retry once with
    // rollbackPendingUser — not mark the bubble failed.
    postMode = 'fail-first';
    failKillsLeft = 1;
    final key = await boot();

    await container.read(chatStoreProvider.notifier).send('hi');
    await until('retried', () => postedBodies.length == 2);
    expect(postedBodies[1]['rollbackPendingUser'], isTrue);
    await until('assistant', () {
      final s = container.read(chatStoreProvider).chats[key]!;
      return s.entries.any((e) => e is AssistantEntry && e.text == 'Hello!');
    });

    final s = container.read(chatStoreProvider).chats[key]!;
    expect(s.phase, TurnPhase.idle);
    // Exactly one user bubble, not failed — the retry superseded the mark.
    final users = s.entries.whereType<UserEntry>().toList();
    expect(users, hasLength(1));
    expect(users.single.failed, isFalse);
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('HTTP error before the first frame marks failed without retrying',
      () async {
    postMode = 'http-error';
    final key = await boot();

    await container.read(chatStoreProvider.notifier).send('hi');
    await until('failed', () {
      final s = container.read(chatStoreProvider).chats[key]!;
      return s.entries.whereType<UserEntry>().any((e) => e.failed);
    });
    // A real server rejection is not retried.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(postedBodies, hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('HTTP rejection with an unreadable body is still not retried',
      () async {
    // 502 without a parseable {"error": ...} field: sseErrorText returns
    // null, but the response object proves an HTTP-layer rejection —
    // the retry gate keys on that, not on body readability.
    postMode = 'http-plain';
    final key = await boot();

    await container.read(chatStoreProvider.notifier).send('hi');
    await until('failed', () {
      final s = container.read(chatStoreProvider).chats[key]!;
      return s.entries.whereType<UserEntry>().any((e) => e.failed);
    });
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(postedBodies, hasLength(1));
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('resend after a server rejection also auto-retries on network death',
      () async {
    // resendFailed passes rollback:true on its FIRST attempt, so the
    // retry gate must not lean on rollback as its generation marker.
    postMode = 'http-error';
    final key = await boot();
    await container.read(chatStoreProvider.notifier).send('hi');
    await until('failed', () {
      final s = container.read(chatStoreProvider).chats[key]!;
      return s.entries.whereType<UserEntry>().any((e) => e.failed);
    });

    postMode = 'fail-first';
    failKillsLeft = 1;
    await container.read(chatStoreProvider.notifier).resendFailed();
    await until('assistant', () {
      final s = container.read(chatStoreProvider).chats[key]!;
      return s.entries.any((e) => e is AssistantEntry && e.text == 'Hello!');
    });

    final s = container.read(chatStoreProvider).chats[key]!;
    expect(s.phase, TurnPhase.idle);
    expect(postedBodies, hasLength(3));
    expect(postedBodies[2]['rollbackPendingUser'], isTrue);
    final users = s.entries.whereType<UserEntry>().toList();
    expect(users, hasLength(1));
    expect(users.single.failed, isFalse);
  }, timeout: const Timeout(Duration(seconds: 20)));
}

void _json(HttpRequest req, Map<String, dynamic> body, {int status = 200}) {
  req.response.statusCode = status;
  req.response.headers.contentType = ContentType.json;
  req.response.write(jsonEncode(body));
  req.response.close();
}

Future<void> _sseFrame(HttpResponse res, int id, Map<String, dynamic> payload) async {
  res.write('id: $id\n');
  res.write('data: ${jsonEncode(payload)}\n\n');
  await res.flush();
}

