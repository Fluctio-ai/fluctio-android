import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Knowledge tab per the prototype: search field + entry grid. Counts and
/// recent-documents arrive with the M2 tickets; Wiki routes now.
class KbPage extends StatefulWidget {
  const KbPage({super.key});

  @override
  State<KbPage> createState() => _KbPageState();
}

class _KbPageState extends State<KbPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entries = <_KbEntry>[
      _KbEntry(l.kbArticles, LucideIcons.fileText, () => _comingSoon(context, l)),
      _KbEntry(l.kbNotes, LucideIcons.stickyNote, () => _comingSoon(context, l)),
      _KbEntry(l.kbIdeas, LucideIcons.lightbulb, () => _comingSoon(context, l)),
      _KbEntry(l.kbTodos, LucideIcons.listChecks, () => _comingSoon(context, l)),
      _KbEntry(l.kbDiary, LucideIcons.calendarDays, () => _comingSoon(context, l)),
      _KbEntry(l.kbBookmarks, LucideIcons.bookmark, () => _comingSoon(context, l)),
      _KbEntry(l.kbCards, LucideIcons.layers, () => _comingSoon(context, l)),
      _KbEntry(l.kbWiki, LucideIcons.globe, () => context.push('/wiki')),
    ];
    final query = _search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? entries
        : entries.where((e) => e.name.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.navKnowledge)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l.kbSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(child: Text(l.comingSoon, style: theme.textTheme.bodyMedium))
                : GridView.count(
                    crossAxisCount: 4,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.86,
                    children: [
                      for (final e in visible) _KbCard(entry: e),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, AppLocalizations l) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingSoon)));
  }
}

class _KbEntry {
  const _KbEntry(this.name, this.icon, this.onTap);
  final String name;
  final IconData icon;
  final VoidCallback onTap;
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
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.icon, size: 26, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
