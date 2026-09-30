import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../../util/open_url.dart';

/// Web bookmarks: newest first, save URL (server fetches the page body
/// so the link survives rot), edit metadata, promote into a full KB
/// article.
class KbBookmarksPage extends ConsumerWidget {
  const KbBookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final bookmarks = agentId == null ? null : ref.watch(kbBookmarksProvider(agentId));

    return Scaffold(
      appBar: AppBar(title: Text(l.kbBookmarks)),
      floatingActionButton: FloatingActionButton(
        onPressed: agentId == null ? null : () => _add(context, ref, agentId),
        child: const Icon(LucideIcons.plus),
      ),
      body: bookmarks == null
          ? const SizedBox.shrink()
          : bookmarks.when(
              loading: () => const SkeletonListView(),
              error: (e, _) => ErrorPane(message: l.chatHistoryError),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(icon: LucideIcons.bookmark, message: l.kbEmpty);
                }
                return RefreshIndicator(
                  onRefresh: () => agentId == null
                      ? Future.value()
                      : ref.refresh(kbBookmarksProvider(agentId).future),
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final b = list[i];
                      final scheme = theme.colorScheme;
                      // iOS-style swipe actions — the row keeps its full
                      // title width, no trailing menu.
                      return Slidable(
                        key: ValueKey('bm-${b.id}'),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: b.promoted ? 0.4 : 0.58,
                          children: [
                            SlidableAction(
                              onPressed: (_) =>
                                  _BookmarkActions.run(context, ref, agentId!, b, 'edit'),
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              icon: LucideIcons.penLine,
                              label: l.chatRename,
                            ),
                            if (!b.promoted)
                              SlidableAction(
                                onPressed: (_) =>
                                    _BookmarkActions.run(context, ref, agentId!, b, 'promote'),
                                backgroundColor: scheme.tertiary,
                                foregroundColor: scheme.onTertiary,
                                icon: LucideIcons.trendingUp,
                                label: l.kbPromote,
                              ),
                            SlidableAction(
                              onPressed: (_) =>
                                  _BookmarkActions.run(context, ref, agentId!, b, 'delete'),
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                              icon: LucideIcons.trash2,
                              label: l.chatDelete,
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Row(
                            children: [
                              if (b.promoted)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(LucideIcons.checkCircle2,
                                      size: 14, color: scheme.primary),
                                ),
                              Expanded(
                                child: Text(b.title.isEmpty ? b.url : b.title,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            b.summary.isEmpty ? _host(b.url) : b.summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => openExternalUrl(b.url),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String agentId) async {
    final l = AppLocalizations.of(context)!;
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.kbAddBookmark),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: urlController,
                autofocus: true,
                decoration: InputDecoration(hintText: 'https://…')),
            const SizedBox(height: 8),
            TextField(
                controller: titleController,
                decoration: InputDecoration(hintText: l.kbTitleOptional)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatSend)),
        ],
      ),
    );
    if (saved != true) return;
    final url = urlController.text.trim();
    if (url.isEmpty) return;
    try {
      await ref
          .read(kbRepoProvider)
          .saveBookmark(agentId, url, title: titleController.text.trim());
      ref.invalidate(kbBookmarksProvider(agentId));
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  String _host(String url) => Uri.tryParse(url)?.host ?? url;
}

/// Row-action runner for the swipe actions (edit / promote / delete).
class _BookmarkActions {
  _BookmarkActions._();

  static Future<void> run(BuildContext context, WidgetRef ref,
      String agentId, KbBookmark bookmark, String action) async {
    final l = AppLocalizations.of(context)!;
    final repo = KbRepo(ref.read(apiClientProvider));
    try {
      switch (action) {
        case 'edit':
          final title = TextEditingController(text: bookmark.title);
          final summary = TextEditingController(text: bookmark.summary);
          final saved = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l.chatRename),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: title,
                      autofocus: true,
                      decoration: InputDecoration(hintText: l.kbTitleOptional)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: summary,
                      maxLines: 3,
                      decoration: InputDecoration(hintText: l.kbSummary)),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatSend)),
              ],
            ),
          );
          if (saved == true) {
            await repo.updateBookmark(agentId, bookmark.id,
                title: title.text.trim(), summary: summary.text.trim());
            ref.invalidate(kbBookmarksProvider(agentId));
          }
        case 'promote':
          await ref.read(kbRepoProvider).promoteBookmark(agentId, bookmark.id);
          ref.invalidate(kbBookmarksProvider(agentId));
          ref.invalidate(kbSourcesProvider(agentId));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l.kbPromoted)));
          }
        case 'delete':
          final yes = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              content: Text(l.chatDeleteConfirm),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(l.chatDelete)),
              ],
            ),
          );
          if (yes == true) {
            await repo.deleteBookmark(agentId, bookmark.id);
            ref.invalidate(kbBookmarksProvider(agentId));
          }
      }
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }
}
