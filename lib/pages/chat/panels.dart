
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../kb/kb_editor_page.dart';


import '../../chat/chat_controller.dart';
import '../../chat/models.dart';
import '../../files/file_preview.dart';
import '../../files/workspace_files.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/font_scale.dart';
import '../../theme/tokens.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/row_meta.dart';
import '../../ui/load_states.dart';

/// One session row (drawer, chat list, share picker): WeChat layout —
/// timestamp on the title line's right, channel/chat-only marks where
/// WeChat puts the mute icon (descriptor line's right). No per-row ⋯:
/// long-press opens the same actions (pin / rename / delete), so the
/// button only burned row-edge space (user feedback 2026-11-21).
class SessionTile extends ConsumerWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.selected,
    this.leading,
    this.trailing,
    this.slideActions = false,
    required this.onTap,
  });

  final ChatSessionInfo session;
  final bool selected;
  final Widget? leading;
  final Widget? trailing;

  /// Whether the host wraps the row in Slidable swipe actions (the
  /// chat list); the drawer rows stay plain - their horizontal space
  /// belongs to the drawer fling.
  final bool slideActions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Vertical rhythm breathes with the font tier (fontLayoutScale) —
    // fixed dp gaps read oversized at 小 and cramped at 大.
    final s = fontLayoutScale(context);
    final title = Text.rich(
      TextSpan(
        text: session.title.isEmpty ? l.chatNew : session.title,
        // Keep-at-top marker after the name (web chat-row marker:
        // 12px pin icon in the muted color, shrink-0 past truncation).
        children: [
          if (session.pinned)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Icon(LucideIcons.pin, size: 12, color: scheme.outline),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // Transcript size (13.5), the list-title size reference for the
      // whole app (user correction 2026-11-21: the round-3 titleMedium
      // bump made every list family grow to match and the rows read
      // oversized — unify DOWN onto the session size, never up).
      style: const TextStyle(fontSize: AppType.transcript),
    );
    final tile = InkWell(
      onTap: onTap,
      // Long-press menu is the only row action channel (pin / rename /
      // delete) - the ⋯ button was redundant with it.
      onLongPress: () => showRowActionsMenu(context, [
        RowAction(
          icon: session.pinned ? LucideIcons.pinOff : LucideIcons.pin,
          label: session.pinned ? l.chatUnpin : l.chatPin,
          onRun: () => _SessionMenu.run(context, ref, session, 'pin'),
        ),
        RowAction(
          icon: LucideIcons.penLine,
          label: l.chatRename,
          onRun: () => _SessionMenu.run(context, ref, session, 'rename'),
        ),
        RowAction(
          icon: LucideIcons.trash2,
          label: l.chatDelete,
          destructive: true,
          onRun: () => _SessionMenu.run(context, ref, session, 'delete'),
        ),
      ]),
      child: Container(
        // WeChat-style hairline between rows (user feedback 2026-11-21)
        // — full-bleed, painted at the container edge past the padding.
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: EdgeInsets.fromLTRB(12, 10 * s, 12, 10 * s),
        child: Row(
          children: [
            // Chevron rhythm shared with the KB lists (ChevronListTile).
            leading ??
                Icon(LucideIcons.chevronRight, size: 16, color: scheme.outline),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title line: title + timestamp at the right, like
                  // WeChat's time-on-the-title-line.
                  Row(children: [
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    RowMetaTime(tsMs: session.updatedAt),
                  ]),
                  // Descriptor line: preview + the channel / chat-only
                  // marks in WeChat's mute-icon slot.
                  if (session.preview.isNotEmpty ||
                      session.isImChannel ||
                      session.chatOnly)
                    Padding(
                      padding: EdgeInsets.only(top: 2 * s),
                      child: Row(children: [
                        Expanded(
                          child: Text(session.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.listSubtitleStyle(scheme)),
                        ),
                        if (session.chatOnly)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Tooltip(
                              message: l.chatOnlyMode,
                              child: Icon(LucideIcons.messageCircle,
                                  size: 12, color: scheme.outline),
                            ),
                          ),
                        if (session.isImChannel)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Tooltip(
                              message:
                                  '${channelLabel(session.channel)} · ${l.chatImChannelBadge}',
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.all(AppRadius.nested),
                                  border: Border.all(
                                      color: scheme.outlineVariant),
                                ),
                                child: Text(
                                  channelLabel(session.channel),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: scheme.outline),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    if (!slideActions) return tile;
    return Slidable(
      key: ValueKey('session-${session.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        // Three actions (pin / rename / delete) - delete stays at the
        // edge, ~80dp per pane at phone widths.
        extentRatio: 0.6,
        children: [
          SlidableAction(
            onPressed: (_) => _SessionMenu.run(context, ref, session, 'rename'),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            icon: LucideIcons.penLine,
            label: l.chatRename,
          ),
          SlidableAction(
            onPressed: (_) => _SessionMenu.run(context, ref, session, 'pin'),
            backgroundColor: scheme.secondary,
            foregroundColor: scheme.onSecondary,
            icon: session.pinned ? LucideIcons.pinOff : LucideIcons.pin,
            label: session.pinned ? l.chatUnpin : l.chatPin,
          ),
          SlidableAction(
            onPressed: (_) => _SessionMenu.run(context, ref, session, 'delete'),
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            icon: LucideIcons.trash2,
            label: l.chatDelete,
          ),
        ],
      ),
      child: tile,
    );
  }
}



/// The session row actions, shared by the long-press menu and the
/// chat-list swipe pane. (The per-row ⋯ button was dropped 2026-11-21:
/// long-press covers it and it only burned row-edge space.)
abstract final class _SessionMenu {
  static Future<void> run(BuildContext context, WidgetRef ref,
      ChatSessionInfo session, String action) async {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(sessionsProvider.notifier);
    switch (action) {
      case 'pin':
        try {
          await notifier.setPinned(session.id, !session.pinned);
        } catch (e) {
          if (context.mounted) showApiError(context, e);
        }
      case 'rename':
        await promptRename(context, ref, l, session);
      case 'delete':
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l.chatDeleteConfirm),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatDelete)),
            ],
          ),
        );
        if (yes != true) return;
        try {
          final wasActive = ref.read(chatStoreProvider).activeKey ==
              '${ref.read(agentsProvider).selectedId}|${session.id}';
          await notifier.delete(session.id);
          if (wasActive) await ref.read(chatStoreProvider.notifier).newChat();
        } catch (e) {
          if (context.mounted) showApiError(context, e);
        }
    }
  }

  static Future<void> promptRename(BuildContext context, WidgetRef ref,
      AppLocalizations l, ChatSessionInfo session) async {
    if (!context.mounted) return;
    // Full-page editor instead of the old dialog — same surface as the
    // KB edits.
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: l.chatRename,
        hint: l.chatRename,
        initialText: session.title,
        onSave: (text, _, _, _, {status}) async {
          if (text.trim().isEmpty) return false;
          try {
            await ref.read(sessionsProvider.notifier).rename(session.id, text.trim());
            return true;
          } catch (e) {
            if (context.mounted) showApiError(context, e);
            return false;
          }
        },
      ),
    ));
  }
}

