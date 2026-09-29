import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../auth/auth_controller.dart';
import '../../chat/chat_controller.dart';
import '../../chat/chat_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import 'chat_image.dart';
import 'image_viewer.dart';

/// Marker inserted between entries when the calendar day changes.
class _DayBreak {
  const _DayBreak(this.ts);
  final int ts;
}

/// Reverse transcript list: newest pinned at the bottom, the older page
/// fetched on approach to the top (reverse list — maxScrollExtent is the
/// oldest end). Entries animate in with the 160ms rise+fade entrance from
/// the design tokens (reduced-motion → pure fade).
class MessageList extends ConsumerStatefulWidget {
  const MessageList({super.key, required this.state});

  final ChatUiState state;

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final Set<String> _animated = {};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (widget.state.historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.state.entries.isEmpty && !widget.state.turnActive) {
      return _EmptyTranscript(l: l);
    }
    final notifier = ref.read(chatStoreProvider.notifier);

    // Interleave day dividers; chronological order, rendered reversed.
    final rows = <Object>[];
    int? currentDay;
    for (final e in widget.state.entries) {
      final ts = switch (e) {
        UserEntry u => u.ts,
        AssistantEntry a => a.ts,
        _ => 0,
      };
      if (ts > 0) {
        final day = _dayKey(ts);
        if (day != currentDay) {
          currentDay = day;
          rows.add(_DayBreak(ts));
        }
      }
      rows.add(e);
    }

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
        itemCount: rows.length + (widget.state.loadMoreRunning ? 1 : 0),
        itemBuilder: (context, i) {
          if (widget.state.loadMoreRunning && i == rows.length) {
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
          final row = rows[rows.length - 1 - i];
          if (row is _DayBreak) {
            return _DayDivider(ts: row.ts);
          }
          final entry = row as UiEntry;
          return _EntryIn(
            animate: _animated.add(entry.key),
            child: switch (entry) {
              UserEntry() => _UserBubble(entry: entry),
              AssistantEntry() => _AssistantBubble(entry: entry, isLast: i == 0),
              ToolEntry() => _ToolCard(entry: entry),
              NoticeEntry() => _NoticeChip(entry: entry),
              AuthPromptEntry() => _AuthCard(entry: entry),
            },
          );
        },
      ),
    );
  }

  int _dayKey(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return d.year * 10000 + d.month * 100 + d.day;
  }
}

class _EmptyTranscript extends StatelessWidget {
  const _EmptyTranscript({required this.l});

  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 44, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(l.chatEmpty, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

/// 160ms rise + fade entrance (design token: 消息入场 160ms 上浮淡入);
/// reduced-motion requests degrade to a pure fade.
class _EntryIn extends StatefulWidget {
  const _EntryIn({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_EntryIn> createState() => _EntryInState();
}

class _EntryInState extends State<_EntryIn> {
  bool _played = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.animate || _played) return widget.child;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      onEnd: () => _played = true,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: reduceMotion ? Offset.zero : Offset(0, 8 * (1 - v)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.ts});

  final int ts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final label = date.isAfter(today.subtract(const Duration(milliseconds: 1)))
        ? l.chatToday
        : date.isAfter(yesterday.subtract(const Duration(milliseconds: 1)))
            ? l.chatYesterday
            : DateFormat.MMMEd(Localizations.localeOf(context).toString()).format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: AppRadius.controlBorder,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
          ),
        ),
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
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          // Asymmetric corners from the radius families (12 card + 4
          // nested): flat corner anchors the bubble to the sender's side.
          borderRadius: const BorderRadius.only(
            topLeft: AppRadius.card,
            topRight: AppRadius.card,
            bottomLeft: AppRadius.card,
            bottomRight: AppRadius.nested,
          ),
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
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.pendingSteer)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      l.chatThinking,
                      style: TextStyle(
                          fontSize: 10,
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.55)),
                    ),
                  ),
                if (entry.ts > 0)
                  Text(
                    DateFormat.Hm(Localizations.localeOf(context).toString())
                        .format(DateTime.fromMillisecondsSinceEpoch(entry.ts)),
                    style: TextStyle(
                        fontSize: 10, color: scheme.onPrimaryContainer.withValues(alpha: 0.55)),
                  ),
              ],
            ),
            if (entry.failed)
              Padding(
                padding: const EdgeInsets.only(top: 2),
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
    final canRegenerate = isLast &&
        !entry.streaming &&
        !ref.watch(chatStoreProvider.select((s) => s.active?.turnActive ?? false));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AgentAvatar(),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
                Row(
                  children: [
                    if (entry.ts > 0)
                      Text(
                        DateFormat.Hm(Localizations.localeOf(context).toString())
                            .format(DateTime.fromMillisecondsSinceEpoch(entry.ts)),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    const Spacer(),
                    if (canRegenerate) _RegenerateButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegenerateButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: theme.colorScheme.outline,
      ),
      onPressed: () => ref.read(chatStoreProvider.notifier).regenerate(),
      icon: const Icon(Icons.refresh, size: 14),
      label: Text(l.chatRegenerate, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Selected agent's avatar (GET /api/agents/*/files/avatar.png — cookie
/// gated, so same-host loads carry the session cookie).
class _AgentAvatar extends ConsumerWidget {
  const _AgentAvatar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final avatarUrl = ref.watch(agentsProvider.select((a) => a.selected?.avatarUrl ?? ''));
    if (avatarUrl.isEmpty) {
      return Container(
        width: 28,
        height: 28,
        decoration:
            BoxDecoration(color: scheme.secondaryContainer, borderRadius: AppRadius.controlBorder),
        child: Icon(Icons.smart_toy_outlined, size: 16, color: scheme.outline),
      );
    }
    return ClipRRect(
      borderRadius: AppRadius.controlBorder,
      child: Image(
        image: chatImageProvider(avatarUrl, baseUrl: auth.baseUrl, cookie: auth.sid),
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 28,
          height: 28,
          color: scheme.secondaryContainer,
          child: Icon(Icons.smart_toy_outlined, size: 16, color: scheme.outline),
        ),
      ),
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
    horizontalRuleDecoration:
        BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant))),
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
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  if (entry.arguments.isNotEmpty && entry.result != null)
                    Divider(height: 12, color: theme.colorScheme.outlineVariant),
                  if (entry.result != null)
                    SelectableText(
                      entry.result!,
                      style:
                          theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12),
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
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
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
                    onPressed: entry.answered
                        ? null
                        : () => ref.read(chatStoreProvider.notifier).answerAuth(option.cmd),
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
