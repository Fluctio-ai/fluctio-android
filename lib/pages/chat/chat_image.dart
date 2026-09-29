import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../auth/auth_controller.dart';
import '../../auth/session_cookie.dart';
import '../../chat/chat_controller.dart';
import '../../theme/tokens.dart';

/// Memoized providers per (cookie, url): data: URLs would otherwise
/// re-run base64Decode — plus a full byte-list hash for the image cache
/// lookup — on every rebuild of every visible bubble.
final _providerCache = <String, ImageProvider>{};

/// Resolves a chat image URL to an [ImageProvider]. Contract notes
/// (docs/api/API.md §4): inline vision content is data: URLs or absolute
/// HTTPS URLs; workspace deliverables surface as paths under the gateway,
/// whose GETs are cookie-gated — same-host loads carry the session cookie
/// in its named form (`fluctio_session=<sid>`), relative paths resolve
/// against baseUrl.
ImageProvider chatImageProvider(String url, {required String baseUrl, String? cookie}) {
  final cacheKey = '${cookie ?? ''}::$url';
  final cached = _providerCache[cacheKey];
  if (cached != null) return cached;
  final provider = _resolve(url, baseUrl: baseUrl, cookie: cookie);
  if (_providerCache.length > 128) _providerCache.clear();
  _providerCache[cacheKey] = provider;
  return provider;
}

ImageProvider _resolve(String url, {required String baseUrl, String? cookie}) {
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
  final sameHost =
      targetUri != null && base != null && isGatewayHost(targetUri, base);
  return NetworkImage(
    target,
    headers: sameHost && cookie != null && cookie.isNotEmpty
        ? {'cookie': sessionCookieHeader(cookie)}
        : null,
  );
}

/// Circular agent avatar (GET /api/agents/*/files/avatar.png — cookie
/// gated, so same-host loads carry the session cookie). Falls back to a
/// smart-toy tile when the agent has no avatar file.
class AgentAvatar extends ConsumerWidget {
  const AgentAvatar({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final avatarUrl = ref.watch(agentsProvider.select((a) => a.selected?.avatarUrl ?? ''));
    if (avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: scheme.secondaryContainer,
        child: Icon(LucideIcons.bot, size: size * 0.55, color: scheme.outline),
      );
    }
    return ClipOval(
      child: Image(
        image: chatImageProvider(avatarUrl, baseUrl: auth.baseUrl, cookie: auth.sid),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
          radius: size / 2,
          backgroundColor: scheme.secondaryContainer,
          child: Icon(LucideIcons.bot, size: size * 0.55, color: scheme.outline),
        ),
      ),
    );
  }
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
                  color: scheme.secondaryContainer,
                  child: Icon(LucideIcons.imageOff, size: 20, color: scheme.outline),
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
                  child: Icon(LucideIcons.x, size: 14, color: scheme.onInverseSurface),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
