import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_routes.dart';
import '../../chat/models.dart';
import '../../kb/diary_models.dart';
import '../../kb/diary_repo.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/settings_repo.dart';
import '../../theme/tokens.dart';
import '../../util/dates.dart';
import 'chat_image.dart';

/// Card-review stats for the fresh-chat board (one provider; the review
/// page keeps its own).
final _cardStatsProvider =
    FutureProvider.autoDispose.family<KbCardStats, String>((ref, agentId) {
  return ref.watch(kbRepoProvider).cardStats(agentId);
});

/// The due queue's first rows for the cards pane (most-overdue first,
/// GET /kb/cards?queue=1) — the pane lists actual cards instead of a
/// bare count.
final _dueCardsProvider =
    FutureProvider.autoDispose.family<List<KbCard>, String>((ref, agentId) {
  return ref.watch(kbRepoProvider).cardQueue(agentId, limit: 4);
});

/// Enabled cron jobs for the fresh-chat board (GET /api/agents/{id}/cron
/// → {"jobs":[...]}); rows stay raw maps — the settings page owns the
/// typed surface.
final _cronJobsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, agentId) async {
  final jobs = await ref.watch(settingsRepoProvider).cronJobs(agentId);
  return jobs.where((j) => j['enabled'] == true).toList();
});

/// Fresh-chat board (web ChatDashboard, chat-dashboard.tsx): the empty
/// state IS the dashboard — today's due cards, open KB todos, recent
/// chats and enabled cron jobs over data the backend already has. Each
/// pane is an entry into an existing page; shown only while the
/// transcript is empty and the composer untouched.
class ChatDashboard extends ConsumerWidget {
  const ChatDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agent = ref.watch(agentsProvider).selected;
    if (agent == null) return const SizedBox.shrink();
    final shelved = ref.watch(diaryShelvedProvider(agent.id));
    // Every pane's fetch goes out up front (web parity — all dashboard
    // fetches fire together); the hold below gates rendering only.
    ref.watch(_cardStatsProvider(agent.id));
    ref.watch(_dueCardsProvider(agent.id));
    ref.watch(kbTodosProvider(agent.id));
    ref.watch(_cronJobsProvider(agent.id));

    final hero = Center(
      child: Column(
        children: [
          const AgentAvatar(size: 56),
          const SizedBox(height: 12),
          Text(agent.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.dashHeroHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );

    // Hold the panes until the shelved opt-in state lands (web
    // chat-dashboard.tsx "hold the first paint"): an enabled ledger
    // mounting a new first pane above already-rendered ones reads as a
    // layout glitch; failure answers enabled:false (fail-closed).
    if (!shelved.hasValue) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        children: [_DashIn(index: 0, child: hero)],
      );
    }

    // Shelved first — most time-sensitive (web grid order); the rest keep
    // their existing sequence. One full-width pane per row (user
    // preference) — same rhythm as the web's stacked mobile dashboard.
    final panes = <Widget>[
      if (shelved.value!.enabled) _ShelvedPane(view: shelved.value!),
      _CardsPane(agentId: agent.id),
      _TodosPane(agentId: agent.id),
      _RecentPane(agentId: agent.id),
      _CronPane(agentId: agent.id),
    ];

    return ListView(
      // Horizontal 12 matches the composer card's margin and the transcript
      // list padding — the panes and the input box share one edge line.
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      children: [
        // Hero: who you're talking to (web fresh-chat header).
        _DashIn(index: 0, child: hero),
        const SizedBox(height: 20),
        for (var i = 0; i < panes.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _DashIn(index: i + 1, child: panes[i]),
        ],
      ],
    );
  }
}

class _PaneCard extends StatelessWidget {
  const _PaneCard({required this.icon, required this.title, this.badge, required this.child});

  final IconData icon;
  final String title;
  final String? badge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: surfaceCardDecoration(theme.colorScheme),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge!,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A pane's trailing "more" link — default (non-compact) density so the
/// 12px label keeps a full ≥44px tap row; primary color, one shared look
/// for the cards/todos/recent panes.
class _PaneLink extends StatelessWidget {
  const _PaneLink({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontSize: AppType.caption)),
    );
  }
}

