import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../ui/load_states.dart';
import '../../util/dates.dart';

/// Calendar + Gantt todo surfaces — a port of the web TodosView
/// calendar pane (fastclaw knowledge-views.tsx) extended with week and
/// day granularities (app-only; the web ships month). One shared
/// period anchor, Monday-first grids with per-day track bars, and a
/// day-column gantt whose bars span start→due (clipped at the window
/// edges with an arrow). Mobile follows the web's own narrow-screen
/// behavior: a cell tap opens a day bottom sheet instead of inline
/// chips.

/// Which period the calendar/gantt panes render.
enum TodoGranularity { month, week, day }

/// The period semantics in one place — anchor normalization, stepping,
/// the day window, and the gantt's per-column width. The panes and the
/// page all consume these; nothing switches on the enum ad hoc.
extension TodoGranularityPeriods on TodoGranularity {
  /// Month → 1st, week → Monday, day → midnight.
  DateTime normalize(DateTime d) => switch (this) {
        TodoGranularity.month => DateTime(d.year, d.month),
        TodoGranularity.week => _weekStart(d),
        TodoGranularity.day => DateTime(d.year, d.month, d.day),
      };

  /// One granularity step from [anchor].
  DateTime step(DateTime anchor, int dir) => switch (this) {
        TodoGranularity.month => DateTime(anchor.year, anchor.month + dir, 1),
        TodoGranularity.week => anchor.add(Duration(days: 7 * dir)),
        TodoGranularity.day => anchor.add(Duration(days: dir)),
      };

  /// The visible day window; day granularity has none — its callers
  /// go straight to the hour ruler.
  (DateTime, DateTime) window(DateTime anchor) => switch (this) {
        TodoGranularity.month => (
            DateTime(anchor.year, anchor.month, 1),
            DateTime(anchor.year, anchor.month + 1, 0)
          ),
        TodoGranularity.week => (anchor, anchor.add(const Duration(days: 6))),
        TodoGranularity.day => throw StateError('day granularity has no day window'),
      };

  /// Gantt content-width budget per day/hour column.
  double get perColumn => switch (this) {
        TodoGranularity.month => 40.0,
        TodoGranularity.week => 64.0,
        TodoGranularity.day => 32.0,
      };
}

/// Monday of [d]'s week.
DateTime _weekStart(DateTime d) {
  final date = DateTime(d.year, d.month, d.day);
  return date.subtract(Duration(days: (date.weekday + 6) % 7));
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The todo's day-key span under the single-day conventions — THE one
/// definition: both dates → [s, e]; inverted span or a single date →
/// that one day (the web's rule: an inverted pair renders on the due
/// day); undated → null. Every pane consumes this so the conventions
/// cannot drift apart.
({String s, String e})? _spanOf(KbSource t) {
  final s = t.startAt == null ? '' : _dayKey(t.startAt!.toLocal());
  final e = t.endAt == null ? '' : _dayKey(t.endAt!.toLocal());
  if (s.isEmpty && e.isEmpty) return null;
  if (s.isEmpty || (e.isNotEmpty && e.compareTo(s) < 0)) return (s: e, e: e);
  if (e.isEmpty) return (s: s, e: s);
  return (s: s, e: e);
}

/// 42 days (6 weeks, Monday-first) covering [anchor]'s month, so a todo
/// spanning a week boundary still renders as aligned bars.
List<DateTime> _monthGrid(DateTime anchor) =>
    List.generate(42, (i) => _weekStart(DateTime(anchor.year, anchor.month, 1)).add(Duration(days: i)));

/// The 7 days of [anchor]'s week (Monday-first).
List<DateTime> _weekGrid(DateTime anchor) =>
    List.generate(7, (i) => _weekStart(anchor).add(Duration(days: i)));

/// Active todo whose due timestamp is in the past (web todoOverdue).
bool _overdue(KbSource t) =>
    t.endAt != null &&
    t.endAt!.isBefore(DateTime.now()) &&
    (t.status == 'pending' || t.status == 'in_progress');

Color _statusDot(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    'in_progress' => paletteOf(context).info,
    'done' => paletteOf(context).success,
    _ => scheme.outline,
  };
}

