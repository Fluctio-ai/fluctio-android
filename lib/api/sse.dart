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

/// Streams SSE frames over a Dio client. `receiveTimeout` is raised
/// per-request on purpose: the gateway pings every 30s, so a quiet 90s
/// window means the connection is dead, not merely thinking — the caller
/// treats that as a disconnect and reconnects via subscribe.
class SseClient {
  SseClient(this._dio);
  final Dio _dio;

  static final _streamOptions = Options(
    responseType: ResponseType.stream,
    headers: {'accept': 'text/event-stream'},
    receiveTimeout: const Duration(seconds: 90),
  );

  Stream<SseFrame> post(String path, {Object? body, CancelToken? cancelToken}) =>
      _open(() => _dio.post(path, data: body, options: _streamOptions, cancelToken: cancelToken));

  Stream<SseFrame> get(String path, Map<String, Object?> query, {CancelToken? cancelToken}) =>
      _open(() => _dio.get(path, queryParameters: query, options: _streamOptions, cancelToken: cancelToken));

  Stream<SseFrame> _open(Future<Response<ResponseBody>> Function() request) async* {
    final response = await request();
    final body = response.data;
    if (body == null) return;
    final parser = SseLineParser();
    await for (final line
        in body.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
      final frame = parser.pushLine(line);
      if (frame != null) yield frame;
    }
  }
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
