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
import '../../ui/load_states.dart';

/// KB articles: server-side semantic search over the whole knowledge
/// base, plain list otherwise.
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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

