import 'package:webview_flutter/webview_flutter.dart';

/// The single owner of the session-cookie encoding (docs/api/API.md §1:
/// auth = `Cookie: fluctio_session=<sid>`; the backend's extract() parses
/// the named form only). Every transport that carries the session — the
/// Dio interceptor, the auth bootstrap client, the WebView container and
/// the image loader — goes through these helpers.
const kSessionCookieName = 'fluctio_session';

/// `fluctio_session=<sid>` header value; empty when no session is held.
String sessionCookieHeader(String? sid) =>
    sid == null || sid.isEmpty ? '' : '$kSessionCookieName=$sid';

/// Whether [url] targets the configured gateway (the cookie only travels
/// same-origin).
bool isGatewayHost(Uri url, Uri base) => url.host == base.host && url.port == base.port;

/// The session as a WebView cookie for the gateway host.
WebViewCookie sessionWebViewCookie(String sid, Uri base) => WebViewCookie(
      name: kSessionCookieName,
      value: sid,
      domain: base.host,
      path: '/',
    );