Widget _paneEmpty(BuildContext context, IconData icon, String text) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.outline),
        const SizedBox(height: 8),
        Text(text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    ),
  );
}

/// DESIGN.md §6 dash-in: panes rise in staggered, "like cards dealt onto
/// water" — 320ms flow easing, 10px rise, 60ms step per index. Plays once
/// per mount, never on rebuilds (history/data refresh never choreographs);
/// reduced motion keeps the 120ms fade and drops the rise. Transform and
/// opacity only — no layout animation.
class _DashIn extends StatefulWidget {
  const _DashIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_DashIn> createState() => _DashInState();
}

class _DashInState extends State<_DashIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, value: 0);

  @override
  void initState() {
    super.initState();
    Future.delayed(AppMotion.staggerStep * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    _c.duration =
        reduce ? AppMotion.reducedFade : AppMotion.stagger;
    if (reduce) return FadeTransition(opacity: _c, child: widget.child);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 10 * (1 - _c.value)),
        child: Opacity(opacity: _c.value, child: child),
      ),
      child: widget.child,
    );
  }
}

/// DESIGN.md §4 loading: a skeleton matching the pane's row rhythm —
/// staggered-width bars, nested 4px radius, no generic spinner.
class _PaneSkeleton extends StatelessWidget {
  const _PaneSkeleton({this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final bar = Theme.of(context).colorScheme.secondaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: switch (i % 3) { 0 => 1.0, 1 => 0.8, _ => 0.55 },
              child: Container(
                height: 10,
                decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.all(AppRadius.nested)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shelved-topics pane (web dashboard shelved pane, opt-in): open rows
/// deep-link back into the deferred conversation's #seq anchor (quick
/// re-entry); resolved rows render as the closed loop, no link. Rows
/// sort oldest-first like the web — longest-shelved on top.
class _ShelvedPane extends StatelessWidget {
  const _ShelvedPane({required this.view});

  final DiaryShelvedView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final open = view.items.where((s) => !s.resolved).length;
    return _PaneCard(
      icon: LucideIcons.archiveRestore,
      title: l.diaryShelved,
      badge: open == 0 ? null : '$open',
      child: view.items.isEmpty
          ? _paneEmpty(context, LucideIcons.archiveRestore, l.dashShelvedNone)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in [...view.items]..sort((a, b) => a.since.compareTo(b.since)))
                  _ShelvedRow(item: s),
                _PaneLink(
                    label: l.dashShelvedView, onTap: () => context.push('/kb/diary')),
              ],
            ),
    );
  }
}

class _ShelvedRow extends StatelessWidget {
  const _ShelvedRow({required this.item});

