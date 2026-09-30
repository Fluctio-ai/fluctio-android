import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../util/dates.dart';
import '../../kb/kb_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../ui/load_states.dart';

/// KB articles: server-side semantic search over the whole knowledge
/// base, plain list otherwise.
/// KB nav grid — the web sidebar's 3-column tile grid (nav-knowledge.tsx /
/// nav-tile.tsx): bordered tinted container, icon-over-label tiles, and
/// the last row keeps 1/3-width cells (two tiles + a blank slot). Diary
/// stays out until its ticket lands; review fills the slot so the row
/// pairs like the web's.
class _KbNavGrid extends StatelessWidget {
  const _KbNavGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final entries = <(IconData, String, VoidCallback)>[
      (LucideIcons.fileText, l.kbArticles, () => context.go('/kb')),
      (LucideIcons.stickyNote, l.kbNotes, () => context.push('/kb/notes')),
      (LucideIcons.lightbulb, l.kbIdeas, () => context.push('/kb/flash')),
      (LucideIcons.squareCheckBig, l.kbTodos, () => context.push('/kb/todos')),
      (LucideIcons.link, l.kbBookmarks, () => context.push('/kb/bookmarks')),
      (LucideIcons.layers, l.kbCards, () => context.push('/kb/cards')),
      (LucideIcons.brain, l.cardReview, () => context.push('/kb/cards/review')),
      (LucideIcons.bookMarked, l.navWiki, () => context.push('/wiki')),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var row = 0; row * 3 < entries.length; row++)
            Row(
              children: [
                for (var i = row * 3; i < row * 3 + 3; i++)
                  Expanded(
                    child: i < entries.length
                        ? _tile(context, entries[i])
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, (IconData, String, VoidCallback) e) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.controlBorder,
        child: InkWell(
          borderRadius: AppRadius.controlBorder,
          onTap: e.$3,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(e.$1, size: 18, color: theme.colorScheme.outline),
                const SizedBox(height: 4),
                Text(e.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KbArticlesPage extends ConsumerStatefulWidget {
  const KbArticlesPage({super.key});

  @override
  ConsumerState<KbArticlesPage> createState() => _KbArticlesPageState();
}

class _KbArticlesPageState extends ConsumerState<KbArticlesPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<KbSearchResult>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final agentId = ref.read(agentsProvider).selectedId;
      if (agentId == null) return;
      try {
        final results = await ref.read(kbRepoProvider).search(agentId, query.trim());
        if (mounted) setState(() => _results = results);
      } catch (_) {
        if (mounted) setState(() => _results = const []);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final sources = agentId == null
        ? null
        : ref.watch(kbSourcesProvider(agentId));

    return Scaffold(
      appBar: AppBar(title: Text(l.kbArticles)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: _KbNavGrid(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onQuery,
              decoration: InputDecoration(
                hintText: l.kbSearchHint,
                prefixIcon: const Icon(LucideIcons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _results != null || _searching
                ? _searchResults(context, theme)
                : (sources == null
                    ? const SizedBox.shrink()
                    : sources.when(
                        loading: () => const SkeletonListView(),
                        error: (e, _) => ErrorPane(message: l.chatHistoryError),
                        data: (list) {
                          final articles = list.where((s) => s.type == 'article').toList();
                          if (articles.isEmpty) {
                            return EmptyState(icon: LucideIcons.newspaper, message: l.kbEmpty);
                          }
                          return RefreshIndicator(
                            onRefresh: () => agentId == null
                                ? Future.value()
                                : ref.refresh(kbSourcesProvider(agentId).future),
                            child: ListView.builder(
                              itemCount: articles.length,
                              itemBuilder: (context, i) {
                                final s = articles[i];
                                return ListTile(
                                  title: Text(s.title,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    '${s.totalChars} · ${DateTime.tryParse(s.updatedAt) == null ? '' : formatShortDate(DateTime.parse(s.updatedAt))}',
                                    maxLines: 1,
                                  ),
                                  onTap: () => context.push(
                                      '/kb/articles/${Uri.encodeComponent(s.id)}?title=${Uri.encodeComponent(s.title)}'),
                                );
                              },
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }

  Widget _searchResults(BuildContext context, ThemeData theme) {
    final l = AppLocalizations.of(context)!;
    if (_searching && _results == null) {
      return const SkeletonListView(itemCount: 4);
    }
    final results = _results ?? const <KbSearchResult>[];
    if (results.isEmpty) {
      return EmptyState(icon: LucideIcons.search, message: l.kbEmpty);
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final r = results[i];
        return ListTile(
          title: Text(r.sourceTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(r.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => context.push(
              '/kb/articles/${Uri.encodeComponent(r.sourceId)}?title=${Uri.encodeComponent(r.sourceTitle)}'),
        );
      },
    );
  }

}

