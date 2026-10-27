/// The `/c/<sid>` chat-route builder — the single source for its shape
/// (deep-link `?seq=N` included). UI go-helpers (chat_nav), transcript
/// chips and notification payloads alike build through here, so a route
/// format change has exactly one edit point.
String chatSessionRoute(String sessionId, {int? seq}) {
  final base = '/c/${Uri.encodeComponent(sessionId)}';
  return seq == null ? base : '$base?seq=$seq';
}