  final DiaryShelved item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (item.resolved) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(LucideIcons.check, size: 13, color: paletteOf(context).success),
            const SizedBox(width: 6),
            Expanded(
              child: Text(item.topic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
            ),
            Text(l.diaryShelvedResolved,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
          ],
        ),
      );
    }
    return InkWell(
      onTap: item.session.isEmpty
          ? null
          : () => context.push(chatSessionRoute(item.session, seq: item.seq)),
      borderRadius: AppRadius.controlBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(item.topic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(l.dashShelvedDaysAgo(item.daysOpen),
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardsPane extends ConsumerWidget {
  const _CardsPane({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = ref.watch(_cardStatsProvider(agentId));
    final due = ref.watch(_dueCardsProvider(agentId));
    final dueCount = stats.value?.dueToday ?? 0;
    return _PaneCard(
      icon: LucideIcons.layers,
      title: l.dashCardsTitle,
      badge: dueCount == 0 ? null : '$dueCount',
      child: due.when(
        loading: () => const _PaneSkeleton(lines: 3),
        error: (_, _) => _paneEmpty(context, LucideIcons.layers, l.dashCardsNone),
        data: (cards) {
          final s = stats.value;
          // Due rows like the recent-chats pane: question preview, one
          // line, tap opens the review deck; streak + browse trail.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cards.isEmpty)
                Text(l.dashCardsNone, style: theme.textTheme.bodySmall)
              else
                for (final c in cards)
                  InkWell(
                    onTap: () => context.push('/kb/cards/review'),
                    borderRadius: AppRadius.controlBorder,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(c.question,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                    ),
                  ),
              if (s != null && s.streakDays > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.flame,
                          size: 13, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Text(l.dashCardsStreak(s.streakDays),
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              _PaneLink(
                  label: l.dashCardsBrowse,
                  onTap: () => context.push('/kb/cards/review')),
            ],
          );
        },
      ),
    );
  }
}

class _TodosPane extends ConsumerWidget {
  const _TodosPane({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final todos = ref.watch(kbTodosProvider(agentId));
    final open = todos.value
            ?.where((t) => t.status == 'pending' || t.status == 'in_progress')
            .toList() ??
        const <KbSource>[];
    return _PaneCard(
      icon: LucideIcons.squareCheckBig,
      title: l.dashTodoTitle,
      badge: open.isEmpty ? null : '${open.length}',
      child: todos.when(
        loading: () => const _PaneSkeleton(lines: 5),
        error: (_, _) => _paneEmpty(context, LucideIcons.squareCheckBig, l.dashTodoNone),
        data: (list) {
          if (open.isEmpty) return _paneEmpty(context, LucideIcons.squareCheckBig, l.dashTodoNone);
          final now = DateTime.now();
          final sorted = [...open]..sort((a, b) {
              final da = a.endAt ?? DateTime(2999);
              final db = b.endAt ?? DateTime(2999);
              return da.compareTo(db);
            });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in sorted.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _todoDot(context, t.status),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(t.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                      if (t.endAt != null)
                        Text(
                          t.endAt!.isBefore(now) ? l.dashTodoOverdue : formatShortDate(t.endAt!),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: t.endAt!.isBefore(now)
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.outline),
                        ),
                    ],
                  ),
                ),
              _PaneLink(
                  label: l.dashTodoView, onTap: () => context.push('/kb/todos')),
            ],
          );
        },
      ),
    );
  }

  Widget _todoDot(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: status == 'in_progress' ? 10 : 8,
      height: status == 'in_progress' ? 10 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: status == 'in_progress' ? scheme.tertiary : scheme.outline,
          width: status == 'in_progress' ? 2 : 1,
        ),
      ),
    );
  }
}

class _RecentPane extends ConsumerWidget {
  const _RecentPane({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final sessions = ref.watch(sessionsProvider);
    final theme = Theme.of(context);
    final list = [...(sessions.value ?? <ChatSessionInfo>[])]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _PaneCard(
      icon: LucideIcons.messageSquare,
      title: l.dashRecentTitle,
      child: sessions.when(
        loading: () => const _PaneSkeleton(lines: 5),
        error: (_, _) => _paneEmpty(context, LucideIcons.messageSquare, l.dashRecentNone),
        data: (all) {
          if (list.isEmpty) return _paneEmpty(context, LucideIcons.messageSquare, l.dashRecentNone);
          return Column(
            // start — the trailing "more" link must hug the left like the
            // cards / todos panes, not center.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in list.take(5))
                InkWell(
                  onTap: () {
                    ref.read(chatStoreProvider.notifier).openSession(agentId, s.id);
                    context.go('/c/${Uri.encodeComponent(s.id)}');
                  },
                  borderRadius: AppRadius.controlBorder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.title.isEmpty ? s.preview : s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (s.updatedAt > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              formatSessionTime(s.updatedAt,
                                  locale: Localizations.localeOf(context).toString()),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              // No extra gap before the link — matches the todos pane
              // (row padding + link, nothing in between).
              _PaneLink(
                  label: l.dashRecentAll, onTap: () => context.push('/chats')),
            ],
          );
        },
      ),
    );
  }
}

class _CronPane extends ConsumerWidget {
  const _CronPane({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final jobs = ref.watch(_cronJobsProvider(agentId));
    return _PaneCard(
      icon: LucideIcons.timer,
      title: l.dashCronTitle,
      child: jobs.when(
        loading: () => const _PaneSkeleton(lines: 4),
        error: (_, _) => _paneEmpty(context, LucideIcons.timer, l.dashCronNone),
        data: (list) {
          if (list.isEmpty) return _paneEmpty(context, LucideIcons.timer, l.dashCronNone);
          return Column(
            children: [
              for (final j in list.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${j['name'] ?? j['message'] ?? j['id'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '${j['schedule'] ?? j['cron'] ?? ''}',
                          maxLines: 1,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
