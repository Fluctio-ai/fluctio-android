import 'dart:convert';

import 'package:dio/dio.dart';

/// One parsed SSE frame: an optional `id:` line plus one or more `data:`
/// lines joined with `\n` (contract docs/api/API.md §4 — the gateway never
/// sends an `event:` line). Comment-only frames (`: ping`, `: ok`) never
/// surface; they are keepalive only.
class SseFrame {
  const SseFrame({this.id, required this.data});
  final int? id;
  final String data;
}

/// Line-level SSE parser. Push every line the wire produces, in order;
/// frames come back on the blank line that terminates them.
class SseLineParser {
  final List<String> _data = <String>[];
  int? _id;

  SseFrame? pushLine(String line) {
    if (line.isEmpty) {
      if (_data.isEmpty) return null; // separator right after a comment
      final frame = SseFrame(id: _id, data: _data.join('\n'));
      _data.clear();
      _id = null;
      return frame;
    }
    if (line.startsWith(':')) return null; // ping / ok comment
    if (line.startsWith('id:')) {
      _id = int.tryParse(line.substring(3).trim());
      return null;
    }
    if (line.startsWith('data:')) {
      var value = line.substring(5);
      if (value.startsWith(' ')) value = value.substring(1);
      _data.add(value);
    }
    // Other field names are ignored per the SSE spec.
    return null;
  }
}

/// Streams SSE frames over a Dio client.
///
/// dio's `receiveTimeout` only bounds the wait for response *headers*
/// (io_adapter.dart wraps `request.close()` in `.timeout()`) — it never
/// fires once the body stream is flowing. Liveness on an open stream
/// therefore comes from the watchdog `.timeout(idleTimeout)` on the raw
/// chunk stream: any byte (a 30s `: ping` included) resets it, so
/// silence past the budget means the TCP path died without a FIN — the
/// stream errors with a receiveTimeout-shaped DioException and the
/// caller's normal disconnect path takes over (reconnect via subscribe,
/// `since=lastSeq` replay). Before the watchdog this was the "sent but
/// no reply ever renders" bug: a silently-dead socket just hung forever.
class SseClient {
  SseClient(this._dio, {this.idleTimeout = const Duration(seconds: 90)});
  final Dio _dio;

  /// Silence budget on an open stream. The gateway pings every 30s
  /// (contract §4), so 90s of nothing is decisively dead, not thinking.
  final Duration idleTimeout;

  static final _streamOptions = Options(
    responseType: ResponseType.stream,
    headers: {'accept': 'text/event-stream'},
    receiveTimeout: const Duration(seconds: 90),
  );

  Stream<SseFrame> post(String path, {Object? body, CancelToken? cancelToken}) =>
      _open(() => _dio.post(path, data: body, options: _streamOptions, cancelToken: cancelToken),
          cancelToken);

  Stream<SseFrame> get(String path, Map<String, Object?> query, {CancelToken? cancelToken}) =>
      _open(
          () => _dio.get(path, queryParameters: query, options: _streamOptions, cancelToken: cancelToken),
          cancelToken);

  Stream<SseFrame> _open(
      Future<Response<ResponseBody>> Function() request, CancelToken? cancelToken) async* {
    final Response<ResponseBody> response;
    try {
      response = await request();
    } on DioException catch (e) {
      // Deliberate cancellation (switch/dispose/stop): the subscription is
      // often gone by now, so letting this escape turns into an unhandled
      // zone error. Errors nobody asked for still rethrow.
      if (_isCancelled(e, cancelToken)) return;
      rethrow;
    }
    final body = response.data;
    if (body == null) return;
    final parser = SseLineParser();
    try {
      // The watchdog rides the raw chunk stream — before decoding — so a
      // header-less partial line still counts as traffic. On timeout the
      // error is injected into the stream, which unwinds this await for
      // and cancels the upstream response body (the dead socket goes
      // with it).
      await for (final line in body.stream
          .timeout(idleTimeout, onTimeout: (sink) {
        sink.addError(DioException.receiveTimeout(
          timeout: idleTimeout,
          requestOptions: response.requestOptions,
        ));
      })
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final frame = parser.pushLine(line);
        if (frame != null) yield frame;
      }
    } on DioException catch (e) {
      if (_isCancelled(e, cancelToken)) return;
      rethrow;
    }
  }

  static bool _isCancelled(DioException e, CancelToken? token) =>
      token?.isCancelled == true || e.type == DioExceptionType.cancel;
}

/// Early-failure text extraction for SSE requests: dio raises a
/// DioException with a still-undecoded [ResponseBody] for non-2xx stream
/// replies, and the gateway's early errors are JSON — both the `{"ok":false}`
/// and the bare `{"error":...}` shapes (contract §0). Returns null when
/// nothing readable is there.
Future<String?> sseErrorText(Object error) async {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is ResponseBody) {
    try {
      final bytes = <int>[];
      await for (final chunk in data.stream) {
        bytes.addAll(chunk);
      }
      return _errorField(jsonDecode(utf8.decode(bytes)));
    } catch (_) {
      return null;
    }
  }
  return _errorField(data);
}

String? _errorField(Object? decoded) {
  if (decoded is Map) {
    final error = decoded['error'];
    if (error is String && error.isNotEmpty) return error;
  }
  return null;
}
