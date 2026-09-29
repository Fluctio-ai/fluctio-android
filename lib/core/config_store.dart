import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive app config (server address, trust options) backed by
/// SharedPreferences. The session cookie itself never lands here — see
/// [lib/auth/credentials_store.dart] (Keystore-encrypted).
class ConfigStore {
  ConfigStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const _kBaseUrl = 'server.baseUrl';
  static const _kAllowSelfSigned = 'server.allowSelfSigned';
  static const _kChatAgentId = 'chat.agentId';

  Future<String> baseUrl() => _prefs.getString(_kBaseUrl).then((v) => v ?? '');

  Future<bool> allowSelfSigned() => _prefs.getBool(_kAllowSelfSigned).then((v) => v ?? false);

  Future<void> setServer(String baseUrl, {required bool allowSelfSigned}) async {
    await _prefs.setString(_kBaseUrl, baseUrl);
    await _prefs.setBool(_kAllowSelfSigned, allowSelfSigned);
  }

  Future<void> clearServer() => _prefs.remove(_kBaseUrl);

  // Chat surface remembrance (ticket 04): last agent + last session per
  // agent, so reopening the app lands where the user left off.
  Future<String?> chatAgentId() => _prefs.getString(_kChatAgentId);

  Future<void> setChatAgentId(String id) => _prefs.setString(_kChatAgentId, id);

  Future<String> chatSession(String agentId) =>
      _prefs.getString('chat.session.$agentId').then((v) => v ?? '');

  Future<void> setChatSession(String agentId, String sessionId) =>
      _prefs.setString('chat.session.$agentId', sessionId);
}
