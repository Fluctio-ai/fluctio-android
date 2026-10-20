
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
import '../../theme/tokens.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/load_states.dart';
import '../../util/dates.dart';

/// One session row (used in the navigation drawer): title/preview/time,
/// per-item menu (rename / delete / chat-only toggle).
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

  /// Chat-list rows replace the ⋯ trailing menu with iOS-style swipe
  /// actions (full-width titles); the drawer keeps the menu (too narrow).
  final bool slideActions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final time = formatSessionTime(session.updatedAt,
        locale: Localizations.localeOf(context).toString());
    final tile = ListTile(
      dense: true,
      selected: selected,
      // Chevron rhythm shared with the KB lists (ChevronListTile) —
      // rows without an explicit leading still carry the pointer.
      leading: leading ??
          Icon(LucideIcons.chevronRight,
              size: 16, color: Theme.of(context).colorScheme.outline),
      horizontalTitleGap: 8,
      // Right gutter narrowed — the ⋯ menu hugs the row edge (its own
      // box adds a few px); left stays at the standard 16.
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      title: Text(
        session.title.isEmpty ? l.chatNew : session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // Same size as the transcript body (web runs sidebar text-sm 14
        // next to chat-md 13.5) — the dense ListTile default ran ~2px
        // smaller and the sidebar read disconnected from the chat.
        style: const TextStyle(fontSize: AppType.transcript),
      ),
      subtitle: switch ((session.preview, time)) {
        ('', '') => null,
        ('', _) => Text(time, maxLines: 1),
        (_, '') => Text(session.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        (_, _) => Text('${session.preview} · $time', maxLines: 1, overflow: TextOverflow.ellipsis),
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // IM-channel mark (web parity: ChannelIcon next to the title).
          // No brand assets on the app side — a text chip names the
          // channel and flags the read-only chat.
          if (session.isImChannel)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: '${channelLabel(session.channel)} · ${l.chatImChannelBadge}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(AppRadius.nested),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Text(
                    channelLabel(session.channel),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              ),
            ),
          if (session.chatOnly)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Tooltip(
                message: l.chatOnlyMode,
                child: Icon(LucideIcons.messageCircle,
                    size: 16, color: Theme.of(context).colorScheme.outline),
              ),
            ),
          if (!slideActions) _SessionMenu(session: session),
          ?trailing,
        ],
      ),
      onTap: onTap,
      // Long-press menu mirrors the swipe actions — the discoverable
      // channel; drawer rows (no swipe) get it too, their ⋯ menu
      // stays as the visual affordance.
      onLongPress: () => showRowActionsMenu(context, [
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
    );
    if (!slideActions) return tile;
    final scheme = Theme.of(context).colorScheme;
    return Slidable(
      key: ValueKey('session-${session.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) => _SessionMenu.run(context, ref, session, 'rename'),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            icon: LucideIcons.penLine,
            label: l.chatRename,
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



class _SessionMenu extends ConsumerWidget {
  const _SessionMenu({required this.session});

  final ChatSessionInfo session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return RowMenuButton(
      onSelected: (action) => run(context, ref, session, action),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(l.chatRename)),
        PopupMenuItem(value: 'delete', child: Text(l.chatDelete)),
      ],
    );
  }

  static Future<void> run(BuildContext context, WidgetRef ref,
      ChatSessionInfo session, String action) async {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(sessionsProvider.notifier);
    switch (action) {
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
