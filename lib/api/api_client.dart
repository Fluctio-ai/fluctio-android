import 'dart:io' show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';

/// Generic API failure carrying the gateway's error text.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Status-code predicates — DioException flows through untouched; call
/// sites decide what 401/429 mean in context (the interceptor only owns
/// the global "session revoked" side effect).
bool isUnauthorized(Object e) => e is DioException && e.response?.statusCode == 401;
bool isRateLimited(Object e) => e is DioException && e.response?.statusCode == 429;

/// The gateway Dio client. Contract notes (docs/api/API.md):
/// - auth = `Cookie: fluctio_session=<sid>` header, stamped by the
///   interceptor from the in-memory auth state
/// - a 401 on any authenticated call means the session was revoked →
///   global logout via AuthController.onUnauthorized. The login call's
///   own 401 (wrong password) is a form error, not a global logout —
///   onUnauthorized no-ops unless a session exists.
final apiClientProvider = Provider<Dio>((ref) {
  final auth = ref.watch(authControllerProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: auth.baseUrl.isEmpty ? '/' : auth.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      // SSE endpoints override per-request; JSON calls keep the default.
      headers: {'accept': 'application/json'},
    ),
  );
  if (auth.allowSelfSigned) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()..badCertificateCallback = (_, _, _) => true,
    );
  }
  final sid = auth.sid;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (sid != null && sid.isNotEmpty) {
          options.headers['cookie'] = 'fluctio_session=$sid';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          ref.read(authControllerProvider.notifier).onUnauthorized();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});

/// Maps any API failure to localized user-facing copy.
String apiErrorMessage(Object error, AppLocalizations l) {
  if (isUnauthorized(error)) return l.errorInvalidCredentials;
  if (isRateLimited(error)) return l.errorRateLimited;
  if (error is ApiException) return error.message;
  return l.errorNetwork;
}
