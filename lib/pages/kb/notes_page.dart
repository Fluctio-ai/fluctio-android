import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/dialogs.dart';
import '../../ui/load_states.dart';
import '../../webview/web_container.dart';
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
                  return EmptyState(icon: LucideIcons.notebookPen, message: l.kbEmpty);
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      agentId == null ? Future.value() : ref.refresh(kbNotesProvider(agentId).future),
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final n = list[i];
                      return ListTile(
                        leading: const Icon(LucideIcons.notebookPen, size: 20),
                        title: Text(n.title.isEmpty ? l.noteUntitled : n.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(n.updatedAt, maxLines: 1),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.noteWhiteboard,
                              icon: Icon(LucideIcons.penTool,
                                  size: 18, color: theme.colorScheme.primary),
                              onPressed: () => openWebContainer(context, l.noteWhiteboard,
                                  WebRoutes.noteEditor(agentId!)),
                            ),
                            IconButton(
                              icon: Icon(LucideIcons.trash2,
                                  size: 18, color: theme.colorScheme.outline),
                              onPressed: () => _delete(context, ref, agentId!, n),
                            ),
                          ],
                        ),
                        onTap: () => _view(context, ref, agentId!, n),
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
    final repo = ref.read(kbRepoProvider);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KbTextViewPage(
        title: n.title.isEmpty ? l.noteUntitled : n.title,
        loadContent: () async => n.contentMd,
        onEdit: (current) async {
          final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => KbEditorPage(
              heading: l.chatRename,
              hint: l.noteBodyHint,
              titleLabel: l.kbTitleOptional,
              initialTitle: n.title,
              initialText: current,
              onSave: (text, title, _) async {
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
        },
      ),
    ));
  }

  Future<void> _new(BuildContext context, WidgetRef ref, String agentId) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(kbRepoProvider);
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: l.noteNew,
        hint: l.noteBodyHint,
        titleLabel: l.kbTitleOptional,
        onSave: (text, title, _) async {
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
