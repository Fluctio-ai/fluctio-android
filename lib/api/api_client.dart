import 'dart:io' show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/session_cookie.dart';
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
          options.headers['cookie'] = sessionCookieHeader(sid);
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint('API ${error.requestOptions.method} ${error.requestOptions.uri} '
              '-> ${error.response?.statusCode ?? error.type} ${error.message}');
        }
        if (error.response?.statusCode == 401) {
          ref.read(authControllerProvider.notifier).onUnauthorized();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});

/// Parses a gateway list payload: a bare JSON array, or an object
/// wrapping the array under [key] (falling back to the first list-valued
/// field for envelopes whose wrapper name isn't pinned down). Non-map
/// rows are skipped defensively.
List<T> parseRows<T>(
  dynamic data, {
  String? key,
  required T Function(Map<String, dynamic>) fromJson,
}) {
  List? rows;
  if (data is List) {
    rows = data;
  } else if (data is Map) {
    if (key != null && data[key] is List) {
      rows = data[key] as List;
    } else {
      for (final v in data.values) {
        if (v is List) {
          rows = v;
          break;
        }
      }
    }
  }
  if (rows == null) return [];
  return [for (final r in rows) if (r is Map) fromJson(Map<String, dynamic>.from(r))];
}

/// Parses a single-object gateway payload; null when the shape isn't a map.
T? parseObject<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) =>
    data is Map ? fromJson(Map<String, dynamic>.from(data)) : null;

/// Localized error snackbar for API failures — the one failure surface
/// for non-chat screens (chat transcript failures render as NoticeEntry
/// chips instead).
void showApiError(BuildContext context, Object error) {
  final l = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(apiErrorMessage(error, l))));
}

/// Maps any API failure to localized user-facing copy.
String apiErrorMessage(Object error, AppLocalizations l) {
  if (isUnauthorized(error)) return l.errorInvalidCredentials;
  if (isRateLimited(error)) return l.errorRateLimited;
  if (error is ApiException) return error.message;
  if (error is AuthProtocolException) return error.message;
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code != null && code >= 500) return l.errorServerUnavailable;
  }
  return l.errorNetwork;
}
