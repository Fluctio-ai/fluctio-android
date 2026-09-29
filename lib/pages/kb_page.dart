import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat/chat_controller.dart';
import '../kb/kb_repo.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Knowledge tab per the prototype: entry grid with live counts from the
/// KB sources / bookmarks of the selected agent. Wiki routes now; notes,
/// diary and cards arrive with ticket 06.
class KbPage extends ConsumerWidget {
  const KbPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final sources = agentId == null ? null : ref.watch(kbSourcesProvider(agentId));
    final bookmarks = agentId == null ? null : ref.watch(kbBookmarksProvider(agentId));

    int? count(bool Function(String type) match) {
      final list = sources?.value;
      if (list == null) return null;
      return list.where((s) => match(s.type)).length;
    }

    final entries = <_KbEntry>[
      _KbEntry(l.kbArticles, LucideIcons.fileText,
          () => context.push('/kb/articles'), count: count((t) => t == 'article')),
      _KbEntry(l.kbIdeas, LucideIcons.stickyNote, () => context.push('/kb/flash'),
          count: count((t) => t == 'flash')),
      _KbEntry(l.kbTodos, LucideIcons.listChecks, () => context.push('/kb/todos'),
          count: count((t) => t == 'todo')),
      _KbEntry(l.kbDiary, LucideIcons.calendarDays, () => _soon(context, l)),
      _KbEntry(l.kbBookmarks, LucideIcons.bookmark, () => context.push('/kb/bookmarks'),
          count: bookmarks?.value?.length),
      _KbEntry(l.kbNotes, LucideIcons.notebookPen, () => context.push('/kb/notes')),
      _KbEntry(l.kbCards, LucideIcons.layers, () => context.push('/kb/cards')),
      _KbEntry(l.kbWiki, LucideIcons.globe, () => context.push('/wiki')),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.navKnowledge)),
      body: GridView.count(
        crossAxisCount: 4,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.86,
        children: [for (final e in entries) _KbCard(entry: e)],
      ),
    );
  }

  void _soon(BuildContext context, AppLocalizations l) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingSoon)));
  }
}

class _KbEntry {
  const _KbEntry(this.name, this.icon, this.onTap, {this.count});

  final String name;
  final IconData icon;
  final VoidCallback onTap;

  /// null = not yet loaded / not applicable.
  final int? count;
}

class _KbCard extends StatelessWidget {
  const _KbCard({required this.entry});

  final _KbEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: entry.onTap,
      borderRadius: AppRadius.cardBorder,
      child: Container(
        decoration: surfaceCardDecoration(theme.colorScheme),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.icon, size: 26, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium),
            if (entry.count != null)
              Text('${entry.count}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
