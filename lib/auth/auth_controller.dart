import 'dart:io' show HttpClient;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config_store.dart';
import 'auth_state.dart';
import 'credentials_store.dart';

final configStoreProvider = Provider<ConfigStore>((ref) => ConfigStore(SharedPreferencesAsync()));

final credentialsStoreProvider = Provider<CredentialsStore>((ref) => CredentialsStore(defaultSecureStorage()));

/// Session lifecycle, mirrored from the gateway contract (docs/api/API.md):
/// login mints a `fluctio_session` cookie, no bearer token exists, and a
/// 401 anywhere means the session was revoked — back to the login screen.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// The server answered login 200-OK but didn't set the session cookie —
/// a protocol-level surprise, surfaced as its own message.
class AuthProtocolException implements Exception {
  final String message;
  const AuthProtocolException(this.message);

  @override
  String toString() => message;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();

  /// Auth calls use their own Dio instance instead of apiClientProvider.
  /// The shared client watches this controller (for cookie stamping), so
  /// reading it from inside a controller method is a dependency cycle —
  /// Riverpod 3 raises CircularDependencyError on exactly that shape.
  /// Auth is also special: it *establishes* the session, so it can't
  /// depend on the session-scoped client. No interceptors beyond a
  /// plain cookie stamp when a sid is already held.
  Dio _authClient() {
    final s = state;
    final dio = Dio(
      BaseOptions(
        baseUrl: s.baseUrl.isEmpty ? '/' : s.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'accept': 'application/json'},
      ),
    );
    if (s.allowSelfSigned) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient()..badCertificateCallback = (_, _, _) => true,
      );
    }
    final sid = s.sid;
    if (sid != null && sid.isNotEmpty) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['cookie'] = 'fluctio_session=$sid';
            handler.next(options);
          },
        ),
      );
    }
    return dio;
  }

  /// Cold-start restore: address from prefs, session id from the Keystore,
  /// then a live `/api/me` probe to tell "still valid" from "revoked".
  /// A network failure keeps the optimistic logged-in state — opening the
  /// app on a plane must not log you out; only an explicit 401 revokes.
  Future<void> restore() async {
    final config = ref.read(configStoreProvider);
    final baseUrl = await config.baseUrl();
    if (baseUrl.isEmpty) {
      state = const AuthState.needSetup();
      return;
    }
    final allowSelfSigned = await config.allowSelfSigned();
    final sid = await ref.read(credentialsStoreProvider).sessionId();
    if (sid == null || sid.isEmpty) {
      state = AuthState.loggedOut(baseUrl: baseUrl, allowSelfSigned: allowSelfSigned);
      return;
    }
    state = AuthState.loading(baseUrl: baseUrl, allowSelfSigned: allowSelfSigned, sid: sid);
    try {
      final res = await _authClient().get('/api/me');
      state = AuthState.loggedIn(
        baseUrl: baseUrl,
        allowSelfSigned: allowSelfSigned,
        sid: sid,
        user: res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null,
      );
    } catch (e) {
      final revoked = e is DioException && e.response?.statusCode == 401;
      if (revoked) {
        await ref.read(credentialsStoreProvider).clear();
        state = AuthState.loggedOut(baseUrl: baseUrl, allowSelfSigned: allowSelfSigned);
      } else {
        // Offline / server down: keep the session, re-probe on real use.
        state = AuthState.loggedIn(baseUrl: baseUrl, allowSelfSigned: allowSelfSigned, sid: sid);
      }
    }
  }

  /// Saves the server address (already validated by the form) and moves
  /// on to the login form. Connection probing has its own button.
  Future<void> saveServer(String baseUrl, {required bool allowSelfSigned}) async {
    await ref.read(configStoreProvider).setServer(baseUrl, allowSelfSigned: allowSelfSigned);
    state = AuthState.loggedOut(baseUrl: baseUrl, allowSelfSigned: allowSelfSigned);
  }

  /// Drops the stored address ("switch server" in settings).
  Future<void> clearServer() async {
    await ref.read(credentialsStoreProvider).clear();
    await ref.read(configStoreProvider).clearServer();
    state = const AuthState.needSetup();
  }

  Future<void> login(String login, String password) async {
    final s = state;
    final res = await _authClient().post('/api/login', data: {'login': login, 'password': password});
    final sid = _extractSessionCookie(res.headers.map['set-cookie'] ?? const []);
    if (sid == null) {
      throw const AuthProtocolException('login succeeded but no session cookie was set');
    }
    await ref.read(credentialsStoreProvider).saveSessionId(sid);
    final user = res.data is Map<String, dynamic> ? (res.data as Map<String, dynamic>)['user'] : null;
    state = AuthState.loggedIn(
      baseUrl: s.baseUrl,
      allowSelfSigned: s.allowSelfSigned,
      sid: sid,
      user: user is Map<String, dynamic> ? user : null,
    );
  }

  Future<void> logout() async {
    final s = state;
    try {
      await _authClient().post('/api/logout');
    } catch (_) {
      // Best-effort server-side revoke; local state clears regardless.
    }
    await ref.read(credentialsStoreProvider).clear();
    state = AuthState.loggedOut(baseUrl: s.baseUrl, allowSelfSigned: s.allowSelfSigned);
  }

  /// Called by the API client's 401 interceptor. A 401 on the login call
  /// itself (wrong password) must not flip a session that doesn't exist.
  void onUnauthorized() {
    if (state.status == AuthStatus.loggedIn) {
      ref.read(credentialsStoreProvider).clear();
      state = state.loggedOutCopy();
    }
  }

  String? _extractSessionCookie(List<String> setCookies) {
    for (final raw in setCookies) {
      final pair = raw.split(';').first.trim();
      if (pair.startsWith('fluctio_session=')) {
        final v = pair.substring('fluctio_session='.length);
        return v.isEmpty ? null : v;
      }
    }
    return null;
  }
}
