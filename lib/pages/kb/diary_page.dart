import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_routes.dart';
import '../../kb/diary_models.dart';
import '../../kb/diary_repo.dart';
import '../../kb/shelved_actions.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/fling_detector.dart';
import '../../ui/master_detail.dart';
import '../../ui/load_states.dart';
import '../../ui/row_meta.dart';
import '../../util/dates.dart';

/// Diary (web `agents/<id>/knowledge/diary`, stacked for mobile): the
/// month heatmap calendar stays pinned on top; the area below swaps
/// between the month's entries (nothing selected) and the selected
/// day's content — never a page navigation, the calendar never moves.
class KbDiaryPage extends ConsumerStatefulWidget {
  const KbDiaryPage({super.key, this.initialDate});

  /// YYYY-MM-DD day to open directly (card-source jumps, ?date=).
  final String? initialDate;

  @override
  ConsumerState<KbDiaryPage> createState() => _KbDiaryPageState();
}

/// Today as the diary's YYYY-MM-DD UTC+8 frame (server dates live there).
String _todayCST() =>
    DateTime.now().toUtc().add(const Duration(hours: 8)).toIso8601String().substring(0, 10);

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _KbDiaryPageState extends ConsumerState<KbDiaryPage> {
  late DateTime _month = DateTime.parse('${_todayCST().substring(0, 7)}-01');
  late String _genDate = _todayCST();
  String? _selected;

  /// Calendar folded to the open day's single week — set by scrolling up
  /// inside the day pane (reading space wins over the month overview),
  /// cleared when the reader returns to the top or back to the list.
  bool _collapsed = false;

  /// Last seen split flag — the fold is phone-only, so entering the wide
  /// layout must reset [_collapsed] or the visual (always-expanded
  /// calendar) and the gates (drawerFling, enableRefresh) decouple.
  bool? _lastSplit;

  @override
  void initState() {
    super.initState();
    // Deep-linked day (card-source jump): land on its month with it open.
    final initial = widget.initialDate;
    final d = initial == null ? null : DateTime.tryParse('${initial}T00:00:00');
    if (d != null) {
      _month = DateTime(d.year, d.month, 1);
      _genDate = _ymd(d);
      _selected = _genDate;
    }
  }

  /// Fold/unfold driver for the day pane's scroll: a downward read (finger
  /// up) collapses once the gesture's accumulated travel passes a small
  /// threshold — per-frame deltas never fire on a slow drag. Days with no
  /// or shorter-than-viewport content never produce scroll deltas, so the
  /// fold also listens at the bottom edge: a damped upward overscroll
  /// (≥90px) collapses those (user report 2026-11-19). Unfolding stays
  /// the deliberate damped top pull; the pull-to-refresh only mounts in
  /// the expanded state, so the three gestures never fight.
  ///
  /// Invariant: the bottom-edge pull rides the SAME accumulator as scroll
  /// travel, and the two paths can never compete — taller content folds
  /// at the tiny >12 travel in ScrollUpdate (before any overscroll can
  /// happen), shorter content accumulates only overscroll and folds at
  /// the ScrollEnd ≥90px check.
  double _readScroll = 0;
  double _expandPull = 0;

  bool _onDayPaneScroll(ScrollNotification n) {
    if (n.depth != 0 || _selected == null) return false;
    if (n is ScrollStartNotification) {
      _readScroll = 0;
      _expandPull = 0;
    } else if (n is ScrollUpdateNotification) {
      _readScroll += n.scrollDelta ?? 0;
      if (_readScroll > 12 && !_collapsed) {
        setState(() => _collapsed = true);
      }
    } else if (n is OverscrollNotification) {
      // ClampingScrollPhysics reports a top-edge pull as NEGATIVE
      // overscroll (value - pixels < 0 at min extent) and a bottom-edge
      // pull as positive (at max extent).
      if (n.overscroll < 0 && n.metrics.pixels <= 0 && _collapsed) {
        _expandPull += -n.overscroll;
      } else if (n.overscroll > 0 &&
          n.metrics.pixels >= n.metrics.maxScrollExtent &&
          !_collapsed) {
        _readScroll += n.overscroll;
      }
    } else if (n is ScrollEndNotification) {
      if (_collapsed ? _expandPull >= 90 : _readScroll >= 90) {
        setState(() => _collapsed = !_collapsed);
      }
      _readScroll = 0;
      _expandPull = 0;
    }
    return false;
  }

  void _shiftMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta, 1);
        _selected = null;
        _collapsed = false;
      });

  /// Fling left/right inside the open day = next/previous day (calendar
  /// convention: right = back a day), clamped at today. The month view
  /// follows across month boundaries so the heat calendar stays in sync.
  void _shiftDay(int deltaDays) {
    final s = _selected;
    if (s == null) return;
    final d = DateTime.parse('$s 00:00:00').add(Duration(days: deltaDays));
    final today = DateTime.parse('${_todayCST()} 00:00:00');
    if (d.isAfter(today)) return;
    setState(() {
      _genDate = _ymd(d);
      _selected = _genDate;
      _month = DateTime(d.year, d.month, 1);
    });
  }

  Future<void> _pickDate() async {
    final today = DateTime.tryParse(_todayCST());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_genDate) ?? today ?? DateTime.now(),
      firstDate: DateTime(today?.year ?? 2026, 1, 1),
      lastDate: today ?? DateTime.now(),
    );
    if (picked != null) setState(() => _genDate = _ymd(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    if (agentId == null) {
      return Scaffold(appBar: AppBar(title: Text(l.kbDiary)));
    }
    final ym = _ymd(_month).substring(0, 7);
    final diaries = ref.watch(diaryMonthProvider((agentId, ym)));
    final split = MasterDetailScaffold.isSplit(context);
    // The fold is phone-only — reset it when entering the wide layout
    // (plain field mutation before the widgets build; no setState).
    if (_lastSplit == false && split && _collapsed) {
      _collapsed = false;
    }
    _lastSplit = split;

    // A run that just finished → reload the month (and the selected
    // day's entry, if shown).
    ref.listen(diaryGeneratingProvider, (prev, next) {
      final finished = prev != null && prev.any((d) => !next.contains(d));
      if (finished) {
        ref.invalidate(diaryMonthProvider((agentId, ym)));
        final s = _selected;
        if (s != null) ref.invalidate(diaryEntryProvider((agentId, s)));
      }
    });

    // Wide (tablet landscape): the left column keeps month nav + heat
    // calendar + generate row + the month entries ALWAYS visible; the
    // selected day's pane docks right (no fold, no swap). Phone keeps the
    // original fold-on-scroll swap behavior.
    //
    // The open day pane renders from its own entry provider and stays
    // mounted across a month load (a cross-month day fling swaps the
    // month provider to loading) — a whole-body skeleton here used to
    // blank out the text being read.
    final list = diaries.value ?? const <DailyDiary>[];
    final byDate = {for (final d in list) d.date: d};
    final entries =
        list.where((d) => !d.isEmptyDay).toList()..sort((a, b) => b.date.compareTo(a.date));
    final genRunning =
        ref.watch(diaryGeneratingProvider.select((s) => s.contains(_genDate)));
    // An already-empty day yields nothing on regeneration — the
    // server had no summaries for it (web genDateIsEmpty).
    final genDateEmpty = byDate[_genDate]?.isEmptyDay ?? false;
    // The fold applies only with a day open — one boolean, three
    // readers (calendar, generate row, scroll listener's gate).
    // Phone-only: the wide layout never folds (nothing swaps).
    final folded = !split && _collapsed && _selected != null;
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          _MonthNav(month: _month, onShift: _shiftMonth),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? AppMotion.reducedFade
                : const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeatCalendar(
                  month: _month,
                  byDate: byDate,
                  selected: _selected ?? _genDate,
                  collapsed: folded,
                  onTapDay: (date) => setState(() {
                    _genDate = date;
                    _selected = date;
                  }),
                ),
                if (!folded) ...[
                  const SizedBox(height: 6),
                  _GenerateRow(
                    date: _genDate,
                    running: genRunning,
                    disabled: genRunning || genDateEmpty,
                    onPick: _pickDate,
                    onGenerate: () => ref
                        .read(diaryGeneratingProvider.notifier)
                        .start(agentId, _genDate),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    final entriesPane = entries.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.diaryNoDiaryMonth,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
            ),
          )
        : RefreshIndicator(
            onRefresh: () =>
                ref.refresh(diaryMonthProvider((agentId, ym)).future),
            child: ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final d = entries[i];
                return ChevronListTile(
                  selected: _selected == d.date,
                  title: Text(d.overview.isNotEmpty ? d.overview : d.date,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      l.diaryListMeta(d.themes.length, d.blindspots.length),
                      maxLines: 1),
                  trailing: RowMetaTime.day(d.date),
                  onTap: () => setState(() {
                    _genDate = d.date;
                    _selected = d.date;
                  }),
                );
              },
            ),
          );
    // Month-data chrome for the list area (error / first load); the open
    // day pane bypasses it entirely.
    Widget monthArea() {
      if (diaries.hasError) return ErrorPane(message: l.chatHistoryError);
      if (diaries.isLoading && list.isEmpty) {
        return const SkeletonListView(itemCount: 6);
      }
      return entriesPane;
    }

    // Left column always: the list + entries (the wide detail pane
    // lives outside this builder; phone swaps a day pane in below).
    final body = Column(
      children: [
        head,
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        Expanded(
          // Phone swap area: the selected day's content, or the list.
          child: split
              ? monthArea()
              : NotificationListener<ScrollNotification>(
                  onNotification: _onDayPaneScroll,
                  child: _selected != null
                      // Day flings (left = next day, right = previous)
                      // own the horizontal space only once the reader
                      // scrolled and the calendar folded to its week
                      // (reading mode); with the month calendar still
                      // expanded, swipe-right keeps the drawer (see
                      // drawerFling below) — no double binding.
                      ? HorizontalFlingDetector(
                          onFlingLeft: _collapsed ? () => _shiftDay(1) : null,
                          onFlingRight: _collapsed ? () => _shiftDay(-1) : null,
                          child: _DayPane(agentId: agentId, date: _selected!,
                              enableRefresh: !_collapsed,
                              onClose: () => setState(() {
                                    _selected = null;
                                    _collapsed = false;
                                  })),
                        )
                      : monthArea(),
                ),
        ),
      ],
    );

    // MasterDetailScaffold renders BOTH layouts: wide = list|detail with
    // the selected day docked right; phone = the list alone (the day
    // swap already lives inside `body` above). The folded day view
    // (week calendar, reading mode) owns horizontal flings for date
    // switching; every other state keeps the drawer gesture.
    return MasterDetailScaffold(
      appBar: AppBar(title: Text(l.kbDiary)),
      drawerFling: _selected == null || !_collapsed,
      placeholderIcon: LucideIcons.calendarDays,
      placeholderText: l.kbSelectToView,
      listPane: body,
      detail: _selected == null
          ? null
          : _DayPane(
              agentId: agentId,
              date: _selected!,
              onClose: () => setState(() {
                    _selected = null;
                    _collapsed = false;
                  })),
    );
  }
}