/// Chip fg/bg pair per lifecycle state (web statusChipBg) — one switch
/// instead of a color function per use.
(Color, Color) _statusChipColors(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    'in_progress' => (
        paletteOf(context).info,
        paletteOf(context).info.withValues(alpha: 0.15)
      ),
    'done' => (
        paletteOf(context).success,
        paletteOf(context).success.withValues(alpha: 0.15)
      ),
    'cancelled' => (
        scheme.outline,
        scheme.secondaryContainer.withValues(alpha: 0.6)
      ),
    _ => (scheme.onSurface.withValues(alpha: 0.75), scheme.secondaryContainer),
  };
}

/// The red overdue marker (sized per context: rows 6, calendar chip 4).
Widget _overdueDot(BuildContext context, {double size = 6}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: paletteOf(context).destructive, shape: BoxShape.circle),
    );

/// Status color of a span bar (progress-bar look): the whole start→due
/// strip fills with the lifecycle color — blue in progress, green done,
/// muted gray pending, faded+struck cancelled. Shared by the calendar
/// track bars and the gantt rows.
Color _barColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    'in_progress' => paletteOf(context).info,
    'done' => paletteOf(context).success,
    'cancelled' => scheme.outline.withValues(alpha: 0.3),
    _ => scheme.outline.withValues(alpha: 0.5), // pending
  };
}

/// A todo's date coverage: "M/d – M/d" when start and due fall on
/// different days, else the single timestamp (web todoSpanText).
/// Undated todos render an empty label — never a fabricated date.
String _spanText(KbSource t) {
  final s = t.startAt?.toLocal();
  final e = t.endAt?.toLocal();
  if (s != null && e != null) {
    return _dayKey(s) == _dayKey(e)
        ? formatShortDate(e)
        : '${formatShortDate(s)} – ${formatShortDate(e)}';
  }
  return (s == null && e == null) ? '' : formatShortDate((e ?? s)!);
}

/// Border-only card frame (the tinted variant is surfaceCardDecoration
/// in tokens) — one owner for the todo panes' five frames.
BoxDecoration _outlineCard(ThemeData theme) => BoxDecoration(
      borderRadius: AppRadius.cardBorder,
      border: Border.all(color: theme.colorScheme.outlineVariant),
    );

/// "New todo at 09:00" action shared by the calendar's day view and
/// the cell day sheet.
Widget _dayCreateButton(AppLocalizations l, ValueChanged<DateTime> onCreateAt, DateTime day) => SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: () => onCreateAt(DateTime(day.year, day.month, day.day, 9)),
        icon: const Icon(LucideIcons.plus, size: 16),
        label: Text(l.kbAddTodo),
      ),
    );

/// Title text that recovers the full content when the server truncated
/// the row title (~50 bytes + '…', deriveTitle): fetches the source's
/// entries once and shows the first non-empty line (web todoFirstLine)
/// — the same recovery the list view's _TodoTile does. Used by the
/// gantt rows and [TodoLine]; the calendar's tiny chips keep the
/// truncated title.
class TodoFullTitle extends ConsumerStatefulWidget {
  const TodoFullTitle({super.key, required this.todo, this.style});

  final KbSource todo;
  final TextStyle? style;

  @override
  ConsumerState<TodoFullTitle> createState() => _TodoFullTitleState();
}

class _TodoFullTitleState extends ConsumerState<TodoFullTitle> {
  String? _full;

  @override
  void initState() {
    super.initState();
    if (widget.todo.title.endsWith('…')) _load();
  }

  @override
  void didUpdateWidget(TodoFullTitle old) {
    super.didUpdateWidget(old);
    // Row elements are reused positionally — a different todo at the
    // same spot must not keep the old title's fetched text.
    if (old.todo.id != widget.todo.id) {
      _full = null;
      if (widget.todo.title.endsWith('…')) _load();
    }
  }

  Future<void> _load() async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    try {
      final text = await ref.read(kbRepoProvider).fullText(agentId, widget.todo.id);
      final line = text
          .split('\n')
          .map((l) => l.replaceFirst(RegExp('^#{1,6}\\s*'), '').trim())
          .firstWhere((l) => l.isNotEmpty, orElse: () => '');
      if (line.isNotEmpty && mounted) setState(() => _full = line);
    } catch (_) {
      // Offline/failure: the truncated title stays.
    }
  }

  @override
  Widget build(BuildContext context) => Text(_full ?? widget.todo.title, style: widget.style);
}

