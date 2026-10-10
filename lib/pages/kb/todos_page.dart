import '../app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../todo/todo_reminders.dart';
import '../../ui/adaptive_tab_bar.dart';
import '../../ui/load_states.dart';
import '../../ui/dialogs.dart';
import '../../ui/row_actions_menu.dart';
import '../../util/dates.dart';
import '../../util/app_toast.dart';
import 'kb_editor_page.dart';
import 'todo_views.dart';

/// KB todos: list (grouped 今天/明天/日期/无日期), calendar and gantt
/// (todo_views.dart, web TodosView parity), checkbox to complete, tap
/// to reschedule/edit.
enum _TodoView { list, calendar, gantt }

class KbTodosPage extends ConsumerStatefulWidget {
  const KbTodosPage({super.key});

  @override
  ConsumerState<KbTodosPage> createState() => _KbTodosPageState();
}

class _KbTodosPageState extends ConsumerState<KbTodosPage> {
  _TodoView _view = _TodoView.list;

  /// Shared period anchor of the calendar + gantt panes (web calAnchor)
  /// and the month/week/day granularity both panes respect.
  DateTime _anchor = DateTime(DateTime.now().year, DateTime.now().month);
  TodoGranularity _granularity = TodoGranularity.month;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final todos = agentId == null ? null : ref.watch(kbTodosProvider(agentId));