class _MonthNav extends StatelessWidget {
  const _MonthNav({required this.month, required this.onShift});

  final DateTime month;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        IconButton(
          onPressed: () => onShift(-1),
          tooltip: l.diaryPrevMonth,
          icon: const Icon(LucideIcons.chevronLeft, size: 18),
        ),
        Expanded(
          child: Center(
              child: Text(formatMonthTitle(month, locale: l.localeName),
                  style: theme.textTheme.titleSmall)),
        ),
        IconButton(
          onPressed: () => onShift(1),
          tooltip: l.diaryNextMonth,
          icon: const Icon(LucideIcons.chevronRight, size: 18),
        ),
      ],
    );
  }
}

/// One month as a 7-column heatmap: shade = themes + blindspots carried
/// that day (diary-view.tsx thresholds). Red frame = generated but empty
/// (no summaries); faded = never generated; 30% = future (no diary yet).
class _HeatCalendar extends StatelessWidget {
  const _HeatCalendar({
    required this.month,
    required this.byDate,
    required this.selected,
    required this.onTapDay,
    this.collapsed = false,
  });

  final DateTime month;
  final Map<String, DailyDiary> byDate;
  final String selected;
  final ValueChanged<String> onTapDay;

  /// Folded mode: only the selected day's week renders — the month grid
  /// gives way to the reading surface below.
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final today = _todayCST();
    final dows = weekdayShortLabels(l.localeName); // Monday-first
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: Mon=1..Sun=7 → leading blanks for a Monday-first grid.
    final leading = DateTime(month.year, month.month, 1).weekday - 1;