/// Prev / period-title / next / today — the shared calendar + gantt
/// header (web MonthNav) with the granularity pill; arrows step by the
/// active granularity.
class MonthNavRow extends StatelessWidget {
  const MonthNavRow({
    super.key,
    required this.anchor,
    required this.granularity,
    required this.onGranularity,
    required this.onChange,
    this.trailing,
  });

  final DateTime anchor;
  final TodoGranularity granularity;
  final ValueChanged<TodoGranularity> onGranularity;
  final ValueChanged<DateTime> onChange;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final title = switch (granularity) {
      TodoGranularity.month => formatMonthTitle(anchor, locale: l.localeName),
      TodoGranularity.week =>
        '${formatShortDate(anchor)} – ${formatShortDate(anchor.add(const Duration(days: 6)))}',
      TodoGranularity.day => formatDayLabel(anchor, locale: l.localeName),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => onChange(granularity.step(anchor, -1)),
              icon: const Icon(LucideIcons.chevronLeft, size: 18),
            ),
            Expanded(
              child: Center(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => onChange(granularity.step(anchor, 1)),
              icon: const Icon(LucideIcons.chevronRight, size: 18),
            ),
            TextButton(
              onPressed: () => onChange(granularity.normalize(DateTime.now())),
              child: Text(l.chatToday),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              GranularityPill(
                  granularity: granularity, onGranularity: onGranularity),
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact 月/周/日 toggle shared by the two panes.
class GranularityPill extends StatelessWidget {
  const GranularityPill({super.key, required this.granularity, required this.onGranularity});

  final TodoGranularity granularity;
  final ValueChanged<TodoGranularity> onGranularity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final g in TodoGranularity.values)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => onGranularity(g),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: g == granularity ? scheme.secondaryContainer : null,
                ),
                child: Text(
                  switch (g) {
                    TodoGranularity.month => l.kbViewMonth,
                    TodoGranularity.week => l.kbViewWeek,
                    TodoGranularity.day => l.kbViewDay,
                  },
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: g == granularity ? scheme.onSecondaryContainer : scheme.outline,
                    fontWeight: g == granularity ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact one-line todo row (day sheets, undated strips, day view):
/// status dot + title + span, strike-through for done/cancelled.
class TodoLine extends StatelessWidget {
  const TodoLine({super.key, required this.todo, required this.onOpen});

  final KbSource todo;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelled = todo.status == 'cancelled';
    final struck = cancelled || todo.status == 'done';
    final span = _spanText(todo);
    return InkWell(
      onTap: onOpen,
      borderRadius: AppRadius.controlBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: _statusDot(context, todo.status), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TodoFullTitle(
                todo: todo,
                style: TextStyle(
                  decoration: struck ? TextDecoration.lineThrough : null,
                  color: cancelled ? theme.colorScheme.outline : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_overdue(todo))
              Padding(padding: const EdgeInsets.only(right: 6), child: _overdueDot(context)),
            if (span.isNotEmpty)
              Text(span,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

/// Collapsed no-date list shared by the calendar and gantt (web
/// UndatedStrip).
class UndatedStrip extends StatefulWidget {
  const UndatedStrip({super.key, required this.items, required this.onOpen});

  final List<KbSource> items;
  final void Function(KbSource) onOpen;

  @override
  State<UndatedStrip> createState() => _UndatedStripState();
}

class _UndatedStripState extends State<UndatedStrip> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: _outlineCard(theme),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Text('${l.kbNoDate} (${widget.items.length})',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                  const Spacer(),
                  Icon(_open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                      size: 14, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
          if (_open)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                for (final t in widget.items) TodoLine(todo: t, onOpen: () => widget.onOpen(t)),
              ],
            ),
        ],
      ),
    );
  }
}

/// A dated todo placed on the grid: [track] keeps a multi-day span on
/// one row across the week (web calendar layout).
class _CalSeg {
  const _CalSeg(this.todo, this.track, this.roundStart, this.roundEnd);
  final KbSource todo;
  final int track;
  final bool roundStart;
  final bool roundEnd;
}

class _CalLayout {
  _CalLayout(this.byDay, this.undated);
  final Map<String, List<_CalSeg>> byDay;
  final List<KbSource> undated;
}

/// Per-day segments with track assignment over [grid]: the lowest track
/// free across an event's whole in-grid span keeps a multi-day bar on
/// one row, so it reads as one continuous block across the week (direct
/// port of the web algorithm). Span conventions come from [_spanOf].
_CalLayout _calendarLayout(List<KbSource> items, List<DateTime> grid) {
  final gridKeys = grid.map(_dayKey).toList();
  final evs = <(KbSource, String s, String e)>[];
  final undated = <KbSource>[];
  for (final t in items) {
    final span = _spanOf(t);
    if (span == null) {
      undated.add(t);
    } else {
      evs.add((t, span.s, span.e));
    }
  }
  evs.sort((a, b) => a.$2.compareTo(b.$2));

  final taken = <int, Set<String>>{};
  final byDay = <String, List<_CalSeg>>{};
  for (final (t, s, e) in evs) {
    final days = gridKeys.where((k) => k.compareTo(s) >= 0 && k.compareTo(e) <= 0).toList();
    if (days.isEmpty) continue;
    // Lowest track whose days are all free across the span.
    var track = 0;
    outer:
    while (true) {
      final set = taken[track];
      if (set == null) break;
      for (final k in days) {
        if (set.contains(k)) {
          track++;
          continue outer;
        }
      }
      break;
    }
    (taken[track] ??= {}).addAll(days);
    for (final k in days) {
      final idx = gridKeys.indexOf(k);
      byDay.putIfAbsent(k, () => []).add(_CalSeg(
        t,
        track,
        k == s || idx % 7 == 0, // flatten at week edges, round on span ends
        k == e || idx % 7 == 6,
      ));
    }
  }
  return _CalLayout(byDay, undated);
}

/// Month / week calendar grid. Month cells carry status track bars (max
/// 2 + "+N"); the week's taller cells carry text chips like the web's
/// desktop calendar (max 5 + "+N"). Tapping a cell opens a day sheet
/// with the day's todos and a "new todo at 9:00" action; the day
/// granularity becomes that sheet as a page.
class TodoCalendarView extends StatelessWidget {
  const TodoCalendarView({
    super.key,
    required this.items,
    required this.anchor,
    required this.granularity,
    required this.onGranularity,
    required this.onAnchor,
    required this.onOpen,
    required this.onCreateAt,
  });

  final List<KbSource> items;
  final DateTime anchor;
  final TodoGranularity granularity;
  final ValueChanged<TodoGranularity> onGranularity;
  final ValueChanged<DateTime> onAnchor;
  final void Function(KbSource) onOpen;
  final ValueChanged<DateTime> onCreateAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    if (granularity == TodoGranularity.day) return _dayView(context, l, theme);

    final grid = granularity == TodoGranularity.month ? _monthGrid(anchor) : _weekGrid(anchor);
    final layout = _calendarLayout(items, grid);
    final todayK = _dayKey(DateTime.now());
    final dows = weekdayShortLabels(l.localeName);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        MonthNavRow(
            anchor: anchor, granularity: granularity, onGranularity: onGranularity, onChange: onAnchor),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Row(
                children: [
                  for (final d in dows)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Center(
                          child: Text(d,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.outline)),
                        ),
                      ),
                    ),
                ],
              ),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              // Week rows of seven cells — Rows instead of GridView so
              // the whole grid shares the container's width. Fixed cell
              // height (NOT CrossAxisAlignment.stretch): the grid lives
              // in a ListView's unbounded height, where stretch forces
              // an infinite-height constraint and the layout fails.
              for (final week in _weeks(grid))
                Row(
                  children: [
                    for (final day in week)
                      _cell(context, day, todayK, layout,
                          compact: granularity == TodoGranularity.month),
                  ],
                ),
            ],
          ),
        ),
        if (layout.undated.isNotEmpty)
          UndatedStrip(items: layout.undated, onOpen: onOpen),
      ],
    );
  }

  List<List<DateTime>> _weeks(List<DateTime> grid) => [
        for (var i = 0; i < grid.length; i += 7) grid.sublist(i, i + 7),
      ];

  /// The day granularity: the day sheet's content as the page — every
  /// todo overlapping the day plus the same "new at 9:00" action.
  Widget _dayView(BuildContext context, AppLocalizations l, ThemeData theme) {
    final dayItems = _todosOn(items, anchor);
    final undated = _undated(items);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        MonthNavRow(
            anchor: anchor, granularity: granularity, onGranularity: onGranularity, onChange: onAnchor),
        const SizedBox(height: 12),
        if (dayItems.isEmpty)
          EmptyState(icon: LucideIcons.squareCheckBig, message: l.kbNoTodos)
        else
          Container(
            decoration: _outlineCard(theme),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final t in dayItems) TodoLine(todo: t, onOpen: () => onOpen(t)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _dayCreateButton(l, onCreateAt, anchor),
        if (undated.isNotEmpty) UndatedStrip(items: undated, onOpen: onOpen),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime day, String todayK, _CalLayout layout,
      {required bool compact}) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final k = _dayKey(day);
    final inMonth = day.month == anchor.month;
    final isToday = k == todayK;
    // Copy before sorting — the const fallback (and any future immutable
    // list) rejects in-place sort.
    final segs = (layout.byDay[k] ?? const <_CalSeg>[]).toList()
      ..sort((a, b) => a.track.compareTo(b.track));

    // Track-padded bar rows: a bar on track 1 keeps one blank row above
    // it so its position stays stable across days. Month cells cap at
    // 2 bars (then +N); the week's tall cells take 5 chips.
    final maxTracks = compact ? 2 : 5;
    final shown = segs.where((s) => s.track < maxTracks).toList();
    final hidden = segs.length - shown.length;

    return Expanded(
      child: InkWell(
        onTap: () => _openDaySheet(context, l, day, layout.byDay[k] ?? const [], onOpen, onCreateAt),
        child: Container(
          // Fixed height keeps the week row aligned without stretch
          // (web cells are min-h 76/96; 74 fits two bars + +N on a
          // phone column). Week cells are proportionally taller for
          // text chips.
          height: compact ? 74.0 : 340.0,
          foregroundDecoration: BoxDecoration(
            color: inMonth ? null : scheme.secondaryContainer.withValues(alpha: 0.25),
            border: Border(
              top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
              right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? scheme.primary : null,
                ),
                child: Text('${day.day}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isToday
                          ? scheme.onPrimary
                          : inMonth
                              ? scheme.onSurface
                              : scheme.outline,
                      fontWeight: isToday ? FontWeight.w700 : null,
                    )),
              ),
              const SizedBox(height: 4),
              for (final seg in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: compact ? _bar(context, seg) : _chip(context, seg),
                ),
              if (hidden > 0)
                Text('+$hidden',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.outline, fontSize: AppType.chart)),
            ],
          ),
        ),
      ),
    );
  }

  /// Status-tinted track bar; a multi-day span keeps one row via
  /// [roundStart]/[roundEnd] flattening at week edges.
  Widget _bar(BuildContext context, _CalSeg seg) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: _barColor(context, seg.todo.status),
        borderRadius: BorderRadius.horizontal(
          left: seg.roundStart ? const Radius.circular(3) : Radius.zero,
          right: seg.roundEnd ? const Radius.circular(3) : Radius.zero,
        ),
      ),
    );
  }

  /// The week cell's text chip (web's desktop calendar chip): status
  /// background tint + truncated title + overdue dot.
  Widget _chip(BuildContext context, _CalSeg seg) {
    final theme = Theme.of(context);
    final cancelled = seg.todo.status == 'cancelled';
    final (fg, bg) = _statusChipColors(context, seg.todo.status);
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.horizontal(
          left: seg.roundStart ? const Radius.circular(3) : Radius.zero,
          right: seg.roundEnd ? const Radius.circular(3) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              seg.todo.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: AppType.chart,
                color: fg,
                decoration: cancelled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (_overdue(seg.todo))
            Padding(padding: const EdgeInsets.only(left: 2), child: _overdueDot(context, size: 4)),
        ],
      ),
    );
  }
}

