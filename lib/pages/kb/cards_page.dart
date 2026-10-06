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
import '../../ui/form_editor_page.dart';
import '../../ui/load_states.dart';
import '../../ui/dialogs.dart';
import '../../ui/chevron_list_tile.dart';
import '../../theme/tokens.dart';
import '../../util/dates.dart';
import '../chat/message_list.dart';

/// Cards dashboard: stats header, start-review CTA over the due queue,
/// manual card creation.
class KbCardsPage extends ConsumerStatefulWidget {
  const KbCardsPage({super.key});

  @override
  ConsumerState<KbCardsPage> createState() => _KbCardsPageState();
}

class _KbCardsPageState extends ConsumerState<KbCardsPage> {
  KbCardStats? _stats;
  int _queueLength = 0;
  List<KbCard> _cards = const [];
  String? _error;

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
        repo.cardList(agentId),
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
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    return Scaffold(
      // Drawer on every list surface — same gesture zone as chat.
      drawer: const AppDrawer(),
      drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
      appBar: AppBar(title: Text(l.kbCards)),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCard,
        child: const Icon(LucideIcons.plus),
      ),
      body: _error != null
          ? ErrorPane(message: _error!)
          : stats == null
              ? const SkeletonListView(itemCount: 5)
              : ListView(
                  // 88 bottom = the usual 16 plus FAB clearance (56 + 16).
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    // Stats header.
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: surfaceCardDecoration(theme.colorScheme),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(l.cardDue, '${stats.dueToday}', theme.colorScheme.primary),
                          _Stat(l.cardActive, '${stats.active}', null),
                          _Stat(l.cardMastered, '${stats.mastered}', null),
                          _Stat(l.cardStreak, '${stats.streakDays}', null),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_queueLength > 0)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          await context.push('/kb/cards/review');
                          _load();
                        },
                        icon: const Icon(LucideIcons.brain, size: 18),
                        label: Text('${l.cardStart} ($_queueLength)'),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            l.cardAllDone,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ),
                      ),
                    // Card library — the stats numbers above finally have
                    // the rows behind them (GET /kb/cards?filter=).
                    for (final c in _cards)
                      Slidable(
                        key: ValueKey('card-${c.id}'),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.4,
                          children: [
                            SlidableAction(
                              onPressed: (_) async {
                                try {
                                  await ref
                                      .read(kbRepoProvider)
                                      .archiveCard(agentId!, c.id, true);
                                  _load();
                                } catch (e) {
                                  if (context.mounted) showApiError(context, e);
                                }
                              },
                              // Gold (warning) — distinct from the red
                              // delete block.
                              backgroundColor: paletteOf(context).warning,
                              foregroundColor: paletteOf(context).warningForeground,
                              icon: LucideIcons.archive,
                              label: l.kbArchive,
                            ),
                            SlidableAction(
                              onPressed: (_) async {
                                if (!await confirmDelete(context)) return;
                                try {
                                  await ref.read(kbRepoProvider).deleteCard(agentId!, c.id);
                                  _load();
                                } catch (e) {
                                  if (context.mounted) showApiError(context, e);
                                }
                              },
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                              icon: LucideIcons.trash2,
                              label: l.chatDelete,
                            ),
                          ],
                        ),
                        child: ChevronListTile(
                          padding: EdgeInsets.zero,
                          dense: true,
                          title: Text(c.question,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(c.answer,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: c.dueAt == null
                              ? null
                              : Text(formatShortDate(c.dueAt!.toLocal()),
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: theme.colorScheme.outline)),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => _CardViewPage(card: c),
                          )),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleLarge?.copyWith(
                color: color ?? theme.colorScheme.onSurface, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
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
