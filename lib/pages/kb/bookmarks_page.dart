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
import '../../ui/app_fab.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/fling_detector.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/row_meta.dart';
import '../../ui/load_states.dart';
import '../../ui/slide_action.dart';
import '../../util/open_url.dart';
import '../../util/app_toast.dart';
import 'kb_editor_page.dart';

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
      drawer: AppDrawer.adaptive(context),
      drawerEdgeDragWidth: AppDrawer.edgeDragWidth,
      appBar: AppBar(title: Text(l.kbBookmarks)),
      floatingActionButton: AppFab(
        onPressed: agentId == null ? null : () => _add(context, ref, agentId),
        icon: LucideIcons.plus,
      ),
      // DrawerFling: rows are Slidables that eat the arena drag.
      body: DrawerFling(
        child: bookmarks == null
            ? const SizedBox.shrink()
            : bookmarks.when(
                loading: () => const SkeletonListView(),
                error: (e, _) => ErrorPane(message: l.chatHistoryError),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: LucideIcons.bookmark,
                      message: l.kbEmpty,
                      // The empty state carries its own entry — same as the
                      // notes/flash lists.
                      action: agentId == null
                          ? null
                          : FilledButton(
                              onPressed: () => _add(context, ref, agentId),
                              child: Text(l.kbAddBookmark)),
                    );
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
                              SlideActionTile(
                                icon: LucideIcons.penLine,
                                label: l.kbEdit,
                                onPressed: () =>
                                    _BookmarkActions.run(context, ref, agentId!, b, 'edit'),
                              ),
                              if (!b.promoted)
                                SlideActionTile(
                                  icon: LucideIcons.trendingUp,
                                  label: l.kbPromote,
                                  onPressed: () =>
                                      _BookmarkActions.run(context, ref, agentId!, b, 'promote'),
                                ),
                              SlideActionTile(
                                icon: LucideIcons.trash2,
                                label: l.chatDelete,
                                destructive: true,
                                onPressed: () =>
                                    _BookmarkActions.run(context, ref, agentId!, b, 'delete'),
                              ),
                            ],
                          ),
                          child: ChevronListTile(
                            title: Text(b.title.isEmpty ? b.url : b.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: RowMetaTime.iso(b.createdAt),
                            subtitle: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    b.summary.isEmpty ? _host(b.url) : b.summary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // "Promoted to article" mark in the
                                // descriptor line's right slot (WeChat's
                                // mute-icon position), not before the title.
                                if (b.promoted)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6),
                                    child: Icon(LucideIcons.checkCircle2,
                                        size: 12, color: scheme.primary),
                                  ),
                              ],
                            ),
                            onTap: () => openExternalUrl(b.url),
                            onLongPress: () => showRowActionsMenu(context, [
                              RowAction(
                                icon: LucideIcons.penLine,
                                label: l.kbEdit,
                                onRun: () => _BookmarkActions.run(context, ref, agentId!, b, 'edit'),
                              ),
                              if (!b.promoted)
                                RowAction(
                                  icon: LucideIcons.trendingUp,
                                  label: l.kbPromote,
                                  onRun: () =>
                                      _BookmarkActions.run(context, ref, agentId!, b, 'promote'),
                                ),
                              RowAction(
                                icon: LucideIcons.trash2,
                                label: l.chatDelete,
                                destructive: true,
                                onRun: () => _BookmarkActions.run(context, ref, agentId!, b, 'delete'),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, String agentId) async {
    final l = AppLocalizations.of(context)!;
    // URL capture stays a form (typed input + validation, no prose to
    // read back); editing an existing bookmark goes through KbEditorPage
    // like the other KB items' bodies.
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
          // The notes-style full-screen editor (user feedback
          // 2026-11-21): the summary is prose the user reads back, not a
          // metadata stub — it gets the big editing surface like
          // note/flash bodies, title row on top. A cleared summary is a
          // legitimate state (the repo drops empty strings), hence the
          // always-true canSave.
          await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => KbEditorPage(
              heading: l.kbEdit,
              titleLabel: l.kbTitleOptional,
              initialTitle: bookmark.title,
              initialText: bookmark.summary,
              canSave: (_, _) => true,
              onSave: (text, title, date, endDate, {status}) async {
                try {
                  await repo.updateBookmark(agentId, bookmark.id,
                      title: title.trim(), summary: text.trim());
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
          AppToast.show(l.kbPromoted);
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
