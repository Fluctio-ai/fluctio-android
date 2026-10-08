import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../app_drawer.dart';
import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/adaptive_tab_bar.dart';
import '../../ui/form_editor_page.dart';
import '../../ui/load_states.dart';
import '../../ui/dialogs.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/chevron_list_tile.dart';
import '../../theme/tokens.dart';
import '../../util/dates.dart';
import '../../chat/markdown.dart';

/// Cards dashboard: stats header, start-review CTA over the due queue,
/// manual card creation.
class KbCardsPage extends ConsumerStatefulWidget {
  const KbCardsPage({super.key});

  @override
  ConsumerState<KbCardsPage> createState() => _KbCardsPageState();
}

class _KbCardsPageState extends ConsumerState<KbCardsPage> {
  /// Filter-tab order (contract §7: due|active|mastered|archived) — one
  /// list drives the default filter, the tab index and the switch.
  static const _filters = ['due', 'active', 'mastered', 'archived'];

  KbCardStats? _stats;
  int _queueLength = 0;
  List<KbCard> _cards = const [];
  String? _error;

  /// Library filter of the active tab; tab switching refetches only the
  /// list; stats stay.
  String _filter = _filters[1];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    try {
      final repo = ref.read(kbRepoProvider);
      final (stats, queue, cards) = await (
        repo.cardStats(agentId),
        repo.cardQueue(agentId),
        repo.cardList(agentId, filter: _filter),
      ).wait;
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _queueLength = queue.length;
        _cards = cards;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _switchFilter(String filter) async {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    try {
      final cards = await ref.read(kbRepoProvider).cardList(agentId, filter: filter);
      if (mounted) setState(() => _cards = cards);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  // Swipe + long-press sheet share these — one code path per action.
  Future<void> _archiveCard(KbCard c) async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    try {
      await ref.read(kbRepoProvider).archiveCard(agentId, c.id, true);
      _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _deleteCard(KbCard c) async {
    if (!await confirmDelete(context)) return;
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    try {
      await ref.read(kbRepoProvider).deleteCard(agentId, c.id);
      _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _addCard() async {
    final l = AppLocalizations.of(context)!;
    // Full-page editor (question + answer) — same surface as the other
    // KB edits; the old AlertDialog squeezed the answer behind it.
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FormEditorPage<bool>(
        heading: l.cardAdd,
        fields: [
          EditorField(label: l.cardQuestion, autofocus: true),
          EditorField(label: l.cardAnswer, maxLines: 8),
        ],
        canSave: (v) => v[0].trim().isNotEmpty,
        onSave: (v) async {
          await ref
              .read(kbRepoProvider)
              .saveCard(ref.read(agentsProvider).selectedId!, v[0].trim(), v[1].trim());
          return true;
        },
      ),
    ));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = _stats;
    // Watch-only: rebuild on agent switch — the row actions re-read the
    // id at run time (moved out of the build when the inline swipe
    // closures became shared methods).
    ref.watch(agentsProvider.select((a) => a.selectedId));
    return DefaultTabController(
      // initialIndex matches the default filter (active).
      initialIndex: _filters.indexOf(_filter),
      length: 4,
      child: Scaffold(
        // Drawer on every list surface — same gesture zone as chat.
        drawer: const AppDrawer(),
        drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
        appBar: AppBar(
          title: Text(l.kbCards),
          // The stats numbers became filter tabs (user feedback): due /
          // active / mastered / archived with inline counts, evenly
          // spread like the wiki tabs. Streak isn't a filter — it rides
          // as a caption under the review CTA.
          bottom: AdaptiveTabBar(
            onTap: (i) => _switchFilter(_filters[i]),
            tabs: [
              Tab(text: _tabLabel(l.cardDue, stats?.dueToday)),
              Tab(text: _tabLabel(l.cardActive, stats?.active)),
              Tab(text: _tabLabel(l.cardMastered, stats?.mastered)),
              Tab(text: _tabLabel(l.cardArchived, stats?.archived)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addCard,
          child: const Icon(LucideIcons.plus),
        ),
        body: _error != null
            ? ErrorPane(message: _error!)
            : stats == null
                ? const SkeletonListView(itemCount: 5)
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _queueLength > 0
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: AppRadius.controlBorder),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () async {
                                  await context.push('/kb/cards/review');
                                  _load();
                                },
                                icon: const Icon(LucideIcons.brain, size: 18),
                                label: Text('${l.cardStart} ($_queueLength)'),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    l.cardAllDone,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: theme.colorScheme.outline),
                                  ),
                                ),
                              ),
                      ),
                      if (stats.streakDays > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: Text(
                            '${l.cardStreak} · ${stats.streakDays}',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ),
                      Expanded(
                        child: _cards.isEmpty
                            ? EmptyState(icon: LucideIcons.layers, message: l.kbEmpty)
                            // Card library filtered by the active tab
                            // (GET /kb/cards?filter=).
                            : ListView(
                                // 88 bottom = the usual 16 plus FAB clearance (56 + 16).
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                                children: [
                                  for (final c in _cards)
                                    Slidable(
                                      key: ValueKey('card-${c.id}'),
                                      endActionPane: ActionPane(
                                        motion: const DrawerMotion(),
                                        extentRatio: 0.4,
                                        children: [
                                          SlidableAction(
                                            onPressed: (_) => _archiveCard(c),
                                            // Gold (warning) — distinct from the red
                                            // delete block.
                                            backgroundColor: paletteOf(context).warning,
                                            foregroundColor: paletteOf(context).warningForeground,
                                            icon: LucideIcons.archive,
                                            label: l.kbArchive,
                                          ),
                                          SlidableAction(
                                            onPressed: (_) => _deleteCard(c),
                                            backgroundColor: theme.colorScheme.error,
                                            foregroundColor: theme.colorScheme.onError,
                                            icon: LucideIcons.trash2,
                                            label: l.chatDelete,
                                          ),
                                        ],
                                      ),
                                      child: ChevronListTile(
                                        padding: EdgeInsets.zero,
                                        // Not dense — the 12px title read too small on
                                        // device (user feedback); matches the wiki /
                                        // article rows.
                                        title: Text(c.question,
                                            maxLines: 2, overflow: TextOverflow.ellipsis),
                                        subtitle: Text(c.answer,
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                        trailing: c.dueAt == null
                                            ? null
                                            : Text(formatShortDate(c.dueAt!.toLocal()),
                                                style: theme.textTheme.labelSmall
                                                    ?.copyWith(color: theme.colorScheme.outline)),
                                        onTap: () => Navigator.of(context)
                                            .push(MaterialPageRoute<void>(
                                          builder: (_) => _CardViewPage(card: c),
                                        )),
                                        onLongPress: () => showRowActionsMenu(context, [
                                          RowAction(
                                            icon: LucideIcons.archive,
                                            label: l.kbArchive,
                                            onRun: () => _archiveCard(c),
                                          ),
                                          RowAction(
                                            icon: LucideIcons.trash2,
                                            label: l.chatDelete,
                                            destructive: true,
                                            onRun: () => _deleteCard(c),
                                          ),
                                        ]),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  /// Tab label with the wiki-tab count convention (blank until stats land).
  String _tabLabel(String label, int? count) => count == null || count == 0 ? label : '$label $count';
}

/// Read-only card view: question / answer rendered as markdown plus the
/// schedule metadata row.
class _CardViewPage extends StatelessWidget {
  const _CardViewPage({required this.card});

  final KbCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final status = switch (card.status) {
      'mastered' => l.cardMastered,
      'archived' => l.cardArchived,
      _ => l.cardActive,
    };
    Widget section(String label, String body) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            transcriptMarkdown(context, body),
          ],
        );
    return Scaffold(
      appBar: AppBar(
          title: Text(card.question, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section(l.cardQuestion, card.question),
          const SizedBox(height: 20),
          section(l.cardAnswer, card.answer),
          // Origin excerpt — the passage this card was distilled from
          // (manual cards have none).
          if (card.sourceExcerpt.isNotEmpty) ...[
            const SizedBox(height: 20),
            section(l.cardSource, card.sourceExcerpt),
          ],
          const SizedBox(height: 24),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            '$status · ${l.cardReviewCount(card.reviewCount)} · ${l.cardLapseCount(card.lapseCount)}'
            '${card.dueAt == null ? '' : ' · ${formatShortDate(card.dueAt!.toLocal())}'}',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
