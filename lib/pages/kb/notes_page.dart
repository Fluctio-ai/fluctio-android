import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../l10n/app_localizations.dart';

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
        onPressed: agentId == null ? null : () => _edit(context, ref, agentId, null),
        child: const Icon(LucideIcons.plus),
      ),
      body: notes == null
          ? const SizedBox.shrink()
          : notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(l.chatHistoryError,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(child: Text(l.kbEmpty, style: theme.textTheme.bodyMedium));
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
                        trailing: IconButton(
                          icon: Icon(LucideIcons.trash2,
                              size: 18, color: theme.colorScheme.outline),
                          onPressed: () => _delete(context, ref, agentId!, n),
                        ),
                        onTap: () => _edit(context, ref, agentId!, n),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, String agentId, KbNote? existing) async {
    final l = AppLocalizations.of(context)!;
    final title = TextEditingController(text: existing?.title ?? '');
    final body = TextEditingController(text: existing?.contentMd ?? '');
    var noteId = existing?.id ?? '';
    var dirty = false;
    var attachments = const <KbNoteAttachment>[];

    if (existing != null) {
      try {
        attachments =
            await KbRepo(ref.read(apiClientProvider)).noteAttachments(agentId, existing.id);
      } catch (_) {}
    }

    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final discard = await showDialog<bool>(
              context: dialogContext,
              builder: (context) => AlertDialog(
                content: Text(l.noteDiscard),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(l.chatDelete)),
                ],
              ),
            );
            if (discard == true && dialogContext.mounted) {
              Navigator.of(dialogContext).pop(false);
            }
          },
          child: AlertDialog(
            title: Text(existing == null ? l.noteNew : l.chatRename),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    onChanged: (_) => setDialogState(() => dirty = true),
                    decoration: InputDecoration(hintText: l.kbTitleOptional),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: body,
                    onChanged: (_) => setDialogState(() => dirty = true),
                    maxLines: 8,
                    minLines: 6,
                    decoration: InputDecoration(hintText: l.noteBodyHint),
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(l.noteAttachments,
                          style: Theme.of(dialogContext).textTheme.labelSmall),
                    ),
                    for (final a in attachments)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('• ${a.fileName} (${a.size ~/ 1024} KB)',
                            style: Theme.of(dialogContext).textTheme.bodySmall),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  noteId = '';
                  Navigator.of(dialogContext).pop(false);
                },
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () {
                  dirty = false;
                  Navigator.of(dialogContext).pop(true);
                },
                child: Text(l.chatSend),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    try {
      noteId = await KbRepo(ref.read(apiClientProvider)).saveNote(
            agentId,
            id: noteId,
            title: title.text.trim(),
            contentMd: body.text,
          );
      ref.invalidate(kbNotesProvider(agentId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, String agentId, KbNote n) async {
    final l = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.chatDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatDelete)),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await KbRepo(ref.read(apiClientProvider)).deleteNote(agentId, n.id);
      ref.invalidate(kbNotesProvider(agentId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
