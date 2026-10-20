import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../util/dates.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/dialogs.dart';
import '../../ui/master_detail.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/load_states.dart';
import 'article_detail_page.dart';

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

  /// Wide-layout selection: the article showing in the detail pane. Null
  /// = placeholder. Phone layouts never set this (rows push the detail
  /// route instead).
  String? _selectedId;
  String _selectedTitle = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Row tap: wide selects into the detail pane, phone pushes the route.
  void _open(String id, String title) {
    if (MasterDetailScaffold.isSplit(context)) {
      setState(() {
        _selectedId = id;
        _selectedTitle = title;
      });
    } else {
      context.push(
          '/kb/articles/${Uri.encodeComponent(id)}?title=${Uri.encodeComponent(title)}');
    }
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

    return MasterDetailScaffold(
      appBar: AppBar(title: Text(l.kbArticles)),
      placeholderIcon: LucideIcons.newspaper,
      placeholderText: l.kbSelectToView,
      detail: _selectedId == null
          ? null
          : KbArticleDetailPage(
              // Rebuild on selection change (fresh load per article).
              key: ValueKey(_selectedId),
              sourceId: _selectedId!,
              title: _selectedTitle,
              embedded: true,
            ),
      listPane: Column(
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
                ? _searchResults(context)
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
                                final scheme = theme.colorScheme;
                                // Character count localized like a human
                                // would say it — a bare "12345 · 10-07"
                                // reads as an ID, not a size.
                                final chars = l.localeName.startsWith('zh') &&
                                        s.totalChars >= 10000
                                    ? l.articleCharsWan(
                                        (s.totalChars / 10000).toStringAsFixed(1))
                                    : l.articleCharsCount(s.totalChars);
                                Future<void> delete() async {
                                  if (!await confirmDelete(context)) return;
                                  try {
                                    await ref.read(kbRepoProvider).deleteSource(agentId!, s.id);
                                    ref.invalidate(kbSourcesProvider(agentId));
                                    // A deleted article can't stay open in
                                    // the detail pane.
                                    if (_selectedId == s.id) {
                                      setState(() => _selectedId = null);
                                    }
                                  } catch (e) {
                                    if (context.mounted) showApiError(context, e);
                                  }
                                }
                                return Slidable(
                                  key: ValueKey('art-${s.id}'),
                                  endActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    extentRatio: 0.25,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) => delete(),
                                        backgroundColor: scheme.error,
                                        foregroundColor: scheme.onError,
                                        icon: LucideIcons.trash2,
                                        label: l.chatDelete,
                                      ),
                                    ],
                                  ),
                                  child: ChevronListTile(
                                  selected: _selectedId == s.id,
                                  title: Text(s.title,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    '$chars · ${DateTime.tryParse(s.updatedAt) == null ? '' : formatShortDate(DateTime.parse(s.updatedAt))}',
                                    maxLines: 1,
                                  ),
                                  onTap: () => _open(s.id, s.title),
                                  onLongPress: () => showRowActionsMenu(context, [
                                    RowAction(
                                      icon: LucideIcons.trash2,
                                      label: l.chatDelete,
                                      destructive: true,
                                      onRun: delete,
                                    ),
                                  ]),
                                ),
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

  Widget _searchResults(BuildContext context) {
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
        return ChevronListTile(
          title: Text(r.sourceTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(r.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _open(r.sourceId, r.sourceTitle),
        );
      },
    );
  }

}

