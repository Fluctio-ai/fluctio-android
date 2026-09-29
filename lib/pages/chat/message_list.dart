import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_controller.dart';
import '../../chat/chat_controller.dart';
import '../../chat/chat_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'chat_image.dart';
import 'image_viewer.dart';

/// Reverse transcript list: newest pinned at the bottom, the older page
/// fetched on approach to the top (reverse list — maxScrollExtent is the
/// oldest end).
class MessageList extends ConsumerWidget {
  const MessageList({super.key, required this.state});

  final ChatUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    if (state.historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.entries.isEmpty && !state.turnActive) {
      return Center(child: Text(l.chatEmpty, style: Theme.of(context).textTheme.bodyMedium));
    }
    final notifier = ref.read(chatStoreProvider.notifier);
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0 && n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
          notifier.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: state.entries.length + (state.loadMoreRunning ? 1 : 0),
        itemBuilder: (context, i) {
          if (state.loadMoreRunning && i == state.entries.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final entry = state.entries[state.entries.length - 1 - i];
          return switch (entry) {
            UserEntry() => _UserBubble(entry: entry),
            AssistantEntry() => _AssistantBubble(entry: entry, isLast: i == 0),
            ToolEntry() => _ToolCard(entry: entry),
            NoticeEntry() => _NoticeChip(entry: entry),
            AuthPromptEntry() => _AuthCard(entry: entry),
          };
        },
      ),
    );
  }
}

class _UserBubble extends ConsumerWidget {
  const _UserBubble({required this.entry});

  final UserEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final l = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: AppRadius.cardBorder,
          border: entry.failed ? Border.all(color: scheme.error) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.imageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  children: [
                    for (final url in entry.imageUrls)
                      ChatImageThumb(
                        url: url,
                        baseUrl: auth.baseUrl,
                        cookie: auth.sid,
                        size: 84,
                        onTap: () => _openImage(context, url, auth.baseUrl, auth.sid),
                      ),
                  ],
                ),
              ),
            if (entry.text.isNotEmpty)
              Text(
                entry.text,
                style: TextStyle(color: scheme.onPrimaryContainer, height: 1.5),
              ),
            if (entry.pendingSteer)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l.chatThinking,
                    style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer.withValues(alpha: 0.6))),
              ),
            if (entry.failed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: scheme.error,
                  ),
                  onPressed: () => ref.read(chatStoreProvider.notifier).resendFailed(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l.chatResend),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBubble extends ConsumerWidget {
  const _AssistantBubble({required this.entry, required this.isLast});

  final AssistantEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final canRegenerate =
        isLast && !entry.streaming && !ref.watch(chatStoreProvider.select((s) => s.active?.turnActive ?? false));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: entry.text,
          extensionSet: md.ExtensionSet.gitHubWeb,
          styleSheet: _markdownStyle(context),
          onTapLink: (_, href, _) => _openLink(context, href),
          sizedImageBuilder: (config) => _MarkdownImage(
            url: config.uri.toString(),
            width: config.width,
            height: config.height,
          ),
        ),
        if (canRegenerate)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: theme.colorScheme.outline,
              ),
              onPressed: () => ref.read(chatStoreProvider.notifier).regenerate(),
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(l.chatRegenerate, style: const TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}

MarkdownStyleSheet _markdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final zhScope = Localizations.localeOf(context).languageCode == 'zh';
  final lineHeight = zhScope ? 1.7 : 1.5;
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(height: lineHeight),
    listBullet: theme.textTheme.bodyMedium?.copyWith(height: lineHeight),
    blockquote: theme.textTheme.bodyMedium?.copyWith(height: lineHeight),
    code: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 13),
    codeblockDecoration: BoxDecoration(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: AppRadius.controlBorder,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    blockquoteDecoration: BoxDecoration(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: AppRadius.controlBorder,
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    tableHead: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    tableBody: theme.textTheme.bodySmall,
    horizontalRuleDecoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant))),
  );
}

class _MarkdownImage extends ConsumerWidget {
  const _MarkdownImage({required this.url, this.width, this.height});

  final String url;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _openImage(context, url, auth.baseUrl, auth.sid),
        child: ClipRRect(
          borderRadius: AppRadius.controlBorder,
          child: Image(
            image: chatImageProvider(url, baseUrl: auth.baseUrl, cookie: auth.sid),
            width: width,
            height: height,
            errorBuilder: (_, _, _) => Container(
              height: 40,
              padding: const EdgeInsets.all(8),
              color: scheme.secondaryContainer,
              child: Icon(Icons.broken_image_outlined, size: 18, color: scheme.outline),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends ConsumerWidget {
  const _ToolCard({required this.entry});

  final ToolEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final running = entry.result == null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => ref.read(chatStoreProvider.notifier).toggleTool(entry.key),
            borderRadius: BorderRadius.vertical(top: AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                children: [
                  Icon(Icons.terminal_outlined, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.name.isEmpty ? l.chatToolCalling : entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (running)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(l.chatToolDone,
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  const SizedBox(width: 6),
                  Icon(entry.expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
          if (entry.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.arguments.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: AppRadius.controlBorder,
                      ),
                      child: SelectableText(
                        entry.arguments,
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  if (entry.arguments.isNotEmpty && entry.result != null)
                    Divider(height: 12, color: theme.colorScheme.outlineVariant),
                  if (entry.result != null)
                    SelectableText(
                      entry.result!,
                      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoticeChip extends StatelessWidget {
  const _NoticeChip({required this.entry});

  final NoticeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final label = switch (entry.kind) {
      NoticeKind.serverError => entry.text,
      NoticeKind.stopped => l.chatStopped,
      NoticeKind.compaction => entry.text.isEmpty ? l.chatCompacted : entry.text,
      NoticeKind.turnAborted => entry.text,
      NoticeKind.historyError => l.chatHistoryError,
    };
    final (icon, color) = switch (entry.tone) {
      NoticeTone.error => (Icons.error_outline, theme.colorScheme.error),
      NoticeTone.warn => (Icons.warning_amber_outlined, theme.colorScheme.outline),
      NoticeTone.info => (Icons.info_outline, theme.colorScheme.outline),
    };
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthCard extends ConsumerWidget {
  const _AuthCard({required this.entry});

  final AuthPromptEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(l.chatAuthTitle, style: theme.textTheme.titleSmall),
            ],
          ),
          if (entry.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(entry.description, style: theme.textTheme.bodySmall),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final option in entry.options)
                  OutlinedButton(
                    onPressed:
                        entry.answered ? null : () => ref.read(chatStoreProvider.notifier).answerAuth(option.cmd),
                    child: Text(option.label(locale), style: const TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _openImage(BuildContext context, String url, String baseUrl, String? cookie) {
  openImageViewer(context, chatImageProvider(url, baseUrl: baseUrl, cookie: cookie));
}

Future<void> _openLink(BuildContext context, String? href) async {
  final uri = Uri.tryParse(href ?? '');
  if (uri == null || !uri.hasScheme) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No handler for the scheme — ignore silently.
  }
}
