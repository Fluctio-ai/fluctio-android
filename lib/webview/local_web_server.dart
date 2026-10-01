import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';

/// Serves the bundled web UI (next-export snapshot, assets/webui.zip)
/// from loopback, proxying /api to the gateway — the WebView loads
/// instantly from local files, no self-signed TLS, and data requests
/// carry the session cookie via dio.
///
/// Route A of the local-webui plan: the snapshot is synced from
/// fastclaw/web/out by tool/sync_webui.py (one deflated zip, ~7.5MB).
/// Extracted once into app-support storage and re-extracted whenever
/// the bundled zip changes (size-stamped). Any path miss falls back to
/// the SPA shell, exactly like a static host would.
class LocalWebServer {
  LocalWebServer._();

  static final LocalWebServer instance = LocalWebServer._();

  HttpServer? _server;
  Dio? _dio;
  String? _cookie;
  String? _root;
  bool _ready = false;

  void configure(Dio dio, String? cookie) {
    _dio = dio;
    _cookie = cookie;
  }

  Future<int> ensureStarted() async {
    final s = _server;
    if (s != null) return s.port;
    await _ensureExtracted();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (_) {});
    return server.port;
  }

  Future<String> urlFor(String path) async {
    final port = await ensureStarted();
    final p = path.startsWith('/') ? path : '/$path';
    return 'http://127.0.0.1:$port$p';
  }

  // -- zip extraction ------------------------------------------------

  Future<void> _ensureExtracted() async {
    if (_ready) return;
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/webui');
    final stamp = File('${support.path}/webui.stamp');
    final data = await rootBundle.load('assets/webui.zip');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // Size stamp: a re-synced zip (different length) re-extracts; the
    // snapshot is build-time content, equal length ⇒ equal content.
    final stampValue = '${bytes.length}';
    if (!await root.exists() || !await stamp.exists() || await stamp.readAsString() != stampValue) {
      if (await root.exists()) await root.delete(recursive: true);
      await root.create(recursive: true);
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final f in archive.files) {
        if (!f.isFile) continue;
        // Defensive: zip entries must use forward slashes (the sync
        // script normalizes; a stray separator would create garbage
        // filenames on Android).
        final name = f.name.replaceAll('\\', '/');
        final out = File('${root.path}/$name');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(f.content as List<int>);
      }
      await stamp.writeAsString(stampValue);
    }
    _root = root.path;
    _ready = true;
  }

  // -- request handling ----------------------------------------------

  Future<void> _handle(HttpRequest req) async {
    try {
      if (req.uri.path.startsWith('/api/')) {
        await _proxyApi(req);
        return;
      }
      await _serveFile(req);
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  /// /api passthrough to the gateway: cookie attached by dio (the
  /// WebView can't reach the gateway's session cookie on a loopback
  /// origin), self-signed allowed.
  Future<void> _proxyApi(HttpRequest req) async {
    final dio = _dio;
    if (dio == null) {
      req.response.statusCode = HttpStatus.serviceUnavailable;
      await req.response.close();
      return;
    }
    final upstream = await dio.get<ResponseBody>(
      req.uri.toString(),
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          if (_cookie != null && _cookie!.isNotEmpty)
            'cookie': 'fluctio_session=$_cookie',
        },
      ),
    );
    final res = req.response;
    res.statusCode = upstream.statusCode ?? HttpStatus.ok;
    final v = upstream.headers.value(HttpHeaders.contentTypeHeader);
    if (v != null) res.headers.set(HttpHeaders.contentTypeHeader, v);
    await res.addStream(upstream.data!.stream.cast<List<int>>());
    await res.close();
  }

  Future<void> _serveFile(HttpRequest req) async {
    final res = req.response;
    final root = _root;
    if (root == null) {
      res.statusCode = HttpStatus.serviceUnavailable;
      await res.close();
      return;
    }
    // Normalize: strip query, trailing slash → index.html, block traversal.
    var path = Uri.decodeComponent(req.uri.path);
    if (path.startsWith('/')) path = path.substring(1);
    if (path.isEmpty) path = 'index.html';

    // Directory hit → canonical trailing-slash redirect (the web app
    // builds with trailingSlash:true; keeps client routing stable).
    if (!path.endsWith('.html')) {
      final dir = Directory('$root/$path');
      if (await dir.exists()) {
        res.statusCode = HttpStatus.movedPermanently;
        res.headers.set(HttpHeaders.locationHeader, '/$path/');
        await res.close();
        return;
      }
    }
    if (path.endsWith('/')) path += 'index.html';

    Future<bool> send(File f) async {
      if (!await f.exists()) return false;
      res.statusCode = HttpStatus.ok;
      res.headers.set(HttpHeaders.contentTypeHeader, _mime(f.path));
      res.headers.set(HttpHeaders.cacheControlHeader, 'max-age=3600');
      await res.addStream(f.openRead());
      await res.close();
      return true;
    }

    if (await send(File('$root/$path'))) return;
    if (!path.endsWith('.html') && await send(File('$root/$path/index.html'))) return;

    // SPA fallback — page navigations only (no extension, or .html):
    // a JS/RSC/txt miss must 404, otherwise the router parses HTML as
    // data and reloads in a loop.
    final looksLikePage = !path.contains('.') || path.endsWith('.html');
    if (looksLikePage && await send(File('$root/index.html'))) return;

    res.statusCode = HttpStatus.notFound;
    await res.close();
  }

  static String _mime(String p) {
    final ext = p.contains('.') ? p.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'html' || 'htm' => 'text/html; charset=utf-8',
      'js' || 'mjs' => 'application/javascript',
      'css' => 'text/css',
      'json' || 'map' => 'application/json',
      'txt' => 'text/plain; charset=utf-8',
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'ico' => 'image/x-icon',
      'woff' => 'font/woff',
      'woff2' => 'font/woff2',
      'ttf' => 'font/ttf',
      'wasm' => 'application/wasm',
      _ => 'application/octet-stream',
    };
  }
}

/// One-call wiring for call sites that hold a WidgetRef.
void configureLocalWebServer(WidgetRef ref) {
  final auth = ref.read(authControllerProvider);
  LocalWebServer.instance.configure(ref.read(apiClientProvider), auth.sid);
}
