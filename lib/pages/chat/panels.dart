import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../kb/kb_editor_page.dart';

import '../../chat/chat_controller.dart';
import '../../chat/models.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
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
      leading: leading,
      title: Text(
        session.title.isEmpty ? l.chatNew : session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: switch ((session.preview, time)) {
        ('', '') => null,
        ('', _) => Text(time, maxLines: 1),
        (_, '') => Text(session.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        (_, _) => Text('$session.preview · $time', maxLines: 1, overflow: TextOverflow.ellipsis),
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    return PopupMenuButton<String>(
      onSelected: (action) => run(context, ref, session, action),
      // child form instead of icon: the icon variant centers the 18px
      // glyph inside a 48dp tap-target box, leaving wide gutters on both
      // sides; the plain child hugs the glyph.
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Icon(LucideIcons.ellipsisVertical,
            size: 18, color: Theme.of(context).colorScheme.outline),
      ),
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
        onSave: (text, _, _) async {
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
                      icon: const Icon(Icons.refresh),
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
