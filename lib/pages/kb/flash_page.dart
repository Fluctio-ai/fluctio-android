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
import '../../ui/load_states.dart';
import '../../ui/master_detail.dart';
import '../../ui/dialogs.dart';
import '../../ui/row_actions_menu.dart';
import '../../util/dates.dart';
import '../../util/app_toast.dart';
import 'kb_editor_page.dart';
import 'kb_text_view_page.dart';

/// Flash notes (灵感闪记): newest-first list, "记一笔" quick capture,
/// tap to edit, menu to delete. Wide layouts split list|preview with the
/// edit pencil in the pane header (same shape as notes).
class KbFlashPage extends ConsumerStatefulWidget {
  const KbFlashPage({super.key});

  @override
  ConsumerState<KbFlashPage> createState() => _KbFlashPageState();
}

class _KbFlashPageState extends ConsumerState<KbFlashPage> {
  /// Wide-layout selection: the flash previewing in the detail pane.
  /// Phones never set this — rows push the read-only viewer there.
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final sources = agentId == null ? null : ref.watch(kbSourcesProvider(agentId));
    final split = MasterDetailScaffold.isSplit(context);
    KbSource? selected;
    final list = sources?.value;
    if (split && _selectedId != null && list != null) {
      for (final s in list) {
        if (s.id == _selectedId) selected = s;
      }
    }
    // Final alias: closures capture it with promotion intact.
    final sel = selected;

    return MasterDetailScaffold(
      appBar: AppBar(title: Text(l.kbIdeas)),
      floatingActionButton: FloatingActionButton(
        onPressed: agentId == null ? null : () => _new(context, ref, agentId),
        child: const Icon(LucideIcons.plus),
      ),
      placeholderIcon: LucideIcons.zap,
      placeholderText: l.kbSelectToView,
      detail: sel == null
          ? null
          : _FlashPane(
              // Rebuild (fresh fetch) when the source changes or a new
              // selection lands.
              key: ValueKey('${sel.id}-${sel.updatedAt}'),
              agentId: agentId!,
              source: sel,
              onEdit: () => _edit(context, ref, agentId, sel),
            ),
      listPane: sources == null
          ? const SizedBox.shrink()
          : sources.when(
              loading: () => const SkeletonListView(),
              error: (e, _) => ErrorPane(message: l.chatHistoryError),
              data: (list) {
                final flashes = list.where((s) => s.type == 'flash').toList();
                if (flashes.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.zap,
                    message: l.kbEmpty,
                    // The empty state carries its own entry — same as the
                    // notes list.
                    action: agentId == null
                        ? null
                        : FilledButton(
                            onPressed: () => _new(context, ref, agentId),
                            child: Text(l.kbAddFlash)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      agentId == null ? Future.value() : ref.refresh(kbSourcesProvider(agentId).future),
                  child: ListView.builder(
                    // Bottom FAB clearance (56 + 16 + 16) so the last
                    // row scrolls out from under the button.
                    padding: const EdgeInsets.only(bottom: 88),
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
                              label: l.kbEdit,
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
                        child: ChevronListTile(
                          selected: _selectedId == s.id,
                          title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(DateTime.tryParse(s.updatedAt) == null
                              ? ''
                              : formatShortDate(DateTime.parse(s.updatedAt))),
                          onTap: () => _view(context, ref, agentId!, s),
                          onLongPress: () => showRowActionsMenu(context, [
                            RowAction(
                              icon: LucideIcons.penLine,
                              label: l.kbEdit,
                              onRun: () => _edit(context, ref, agentId!, s),
                            ),
                            RowAction(
                              icon: LucideIcons.trash2,
                              label: l.chatDelete,
                              destructive: true,
                              onRun: () => _delete(context, ref, agentId!, s),
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

  /// Tap opens the full content — the list row only carries the
  /// truncated title, the real text lives in the source's entries (same
  /// join the web flash view does before editing). Wide: select into the
  /// pane, phone: push the read-only viewer.
  Future<void> _view(BuildContext context, WidgetRef ref, String agentId, KbSource s) async {
    if (MasterDetailScaffold.isSplit(context)) {
      setState(() => _selectedId = s.id);
      return;
    }
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(kbRepoProvider);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KbTextViewPage(
        title: s.title.isEmpty ? l.kbIdeas : s.title,
        loadContent: () => repo.fullText(agentId, s.id),
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
        initial = await repo.fullText(agentId, s.id);
      } catch (_) {}
      if (!context.mounted) return false;
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: l.kbEdit,
        hint: l.kbFlashHint,
        initialText: initial,
        onSave: (text, _, _, _, {status}) async {
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
        onSave: (text, _, _, _, {status}) async {
          try {
            final deduped = await repo.saveFlash(agentId, text.trim());
            if (deduped) {
              AppToast.show(l.kbDeduped);
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
      // A deleted flash can't stay open in the detail pane.
      if (_selectedId == s.id && mounted) setState(() => _selectedId = null);
    } catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

}

/// The wide-layout detail pane for a flash: pane header (title + edit
/// pencil, notes-style) above the read-only markdown body. The full text
/// is fetched from the source entries (the list row only carries the
/// truncated title) — keyed by id+updatedAt from the parent so edits
/// re-mount it with a fresh future.
class _FlashPane extends ConsumerStatefulWidget {
  const _FlashPane({
    super.key,
    required this.agentId,
    required this.source,
    required this.onEdit,
  });

  final String agentId;
  final KbSource source;
  final VoidCallback onEdit;

  @override
  ConsumerState<_FlashPane> createState() => _FlashPaneState();
}

class _FlashPaneState extends ConsumerState<_FlashPane> {
  Future<String>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(kbRepoProvider).fullText(widget.agentId, widget.source.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.source.title.isEmpty ? l.kbIdeas : widget.source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l.kbEdit,
                icon: const Icon(LucideIcons.penLine, size: 20),
                onPressed: widget.onEdit,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Expanded(child: KbTextView(future: _future)),
      ],
    );
  }
}
