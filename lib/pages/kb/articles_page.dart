import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../l10n/app_localizations.dart';

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
        final results = await KbRepo(ref.read(apiClientProvider))
            .search(agentId, query.trim());
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
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text(l.chatHistoryError,
                            style: TextStyle(color: theme.colorScheme.error))),
                        data: (list) {
                          final articles = list.where((s) => s.type == 'article').toList();
                          if (articles.isEmpty) {
                            return Center(
                              child: Text(l.kbEmpty, style: theme.textTheme.bodyMedium),
                            );
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
                                    '${s.totalChars} · ${_fmtDate(s.updatedAt)}',
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
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final results = _results ?? const <KbSearchResult>[];
    if (results.isEmpty) {
      return Center(child: Text(l.kbEmpty, style: theme.textTheme.bodyMedium));
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

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final local = d.toLocal();
    final now = DateTime.now();
    return '${local.year == now.year ? '' : '${local.year}/'}${local.month}/${local.day}';
  }
}
