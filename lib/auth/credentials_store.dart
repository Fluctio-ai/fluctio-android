import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the gateway session id (`fluctio_session` cookie value).
/// Stored in Android Keystore-backed encrypted storage — never in
/// SharedPreferences, never logged.
class CredentialsStore {
  CredentialsStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _kSid = 'auth.session_sid';

  Future<String?> sessionId() => _storage.read(key: _kSid);

  Future<void> saveSessionId(String sid) => _storage.write(key: _kSid, value: sid);

  Future<void> clear() => _storage.delete(key: _kSid);
}

/// Seam for tests: swap in a fake factory to avoid the platform channel.
FlutterSecureStorage defaultSecureStorage() => const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
