import '../app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/dialogs.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/load_states.dart';
import 'kb_editor_page.dart';
import 'kb_text_view_page.dart';

/// Notes: markdown list + plain-text editor (upsert on save), read-only
/// attachment listing.
class KbNotesPage extends ConsumerWidget {
  const KbNotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final notes = agentId == null ? null : ref.watch(kbNotesProvider(agentId));

    return Scaffold(
      // Drawer on every list surface — same gesture zone as chat.
      drawer: const AppDrawer(),
      drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
      appBar: AppBar(title: Text(l.kbNotes)),
      floatingActionButton: FloatingActionButton(
        onPressed: agentId == null ? null : () => _new(context, ref, agentId),
        child: const Icon(LucideIcons.plus),
      ),
      body: notes == null
          ? const SizedBox.shrink()
          : notes.when(
              loading: () => const SkeletonListView(),
              error: (e, _) => ErrorPane(message: l.chatHistoryError),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.notebookPen,
                    message: l.kbEmpty,
                    // The empty state carries its own entry — the FAB in
                    // the corner is not where a new user looks first.
                    action: agentId == null
                        ? null
                        : FilledButton(
                            onPressed: () => _new(context, ref, agentId),
                            child: Text(l.noteNew)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      agentId == null ? Future.value() : ref.refresh(kbNotesProvider(agentId).future),
                  child: ListView.builder(
                    // Bottom FAB clearance (56 + 16 + 16) so the last
                    // row scrolls out from under the button.
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final n = list[i];
                      final scheme = theme.colorScheme;
                      return Slidable(
                        key: ValueKey('note-${n.id}'),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.4,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _edit(context, ref, agentId!, n),
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              icon: LucideIcons.penLine,
                              label: l.kbEdit,
                            ),
                            SlidableAction(
                              onPressed: (_) => _delete(context, ref, agentId!, n),
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                              icon: LucideIcons.trash2,
                              label: l.chatDelete,
                            ),
                          ],
                        ),
                        child: ChevronListTile(
                        title: Text(n.title.isEmpty ? l.noteUntitled : n.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(n.updatedAt, maxLines: 1),
                        onTap: () => _view(context, ref, agentId!, n),
                        onLongPress: () => showRowActionsMenu(context, [
                          RowAction(
                            icon: LucideIcons.penLine,
                            label: l.kbEdit,
                            onRun: () => _edit(context, ref, agentId!, n),
                          ),
                          RowAction(
                            icon: LucideIcons.trash2,
                            label: l.chatDelete,
                            destructive: true,
                            onRun: () => _delete(context, ref, agentId!, n),
                          ),
                        ]),
                      ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  /// Tap opens the note read-only (markdown, transcript look); the
  /// pencil edits on a full-screen surface (DESIGN.md §4) instead of
  /// the old alert-box dialog.
  Future<void> _view(BuildContext context, WidgetRef ref, String agentId, KbNote n) async {
    final l = AppLocalizations.of(context)!;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KbTextViewPage(
        title: n.title.isEmpty ? l.noteUntitled : n.title,
        loadContent: () async => n.contentMd,
        onEdit: (current) => _edit(context, ref, agentId, n, initialText: current),
      ),
    ));
  }

  /// Full-screen edit (shared by the swipe action and the viewer's
  /// pencil); [initialText] skips nothing here — notes carry content.
  Future<bool> _edit(BuildContext context, WidgetRef ref, String agentId, KbNote n,
      {String? initialText}) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(kbRepoProvider);
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: l.kbEdit,
        hint: l.noteBodyHint,
        titleLabel: l.kbTitleOptional,
        initialTitle: n.title,
        initialText: initialText ?? n.contentMd,
        onSave: (text, title, _, _, {status}) async {
          try {
            await repo.saveNote(agentId, id: n.id, title: title.trim(), contentMd: text);
            ref.invalidate(kbNotesProvider(agentId));
            return true;
          } catch (e) {
            if (context.mounted) showApiError(context, e);
            return false;
          }
        },
      ),
    ));
    return saved == true;
  }

  Future<void> _new(BuildContext context, WidgetRef ref, String agentId) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(kbRepoProvider);
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: l.noteNew,
        hint: l.noteBodyHint,
        titleLabel: l.kbTitleOptional,
        onSave: (text, title, _, _, {status}) async {
          try {
            await repo.saveNote(agentId, title: title.trim(), contentMd: text);
            ref.invalidate(kbNotesProvider(agentId));
            return true;
          } catch (e) {
            if (context.mounted) showApiError(context, e);
            return false;
          }
        },
      ),
    ));
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, String agentId, KbNote n) async {
    if (!await confirmDelete(context)) return;
    try {
      await ref.read(kbRepoProvider).deleteNote(agentId, n.id);
      ref.invalidate(kbNotesProvider(agentId));
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }
}
