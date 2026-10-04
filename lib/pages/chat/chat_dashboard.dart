import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../chat/models.dart';
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        // Hero: who you're talking to (web fresh-chat header).
        _DashIn(
          index: 0,
          child: Center(
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
          ),
        ),
        const SizedBox(height: 20),
        // One full-width pane per row (user preference) — same rhythm as
        // the web's stacked mobile dashboard.
        _DashIn(index: 1, child: _CardsPane(agentId: agent.id)),
        const SizedBox(height: 12),
        _DashIn(index: 2, child: _TodosPane(agentId: agent.id)),
        const SizedBox(height: 12),
        _DashIn(index: 3, child: _RecentPane(agentId: agent.id)),
        const SizedBox(height: 12),
        _DashIn(index: 4, child: _CronPane(agentId: agent.id)),
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
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
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
        reduce ? const Duration(milliseconds: 120) : const Duration(milliseconds: 320);
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

class _CardsPane extends ConsumerWidget {
  const _CardsPane({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final stats = ref.watch(_cardStatsProvider(agentId));
    return _PaneCard(
      icon: LucideIcons.layers,
      title: l.dashCardsTitle,
      badge: stats.value == null || stats.value!.dueToday == 0 ? null : '${stats.value!.dueToday}',
      child: stats.when(
        loading: () => const _PaneSkeleton(lines: 3),
        error: (_, _) => _paneEmpty(context, LucideIcons.layers, l.dashCardsNone),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dueToday > 0 ? l.dashCardsDue(s.dueToday) : l.dashCardsNone,
                style: Theme.of(context).textTheme.bodySmall),
            if (s.streakDays > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.flame, size: 13, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text(l.dashCardsStreak(s.streakDays),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => context.push('/kb/cards/review'),
              child: Text(l.dashCardsBrowse, style: const TextStyle(fontSize: AppType.caption)),
            ),
          ],
        ),
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
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => context.push('/kb/todos'),
                child: Text(l.dashTodoView, style: const TextStyle(fontSize: AppType.caption)),
              ),
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
