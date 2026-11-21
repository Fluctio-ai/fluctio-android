import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import 'kb_editor_page.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/adaptive_tab_bar.dart';
import '../../ui/app_fab.dart';
import '../../ui/load_states.dart';
import '../../ui/dialogs.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/row_meta.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/master_detail.dart';
import '../../theme/tokens.dart';
import '../../ui/labeled_section.dart';
import '../../util/dates.dart';
import '../../chat/markdown.dart';
import 'card_source_link.dart';

/// Cards dashboard: streak + review CTA on the title row, filter tabs,
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

  /// Wide-layout selection: the card showing in the detail pane. Phones
  /// never set this — rows push the card view there.
  KbCard? _selected;

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
      // An archived card leaves the due/active lists — close its pane.
      if (_selected?.id == c.id) _selected = null;
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
      if (_selected?.id == c.id) _selected = null;
      _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _addCard() async {
    final l = AppLocalizations.of(context)!;
    // The notes-style full-screen editor — the answer renders as
    // markdown in the card view, so it gets the markdown editing
    // surface like note/flash bodies; question rides the title row.
    // canSave: the question is the required field, the answer may be
    // empty (the old form allowed that too).
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: l.cardAdd,
        titleLabel: l.cardQuestion,
        hint: l.cardAnswer,
        canSave: (text, title) => title.trim().isNotEmpty,
        onSave: (text, title, date, endDate, {status}) async {
          await ref.read(kbRepoProvider).saveCard(
              ref.read(agentsProvider).selectedId!, title.trim(), text.trim());
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
      child: MasterDetailScaffold(
        appBar: AppBar(
          title: Text(l.kbCards),
          // The stats numbers became filter tabs (user feedback): due /
          // active / mastered / archived with inline counts, evenly
          // spread like the wiki tabs. Streak isn't a filter — with the
          // review CTA it rides the title row (user request), small,
          // right of the title; the list starts right under the tabs.
          actions: [
            if (stats != null && stats.streakDays > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.flame, size: 13, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text(l.dashCardsStreak(stats.streakDays),
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.tertiary)),
                  ],
                ),
              ),
            if (_queueLength > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpace.lg),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                    shape:
                        RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
                  ),
                  onPressed: () async {
                    await context.push('/kb/cards/review');
                    _load();
                  },
                  icon: const Icon(LucideIcons.brain, size: 18),
                  label: Text('${l.cardStart} ($_queueLength)'),
                ),
              ),
          ],
          bottom: AdaptiveTabBar(
            onTap: (i) => _switchFilter(_filters[i]),
            tabs: [
              (label: l.cardDue, count: stats?.dueToday),
              (label: l.cardActive, count: stats?.active),
              (label: l.cardMastered, count: stats?.mastered),
              (label: l.cardArchived, count: stats?.archived),
            ],
          ),
        ),
        floatingActionButton: AppFab(
          onPressed: _addCard,
          icon: LucideIcons.plus,
        ),
        placeholderIcon: LucideIcons.layers,
        placeholderText: l.kbSelectToView,
        detail: _selected == null ? null : CardViewBody(card: _selected!),
        listPane: _error != null
            ? ErrorPane(message: _error!)
            : stats == null
                ? const SkeletonListView(itemCount: 5)
                : _cards.isEmpty
                    ? EmptyState(icon: LucideIcons.layers, message: l.kbEmpty)
                    // Card library filtered by the active tab
                    // (GET /kb/cards?filter=).
                    : ListView(
                        // Rows own their 12px gutters like the sibling KB
                        // lists; 88 bottom = FAB clearance (56 + 16 + some).
                        padding: const EdgeInsets.only(top: 8, bottom: 88),
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
                                selected: _selected?.id == c.id,
                                title: Text(c.question,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Row(
                                  children: [
                                    Expanded(
                                      child: Text(c.answer,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    // Origin in the descriptor line's right
                                    // slot (diary/wiki generation — manual
                                    // cards carry no badge).
                                    if (c.sourceType == 'diary' ||
                                        c.sourceType == 'wiki')
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          c.sourceType == 'diary'
                                              ? l.kbDiary
                                              : l.kbWiki,
                                          maxLines: 1,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: c.dueAt == null
                                    ? null
                                    : RowMetaTime(
                                        tsMs: c.dueAt!.millisecondsSinceEpoch),
                                onTap: () {
                                  // Wide: select into the detail pane;
                                  // phone: push the read-only card view.
                                  if (MasterDetailScaffold.isSplit(context)) {
                                    setState(() => _selected = c);
                                  } else {
                                    Navigator.of(context)
                                        .push(MaterialPageRoute<void>(
                                      builder: (_) => _CardViewPage(card: c),
                                    ));
                                  }
                                },
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
    );
  }
}

  /// Read-only card view: question / answer rendered as markdown plus the
  /// schedule metadata row. The pushed page wraps [CardViewBody] in a
/// Scaffold; the master-detail pane renders the body directly.
class _CardViewPage extends StatelessWidget {
  const _CardViewPage({required this.card});

  final KbCard card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(card.question, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: CardViewBody(card: card),
    );
  }
}

/// The card view body (question / answer / excerpt / source / schedule
/// meta) without page chrome — shared by the pushed page and the
/// master-detail pane.
class CardViewBody extends StatelessWidget {
  const CardViewBody({super.key, required this.card});

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
    Widget section(String label, String body) => LabeledSection(
          label: label,
          child: transcriptMarkdown(context, body),
        );
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section(l.cardQuestion, card.question),
          const SizedBox(height: 20),
          section(l.cardAnswer, card.answer),
          // Origin excerpt — the passage this card was distilled from
          // (manual cards have none).
          if (card.sourceExcerpt.isNotEmpty) ...[
            const SizedBox(height: 20),
            section(l.cardExcerpt, card.sourceExcerpt),
          ],
          // Origin jump — the diary day / wiki page this card came from.
          if (CardSourceLink.navigable(card.sourceType, card.sourceRef)) ...[
            const SizedBox(height: 20),
            CardSourceLink(sourceType: card.sourceType, sourceRef: card.sourceRef),
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
      );
  }
}
