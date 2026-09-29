import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import 'auth_state.dart';
import 'credentials_store.dart';
import '../core/config_store.dart';

final configStoreProvider = Provider<ConfigStore>((ref) => ConfigStore(SharedPreferencesAsync()));

final credentialsStoreProvider = Provider<CredentialsStore>((ref) => CredentialsStore(defaultSecureStorage()));

/// Session lifecycle, mirrored from the gateway contract (docs/api/API.md):
/// login mints a `fluctio_session` cookie, no bearer token exists, and a
/// 401 anywhere means the session was revoked — back to the login screen.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.initial();

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
      final res = await ref.read(apiClientProvider).get('/api/me');
      state = AuthState.loggedIn(
        baseUrl: baseUrl,
        allowSelfSigned: allowSelfSigned,
        sid: sid,
        user: res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null,
      );
    } catch (e) {
      if (isUnauthorized(e)) {
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
    final res = await ref.read(apiClientProvider).post('/api/login', data: {'login': login, 'password': password});
    final sid = _extractSessionCookie(res.headers.map['set-cookie'] ?? const []);
    if (sid == null) {
      throw const ApiException('login succeeded but no session cookie was set');
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
      await ref.read(apiClientProvider).post('/api/logout');
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