    Widget cell(int day) {
      final date = _ymd(DateTime(month.year, month.month, day));
      final dia = byDate[date];
      final future = date.compareTo(today) > 0;
      final scheme = theme.colorScheme;
      Color? bg;
      Border? border;
      Color fg = scheme.onSurface;
      if (dia != null && !dia.isEmptyDay) {
        final w = dia.themes.length + dia.blindspots.length;
        bg = scheme.primary
            .withValues(alpha: w <= 2 ? 0.25 : w <= 4 ? 0.45 : w <= 7 ? 0.65 : 0.85);
      } else if (dia != null) {
        border = Border.all(color: scheme.error);
        fg = scheme.error;
      }
      if (date == selected) {
        border = Border.all(color: scheme.primary, width: 2);
      }
      return SizedBox(
        height: 38, // compact cells — the swap area below gets the savings
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: InkWell(
            onTap: future ? null : () => onTapDay(date),
            borderRadius: BorderRadius.all(AppRadius.nested),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                border: border,
                borderRadius: BorderRadius.all(AppRadius.nested),
              ),
              child: Opacity(
                opacity: future ? 0.3 : dia == null ? 0.55 : 1,
                child: Text('$day', style: theme.textTheme.labelSmall?.copyWith(color: fg)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in dows)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                        child: Text(d,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.outline))),
                  ),
                ),
            ],
          ),
          // The fold swaps the whole month grid for the selected day's
          // single week row (AnimatedSize smooths the height change).
          if (collapsed)
            _foldedWeek(context, cell)
          else
            for (var w = 0; w * 7 < leading + daysInMonth; w++)
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: w * 7 + i < leading || w * 7 + i >= leading + daysInMonth
                          ? const SizedBox(height: 38)
                          : cell(w * 7 + i - leading + 1),
                    ),
                ],
              ),
        ],
      ),
    );
  }

  /// The folded row: the selected day's Monday-first week. Days outside
  /// [month] render as empty slots (the shared cell() maps its day
  /// number onto this month only); the selected day itself is always in
  /// month, so the fold never hides it.
  Widget _foldedWeek(BuildContext context, Widget Function(int day) cell) {
    final sel = DateTime.tryParse('${selected}T00:00:00');
    if (sel == null) return const SizedBox.shrink();
    final weekStart = DateTime(sel.year, sel.month, sel.day)
        .subtract(Duration(days: (sel.weekday + 6) % 7));
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: DateTime(weekStart.year, weekStart.month, weekStart.day + i).month != month.month
                ? const SizedBox(height: 38)
                : cell(DateTime(weekStart.year, weekStart.month, weekStart.day + i).day),
          ),
      ],
    );
  }
}

