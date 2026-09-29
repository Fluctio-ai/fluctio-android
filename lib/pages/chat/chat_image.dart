import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Resolves a chat image URL to an [ImageProvider]. Contract notes
/// (docs/api/API.md §4): inline vision content is data: URLs or absolute
/// HTTPS URLs; workspace deliverables surface as paths under the gateway,
/// whose GETs are cookie-gated — same-host loads carry the session cookie,
/// relative paths resolve against baseUrl.
ImageProvider chatImageProvider(String url, {required String baseUrl, String? cookie}) {
  if (url.startsWith('data:')) {
    final comma = url.indexOf(',');
    if (comma > 0 && url.substring(0, comma).endsWith(';base64')) {
      try {
        return MemoryImage(base64Decode(url.substring(comma + 1)));
      } catch (_) {
        // fall through to the network path and its error builder
      }
    }
  }
  var target = url;
  final parsed = Uri.tryParse(url);
  if (parsed != null && !parsed.hasScheme && !parsed.hasAuthority) {
    target = '$baseUrl${url.startsWith('/') ? url : '/$url'}';
  }
  final base = Uri.tryParse(baseUrl);
  final targetUri = Uri.tryParse(target);
  final sameHost = targetUri != null &&
      base != null &&
      targetUri.host == base.host &&
      targetUri.port == base.port;
  return NetworkImage(target,
      headers: sameHost && cookie != null && cookie.isNotEmpty ? {'cookie': cookie} : null);
}

/// Square thumbnail used in user bubbles and the composer's pending strip.
class ChatImageThumb extends StatelessWidget {
  const ChatImageThumb({
    super.key,
    required this.url,
    required this.baseUrl,
    required this.cookie,
    this.onTap,
    this.onRemove,
    this.size = 96,
  });

  final String url;
  final String baseUrl;
  final String? cookie;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.cardBorder,
            child: ClipRRect(
              borderRadius: AppRadius.cardBorder,
              child: Image(
                image: chatImageProvider(url, baseUrl: baseUrl, cookie: cookie),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: size,
                  height: size,
                  color: scheme.secondary,
                  child: Icon(Icons.broken_image_outlined, size: 20, color: scheme.outline),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: onRemove,
                child: Container(
                  decoration: BoxDecoration(color: scheme.scrim, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 14, color: scheme.onInverseSurface),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
