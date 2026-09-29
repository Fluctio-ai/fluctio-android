import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../util/dates.dart';

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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(l.chatHistoryError,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(child: Text(l.kbEmpty, style: theme.textTheme.bodyMedium));
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

  Future<void> _edit(
      BuildContext context, WidgetRef ref, String agentId, KbSource? existing) async {
    final l = AppLocalizations.of(context)!;
    final contentController = TextEditingController(text: existing?.title ?? '');
    DateTime? date = existing?.startAt?.toLocal();

    Future<DateTime?> pickDate() => showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? l.kbAddTodo : l.chatRename),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentController,
                autofocus: true,
                decoration: InputDecoration(hintText: l.kbTodoHint),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date == null ? l.kbNoDate : formatShortDate(date!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await pickDate();
                      if (picked != null) setState(() => date = picked);
                    },
                    child: Text(l.kbDueDate),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatSend)),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final content = contentController.text.trim();
    if (content.isEmpty) return;

    final repo = ref.read(kbRepoProvider);
    try {
      if (existing == null) {
        final deduped = await repo.saveTodo(agentId, content, startAt: date);
        if (context.mounted && deduped) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.kbDeduped)));
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
    final done = todo.status == 'done';
    final cancelled = todo.status == 'cancelled';
    return ListTile(
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
              ? theme.colorScheme.primary
              : cancelled
                  ? theme.colorScheme.outline
                  : theme.colorScheme.outline,
        ),
      ),
      title: Text(
        todo.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                decorationColor: theme.colorScheme.outline,
                color: theme.colorScheme.outline,
              )
            : null,
      ),
      subtitle: todo.startAt == null
            ? null
            : Text(formatShortDate(todo.startAt!, withTime: true), maxLines: 1),
      trailing: TextButton(
        onPressed: () => KbTodosPage()._edit(context, ref, agentId, todo),
        child: Text(l.kbDueDate, style: const TextStyle(fontSize: 12)),
      ),
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