/// Date chip + generate button (the web's input[type=date] + 生成 row).
class _GenerateRow extends StatelessWidget {
  const _GenerateRow({
    required this.date,
    required this.running,
    required this.disabled,
    required this.onPick,
    required this.onGenerate,
  });

  final String date;
  final bool running;
  final bool disabled;
  final VoidCallback onPick;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onPick,
            borderRadius: AppRadius.controlBorder,
            child: Container(
              // 44px touch row — matches the generate button beside it.
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: AppRadius.controlBorder,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(date, style: theme.textTheme.bodySmall),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: disabled ? null : onGenerate,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
          ),
          icon: running
              ? const SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.sparkles, size: 14),
          label: Text(running ? l.diaryGenerating : l.diaryGenerate),
        ),
      ],
    );
  }
}

/// The selected day's content under the pinned calendar: header (date +
/// back-to-list + regenerate) and the diary body, inline like the web's
/// right pane.
class _DayPane extends ConsumerWidget {
  const _DayPane(
      {required this.agentId, required this.date, required this.onClose, this.enableRefresh = true});

  final String agentId;
  final String date;
  final VoidCallback onClose;

  /// Pull-to-refresh mounts only in the expanded state — folded (week
  /// view), the top pull belongs to the damped calendar expansion.
  final bool enableRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entry = ref.watch(diaryEntryProvider((agentId, date)));
    final localGen = ref.watch(diaryGeneratingProvider.select((s) => s.contains(date)));