    return Scaffold(
      // Drawer on every list surface — same gesture zone as chat.
      drawer: const AppDrawer(),
      drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
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
                  return EmptyState(
                    icon: LucideIcons.squareCheckBig,
                    message: l.kbEmpty,
                    // The empty state carries its own entry — same as the
                    // notes/flash lists.
                    action: agentId == null
                        ? null
                        : FilledButton(
                            onPressed: () => _edit(context, ref, agentId, null),
                            child: Text(l.kbAddTodo)),
                  );
                }
                return Column(
                  children: [
                    // View switcher as underline tabs — the same TabBar
                    // idiom as the article detail page (原文/概要…),
                    // replacing the SegmentedButton block (user
                    // feedback); evenly spread like the wiki tabs
                    // (user feedback). The panes below stay a plain
                    // switch, not a TabBarView: calendar/gantt own their
                    // horizontal drags and would fight the page swipe.
                    DefaultTabController(
                      length: 3,
                      child: AdaptiveTabBar(
                        onTap: (i) => setState(() => _view = _TodoView.values[i]),
                        tabs: [
                          Tab(text: l.kbViewList),
                          Tab(text: l.kbViewCalendar),
                          Tab(text: l.kbViewGantt),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        // Writes re-sync alarms via the repo's onTodoWrite; the
                        // refresh gesture is the one read path that pulls fresh
                        // server state, so it re-syncs here too.
                        onRefresh: () => agentId == null
                            ? Future.value()
                            : ref
                                .refresh(kbTodosProvider(agentId).future)
                                .then((_) => ref.read(todoReminderServiceProvider).sync()),
                        child: switch (_view) {
                          _TodoView.list => _listView(context, theme, l, agentId!, list),
                          _TodoView.calendar => TodoCalendarView(
                              items: list,
                              anchor: _anchor,
                              granularity: _granularity,
                              onGranularity: _setGranularity,
                              onAnchor: _setAnchor,
                              onOpen: (t) => _edit(context, ref, agentId!, t),
                              onCreateAt: (d) =>
                                  _edit(context, ref, agentId!, null, initialDate: d),
                            ),
                          _TodoView.gantt => TodoGanttView(
                              items: list,
                              anchor: _anchor,
                              granularity: _granularity,
                              onGranularity: _setGranularity,
                              onAnchor: _setAnchor,
                              onOpen: (t) => _edit(context, ref, agentId!, t),
                            ),
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  /// Normalizes an incoming anchor to its granularity (month → 1st,
  /// week → Monday, day → midnight). Granularity switches re-anchor the
  /// existing period (10/1 monthly → 9/28's week).
  void _setAnchor(DateTime d) =>
      setState(() => _anchor = _granularity.normalize(d));

  void _setGranularity(TodoGranularity g) => setState(() {
        _granularity = g;
        _anchor = g.normalize(_anchor);
      });

  Widget _listView(BuildContext context, ThemeData theme, AppLocalizations l,
      String agentId, List<KbSource> list) {
    final groups = _groupByDay(context, list);
    return ListView(
      // Bottom FAB clearance (56 + 16 + 16) so the last row scrolls
      // out from under the button.
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final g in groups.entries) ...[
          Padding(
            // 12 gutters to match the tightened row padding below.
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
            child: Text(
              g.key,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600),
            ),
          ),
          for (final t in g.value) _TodoTile(todo: t, agentId: agentId),
        ],
      ],
    );
  }
}

/// Groups todos under day labels; key order: 今天, 明天, upcoming dates,
/// overdue dates, then 无日期. Rows inside a day follow the shared
/// schedule order (compareTodosByStart: start, then end-only, undated last
/// of all in the 无日期 group).
Map<String, List<KbSource>> _groupByDay(BuildContext context, List<KbSource> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final groups = <String, List<KbSource>>{};
    final dated = <(DateTime, KbSource)>[];
    final noDate = <KbSource>[];
    for (final t in list) {
      // Group by start, falling back to the deadline — an end-only
      // todo belongs under its due day, not under 无日期.
      final anchor = (t.startAt ?? t.endAt)?.toLocal();
      if (anchor == null) {
        noDate.add(t);
      } else {
        dated.add((anchor, t));
      }
    }
    dated.sort((a, b) => compareTodosByStart(a.$2, b.$2));
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
/// [initialDate] seeds the date picker for "new todo at day" (the
/// calendar day sheet); it loses to an existing todo's own start.
Future<void> _edit(BuildContext context, WidgetRef ref, String agentId,
    KbSource? existing, {DateTime? initialDate}) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(kbRepoProvider);

    var initial = '';
    if (existing != null) {
      try {
        initial = await repo.fullText(agentId, existing.id);
      } catch (_) {}
    }
    if (!context.mounted) return;

    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: existing == null ? l.kbAddTodo : l.kbEdit,
        hint: l.kbTodoHint,
        initialText: initial,
        initialStatus: existing == null || existing.status.isEmpty
            ? 'pending'
            : existing.status,
        statusOptions: [
          ('pending', l.todoStatusPending),
          ('in_progress', l.todoStatusInProgress),
          ('done', l.todoStatusDone),
          ('cancelled', l.todoStatusCancelled),
        ],
        dateLabel: l.kbStartDate,
        initialDate: existing?.startAt?.toLocal() ?? initialDate,
        endDateLabel: l.kbEndDate,
        initialEndDate: existing?.endAt?.toLocal(),
        onSave: (text, _, date, endDate, {status}) async {
          final content = text.trim();
          if (content.isEmpty) return false;
          final nextStatus = status ?? 'pending';
          try {
            if (existing == null) {
              final deduped =
                  await repo.saveTodo(agentId, content, status: nextStatus, startAt: date, endAt: endDate);
              if (deduped) {
                AppToast.show(l.kbDeduped);
              }
            } else {
              await repo.updateTodo(
                agentId,
                existing.id,
                content: content,
                status: nextStatus,
                startAt: date,
                endAt: endDate,
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

Future<void> _deleteTodo(
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

/// Full text of a todo row. The list's `title` is server-truncated to
/// ~50 bytes (deriveTitle, fastclaw store_types.go) — barely 16 Chinese
/// chars — so rows marked with a trailing ellipsis fetch their full
/// content from the source's entries and wrap it here instead.
class _TodoTile extends ConsumerStatefulWidget {
  const _TodoTile({required this.todo, required this.agentId});

  final KbSource todo;
  final String agentId;

  @override
  ConsumerState<_TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends ConsumerState<_TodoTile> {
  String? _fullText;

  @override
  void initState() {
    super.initState();
    if (widget.todo.title.endsWith('…')) {
      _loadFullText();
    }
  }

  void _loadFullText() async {
    try {
      // Full text lives in the source's entries (repo.fullText joins
      // the chunks — same rule as the editor's initial load).
      final text = await ref
          .read(kbRepoProvider)
          .fullText(widget.agentId, widget.todo.id);
      if (text.isNotEmpty && mounted) setState(() => _fullText = text);
    } catch (_) {
      // Offline/failure: the truncated title stays on screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final todo = widget.todo;
    final done = todo.status == 'done';
    final cancelled = todo.status == 'cancelled';
    final tile = ListTile(
      // No dense: same rhythm as the other KB lists — dense squeezed
      // the rows a step smaller than the sibling tabs (user feedback).
      // Tighter gutters (user feedback): the default 16 plus the
      // centered 44px hit box read as a wide gap around the checkbox —
      // 12 matches the ChevronListTile rhythm; the right edge sits at
      // 8 (user feedback: full-text rows shouldn't look boxed in).
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      // 24-wide + 8 gap optically balances the gutters (user feedback:
      // edge→glyph ≈ glyph→title — the 36-wide box parked dead space on
      // the right); the 44px-tall hit box stays.
      horizontalTitleGap: 8,
      leading: InkWell(
        onTap: () => _toggle(ref),
        // 44×44 hit target (ticket 14) — a bare 20px icon misses taps;
        // left-aligned so the glyph hugs the row edge, not the box's
        // center.
        child: SizedBox(
          width: 24,
          height: 44,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Icon(
              done
                  ? LucideIcons.squareCheckBig
                  : cancelled
                      ? LucideIcons.circleMinus
                      : LucideIcons.square,
              size: 20,
              color: done ? scheme.primary : scheme.outline,
            ),
          ),
        ),
      ),
      title: Text(
        _fullText ?? todo.title,
        // Full text wraps — the list is the primary surface for reading
        // todo content, so nothing is ellipsized away.
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
      onLongPress: () => showRowActionsMenu(context, [
        RowAction(
          icon: LucideIcons.penLine,
          label: l.kbEdit,
          onRun: () => _edit(context, ref, widget.agentId, todo),
        ),
        RowAction(
          icon: LucideIcons.trash2,
          label: l.chatDelete,
          destructive: true,
          onRun: () => _deleteTodo(context, ref, widget.agentId, todo),
        ),
      ]),
    );
    return Slidable(
      key: ValueKey('todo-${todo.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) => _edit(context, ref, widget.agentId, todo),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            icon: LucideIcons.penLine,
            label: l.kbEdit,
          ),
          SlidableAction(
            onPressed: (_) => _deleteTodo(context, ref, widget.agentId, todo),
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
    HapticFeedback.selectionClick();
    final next = widget.todo.status == 'done' ? 'pending' : 'done';
    ref
        .read(kbRepoProvider)
        .updateTodo(widget.agentId, widget.todo.id, status: next)
        .then((_) {
      ref.invalidate(kbTodosProvider(widget.agentId));
      ref.invalidate(kbSourcesProvider(widget.agentId));
    }).catchError((_) {});
  }
}
