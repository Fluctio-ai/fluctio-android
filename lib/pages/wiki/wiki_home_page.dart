import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/load_states.dart';
import '../../wiki/wiki_models.dart';
import '../../wiki/wiki_repo.dart';
import '../app_drawer.dart';

/// Native wiki tab (replaces the WebView container): the web's
/// three-pane wiki browser distilled for touch — type tabs
/// (实体/概念/来源) instead of stacked sections, tap → preview,
/// slide-to-delete, and the graph one app-bar button away.
class WikiHomePage extends ConsumerStatefulWidget {
  const WikiHomePage({super.key});

  @override
  ConsumerState<WikiHomePage> createState() => _WikiHomePageState();
}

class _WikiHomePageState extends ConsumerState<WikiHomePage> {
  String _query = '';

  /// The web's three list sections (wiki/page.tsx PAGE_TYPE_SECTIONS);
  /// overview pages stay graph-only there and here.
  static const _tabs = ['entity', 'concept', 'source'];

  Future<void> _delete(WikiPageInfo page) async {
    final l = AppLocalizations.of(context)!;
    final agentId = ref.read(agentsProvider).selectedId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.wikiDeleteTitle),
        content: Text(l.wikiDeleteConfirm(page.title)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatDelete)),
        ],
      ),
    );
    if (ok != true || agentId == null) return;
    try {
      await ref.read(wikiRepoProvider).delete(agentId, page.id);
      ref.invalidate(wikiInventoryProvider(agentId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorNetwork)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final inv = agentId == null ? null : ref.watch(wikiInventoryProvider(agentId));

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        // Drawer on every list surface — same gesture zone as chat/KB.
        drawer: const AppDrawer(),
        drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
        appBar: AppBar(
          title: Text(l.navWiki),
          actions: [
            IconButton(
              tooltip: l.wikiKnowledgeGraph,
              icon: const Icon(LucideIcons.network, size: 20),
              onPressed: () => context.push('/wiki/graph'),
            ),
            const SizedBox(width: 4),
          ],
          bottom: TabBar(
            tabs: [
              for (final t in _tabs)
                Tab(text: '${_tabLabel(l, t)}${_tabCount(inv, t)}'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l.wikiSearchHint,
                  prefixIcon: const Icon(LucideIcons.search),
                  isDense: true,
                ),
              ),
            ),
            if (inv != null && inv.hasValue && inv.value?.stats != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.wikiStats(inv.value!.stats!.totalPages, inv.value!.stats!.totalEdges),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
              ),
            Expanded(
              child: inv == null
                  ? const SizedBox.shrink()
                  : inv.when(
                      loading: () => const SkeletonListView(),
                      error: (e, _) => ErrorPane(message: l.wikiLoadFailed),
                      data: (data) => TabBarView(
                        children: [
                          for (final t in _tabs) _typeList(context, data.pages, t),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(AppLocalizations l, String type) => switch (type) {
        'entity' => l.wikiEntity,
        'concept' => l.wikiConcept,
        _ => l.wikiSource,
      };

  /// Web shows each section header's total (independent of the visible
  /// window) — tabs carry the same count.
  String _tabCount(AsyncValue<WikiInventory>? inv, String type) {
    final n = inv?.value?.stats?.pageCounts[type] ??
        inv?.value?.pages.where((p) => p.pageType == type).length ??
        0;
    return n > 0 ? ' $n' : '';
  }

  Widget _typeList(BuildContext context, List<WikiPageInfo> pages, String type) {
    final l = AppLocalizations.of(context)!;
    final q = _query.trim().toLowerCase();
    final rows = pages
        .where((p) => p.pageType == type && (q.isEmpty || p.title.toLowerCase().contains(q)))
        .toList();
    if (rows.isEmpty) {
      return ListView(
        children: [
          if (pages.isEmpty)
            EmptyState(icon: LucideIcons.bookMarked, message: l.wikiNoPages)
          else if (q.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l.wikiNoMatch, style: Theme.of(context).textTheme.bodySmall)),
            ),
        ],
      );
    }
    final agentId = ref.read(agentsProvider).selectedId;
    return RefreshIndicator(
      onRefresh: () => agentId == null
          ? Future.value()
          : ref.refresh(wikiInventoryProvider(agentId).future),
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final p = rows[i];
          return Slidable(
            key: ValueKey('wiki-${p.id}'),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.25,
              children: [
                SlidableAction(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  icon: LucideIcons.trash2,
                  label: l.chatDelete,
                  onPressed: (_) => _delete(p),
                ),
              ],
            ),
            child: ChevronListTile(
              title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: p.summary.isEmpty
                  ? null
                  : Text(p.summary,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => context.push('/wiki/page/${Uri.encodeComponent(p.id)}'),
            ),
          );
        },
      ),
    );
  }
}