    final d = entry.value;
    final generating = localGen || (d?.generating ?? false);
    final regenDisabled = generating || (d != null && !d.generating && d.isEmptyDay);
    final label = DateTime.tryParse('${date}T00:00:00');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l.kbViewList,
                onPressed: onClose,
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
              Expanded(
                child: Text(
                  label == null ? date : formatFullDate(label, locale: l.localeName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: regenDisabled
                    ? null
                    : () => ref.read(diaryGeneratingProvider.notifier).start(agentId, date),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
                icon: generating
                    ? const SizedBox(
                        width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.sparkles, size: 13),
                label: Text(generating ? l.diaryGenerating : l.chatRegenerate,
                    style: theme.textTheme.labelMedium),
              ),
            ],
          ),
        ),
        Expanded(
          child: entry.when(
            loading: () => const SkeletonProse(),
            error: (e, _) => ErrorPane(message: l.chatHistoryError),
            data: (d) => _DayPaneBody(
              agentId: agentId,
              enableRefresh: enableRefresh,
              onRefresh: () =>
                  ref.refresh(diaryEntryProvider((agentId, date)).future),
              generating: generating,
              d: d,
            ),
          ),
        ),
      ],
    );
  }
}

class _DayPaneBody extends StatelessWidget {
  const _DayPaneBody(
      {required this.agentId,
      required this.enableRefresh,
      required this.onRefresh,
      required this.generating,
      this.d});

  final String agentId;
  final bool enableRefresh;
  final Future<void> Function() onRefresh;
  final bool generating;
  final DailyDiary? d;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Local promotion — `this.d` can't flow-narrow after the null branch.
    final day = d;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: [
        if (generating)
          _GeneratingHint()
        else if (day == null)
          EmptyState(icon: LucideIcons.calendarDays, message: l.diaryNoDiary)
        else if (day.isEmptyDay)
          EmptyState(
              icon: LucideIcons.calendarOff,
              message: day.overview.isEmpty ? l.diaryNoThemes : day.overview)
        else
          DiaryContent(diary: day, agentId: agentId),
      ],
    );
    // The indicator stays mounted in both modes: flipping this slot
    // between RefreshIndicator(ListView) and bare ListView swaps the
    // runtimeType and rebuilds the whole subtree — scroll position and an
    // in-progress drag lost mid-fold. The pull is disarmed via the
    // notification predicate instead.
    return RefreshIndicator(
      onRefresh: onRefresh,
      notificationPredicate:
          enableRefresh ? defaultScrollNotificationPredicate : (_) => false,
      child: list,
    );
  }
}

class _GeneratingHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.sparkles, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l.diaryGenerating,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

/// The diary body — shared shape with the web DiaryContent: overview
/// card, theme cards with #seq segment chips, blindspots, archives.
class DiaryContent extends StatelessWidget {
  const DiaryContent({super.key, required this.diary, required this.agentId});

