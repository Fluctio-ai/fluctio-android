import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

/// Local streaming proxy for cookie-gated media: players (ExoPlayer /
/// just_audio) can't attach the session cookie, so they play from
/// loopback /media URLs and this proxy pulls the upstream through dio
/// (cookie + self-signed allowance) and pipes it through — Range
/// requests included, so seeking works.
class MediaProxy {
  MediaProxy._();

  static final MediaProxy instance = MediaProxy._();

  HttpServer? _server;
  Dio? _dio;
  String? _cookie;

  /// Must run before first playback: hands over the authed dio and
  /// refreshes the cookie on every login.
  void configure(Dio dio, String? cookie) {
    _dio = dio;
    _cookie = cookie;
  }

  Future<int> ensureStarted() async {
    final s = _server;
    if (s != null) return s.port;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (_) {});
    return server.port;
  }

  /// The URL a player should use for one workspace file.
  Future<String> urlFor(String agentId, String path) async {
    final port = await ensureStarted();
    return 'http://127.0.0.1:$port/media?agentId=${Uri.encodeComponent(agentId)}'
        '&path=${Uri.encodeComponent(path)}';
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final dio = _dio;
      if (dio == null) {
        req.response.statusCode = HttpStatus.serviceUnavailable;
        await req.response.close();
        return;
      }
      final uri = req.uri;
      if (uri.path != '/media') {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      final agentId = uri.queryParameters['agentId'] ?? '';
      final path = uri.queryParameters['path'] ?? '';
      if (agentId.isEmpty || path.isEmpty) {
        req.response.statusCode = HttpStatus.badRequest;
        await req.response.close();
        return;
      }
      final range = req.headers.value(HttpHeaders.rangeHeader);
      final upstream = await dio.get<ResponseBody>(
        '/api/agents/$agentId/files/$path',
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            if (_cookie != null && _cookie!.isNotEmpty)
              'cookie': 'fluctio_session=$_cookie',
            // Range passthrough — seeking needs 206 support upstream.
            'range': ?range,
          },
        ),
      );
      final res = req.response;
      res.statusCode = upstream.statusCode ?? HttpStatus.ok;
      for (final h in const [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        'content-range',
        'accept-ranges',
      ]) {
        final v = upstream.headers.value(h);
        if (v != null) res.headers.set(h, v);
      }
      await res.addStream(upstream.data!.stream.cast<List<int>>());
      await res.close();
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.badGateway;
        await req.response.close();
      } catch (_) {}
    }
  }
}
