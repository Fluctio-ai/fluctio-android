import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../auth/auth_controller.dart';
import '../../chat/chat_controller.dart';
import '../../chat/chat_engine.dart';
import '../../chat/markdown.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../../ui/row_actions_menu.dart';
import '../../util/dates.dart';
import 'typing_dots.dart';
import '../../theme/tokens.dart';
import '../../files/file_preview.dart';
import 'chat_image.dart';
import 'image_viewer.dart';

/// Reverse transcript list: newest pinned at the bottom, the older page
/// fetched on approach to the top (reverse list — maxScrollExtent is the
/// oldest end). Rendering mirrors the web chat: assistant messages are
/// bare markdown (no bubble), user messages are right-aligned tinted
/// bubbles. Entries animate in with the 160ms rise+fade entrance from
/// the design tokens (reduced-motion → pure fade).
class MessageList extends ConsumerStatefulWidget {
  const MessageList({super.key, required this.state, this.jumpSeq});

  final ChatUiState state;

  /// #seq-N anchor (diary deep links): pull older history until covered,
  /// then scroll the target entry into view. Consumed once per element
  /// (the list is keyed by session, so a session switch restarts it).
  final int? jumpSeq;

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final Set<String> _animated = {};
  final ScrollController _scroll = ScrollController();
  bool _awayFromBottom = false;

  // ---- seq deep-link jump state ----
  int? _pendingSeq;
  int? _targetI; // reverse-list index of the anchor entry
  BuildContext? _anchor;
  int? _builtMinI, _builtMaxI; // reverse-index range the itemBuilder covered

  @override
  void initState() {
    super.initState();
    final seq = widget.jumpSeq;
    if (seq != null && seq > 0) {
      _pendingSeq = seq;
      _runSeqJump();
    }
  }

  /// Deep-link landing (#seq-N). Three phases: cover (page older history
  /// until an entry with seq >= target loads), coarse-jump the reverse
  /// list by an estimated entry height, then let the itemBuilder anchor
  /// registration snap exactly via [Scrollable.ensureVisible]. Bail-out
  /// everywhere is quiet — the coarse position (or the newest end) is
  /// still a sane landing.
  Future<void> _runSeqJump() async {
    final seq = _pendingSeq!;
    // Phase 1 — cover. loadMore is engine-guarded against re-entry.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (mounted && DateTime.now().isBefore(deadline)) {
      final s = widget.state;
      if (!s.historyLoading) {
        if (s.entries.any((e) => (e.seq ?? -1) >= seq) || !s.historyHasMore) break;
        ref.read(chatStoreProvider.notifier).loadMore();
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted || _pendingSeq == null || !_scroll.hasClients) return;
    // Phase 2 — coarse jump. Reverse list: offset grows toward the older
    // end, so the anchor sits (len-1-idx) average-heights from the
    // newest end. Estimation misses are corrected in phase 3.
    final s = widget.state;
    final idx = s.entries.indexWhere((e) => (e.seq ?? -1) >= seq);
    if (idx < 0) {
      _pendingSeq = null; // uncovered (offline cache / seq past the end)
      return;
    }
    _targetI = s.entries.length - 1 - idx;
    _builtMinI = _builtMaxI = null;
    _scroll.jumpTo((((s.entries.length - 1 - idx) * 240.0))
        .clamp(0.0, _scroll.position.maxScrollExtent));
    // Phase 3 — snap. The anchor registers when the target item builds;
    // otherwise step one viewport toward the target based on where the
    // built range actually landed, a few attempts, then settle.
    for (var attempt = 0; attempt < 3 && mounted && _anchor == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (_anchor != null || !mounted || !_scroll.hasClients) break;
      final minI = _builtMinI, maxI = _builtMaxI, targetI = _targetI;
      if (minI == null || maxI == null || targetI == null) continue;
      if (targetI > maxI) {
        _scroll.jumpTo((_scroll.offset + 700).clamp(0.0, _scroll.position.maxScrollExtent));
      } else if (targetI < minI) {
        _scroll.jumpTo((_scroll.offset - 700).clamp(0.0, _scroll.position.maxScrollExtent));
      } else {
        break;
      }
    }
  }

