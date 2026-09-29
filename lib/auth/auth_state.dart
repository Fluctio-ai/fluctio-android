enum AuthStatus { loading, needSetup, loggedOut, loggedIn }

/// Auth state machine for the whole app. `sid` lives in memory only;
/// its durable copy is the Keystore (CredentialsStore) — the state field
/// exists so the Dio interceptor can stamp the cookie synchronously.
class AuthState {
  final AuthStatus status;
  final String baseUrl;
  final bool allowSelfSigned;
  final String? sid;
  final Map<String, dynamic>? user;

  const AuthState({
    required this.status,
    this.baseUrl = '',
    this.allowSelfSigned = false,
    this.sid,
    this.user,
  });

  const AuthState.initial() : this(status: AuthStatus.loading);

  const AuthState.needSetup() : this(status: AuthStatus.needSetup);

  const AuthState.loggedOut({String baseUrl = '', bool allowSelfSigned = false})
      : this(status: AuthStatus.loggedOut, baseUrl: baseUrl, allowSelfSigned: allowSelfSigned);

  const AuthState.loading({String baseUrl = '', bool allowSelfSigned = false, String? sid})
      : this(status: AuthStatus.loading, baseUrl: baseUrl, allowSelfSigned: allowSelfSigned, sid: sid);

  const AuthState.loggedIn({required String baseUrl, required bool allowSelfSigned, required String sid, Map<String, dynamic>? user})
      : this(status: AuthStatus.loggedIn, baseUrl: baseUrl, allowSelfSigned: allowSelfSigned, sid: sid, user: user);

  AuthState loggedOutCopy() => AuthState.loggedOut(baseUrl: baseUrl, allowSelfSigned: allowSelfSigned);

  /// Display name for the signed-in account; the gateway's user object
  /// shape is documented as "待补" in the contract, so read defensively.
  String? get userLabel {
    final u = user;
    if (u == null) return null;
    final v = u['displayName'] ?? u['display_name'] ?? u['login'] ?? u['name'];
    return v is String && v.isNotEmpty ? v : null;
  }
}
