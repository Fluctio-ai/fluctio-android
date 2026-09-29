import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/auth_controller.dart';
import '../../chat/chat_controller.dart';
import '../../chat/models.dart';
import '../../l10n/app_localizations.dart';
import 'chat_image.dart';

/// Session list sheet: switch / new / rename / delete / chat-only toggle.
Future<void> showSessionsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SessionsSheet(),
  );
}

/// Today → HH:mm; this year → M/d HH:mm; older → yyyy/M/d.
String _formatSessionTime(BuildContext context, int ts) {
  if (ts <= 0) return '';
  final locale = Localizations.localeOf(context).toString();
  final date = DateTime.fromMillisecondsSinceEpoch(ts);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (!date.isBefore(today)) return DateFormat.Hm(locale).format(date);
  if (date.year == now.year) {
    return '${DateFormat.Md(locale).format(date)} ${DateFormat.Hm(locale).format(date)}';
  }
  return DateFormat.yMd(locale).format(date);
}

class _SessionsSheet extends ConsumerWidget {
  const _SessionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final sessions = ref.watch(sessionsProvider);
    final agents = ref.watch(agentsProvider);
    final activeKey = ref.watch(chatStoreProvider.select((s) => s.activeKey));
    final auth = ref.watch(authControllerProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text(l.chatSessions, style: Theme.of(context).textTheme.titleMedium)),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(chatStoreProvider.notifier).newChat();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l.chatNew),
                  ),
                ],
              ),
            ),
            Flexible(
              child: sessions.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.chatHistoryError,
                          style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => ref.read(sessionsProvider.notifier).reload(),
                        child: Text(l.chatLoadAgents),
                      ),
                    ],
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l.chatNoSessions, style: TextStyle(color: scheme.outline)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final selected = activeKey == '${agents.selectedId}|${s.id}';
                      return ListTile(
                        selected: selected,
                        leading: s.thumbnailUrl.isEmpty
                            ? const Icon(Icons.chat_bubble_outline)
                            : ChatImageThumb(
                                url: s.thumbnailUrl,
                                baseUrl: auth.baseUrl,
                                cookie: auth.sid,
                                size: 40,
                              ),
                        title: Text(
                          s.title.isEmpty ? l.chatNew : s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: s.preview.isEmpty
                            ? (s.updatedAt > 0 ? Text(_formatSessionTime(context, s.updatedAt)) : null)
                            : Text(
                                '${s.preview} · ${_formatSessionTime(context, s.updatedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (s.chatOnly)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Tooltip(
                                  message: l.chatOnlyMode,
                                  child: Icon(Icons.forum_outlined,
                                      size: 16, color: Theme.of(context).colorScheme.outline),
                                ),
                              ),
                            _SessionMenu(agentSession: s),
                          ],
                        ),
                        onTap: () {
                          final agentId = agents.selectedId;
                          if (agentId != null) {
                            Navigator.of(context).pop();
                            ref.read(chatStoreProvider.notifier).openSession(agentId, s.id);
                          }
                        },
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

class _SessionMenu extends ConsumerWidget {
  const _SessionMenu({required this.agentSession});

  final ChatSessionInfo agentSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(l.chatRename)),
        PopupMenuItem(
          value: 'chatOnly',
          child: Text('${agentSession.chatOnly ? '✓ ' : ''}${l.chatOnlyMode}'),
        ),
        PopupMenuItem(value: 'delete', child: Text(l.chatDelete)),
      ],
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, String action) async {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(sessionsProvider.notifier);
    switch (action) {
      case 'rename':
        await _promptRename(context, ref, l);
      case 'chatOnly':
        try {
          await notifier.setChatOnly(agentSession.id, !agentSession.chatOnly);
        } catch (_) {
          // Toggle failures surface as the stale list state.
        }
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
              '${ref.read(agentsProvider).selectedId}|${agentSession.id}';
          await notifier.delete(agentSession.id);
          if (wasActive) await ref.read(chatStoreProvider.notifier).newChat();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
        }
    }
  }

  Future<void> _promptRename(BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final controller = TextEditingController(text: agentSession.title);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.chatRename),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text), child: Text(l.chatRename)),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      try {
        await ref.read(sessionsProvider.notifier).rename(agentSession.id, name.trim());
      } catch (_) {
        // Rename failures surface as the stale title.
      }
    }
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
    final agentId = activeKey?.substring(0, activeKey.indexOf('|'));
    final sessionId = activeKey?.substring(activeKey.indexOf('|') + 1);
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
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
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
                                    ? Icons.indeterminate_check_box_outlined
                                    : item.done
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
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