/// The day sheet a calendar cell opens: full [TodoLine] rows for the
/// day plus a "new todo" action dated that day at 09:00 (the web's
/// mobile cell behavior).
void _openDaySheet(
  BuildContext context,
  AppLocalizations l,
  DateTime day,
  List<_CalSeg> segs,
  void Function(KbSource) onOpen,
  ValueChanged<DateTime> onCreateAt,
) {
  // Schedule order like the day views; the calendar cell's own chip
  // track layout stays as built (user feedback).
  final ordered = [...segs]..sort((a, b) => compareTodosByStart(a.todo, b.todo));
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(formatDayLabel(day, locale: l.localeName),
                style: Theme.of(sheetContext).textTheme.titleSmall),
          ),
          Flexible(
            child: segs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(l.kbNoTodos,
                        style: TextStyle(color: Theme.of(sheetContext).colorScheme.outline)),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final seg in ordered)
                        TodoLine(
                          todo: seg.todo,
                          onOpen: () {
                            Navigator.of(sheetContext).pop();
                            onOpen(seg.todo);
                          },
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            // Pop first so the editor page pushes after the sheet is
            // gone (same for the create button's 9:00 default).
            child: _dayCreateButton(l, (d) {
              Navigator.of(sheetContext).pop();
              onCreateAt(d);
            }, day),
          ),
        ],
      ),
    ),
  );
}

