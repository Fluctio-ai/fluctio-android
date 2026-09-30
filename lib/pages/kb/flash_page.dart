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
import '../../ui/dialogs.dart';
import '../../util/dates.dart';
import 'kb_editor_page.dart';
import 'kb_text_view_page.dart';

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
        onPressed: agentId == null ? null : () => _new(context, ref, agentId),
        child: const Icon(LucideIcons.plus),
      ),
      body: sources == null
          ? const SizedBox.shrink()
          : sources.when(
              loading: () => const SkeletonListView(),
              error: (e, _) => ErrorPane(message: l.chatHistoryError),
              data: (list) {
                final flashes = list.where((s) => s.type == 'flash').toList();
                if (flashes.isEmpty) {
                  return EmptyState(icon: LucideIcons.zap, message: l.kbEmpty);
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      agentId == null ? Future.value() : ref.refresh(kbSourcesProvider(agentId).future),
                  child: ListView.builder(
                    itemCount: flashes.length,
                    itemBuilder: (context, i) {
                      final s = flashes[i];
                      final scheme = theme.colorScheme;
                      return Slidable(
                        key: ValueKey('flash-${s.id}'),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.4,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _edit(context, ref, agentId!, s),
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              icon: LucideIcons.penLine,
                              label: l.chatRename,
                            ),
                            SlidableAction(
                              onPressed: (_) => _delete(context, ref, agentId!, s),
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                              icon: LucideIcons.trash2,
                              label: l.chatDelete,
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(DateTime.tryParse(s.updatedAt) == null
                              ? ''
                              : formatShortDate(DateTime.parse(s.updatedAt))),
                          onTap: () => _view(context, ref, agentId!, s),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  /// Tap opens the full content — the list row only carries the
  /// truncated title, the real text lives in the source's entries (same
  /// join the web flash view does before editing).
  Future<void> _view(BuildContext context, WidgetRef ref, String agentId, KbSource s) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(kbRepoProvider);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KbTextViewPage(
        title: s.title.isEmpty ? l.kbIdeas : s.title,
        loadContent: () async =>
            (await repo.entries(agentId, s.id)).map((e) => e.content).join('\n'),
        onEdit: (current) => _edit(context, ref, agentId, s, initialText: current),
      ),
    ));
  }

  /// Full-screen edit; [initialText] skips the entries fetch when the
  /// caller already holds the content (the viewer).
  Future<bool> _edit(BuildContext context, WidgetRef ref, String agentId, KbSource s,
      {String? initialText}) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(kbRepoProvider);
    var initial = initialText ?? '';
    if (initialText == null) {
      try {
        initial = (await repo.entries(agentId, s.id)).map((e) => e.content).join('\n');
      } catch (_) {}
      if (!context.mounted) return false;
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: l.chatRename,
        hint: l.kbFlashHint,
        initialText: initial,
        onSave: (text, _, _) async {
          try {
            await repo.updateFlash(agentId, s.id, text.trim());
            ref.invalidate(kbSourcesProvider(agentId));
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
        heading: l.kbAddFlash,
        hint: l.kbFlashHint,
        onSave: (text, _, _) async {
          try {
            final deduped = await repo.saveFlash(agentId, text.trim());
            if (deduped && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kbDeduped)));
            }
            ref.invalidate(kbSourcesProvider(agentId));
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
