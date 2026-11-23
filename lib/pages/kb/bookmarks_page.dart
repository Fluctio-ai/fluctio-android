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
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/form_editor_page.dart';
import '../../ui/dialogs.dart';
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
                  // Edit / promote / delete — one action set shared by the
                  // swipe rows (single column) and the long-press menu of
                  // the wide two-column cards.
                  List<RowAction> actions(KbBookmark b) => [
                        RowAction(
                          icon: LucideIcons.penLine,
                          label: l.kbEdit,
                          onRun: () =>
                              _BookmarkActions.run(context, ref, agentId!, b, 'edit'),
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
                          onRun: () =>
                              _BookmarkActions.run(context, ref, agentId!, b, 'delete'),
                        ),
                      ];
                  return RefreshIndicator(
                    onRefresh: () => agentId == null
                        ? Future.value()
                        : ref.refresh(kbBookmarksProvider(agentId).future),
                    child: LayoutBuilder(builder: (context, constraints) {
                      // Wide screens (pad) show two link cards per row —
                      // a bookmark is a title + blurb, one full-width row
                      // reads as a banner there (user feedback 2026-11-23).
                      // Cards keep the long-press menu; the swipe actions
                      // stay a single-column affordance (half-width slide
                      // panes would crowd the actions).
                      if (constraints.maxWidth >= 600) {
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpace.lg, AppSpace.lg, AppSpace.lg, 88),
                          itemCount: (list.length + 1) ~/ 2,
                          itemBuilder: (context, i) {
                            final a = list[i * 2];
                            final b = i * 2 + 1 < list.length ? list[i * 2 + 1] : null;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpace.sm),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _BookmarkCard(
                                        bookmark: a,
                                        onLongPress: () =>
                                            showRowActionsMenu(context, actions(a)),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.sm),
                                    // An odd one out rides the last row
                                    // alone at half width (fixed-thirds
                                    // rhythm, like the drawer tools grid).
                                    Expanded(
                                      child: b == null
                                          ? const SizedBox.shrink()
                                          : _BookmarkCard(
                                              bookmark: b,
                                              onLongPress: () =>
                                                  showRowActionsMenu(context, actions(b)),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return ListView.builder(
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
                              onLongPress: () => showRowActionsMenu(context, actions(b)),
                            ),
                          );
                        },
                      );
                    }),
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
}

/// Fallback blurb for a bookmark without a summary — just the host.
String _host(String url) => Uri.tryParse(url)?.host ?? url;

/// One bookmark as a wide-screen card (two per row): title + created time
/// on the first line, summary/host blurb below — the same info pair as the
/// single-column row, framed like the drawer's tools tiles.
class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({required this.bookmark, required this.onLongPress});

  final KbBookmark bookmark;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = bookmark;
    return InkWell(
      onTap: () => openExternalUrl(b.url),
      onLongPress: onLongPress,
      borderRadius: AppRadius.cardBorder,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                        fontSize: AppType.transcript, fontWeight: FontWeight.w500),
                    child: Text(b.title.isEmpty ? b.url : b.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpace.sm),
                  child: RowMetaTime.iso(b.createdAt),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.summary.isEmpty ? _host(b.url) : b.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.listSubtitleStyle(scheme),
                  ),
                ),
                // "Promoted to article" mark — same right slot as the row.
                if (b.promoted)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(LucideIcons.checkCircle2,
                        size: 12, color: scheme.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
          final yes = await confirmDelete(context);
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