class _GanttRow {
  _GanttRow(this.todo, this.s, this.e, this.clippedStart, this.clippedEnd);
  final KbSource todo;
  final int s, e; // day indexes 0-based within the window
  final bool clippedStart, clippedEnd;
}

/// Month / week gantt: one row per dated task overlapping the window.
/// Mobile layout — no 120px name gutter, no horizontal scroll (both
/// truncate titles on a phone): each row is a tappable full-width
/// title line with the span drawn as a proportional mini bar under it,
/// all rows sharing one header ruler so overlaps still read at a
/// glance. Row count itself reads as the period workload; undated
/// tasks collapse into the shared strip (web TodoGantt). The day
/// granularity becomes a 24-hour schedule with the same shape.
class TodoGanttView extends StatelessWidget {
  const TodoGanttView({
    super.key,
    required this.items,
    required this.anchor,
    required this.granularity,
    required this.onGranularity,
    required this.onAnchor,
    required this.onOpen,
  });

  final List<KbSource> items;
  final DateTime anchor;
  final TodoGranularity granularity;
  final ValueChanged<TodoGranularity> onGranularity;
  final ValueChanged<DateTime> onAnchor;
  final void Function(KbSource) onOpen;

  /// Content width for the horizontally-swiped timeline card: enough
  /// pixels per column to stay readable, or the natural screen width
  /// when fewer columns would only spread out.
  double _contentWidth(BuildContext context, int columns) {
    final natural = MediaQuery.sizeOf(context).width - 24; // page padding
    return (columns * granularity.perColumn).clamp(natural, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final todayK = _dayKey(DateTime.now());

    if (granularity == TodoGranularity.day) {
      return _dayView(context, theme, l);
    }

    final (ws, we) = granularity.window(anchor);
    final days =
        List.generate(we.difference(ws).inDays + 1, (i) => ws.add(Duration(days: i)));
    final rows = _ganttRows(items, ws, we);
    final undated = _undated(items);
    final todayIdx = days.indexWhere((d) => _dayKey(d) == todayK);
    final scope = granularity == TodoGranularity.month ? l.kbScopeMonth : l.kbScopeWeek;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        MonthNavRow(
          anchor: anchor,
          granularity: granularity,
          onGranularity: onGranularity,
          onChange: onAnchor,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('$scope ${l.kbGanttCount(rows.length)}',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          EmptyState(icon: LucideIcons.squareCheckBig, message: l.kbNoTodos)
        else
          // Horizontal swipe with a wide enough content width — a
          // month's 31 columns squeezed into one screen width is
          // unreadable (user feedback). The week (7 columns) keeps the
          // natural screen width, so it never feels scrollable.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _contentWidth(context, days.length),
              child: Container(
                decoration: _outlineCard(theme),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(context, days, todayK),
                    for (final r in rows) _row(context, r, days, todayIdx),
                  ],
                ),
              ),
            ),
          ),
        if (undated.isNotEmpty) UndatedStrip(items: undated, onOpen: onOpen),
      ],
    );
  }

  /// Header ruler: one slot per day (weekend muted, today primary) —
  /// no name gutter, the titles live above each bar.
  Widget _header(BuildContext context, List<DateTime> days, String todayK) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration:
                  BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
              child: Builder(builder: (context) {
                final isToday = _dayKey(d) == todayK;
                final weekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
                return Text(
                  '${d.day}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppType.chart,
                    color: isToday
                        ? scheme.primary
                        : weekend
                            ? scheme.outline
                            : scheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: isToday ? FontWeight.w700 : null,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  /// One task row: the shared shell maps the span onto fractions of
  /// the content width (day-index/n for month+week, hour/24 for the
  /// day view) — only the mapping differs between the two variants.
  Widget _ganttRowShell(
    BuildContext context,
    KbSource t, {
    required String spanLabel,
    required double startFrac,
    required double endFrac,
    double? nowFrac,
    bool clipStart = false,
    bool clipEnd = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cancelled = t.status == 'cancelled';
    return InkWell(
      onTap: () => onOpen(t),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full-width readable title (wraps to two lines — server
            // titles are ~50 bytes, so that is the whole text in
            // practice); the whole row is the tap target.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: _statusDot(context, t.status), shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // Full title: recovers the server-truncated row title
                  // (…-terminated) from the source's entries; no line
                  // cap — the wide content columns hold it, long ones
                  // just wrap.
                  child: TodoFullTitle(
                    todo: t,
                    // Body step like the list view's rows — the gantt
                    // titles used to sit one step smaller than the
                    // sibling list tab (user feedback).
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      color: cancelled ? scheme.outline : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_overdue(t))
                        Padding(padding: const EdgeInsets.only(right: 6), child: _overdueDot(context)),
                      if (spanLabel.isNotEmpty)
                        Text(spanLabel,
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Progress-bar span: the whole start→due strip fills with
            // the status color over the pale track, so length AND
            // lifecycle read at a glance; clipped ends go square (the
            // span continues beyond the window).
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final left = w * startFrac;
                final width = (w * (endFrac - startFrac)).clamp(4.0, w - left);
                return SizedBox(
                  height: 14,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            color: scheme.secondaryContainer.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      Positioned(
                        left: left,
                        width: width,
                        top: 1,
                        bottom: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.horizontal(
                              left: clipStart ? Radius.zero : const Radius.circular(6),
                              right: clipEnd ? Radius.zero : const Radius.circular(6),
                            ),
                            color: _barColor(context, t.status),
                          ),
                        ),
                      ),
                      if (nowFrac != null)
                        Positioned(
                          left: (w * nowFrac - 0.75).clamp(0, w - 1.5),
                          top: 0,
                          bottom: 0,
                          width: 1.5,
                          child: DecoratedBox(
                            decoration:
                                BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.55)),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Month/week row: window day indexes → fractions; today's marker
  /// sits mid-column ([todayIdx] is precomputed per build).
  Widget _row(BuildContext context, _GanttRow r, List<DateTime> days, int todayIdx) {
    final n = days.length;
    return _ganttRowShell(
      context,
      r.todo,
      spanLabel: _spanText(r.todo),
      startFrac: r.s / n,
      endFrac: (r.e + 1) / n,
      nowFrac: todayIdx >= 0 ? (todayIdx + 0.5) / n : null,
      clipStart: r.clippedStart,
      clipEnd: r.clippedEnd,
    );
  }

  /// Day granularity: the same shape over a 24-hour ruler — full-width
  /// titles, the bar running from start time to end time (date-only
  /// and midnight-to-midnight spans render as full-day bars), a now
  /// line when the anchor is today.
  Widget _dayView(BuildContext context, ThemeData theme, AppLocalizations l) {
    final scheme = theme.colorScheme;
    final rows = _todosOn(items, anchor);
    final undated = _undated(items);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        MonthNavRow(
          anchor: anchor,
          granularity: granularity,
          onGranularity: onGranularity,
          onChange: onAnchor,
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('${l.kbScopeDay} ${l.kbGanttCount(rows.length)}',
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          EmptyState(icon: LucideIcons.squareCheckBig, message: l.kbNoTodos)
        else
          // Same wide-content horizontal swipe as the month/week card
          // (24 hour columns at 40px each).
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _contentWidth(context, 24),
              child: Container(
                decoration: _outlineCard(theme),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hour ruler: every hour labeled. Cell width comes
                    // from the card's actual inner width (the border
                    // stroke eats 2px of the SizedBox), keeping labels
                    // aligned exactly with the bar geometry — a fixed
                    // 24×perColumn row would overflow by that stroke.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cell = constraints.maxWidth / 24;
                        return Row(
                          children: [
                            for (var h = 0; h < 24; h++)
                              Container(
                                width: cell,
                                padding: const EdgeInsets.only(top: 4, bottom: 4, left: 2),
                                decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
                                child: Text('$h',
                                    maxLines: 1,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(fontSize: AppType.chart, color: scheme.outline)),
                              ),
                          ],
                        );
                      },
                    ),
                    for (final t in rows) _hourRow(context, t),
                  ],
                ),
              ),
            ),
          ),
        if (undated.isNotEmpty) UndatedStrip(items: undated, onOpen: onOpen),
      ],
    );
  }

  /// Hour row: start/end times → fractions of the 24h ruler. Date-only
  /// (or midnight-to-midnight) spans render as full-day bars.
  Widget _hourRow(BuildContext context, KbSource t) {
    final s = (t.startAt ?? t.endAt)!.toLocal();
    final e = (t.endAt ?? t.startAt)!.toLocal();
    final dateOnly = (t.startAt == null || (t.startAt!.hour == 0 && t.startAt!.minute == 0)) &&
        (t.endAt == null || (t.endAt!.hour == 0 && t.endAt!.minute == 0));
    final double startH;
    final double endH;
    if (dateOnly) {
      startH = 0;
      endH = 24;
    } else {
      startH = _dayKey(s) == _dayKey(anchor) ? s.hour + s.minute / 60 : 0;
      endH = _dayKey(e) == _dayKey(anchor) ? e.hour + e.minute / 60 : 24;
    }

    final now = DateTime.now();
    final isToday = _dayKey(now) == _dayKey(anchor);
    return _ganttRowShell(
      context,
      t,
      spanLabel: dateOnly
          ? _spanText(t)
          : '${formatTimeOfDay(s)} – ${formatTimeOfDay(e)}',
      startFrac: startH / 24,
      endFrac: endH / 24,
      nowFrac: isToday ? (now.hour + now.minute / 60) / 24 : null,
      clipStart: startH == 0,
      clipEnd: endH >= 24,
    );
  }
}

