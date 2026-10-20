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

/// Is this line a table separator row (`| --- | :---: |`)? Mirrors the
/// package's `_isTableSeparator` semantics so the two never disagree.
bool _isTableSeparator(String line) {
  final t = line.trim();
  if (!t.contains('-') || !t.contains('|')) return false;
  final cells = t.split('|').where((c) => c.trim().isNotEmpty).toList();
  if (cells.isEmpty) return false;
  for (final cell in cells) {
    final c = cell.trim();
    if (c.isEmpty || !c.contains('-')) return false;
    for (final ch in c.runes) {
      if (ch != 0x2D && ch != 0x3A) return false; // '-' and ':'
    }
  }
  return true;
}

/// Pre-render normalization for LLM output shapes gpt_markdown's parser
/// rejects (plusparse follows GFM: tables can't interrupt a paragraph;
/// setext headings aren't implemented):
/// - a table glued to the preceding text line gets a blank line inserted
///   — the most common LLM table shape (`结论：\n| a | b |\n| --- |`)
/// - `Title\n=====` setext H1 becomes `# Title`
/// Fenced code blocks are tracked and never touched (inserting a line
/// inside one would corrupt the payload). One linear scan — cheap even
/// per streaming frame.
String normalizeMarkdownBlocks(String md) {
  if (!md.contains('|') && !md.contains('=')) return md;
  final lines = md.split('\n');
  final out = <String>[];
  var inFence = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final fenceMarker = line.trimLeft();
    if (fenceMarker.startsWith('```') || fenceMarker.startsWith('~~~')) {
      inFence = !inFence;
      out.add(line);
      continue;
    }
    if (inFence) {
      out.add(line);
      continue;
    }
    final t = line.trim();
    if (t.contains('|') &&
        i + 1 < lines.length &&
        _isTableSeparator(lines[i + 1]) &&
        out.isNotEmpty &&
        out.last.trim().isNotEmpty &&
        !out.last.contains('|')) {
      // Table glued to a paragraph line — GFM needs the blank line.
      out.add('');
    } else if (RegExp(r'^={2,}$').hasMatch(t) &&
        out.isNotEmpty &&
        out.last.trim().isNotEmpty &&
        !RegExp(r'^[=\s]*$').hasMatch(out.last)) {
      // Setext H1 → ATX (the package lacks setext support).
      out.last = '# ${out.last.trim()}';
      continue;
    }
    out.add(line);
  }
  return out.join('\n');
}

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
    normalizeMarkdownBlocks(data),
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

/// Chat-bubble variant: the web's chat-md scale (chat-markdown.tsx) —
/// body 13.5 with headings capped at 15/14 — while KB/wiki readers
/// keep the doc ladder from the global theme.
Widget chatTranscript(
  BuildContext context,
  String data, {
  void Function(String href)? onTapLink,
  ImageBuilder? imageBuilder,
}) {
  final scheme = Theme.of(context).colorScheme;
  TextStyle heading(double size, FontWeight weight, double? height) => TextStyle(
      fontSize: size, fontWeight: weight, height: height, color: scheme.onSurface);
  final config = markdownConfig(context, onTapLink: onTapLink, imageBuilder: imageBuilder);
  return GptMarkdownTheme(
    gptThemeData: GptMarkdownTheme.of(context).copyWith(
      h1: heading(AppType.chatH1, FontWeight.w600, 1.4),
      h2: heading(AppType.chatH2, FontWeight.w600, 1.4),
      h3: heading(AppType.transcript, FontWeight.w600, 1.45),
      h4: heading(AppType.transcript, FontWeight.w600, null),
      h5: heading(AppType.transcript, FontWeight.w600, null),
      h6: heading(AppType.transcript, FontWeight.w500, null),
    ),
    child: GptMarkdown(
      normalizeMarkdownBlocks(data),
      useDollarSignsForLatex: true,
      onLinkTap: config.onLinkTap,
      imageBuilder: config.imageBuilder,
      latexWorkaround: config.latexWorkaround,
      blockComponents: config.blockComponents,
      style: config.style?.copyWith(fontSize: AppType.transcript),
    ),
  );
}
