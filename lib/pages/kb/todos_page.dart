import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../../ui/dialogs.dart';
import '../../util/dates.dart';
import 'kb_editor_page.dart';

/// KB todos grouped by due date (今天 / 明天 / 日期 / 无日期), checkbox to
/// complete, tap to reschedule/edit.
class KbTodosPage extends ConsumerWidget {
  const KbTodosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final todos = agentId == null ? null : ref.watch(kbTodosProvider(agentId));

    return Scaffold(
      appBar: AppBar(title: Text(l.kbTodos)),
      floatingActionButton: FloatingActionButton(
        onPressed: agentId == null ? null : () => _edit(context, ref, agentId, null),
        child: const Icon(LucideIcons.plus),
      ),
      body: todos == null
          ? const SizedBox.shrink()
          : todos.when(
              loading: () => const SkeletonListView(),
              error: (e, _) => ErrorPane(message: l.chatHistoryError),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(icon: LucideIcons.squareCheckBig, message: l.kbEmpty);
                }
                final groups = _groupByDay(context, list);
                return RefreshIndicator(
                  onRefresh: () =>
                      agentId == null ? Future.value() : ref.refresh(kbTodosProvider(agentId).future),
                  child: ListView(
                    children: [
                      for (final g in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                          child: Text(
                            g.key,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        for (final t in g.value) _TodoTile(todo: t, agentId: agentId!),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Groups todos under day labels; key order: 今天, 明天, upcoming dates,
  /// overdue dates, then 无日期.
  Map<String, List<KbSource>> _groupByDay(BuildContext context, List<KbSource> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final groups = <String, List<KbSource>>{};
    final dated = <(DateTime, KbSource)>[];
    final noDate = <KbSource>[];
    for (final t in list) {
      final start = t.startAt?.toLocal();
      if (start == null) {
        noDate.add(t);
      } else {
        dated.add((start, t));
      }
    }
    dated.sort((a, b) => a.$1.compareTo(b.$1));
    final l = AppLocalizations.of(context)!;
    for (final (d, t) in dated) {
      final day = DateTime(d.year, d.month, d.day);
      final label = day == today
          ? l.chatToday
          : day == tomorrow
              ? l.kbTomorrow
              : formatShortDate(d);
      groups.putIfAbsent(label, () => []).add(t);
    }
    if (noDate.isNotEmpty) groups[l.kbNoDate] = noDate;
    return groups;
  }

  /// Edit on a full-screen surface (DESIGN.md §4). Existing todos
  /// load their real content from the source's entries — the list row
  /// only carries the truncated title (same join as the web editor).
  static Future<void> _edit(
      BuildContext context, WidgetRef ref, String agentId, KbSource? existing) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(kbRepoProvider);

    var initial = '';
    if (existing != null) {
      try {
        initial = (await repo.entries(agentId, existing.id)).map((e) => e.content).join('\n');
      } catch (_) {}
    }
    if (!context.mounted) return;

    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: existing == null ? l.kbAddTodo : l.chatRename,
        hint: l.kbTodoHint,
        initialText: initial,
        dateLabel: l.kbDueDate,
        initialDate: existing?.startAt?.toLocal(),
        onSave: (text, _, date) async {
          final content = text.trim();
          if (content.isEmpty) return false;
          try {
            if (existing == null) {
              final deduped = await repo.saveTodo(agentId, content, startAt: date);
              if (deduped && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kbDeduped)));
              }
            } else {
              final done = existing.status == 'done';
              await repo.updateTodo(
                agentId,
                existing.id,
                content: content,
                status: done ? 'done' : existing.status.isEmpty ? 'pending' : existing.status,
                startAt: date,
              );
            }
            ref.invalidate(kbTodosProvider(agentId));
            ref.invalidate(kbSourcesProvider(agentId));
            return true;
          } catch (e) {
            if (context.mounted) showApiError(context, e);
            return false;
          }
        },
      ),
    ));
  }

  static Future<void> _deleteTodo(
      BuildContext context, WidgetRef ref, String agentId, KbSource todo) async {
    if (!await confirmDelete(context)) return;
    try {
      await ref.read(kbRepoProvider).deleteSource(agentId, todo.id);
      ref.invalidate(kbTodosProvider(agentId));
      ref.invalidate(kbSourcesProvider(agentId));
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }
}

class _TodoTile extends ConsumerWidget {
  const _TodoTile({required this.todo, required this.agentId});

  final KbSource todo;
  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final done = todo.status == 'done';
    final cancelled = todo.status == 'cancelled';
    final tile = ListTile(
      dense: true,
      leading: InkWell(
        onTap: () => _toggle(ref),
        child: Icon(
          done
              ? LucideIcons.squareCheckBig
              : cancelled
                  ? LucideIcons.circleMinus
                  : LucideIcons.square,
          size: 20,
          color: done
              ? scheme.primary
              : cancelled
                  ? scheme.outline
                  : scheme.outline,
        ),
      ),
      title: Text(
        todo.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                decorationColor: scheme.outline,
                color: scheme.outline,
              )
            : null,
      ),
      subtitle: todo.startAt == null
            ? null
            : Text(formatShortDate(todo.startAt!, withTime: true), maxLines: 1),
    );
    return Slidable(
      key: ValueKey('todo-${todo.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) => KbTodosPage._edit(context, ref, agentId, todo),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            icon: LucideIcons.penLine,
            label: l.chatRename,
          ),
          SlidableAction(
            onPressed: (_) => KbTodosPage._deleteTodo(context, ref, agentId, todo),
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

  void _toggle(WidgetRef ref) {
    final next = todo.status == 'done' ? 'pending' : 'done';
    ref
        .read(kbRepoProvider)
        .updateTodo(agentId, todo.id, status: next)
        .then((_) {
      ref.invalidate(kbTodosProvider(agentId));
      ref.invalidate(kbSourcesProvider(agentId));
    }).catchError((_) {});
  }
}
