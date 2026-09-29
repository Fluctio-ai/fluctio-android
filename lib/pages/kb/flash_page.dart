import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/dialogs.dart';
import '../../util/dates.dart';

/// Flash notes (灵感闪记): newest-first list, "记一笔" quick capture,
/// tap to edit, menu to delete.
class KbFlashPage extends ConsumerWidget {
  const KbFlashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final sources = agentId == null ? null : ref.watch(kbSourcesProvider(agentId));

    return Scaffold(
      appBar: AppBar(title: Text(l.kbIdeas)),
      floatingActionButton: FloatingActionButton(
        onPressed: agentId == null ? null : () => _edit(context, ref, agentId, null),
        child: const Icon(LucideIcons.plus),
      ),
      body: sources == null
          ? const SizedBox.shrink()
          : sources.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(l.chatHistoryError,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
              data: (list) {
                final flashes = list.where((s) => s.type == 'flash').toList();
                if (flashes.isEmpty) {
                  return Center(child: Text(l.kbEmpty, style: theme.textTheme.bodyMedium));
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      agentId == null ? Future.value() : ref.refresh(kbSourcesProvider(agentId).future),
                  child: ListView.builder(
                    itemCount: flashes.length,
                    itemBuilder: (context, i) {
                      final s = flashes[i];
                      return ListTile(
                        title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(DateTime.tryParse(s.updatedAt) == null ? '' : formatShortDate(DateTime.parse(s.updatedAt))),
                        trailing: IconButton(
                          icon: Icon(LucideIcons.trash2,
                              size: 18, color: theme.colorScheme.outline),
                          onPressed: () => _delete(context, ref, agentId!, s),
                        ),
                        onTap: () => _edit(context, ref, agentId!, s),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, String agentId, KbSource? existing) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: existing?.title ?? '');
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? l.kbAddFlash : l.chatRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(hintText: l.kbFlashHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l.chatSend)),
        ],
      ),
    );
    if (content == null || content.trim().isEmpty) return;
    final repo = ref.read(kbRepoProvider);
    try {
      if (existing == null) {
        final deduped = await repo.saveFlash(agentId, content.trim());
        if (context.mounted && deduped) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.kbDeduped)));
        }
      } else {
        await repo.updateFlash(agentId, existing.id, content.trim());
      }
      ref.invalidate(kbSourcesProvider(agentId));
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, String agentId, KbSource s) async {
    if (!await confirmDelete(context)) return;
    try {
      await ref.read(kbRepoProvider).deleteSource(agentId, s.id);
      ref.invalidate(kbSourcesProvider(agentId));
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

}
