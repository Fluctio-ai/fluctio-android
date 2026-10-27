import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:fluctio_android/api/api_client.dart';
import 'package:fluctio_android/chat/chat_controller.dart';
import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/chat/turn_notify.dart';

/// Recording TurnNotify — the lifecycle/hub gating is covered by
/// turn_notify_test.dart; these tests assert the controller calls it.
/// Plain `test` file (no testWidgets): real loopback HTTP stays usable,
/// same scaffold as chat_integration_test.dart.
class _FakeTurnNotify extends TurnNotify {
  _FakeTurnNotify(super.ref);

  final doneCalls = <({String title, String snippet, String route})>[];
  final authCalls = <({String title, String description, String route})>[];

  @override
  void onTurnDone({required String title, required String snippet, required String route}) =>
      doneCalls.add((title: title, snippet: snippet, route: route));

  @override
  void onAuthPrompt({required String title, required String description, required String route}) =>
      authCalls.add((title: title, description: description, route: route));
}

void main() {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

  late HttpServer server;
  late ProviderContainer container;
  late _FakeTurnNotify fakeNotify;
  var streamMode = 'ok'; // 'ok' | 'auth' | 'hold'

  Future<void> until(String label, bool Function() cond,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(deadline)) {
        final st = container.read(chatStoreProvider);
        fail('[$label] not met within $timeout; chats=${st.chats.map((k, v) => MapEntry(k, '${v.phase}/${v.entries.length}'))}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// done/stop trigger a sessions reload whose continuation must land
  /// BEFORE the container teardown, or the disposed-ref error poisons
  /// the next test. Wait for the provider's data plus slack for the
  /// overlapping reload kicked off by the initial lazy build.
  Future<void> settleSessions() async {
    await until('sessions', () => container.read(sessionsProvider).hasValue);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

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
    streamMode = 'ok';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final path = req.uri.path;
      if (path == '/api/agents') {
        _json(req, {
          'agents': [
            {'id': 'agt_test', 'name': 'Test', 'model': 'm1'}
          ]
        });
      } else if (path == '/api/chat/sessions') {
        _json(req, {'sessions': []});
      } else if (path == '/api/chat/history') {
        _json(req, {'history': [], 'earliestSeq': 0, 'hasMore': false, 'latestEventSeq': 10});
      } else if (path == '/api/chat/stream' && req.method == 'POST') {
        // Drain the request body — left unread it can stall the client's
        // view of a long-held SSE response (hold mode).
        await utf8.decoder.bind(req).join();
        req.response.headers.set('Content-Type', 'text/event-stream');
        if (streamMode == 'auth') {
          await _sseFrame(req.response, 11, {
            'seq': 11,
            'type': 'auth_prompt',
            'data': {
              'description': 'run rm -rf',
              'options': [
                {'cmd': '/yes', 'label_zh': '好', 'label_en': 'OK'},
              ],
            },
          });
        } else {
          await _sseFrame(req.response, 11,
              {'seq': 11, 'type': 'content_delta', 'data': {'delta': 'Hel'}});
        }
        if (streamMode == 'hold') {
          // Cut the connection right after the first delta (no done):
          // the turn stays in flight client-side (streaming →
          // reconnecting), leaving it stop-able. A held-open response
          // never flushes the delta to dio over loopback — closing does.
          await req.response.close();
          return;
        }
        await _sseFrame(
            req.response, 12, {'seq': 12, 'type': 'content', 'data': {'content': 'Hello!'}});
        await _sseFrame(req.response, 13, {'seq': 13, 'type': 'done'});
        await req.response.close();
      } else if (path == '/api/chat/stop' && req.method == 'POST') {
        _json(req, {'status': 'ok'});
      } else if (path == '/api/chat/subscribe') {
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
      turnNotifyProvider.overrideWith((ref) => fakeNotify = _FakeTurnNotify(ref)),
    ]);
    container.read(turnNotifyProvider); // force-build the fake
    addTearDown(container.dispose);
    addTearDown(() => server.close(force: true));
  });

  test('done frame → turn-done alert with snippet and session route', () async {
    final key = await boot();
    await container.read(chatStoreProvider.notifier).send('hi');
    await until('done', () => fakeNotify.doneCalls.isNotEmpty);

    final call = fakeNotify.doneCalls.single;
    // No sessions list → title falls back to the agent name.
    expect(call.title, 'Test');
    expect(call.snippet, 'Hello!');
    expect(call.route, '/c/${key.split('|')[1]}');
    await settleSessions();
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('auth_prompt frame → action-needed alert carrying the description', () async {
    streamMode = 'auth';
    await boot();
    await container.read(chatStoreProvider.notifier).send('hi');
    await until('auth', () => fakeNotify.authCalls.isNotEmpty);

    expect(fakeNotify.authCalls.single.description, 'run rm -rf');
    await until('done', () => fakeNotify.doneCalls.isNotEmpty);
    await settleSessions();
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('explicit stop settles the turn without alerting', () async {
    streamMode = 'hold';
    final key = await boot();
    await container.read(chatStoreProvider.notifier).send('hi');
    await until('in flight',
        () => container.read(chatStoreProvider).chats[key]!.phase != TurnPhase.idle);

    await container.read(chatStoreProvider.notifier).stop();
    await until(
        'idle', () => container.read(chatStoreProvider).chats[key]!.phase == TurnPhase.idle);
    expect(fakeNotify.doneCalls, isEmpty);
    expect(fakeNotify.authCalls, isEmpty);
    await settleSessions();
  }, timeout: const Timeout(Duration(seconds: 20)));
}

void _json(HttpRequest req, Map<String, dynamic> body, {int status = 200}) {
  req.response.statusCode = status;
  req.response.headers.contentType = ContentType.json;
  req.response.write(jsonEncode(body));
  req.response.close();
}

Future<void> _sseFrame(HttpResponse res, int id, Map<String, dynamic> payload) async {
  // add(utf8) — res.write is latin-1-bound and throws on CJK payloads.
  res.add(utf8.encode('id: $id\ndata: ${jsonEncode(payload)}\n\n'));
  await res.flush();
}