/// Todos overlapping a calendar day ([_spanOf] owns the conventions),
/// in start-time order — the day views read as a schedule, and the
/// server's updated_at order made the rows jump around (user feedback).
List<KbSource> _todosOn(List<KbSource> items, DateTime day) {
  final k = _dayKey(day);
  final todos = items
      .where((t) {
        final span = _spanOf(t);
        return span != null && k.compareTo(span.s) >= 0 && k.compareTo(span.e) <= 0;
      })
      .toList();
  todos.sort(compareTodosByStart);
  return todos;
}

/// Schedule order shared by the day views and the calendar day sheet
/// (user rule): timed starts first (by start, then end), end-only
/// deadlines after them (by end), fully undated last.
int compareTodosByStart(KbSource a, KbSource b) {
  final sa = a.startAt, sb = b.startAt;
  if (sa != null && sb != null) {
    final c = sa.compareTo(sb);
    return c != 0 ? c : (a.endAt ?? sa).compareTo(b.endAt ?? sb);
  }
  if (sa != null) return -1;
  if (sb != null) return 1;
  final ea = a.endAt, eb = b.endAt;
  if (ea == null && eb == null) return 0;
  if (ea == null) return 1;
  if (eb == null) return -1;
  return ea.compareTo(eb);
}

List<KbSource> _undated(List<KbSource> items) =>
    items.where((t) => _spanOf(t) == null).toList(growable: false);

