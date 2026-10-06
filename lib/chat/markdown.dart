import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../webview/web_container.dart';

/// The markdown bundle every transcript surface uses (chat bubbles, KB
/// readers): math delimiters, LaTeX normalization, link routing and the
/// mermaid card all live here — wiring these per callsite is how KB
/// pages silently lost math once.
///
/// Block styles (code/table/quote/hr) live in [AppTheme]'s
/// [GptMarkdownThemeData.styleSheet]; the locale-dependent body height
/// can't (themes don't see the locale), so it is applied per config.

/// ```mermaid fenced blocks are a custom block type (registered ahead of
/// the built-in fenced-code rule), so standard code keeps the package's
/// default rendering untouched.
const MarkdownBlockComponent _mermaidBlock = MarkdownBlockComponent(
  syntax: FencedBlockSyntax(type: 'mermaid', opening: '```mermaid', closing: '```'),
  builder: _mermaidCardFor,
);

Widget _mermaidCardFor(BuildContext context, MdCustomBlock node, GptMarkdownConfig config) =>
    _mermaidCard(context, node.body);

/// Mermaid fenced blocks become a tappable card that opens the
/// full-screen WebView renderer (ticket 10).
Widget _mermaidCard(BuildContext context, String source) {
  final theme = Theme.of(context);
  final l = AppLocalizations.of(context)!;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: InkWell(
      onTap: () => openMermaidViewer(context, source),
      borderRadius: AppRadius.cardBorder,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.workflow, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l.mermaidHint, style: theme.textTheme.bodySmall)),
            const Icon(LucideIcons.maximize2, size: 14),
          ],
        ),
      ),
    ),
  );
}

/// One stable list instance: gpt_markdown's segment cache and block
/// registry memoize by the LIST's identity — a per-call literal would
/// defeat the incremental fast path during streaming (every delta would
/// re-split the whole message).
final List<MarkdownBlockComponent> markdownBlockComponents = [
  _mermaidBlock,
];

/// `\ ` (control space) draws as a red missing-glyph box in TeX
/// engines — `\,` renders cleanly (ticket 07).
String _normalizeTex(String tex) => tex.replaceAll('\\ ', '\\, ');

double _zhBodyHeight(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'zh' ? 1.7 : 1.5;

/// The shared renderer configuration. [onLinkTap] receives the href
/// verbatim (`https://…`, `/workspace/…`) — exactly what openChatLink
/// needs. Note: passing it via `onLinkTap` (NOT `inlineLinkBuilder`,
/// which runs at span-build time, not tap time).
GptMarkdownConfig markdownConfig(
  BuildContext context, {
  void Function(String href)? onTapLink,
  ImageBuilder? imageBuilder,
}) =>
    GptMarkdownConfig(
      onLinkTap: onTapLink == null ? null : (url, _) => onTapLink(url),
      imageBuilder: imageBuilder,
      latexWorkaround: _normalizeTex,
      blockComponents: markdownBlockComponents,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(height: _zhBodyHeight(context)),
    );

/// Non-scrolling markdown body for chat bubbles and other inline
/// surfaces.
GptMarkdown transcriptMarkdown(
  BuildContext context,
  String data, {
  void Function(String href)? onTapLink,
  ImageBuilder? imageBuilder,
}) {
  final config = markdownConfig(context, onTapLink: onTapLink, imageBuilder: imageBuilder);
  return GptMarkdown(
    data,
    // The backend's math dialect is the web's @streamdown/math:
    // `$...$` inline, `$$ ... $$` block (KaTeX style).
    useDollarSignsForLatex: true,
    onLinkTap: config.onLinkTap,
    imageBuilder: config.imageBuilder,
    latexWorkaround: config.latexWorkaround,
    blockComponents: config.blockComponents,
    style: config.style,
  );
}