  /// Called from itemBuilder: the target entry rendered — snap it into
  /// view once this frame settles (alignment 0.25 keeps a bit of leading
  /// context visible above the anchor).
  void _registerAnchor(BuildContext ctx) {
    _anchor = ctx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _anchor;
      if (anchor != null && anchor.mounted) {
        Scrollable.ensureVisible(anchor,
            duration: const Duration(milliseconds: 200), alignment: 0.25);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (widget.state.historyLoading) {
      return const SkeletonListView(itemCount: 5, leading: false);
    }
    if (widget.state.entries.isEmpty && !widget.state.turnActive) {
      return _EmptyTranscript(l: l);
    }
    final notifier = ref.read(chatStoreProvider.notifier);

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0 && n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
              notifier.loadMore();
            }
            // Reverse list: offset 0 is the newest message; past ~2
            // screens up the jump-to-latest pill appears (ticket 14).
            if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
              final away = n.metrics.pixels > 600;
              if (away != _awayFromBottom) setState(() => _awayFromBottom = away);
            }
            return false;
          },
          child: ListView.builder(
            reverse: true,
            controller: _scroll,
            // Web transcript rhythm: space-y-3 (12px) between turns.
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: widget.state.entries.length + (widget.state.loadMoreRunning ? 1 : 0),
        itemBuilder: (context, i) {
          if (widget.state.loadMoreRunning && i == widget.state.entries.length) {
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
          final entry = widget.state.entries[widget.state.entries.length - 1 - i];
          _builtMinI = _builtMinI == null ? i : _builtMinI! < i ? _builtMinI : i;
          _builtMaxI = _builtMaxI == null ? i : _builtMaxI! > i ? _builtMaxI : i;
          if (_pendingSeq != null && i == _targetI && _anchor == null) {
            _registerAnchor(context);
          }
          final showRegenerate =
              entry is AssistantEntry && i == 0 && !widget.state.turnActive;
          return _EntryIn(
            animate: _animated.add(entry.key),
            child: GestureDetector(
              // Long-press actions (copy / regenerate) like the web's
              // hover toolbar, adapted for touch.
              onLongPress: () => _messageActions(context, entry,
                  regenerate: showRegenerate),
              behavior: HitTestBehavior.opaque,
              child: switch (entry) {
                UserEntry() => _UserBubble(entry: entry),
                AssistantEntry() => _AssistantBubble(entry: entry, isLast: i == 0),
                ToolEntry() => _ToolCard(entry: entry),
                NoticeEntry() => _NoticeChip(entry: entry),
                AuthPromptEntry() => _AuthCard(entry: entry),
              },
            ),
          );
        },
          ),
        ),
        // Jump-to-latest pill (ticket 14) — reverse list, so "latest"
        // is offset 0.
        Positioned(
          right: 12,
          bottom: 8,
          child: IgnorePointer(
            ignoring: !_awayFromBottom,
            child: AnimatedScale(
              scale: _awayFromBottom ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _awayFromBottom ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: _JumpToLatest(
                  onTap: () {
                    if (_scroll.hasClients) {
                      _scroll.animateTo(0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _messageActions(BuildContext context, UiEntry entry, {required bool regenerate}) {
    final l = AppLocalizations.of(context)!;
    final text = switch (entry) {
      UserEntry u => u.text,
      AssistantEntry a => a.text,
      _ => '',
    };
    // Web gates the fork button on msg.seq != null && msg.seq >= 0 —
    // fork-inherited prefix turns (seq<0) never fork again
    // (chat-screen.tsx:2714, 3213).
    final canFork = entry is AssistantEntry && (entry.seq ?? -1) >= 0;
    if (text.isEmpty && !regenerate && !canFork) return;
    showRowActionsMenu(context, [
      if (text.isNotEmpty)
        RowAction(
          icon: LucideIcons.copy,
          label: l.chatCopy,
          onRun: () => Clipboard.setData(ClipboardData(text: text)),
        ),
      if (canFork)
        RowAction(
          icon: LucideIcons.gitBranch,
          label: l.chatFork,
          onRun: () async {
            try {
              await ref.read(chatStoreProvider.notifier).fork(entry.seq!);
            } catch (e) {
              if (context.mounted) showApiError(context, e);
            }
          },
        ),
      if (regenerate)
        RowAction(
          icon: LucideIcons.rotateCcw,
          label: l.chatRegenerate,
          onRun: () => ref.read(chatStoreProvider.notifier).regenerate(),
        ),
    ]);
  }
}

/// Circular outline pill with a down-arrow — the jump-to-latest
/// affordance pinned at the transcript's bottom-right.
class _JumpToLatest extends StatelessWidget {
  const _JumpToLatest({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(LucideIcons.arrowDown, size: 20),
        ),
      ),
    );
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
          Icon(LucideIcons.messageCircle, size: 44, color: theme.colorScheme.outline),
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

class _UserBubble extends ConsumerWidget {
  const _UserBubble({required this.entry});

  final UserEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
              decoration: BoxDecoration(
                // Web: primary/10 tint with primary text (light theme = our
                // primaryContainer accent + onPrimaryContainer). Corners:
                // rounded-2xl with the sender-side corner pulled in
                // (rounded-br-md) — the user sits right, the assistant left,
                // so the tails face who spoke.
                color: scheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: AppRadius.fullscreen,
                  topRight: AppRadius.fullscreen,
                  bottomLeft: AppRadius.fullscreen,
                  bottomRight: AppRadius.control,
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
                              onTap: () => _openImage(context, ref, url),
                            ),
                        ],
                      ),
                    ),
                  // Non-image workspace attachments: name chips only — the
                  // wire history never carries them back, so this is the
                  // live-send bubble (plus offline cache replay).
                  if (entry.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final a in entry.attachments)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: scheme.onPrimaryContainer.withValues(alpha: 0.08),
                                borderRadius: AppRadius.controlBorder,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.fileText,
                                      size: 14, color: scheme.onPrimaryContainer),
                                  const SizedBox(width: 5),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      a.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: AppType.caption,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (entry.text.isNotEmpty)
                    Text(entry.text,
                        style: TextStyle(color: scheme.onPrimaryContainer, height: 1.5)),
                  if (entry.pendingSteer)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        l.chatThinking,
                        style: TextStyle(
                            fontSize: AppType.caption,
                            color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
                      ),
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
                        icon: const Icon(LucideIcons.refreshCw, size: 14),
                        label: Text(l.chatResend),
                      ),
                    ),
                ],
              ),
            ),
            // Web gates the user-side time behind hover (opacity-0
            // group-hover, chat-screen.tsx:3158); touch has none, so show
            // it always — same contract as the assistant side's time.
            if (entry.ts > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  formatTimeOfDay(DateTime.fromMillisecondsSinceEpoch(entry.ts)),
                  style: TextStyle(fontSize: AppType.caption, color: scheme.outline),
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
      // Web transcript rhythm: space-y-3 (12px) between turns.
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Web agent bubble: bg-muted rounded-2xl with the sender-side
          // corner pulled in (chat-screen.tsx renderRegularBubble,
          // rounded-bl-md). Accidentally flattened in 35273ff's layout
          // pass — restored per the web contract.
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: AppRadius.fullscreen,
                topRight: AppRadius.fullscreen,
                bottomLeft: AppRadius.control,
                bottomRight: AppRadius.fullscreen,
              ),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: chatTranscript(
              context,
              entry.text,
              onTapLink: (href) {
                // Gateway file URLs and bare workspace paths preview
                // natively; everything else goes to the browser.
                openChatLink(context, ref, href);
              },
              imageBuilder: (context, url, width, height) => _MarkdownImage(
                url: url,
                width: width,
                height: height,
              ),
            ),
          ),
          // Web's under-bubble meta row: the time is always visible, the
          // hover actions (copy/fork) map to our long-press sheet. The
          // mobile-only regenerate joins the row instead of standing alone.
          if (entry.ts > 0 || canRegenerate)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  if (entry.ts > 0)
                    Text(
                      formatTimeOfDay(DateTime.fromMillisecondsSinceEpoch(entry.ts)),
                      style: TextStyle(
                          fontSize: AppType.caption, color: theme.colorScheme.outline),
                    ),
                  if (canRegenerate) _RegenerateButton(),
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
      icon: const Icon(LucideIcons.rotateCcw, size: 14),
      label: Text(l.chatRegenerate, style: const TextStyle(fontSize: AppType.caption)),
    );
  }
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
        onTap: () => _openImage(context, ref, url),
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
              child: Icon(LucideIcons.imageOff, size: 18, color: scheme.outline),
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
                  Icon(LucideIcons.terminal, size: 15, color: theme.colorScheme.outline),
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
                  if (running) const TypingDots()
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.check, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(l.chatToolDone,
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  const SizedBox(width: 6),
                  Icon(entry.expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 16, color: theme.colorScheme.outline),
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
                            theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: AppType.caption),
                      ),
                    ),
                  if (entry.arguments.isNotEmpty && entry.result != null)
                    Divider(height: 12, color: theme.colorScheme.outlineVariant),
                  if (entry.result != null)
                    SelectableText(
                      entry.result!,
                      style:
                          theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: AppType.caption),
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
    final palette = paletteOf(context);
    final label = switch (entry.kind) {
      NoticeKind.serverError => entry.text,
      NoticeKind.stopped => l.chatStopped,
      NoticeKind.compaction => entry.text.isEmpty ? l.chatCompacted : entry.text,
      NoticeKind.turnAborted => entry.text,
      NoticeKind.historyError => l.chatHistoryError,
      NoticeKind.offlineCache => l.chatOfflineHint,
    };
    final (icon, color) = switch (entry.tone) {
      NoticeTone.error => (LucideIcons.circleAlert, theme.colorScheme.error),
      NoticeTone.warn => (LucideIcons.triangleAlert, palette.warning),
      NoticeTone.info => (LucideIcons.info, palette.info),
    };
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.cardBorder,
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
                    ?.copyWith(color: color),
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
              Icon(LucideIcons.shieldCheck, size: 18, color: theme.colorScheme.primary),
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
                    child: Text(option.label(locale), style: const TextStyle(fontSize: AppType.secondary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens [url] inside the conversation's image lightbox: every image of
/// the active transcript via [UiEntryGalleryImages.galleryImages], so
/// horizontal swipes page through them (ticket 13); a URL not found in
/// the inventory opens alone (agent files etc.).
void _openImage(BuildContext context, WidgetRef ref, String url) {
  final auth = ref.read(authControllerProvider);
  final entries = ref.read(chatStoreProvider).active?.entries ?? const <UiEntry>[];
  final urls = [for (final e in entries) ...e.galleryImages];
  final index = urls.indexOf(url);
  openImageViewer(
    context,
    [
      for (final u in (index >= 0 ? urls : [url]))
        chatImageProvider(u, baseUrl: auth.baseUrl, cookie: auth.sid),
    ],
    initialIndex: index >= 0 ? index : 0,
  );
}


