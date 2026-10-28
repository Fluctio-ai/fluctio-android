import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/api/sse.dart';

/// SseClient idle-watchdog. dio's receiveTimeout only bounds the header
/// wait (io_adapter.dart), so a silently-dead SSE stream used to hang
/// forever — the "sent but no reply ever renders" root cause.
///
/// The harness is a raw-socket server speaking chunked HTTP by hand:
/// dart:io's HttpResponse never delivers flushed data while the response
/// stays unclosed, which is exactly the wrong shape for an SSE fixture.
/// A raw socket also models the real failure faithfully — an open TCP
/// path with nothing on the wire. No widget binding here
/// (see testwidgets-blocks-real-http).
void main() {
  late ServerSocket server;
  Timer? pinger;
  var ping = false;

  void sendFrame(Socket socket, int i) {
    final frame = 'id: $i\ndata: {"seq":$i}\n\n';
    socket.write('${frame.length.toRadixString(16)}\r\n$frame\r\n');
  }

  setUp(() async {
    ping = false;
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      var greeted = false;
      socket.listen((_) {
        // First client segment = the request head; answer once with
        // headers + one real frame, then either keep pinging or go
        // silent with the socket left open.
        if (greeted) return;
        greeted = true;
        socket.write('HTTP/1.1 200 OK\r\n'
            'Content-Type: text/event-stream\r\n'
            'Transfer-Encoding: chunked\r\n\r\n');
        sendFrame(socket, 1);
        if (ping) {
          var i = 2;
          pinger =
              Timer.periodic(const Duration(milliseconds: 100), (_) {
                sendFrame(socket, i++);
              });
        }
      });
    });
  });

  tearDown(() async {
    pinger?.cancel();
    await server.close();
  });

  test('silence past the idle budget kills the stream with receiveTimeout',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
    final sse = SseClient(dio, idleTimeout: const Duration(milliseconds: 300));
    final frames = <SseFrame>[];
    Object? error;
    final done = Completer<void>();
    sse.get('/api/chat/subscribe', const {}).listen(
          frames.add,
          onError: (Object e) {
            error = e;
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
          cancelOnError: true,
        );
    await done.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => fail('watchdog never fired on a silent stream'),
    );
    // The one real frame made it through before the silence.
    expect(frames, hasLength(1));
    expect(error, isA<DioException>());
    expect((error! as DioException).type, DioExceptionType.receiveTimeout);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('live traffic keeps the stream alive past the idle budget', () async {
    ping = true;
    final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'));
    final sse = SseClient(dio, idleTimeout: const Duration(milliseconds: 300));
    final frames = <SseFrame>[];
    Object? error;
    final sub = sse.get('/api/chat/subscribe', const {}).listen(
          frames.add,
          onError: (Object e) => error = e,
          cancelOnError: true,
        );
    // ~10 frames cadence; 1s >> the 300ms idle budget, so only traffic
    // can explain surviving it.
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    sub.cancel();
    expect(error, isNull);
    expect(frames.length, greaterThanOrEqualTo(5));
  }, timeout: const Timeout(Duration(seconds: 15)));
}