  final DailyDiary diary;
  final String agentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (diary.overview.isNotEmpty) ...[
          Text(l.diaryOverview,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(diary.overview, style: theme.textTheme.bodyMedium),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(LucideIcons.fileText, size: 15, color: scheme.primary),
            const SizedBox(width: 6),
            Text(l.diaryThemes, style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 6),
        for (final t in diary.themes) ...[
          _ThemeCard(item: t),
          const SizedBox(height: 8),
        ],
        if (diary.blindspots.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(l.diaryBlindspots, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          for (final b in diary.blindspots) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.05),
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.point, style: theme.textTheme.bodyMedium),
                  if (b.reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(b.reason,
                        style:
                            theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (diary.shelved.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(LucideIcons.archiveRestore, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(l.diaryShelved, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          for (final s in diary.shelved) ...[
            _ShelvedCard(item: s, agentId: agentId),
            const SizedBox(height: 8),
          ],
        ],
        if (diary.archives.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l.diaryArchives, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final a in diary.archives)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $a',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
            ),
        ],
      ],
    );
  }
}

/// A #seq-N deep-link chip into the chat transcript — the shared visual
/// for theme segment chips and shelved-ledger cards; the route shape
/// comes from chatSessionRoute.
class _SeqChip extends StatelessWidget {
  const _SeqChip({required this.session, required this.seq, this.end});

  final String session;
  final int seq;

  /// Segment ranges render as `#seq-a~b`; single points omit it.
  final int? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rangeEnd = end;
    return InkWell(
      onTap: () => context.push(chatSessionRoute(session, seq: seq)),
      borderRadius: BorderRadius.all(AppRadius.nested),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.all(AppRadius.nested),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        child: Text(
          rangeEnd != null && rangeEnd != seq ? '#seq-$seq~$rangeEnd' : '#seq-$seq',
          style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
        ),
      ),
    );
  }
}

/// One shelved-ledger entry (web ShelvedCard): topic + the situation
/// when deferred + a #seq-N chip back into that conversation. Tapping
/// the card body is itself the confirm (ticket #16: viewing counts as
/// settlement, resolution="manual") then deep-links; long-press offers
/// "stop reminding". Rows without an id (legacy snapshots) keep the old
/// inert behaviour. Resolved entries render with the success tint as
/// the closed loop.
class _ShelvedCard extends ConsumerWidget {
  const _ShelvedCard({required this.item, required this.agentId});

  final DiaryShelved item;
  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;
    final success = paletteOf(context).success;
    final resolved = item.resolved;
    final open = !resolved;
    return InkWell(
      onTap: open
          ? () => openShelvedEntry(context, ref, agentId, item)
          : null,
      onLongPress: open && item.settleable
          ? () => stopRemindingShelved(context, ref, agentId, item)
          : null,
      borderRadius: AppRadius.cardBorder,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: resolved
              ? success.withValues(alpha: 0.05)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
              color: resolved
                  ? success.withValues(alpha: 0.3)
                  : scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (resolved) ...[
                        Icon(LucideIcons.check, size: 14, color: success),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                          child: Text(item.topic, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                  if (item.context.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.context,
                        style:
                            theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    resolved
                        ? l.diaryShelvedResolved
                        : l.diaryShelvedSince(item.since, item.daysOpen),
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            if (item.session.isNotEmpty) ...[
              const SizedBox(width: 8),
              _SeqChip(session: item.session, seq: item.seq),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.item});

  final DiaryTheme item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: theme.textTheme.titleSmall),
          if (item.summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.summary,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
          ],
          if (item.points.isNotEmpty)
            for (final p in item.points)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('· $p', style: theme.textTheme.bodyMedium),
              ),
          if (item.segments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // #seq chips deep-link the transcript to the segment's
                // first message (chatSessionRoute builds the shape).
                for (final seg in item.segments.take(6))
                  _SeqChip(session: seg.session, seq: seg.start, end: seg.end),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
