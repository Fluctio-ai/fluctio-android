import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../../theme/tokens.dart';

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
      final (stats, queue) = await (
        ref.read(kbRepoProvider).cardStats(agentId),
        ref.read(kbRepoProvider).cardQueue(agentId),
      ).wait;
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _queueLength = queue.length;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _addCard() async {
    final l = AppLocalizations.of(context)!;
    final q = TextEditingController();
    final a = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.cardAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: q, autofocus: true, decoration: InputDecoration(hintText: l.cardQuestion)),
            const SizedBox(height: 8),
            TextField(controller: a, maxLines: 3, decoration: InputDecoration(hintText: l.cardAnswer)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatSend)),
        ],
      ),
    );
    if (saved != true || q.text.trim().isEmpty) return;
    try {
      await ref
          .read(kbRepoProvider)
          .saveCard(ref.read(agentsProvider).selectedId!, q.text.trim(), a.text.trim());
      _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final stats = _stats;
    return Scaffold(
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
                  padding: const EdgeInsets.all(16),
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
