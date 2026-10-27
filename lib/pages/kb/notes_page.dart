import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../chat/chat_controller.dart';
import '../../auth/auth_controller.dart';
import '../../files/file_preview.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/chat/chat_image.dart';
import '../../theme/tokens.dart';
import '../../ui/chevron_list_tile.dart';
import '../../ui/dialogs.dart';
import '../../ui/master_detail.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/load_states.dart';
import 'kb_editor_page.dart';
import 'kb_text_view_page.dart';

/// Notes: markdown list + plain-text editor (upsert on save), read-only
/// attachment listing.
class KbNotesPage extends ConsumerStatefulWidget {
  const KbNotesPage({super.key});

  @override
  ConsumerState<KbNotesPage> createState() => _KbNotesPageState();
}

class _KbNotesPageState extends ConsumerState<KbNotesPage> {
  /// Wide-layout selection: the note previewing in the detail pane.
  /// Phones never set this — rows push the read-only viewer there.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final notes = agentId == null ? null : ref.watch(kbNotesProvider(agentId));
    final split = MasterDetailScaffold.isSplit(context);
    final sel = split
        ? notes?.value?.where((n) => n.id == _selectedId).firstOrNull
        : null;

    return MasterDetailScaffold(
      appBar: AppBar(title: Text(l.kbNotes)),
      floatingActionButton: FloatingActionButton(
        onPressed: agentId == null ? null : () => _new(context, ref, agentId),
        child: const Icon(LucideIcons.plus),
      ),
      placeholderIcon: LucideIcons.notebookPen,
      placeholderText: l.kbSelectToView,
      detail: sel == null
          ? null
          : _NotePane(
              // Rebuild (fresh read) when the note's content changes.
              key: ValueKey('${sel.id}-${sel.updatedAt}'),
              agentId: agentId!,
              note: sel,
              onEdit: () => _edit(context, ref, agentId, sel),
            ),
      listPane: notes == null
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
                        selected: _selectedId == n.id,
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

  /// Tap opens the note: wide selects it into the pane, phone pushes the
  /// read-only viewer (markdown, transcript look) whose pencil edits on
  /// a full-screen surface (DESIGN.md §4).
  Future<void> _view(BuildContext context, WidgetRef ref, String agentId, KbNote n) async {
    if (MasterDetailScaffold.isSplit(context)) {
      setState(() => _selectedId = n.id);
      return;
    }
    final l = AppLocalizations.of(context)!;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KbTextViewPage(
        title: n.title.isEmpty ? l.noteUntitled : n.title,
        loadContent: () async => n.contentMd,
        // Read-only attachment strip (uploaded from the web side).
        topSection: _NoteAttachmentsBar(agentId: agentId, noteId: n.id),
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
      // A deleted note can't stay open in the detail pane.
      if (_selectedId == n.id && mounted) setState(() => _selectedId = null);
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }
}

/// The wide-layout detail pane for a note: pane header (title + edit
/// pencil) above the read-only markdown body (KbTextView). Editing stays
/// a full-screen push in v1 — the pane header's pencil drives it.
///
/// Stateful so the KbTextView future is created ONCE (a fresh
/// Future.value per build would re-subscribe the FutureBuilder →
/// skeleton flash + full re-parse on any parent rebuild). The parent's
/// ValueKey(id+updatedAt) remounts it when content changes.
class _NotePane extends StatefulWidget {
  const _NotePane({super.key, required this.agentId, required this.note, required this.onEdit});

  final String agentId;
  final KbNote note;
  final VoidCallback onEdit;

  @override
  State<_NotePane> createState() => _NotePaneState();
}

class _NotePaneState extends State<_NotePane> {
  late final Future<String> _content = Future.value(widget.note.contentMd);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        DetailPaneHeader(
          title: widget.note.title.isEmpty ? l.noteUntitled : widget.note.title,
          onEdit: widget.onEdit,
          editTooltip: l.kbEdit,
        ),
        // The note list row already carries the full markdown body.
        Expanded(
          child: KbTextView(
            future: _content,
            topSection: _NoteAttachmentsBar(agentId: widget.agentId, noteId: widget.note.id),
          ),
        ),
      ],
    );
  }
}

/// Read-only attachment strip (uploads happen on the web side): image
/// mimes render thumbnails, everything else a file tile. Taps route
/// through the shared file preview (lightbox / pdf / media / text).
/// Loads best-effort — a failed listing just hides the strip.
class _NoteAttachmentsBar extends ConsumerWidget {
  const _NoteAttachmentsBar({required this.agentId, required this.noteId});

  final String agentId;
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final atts = ref.watch(noteAttachmentsProvider((agentId, noteId)));
    return atts.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(l.noteAttachments,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
            SizedBox(
              height: 64,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final a = list[i];
                  final isImage = a.mime.startsWith('image/');
                  final auth = ref.read(authControllerProvider);
                  return InkWell(
                    onTap: a.filePath.isEmpty
                        ? null
                        : () => openWorkspaceFilePreview(context, ref,
                            agentId: agentId, path: a.filePath, displayName: a.fileName),
                    borderRadius: AppRadius.controlBorder,
                    child: isImage
                        ? ClipRRect(
                            borderRadius: AppRadius.controlBorder,
                            child: Image(
                              image: chatImageProvider(
                                workspaceFileGatewayUrl(auth.baseUrl, agentId, a.filePath),
                                baseUrl: auth.baseUrl,
                                cookie: auth.sid,
                              ),
                              width: 96,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _FileTile(name: a.fileName),
                            ),
                          )
                        : _FileTile(name: a.fileName),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Non-image attachment tile: paperclip + file name (web's file card).
class _FileTile extends StatelessWidget {
  const _FileTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 96,
      height: 64,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: AppRadius.controlBorder,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.paperclip, size: 16, color: theme.colorScheme.outline),
          const SizedBox(height: 4),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