/// Todo panel: single data source = the server's todo.md, refetched on
/// turn end by the chat controller.
Future<void> showTodoSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _TodoSheet(),
  );
}

class _TodoSheet extends ConsumerWidget {
  const _TodoSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final activeKey = ref.watch(chatStoreProvider.select((s) => s.activeKey));
    final agentId = splitSessionKey(activeKey)?.agentId;
    final sessionId = splitSessionKey(activeKey)?.sessionId;
    final todo = agentId == null || sessionId == null
        ? null
        : ref.watch(todoProvider((agentId, sessionId)));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(l.chatTodo, style: Theme.of(context).textTheme.titleMedium)),
                  if (agentId != null && sessionId != null)
                    IconButton(
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      onPressed: () => ref.invalidate(todoProvider((agentId, sessionId))),
                    ),
                ],
              ),
            ),
            Flexible(
              child: todo == null
                  ? const SizedBox.shrink()
                  : todo.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: SkeletonList(itemCount: 4),
                      ),
                      error: (_, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.chatHistoryError,
                            style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
                      ),
                      data: (data) {
                        if (data.items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(l.chatTodoEmpty, style: TextStyle(color: scheme.outline)),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: data.items.length,
                          itemBuilder: (context, i) {
                            final item = data.items[i];
                            final style = item.done
                                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: scheme.outline,
                                    color: scheme.outline,
                                  )
                                : Theme.of(context).textTheme.bodyMedium;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                item.cancelled
                                    ? LucideIcons.circleMinus
                                    : item.done
                                        ? LucideIcons.squareCheckBig
                                        : LucideIcons.square,
                                size: 20,
                                color: item.cancelled || item.done
                                    ? scheme.outline
                                    : scheme.primary,
                              ),
                              title: Text(item.text, style: style),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Agent workspace files (where a turn's attachments land): list +
/// delete, per GET/DELETE /api/agents/{id}/files. The phone surface is a
/// modal sheet over the shared [WorkspaceFilesView]; the tablet split
/// layout docks the same view in the chat page's right panel instead.
Future<void> showFilesSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FilesSheet(),
  );
}

class _FilesSheet extends ConsumerWidget {
  const _FilesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final activeKey = ref.watch(chatStoreProvider.select((s) => s.activeKey));
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    // The open chat's session — files scope to that conversation's
    // workspace subtree, not the whole agent (fileScopeForRequest). No
    // session open → empty state rather than the agent-wide listing.
    final sessionId = splitSessionKey(activeKey)?.sessionId ?? '';
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: agentId == null || sessionId.isEmpty
            ? EmptyState(icon: LucideIcons.folderOpen, message: l.kbEmpty)
            : WorkspaceFilesView(
                agentId: agentId,
                sessionId: sessionId,
                hug: true,
                // Tap previews route through the shared workspace
                // previewer (same path as chat-message file links).
                onOpen: (f) => openWorkspaceFilePreview(context, ref,
                    agentId: agentId,
                    path: f.path,
                    sessionId: sessionId,
                    displayName: f.name),
              ),
      ),
    );
  }
}