/// Rows for the window [ws]–[we]: dated todos overlapping it, bars
/// clipped at the edges; sorted by start then end (web TodoGantt).
List<_GanttRow> _ganttRows(List<KbSource> items, DateTime ws, DateTime we) {
  final firstK = _dayKey(ws);
  final lastK = _dayKey(we);
  final day = DateTime(ws.year, ws.month, ws.day);
  final index = <String, int>{};
  for (var i = 0; i <= we.difference(ws).inDays; i++) {
    index[_dayKey(day.add(Duration(days: i)))] = i;
  }
  final rows = <_GanttRow>[];
  for (final t in items) {
    final span = _spanOf(t);
    if (span == null) continue; // undated live in the strip
    if (span.e.compareTo(firstK) < 0 || span.s.compareTo(lastK) > 0) continue;
    rows.add(_GanttRow(
      t,
      span.s.compareTo(firstK) < 0 ? 0 : index[span.s]!,
      span.e.compareTo(lastK) > 0 ? index.length - 1 : index[span.e]!,
      span.s.compareTo(firstK) < 0,
      span.e.compareTo(lastK) > 0,
    ));
  }
  rows.sort((a, b) => a.s.compareTo(b.s) != 0 ? a.s.compareTo(b.s) : a.e.compareTo(b.e));
  return rows;
}
