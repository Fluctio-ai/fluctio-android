import '../app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/diary_models.dart';
import '../../kb/diary_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/load_states.dart';
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
  /// threshold — per-frame deltas never fire on a slow drag — and coming
  /// to rest at the top unfolds. The month list (nothing selected) never
  /// folds — the calendar stays put there.
  double _readScroll = 0;

  bool _onDayPaneScroll(ScrollNotification n) {
    if (n.depth != 0 || _selected == null) return false;
    if (n is ScrollStartNotification) {
      _readScroll = 0;
    } else if (n is ScrollUpdateNotification) {
      _readScroll += n.scrollDelta ?? 0;
      if (_readScroll > 12 && !_collapsed) {
        setState(() => _collapsed = true);
      }
    } else if (n is ScrollEndNotification) {
      if (n.metrics.pixels <= 8 && _collapsed) {
        setState(() => _collapsed = false);
      }
      _readScroll = 0;
    }
    return false;
  }

  void _shiftMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta, 1);
        _selected = null;
        _collapsed = false;
      });

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

    return Scaffold(
      // Drawer on every list surface — same gesture zone as chat.
      drawer: const AppDrawer(),
      drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
      appBar: AppBar(title: Text(l.kbDiary)),
      body: diaries.when(
        loading: () => const SkeletonListView(itemCount: 6),
        error: (e, _) => ErrorPane(message: l.chatHistoryError),
        data: (list) {
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
          final folded = _collapsed && _selected != null;
          return Column(
            children: [
              // Pinned head: month nav + heatmap + generate row. With a
              // day open, an upward scroll folds the heatmap down to
              // that day's week (AnimatedSize) and drops the generate
              // row — reading space wins; returning to the top unfolds.
              Padding(
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
              ),
              Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
              // Swap area: the selected day's content, or the month list.
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onDayPaneScroll,
                  child: _selected != null
                      ? _DayPane(agentId: agentId, date: _selected!,
                          onClose: () => setState(() {
                                _selected = null;
                                _collapsed = false;
                              }))
                      : entries.isEmpty
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
                                  title: Text(d.overview.isNotEmpty ? d.overview : d.date,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      l.diaryListMeta(
                                          d.date, d.themes.length, d.blindspots.length),
                                      maxLines: 1),
                                  onTap: () => setState(() {
                                    _genDate = d.date;
                                    _selected = d.date;
                                  }),
                                );
                              },
                            ),
                          ),
                ),
              ),
            ],
          );
        },
      ),
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
  const _DayPane({required this.agentId, required this.date, required this.onClose});

  final String agentId;
  final String date;
  final VoidCallback onClose;

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
            data: (d) => RefreshIndicator(
              onRefresh: () => ref.refresh(diaryEntryProvider((agentId, date)).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                children: [
                  if (generating)
                    _GeneratingHint()
                  else if (d == null)
                    EmptyState(icon: LucideIcons.calendarDays, message: l.diaryNoDiary)
                  else if (d.isEmptyDay)
                    EmptyState(
                        icon: LucideIcons.calendarOff,
                        message: d.overview.isEmpty ? l.diaryNoThemes : d.overview)
                  else
                    DiaryContent(diary: d),
                ],
              ),
            ),
          ),
        ),
      ],
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
  const DiaryContent({super.key, required this.diary});

  final DailyDiary diary;

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
                // first message (/c/<sid>?seq=N).
                for (final seg in item.segments.take(6))
                  InkWell(
                    onTap: () => context.push(
                        '/c/${Uri.encodeComponent(seg.session)}?seq=${seg.start}'),
                    borderRadius: BorderRadius.all(AppRadius.nested),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.all(AppRadius.nested),
                        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        seg.start == seg.end
                            ? '#seq-${seg.start}'
                            : '#seq-${seg.start}~${seg.end}',
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
