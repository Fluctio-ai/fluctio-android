import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../app_drawer.dart';
import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/form_editor_page.dart';
import '../../theme/tokens.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/load_states.dart';
import 'kb_editor_page.dart';
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
      // Drawer on every list surface — same gesture zone as chat.
      drawer: const AppDrawer(),
      drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
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
                    // Bottom FAB clearance (56 + 16 + 16) so the last
                    // row scrolls out from under the button.
                    padding: const EdgeInsets.only(bottom: 88),
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
                              label: l.kbEdit,
                            ),
                            if (!b.promoted)
                              SlidableAction(
                                onPressed: (_) =>
                                    _BookmarkActions.run(context, ref, agentId!, b, 'promote'),
                                // Gold (warning) — distinct from the cyan
                                // edit block and the red delete block.
                                backgroundColor: paletteOf(context).warning,
                                foregroundColor: paletteOf(context).warningForeground,
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
                        child: ChevronListTile(
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
    // Full-page editor — same surface as the bookmark edit above; the
    // old add dialog split the two flows.
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FormEditorPage<bool>(
        heading: l.kbAddBookmark,
        fields: [
          EditorField(label: 'URL', hint: 'https://…', keyboardType: TextInputType.url, autofocus: true),
          EditorField(label: l.kbTitleOptional),
        ],
        canSave: (v) => v[0].trim().isNotEmpty,
        onSave: (v) async {
          await ref.read(kbRepoProvider).saveBookmark(agentId, v[0].trim(), title: v[1].trim());
          ref.invalidate(kbBookmarksProvider(agentId));
          return true;
        },
      ),
    ));
    if (saved != true) return;
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
          if (!context.mounted) return;
          // Full-page editor (title + summary) instead of the old
          // dialog - same surface as notes/flash edits.
          await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => KbEditorPage(
              heading: l.kbEdit,
              hint: l.kbSummary,
              titleLabel: l.kbTitleOptional,
              initialTitle: bookmark.title,
              initialText: bookmark.summary,
              onSave: (summary, title, _, _, {status}) async {
                try {
                  await repo.updateBookmark(agentId, bookmark.id,
                      title: title.trim(), summary: summary.trim());
                  ref.invalidate(kbBookmarksProvider(agentId));
                  return true;
                } catch (e) {
                  if (context.mounted) showApiError(context, e);
                  return false;
                }
              },
            ),
          ));
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
