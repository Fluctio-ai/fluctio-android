import 'dart:io' show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Validation + reachability for the user-entered gateway address.
///
/// Policy (REQ §6): HTTPS everywhere; plain HTTP only for loopback /
/// RFC1918 hosts AND with the explicit self-signed trust opt-in.
enum ServerUrlError { invalidFormat, httpsRequired, lanNeedsTrust }

ServerUrlError? validateServerUrl(String raw, {required bool allowSelfSigned}) {
  final u = Uri.tryParse(raw.trim());
  if (u == null || !u.hasScheme || u.host.isEmpty) return ServerUrlError.invalidFormat;
  if (u.scheme == 'https') return null;
  if (u.scheme != 'http') return ServerUrlError.invalidFormat;
  final host = u.host;
  final isPrivate = host == 'localhost' ||
      host.startsWith('127.') ||
      host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      _is172Private(host);
  if (!isPrivate) return ServerUrlError.httpsRequired;
  if (!allowSelfSigned) return ServerUrlError.lanNeedsTrust;
  return null;
}

bool _is172Private(String host) {
  final parts = host.split('.');
  if (parts.length < 2) return false;
  final second = int.tryParse(parts[1]);
  return second != null && second >= 16 && second <= 31;
}

/// Normalizes for storage: trims, strips any trailing slash.
String normalizeServerUrl(String raw) => raw.trim().replaceAll(RegExp(r'/+$'), '');

/// Probes `GET /healthz` (unauthenticated, contract §2) with its own Dio
/// instance — the shared client's baseUrl comes from committed config,
/// which doesn't exist yet while the user is still typing the address.
Future<bool> probeHealth(String baseUrl, {required bool allowSelfSigned}) async {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
    validateStatus: (code) => code != null && code < 500,
  ));
  if (allowSelfSigned) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..badCertificateCallback = (_, _, _) => true,
    );
  }
  try {
    final res = await dio.get<String>('/healthz');
    return res.statusCode == 200 && (res.data?.contains('ok') ?? false);
  } catch (_) {
    return false;
  }
}
