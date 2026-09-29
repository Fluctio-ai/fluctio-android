import 'package:url_launcher/url_launcher.dart';

/// Opens an external http(s) link in the system browser; silently
/// ignores unparsable URLs and missing handlers (best-effort by design).
Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}
