
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:path_provider/path_provider.dart';

import '../kb/kb_editor_page.dart';


import '../../chat/chat_controller.dart';
import '../../chat/models.dart';
import '../../files/agent_files.dart';
import '../../files/file_preview.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../share/share_out.dart';
import '../../theme/tokens.dart';
import '../../ui/dialogs.dart';
import '../../ui/row_actions_menu.dart';
import '../../ui/load_states.dart';
import '../../util/dates.dart';

/// One session row (used in the navigation drawer): title/preview/time,
/// per-item menu (rename / delete / chat-only toggle).
class SessionTile extends ConsumerWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.selected,
    this.leading,
    this.trailing,
    this.slideActions = false,
    required this.onTap,
  });

  final ChatSessionInfo session;
  final bool selected;
  final Widget? leading;
  final Widget? trailing;

  /// Chat-list rows replace the ⋯ trailing menu with iOS-style swipe
  /// actions (full-width titles); the drawer keeps the menu (too narrow).
  final bool slideActions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final time = formatSessionTime(session.updatedAt,
        locale: Localizations.localeOf(context).toString());
    final tile = ListTile(
      dense: true,
      selected: selected,
      // Chevron rhythm shared with the KB lists (ChevronListTile) —
      // rows without an explicit leading still carry the pointer.
      leading: leading ??
          Icon(LucideIcons.chevronRight,
              size: 16, color: Theme.of(context).colorScheme.outline),
      horizontalTitleGap: 8,
      // Right gutter narrowed — the ⋯ menu hugs the row edge (its own
      // box adds a few px); left stays at the standard 16.
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      title: Text(
        session.title.isEmpty ? l.chatNew : session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        // Same size as the transcript body (web runs sidebar text-sm 14
        // next to chat-md 13.5) — the dense ListTile default ran ~2px
        // smaller and the sidebar read disconnected from the chat.
        style: const TextStyle(fontSize: AppType.transcript),
      ),
      subtitle: switch ((session.preview, time)) {
        ('', '') => null,
        ('', _) => Text(time, maxLines: 1),
        (_, '') => Text(session.preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        (_, _) => Text('${session.preview} · $time', maxLines: 1, overflow: TextOverflow.ellipsis),
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // IM-channel mark (web parity: ChannelIcon next to the title).
          // No brand assets on the app side — a text chip names the
          // channel and flags the read-only chat.
          if (session.isImChannel)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: '${channelLabel(session.channel)} · ${l.chatImChannelBadge}',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(AppRadius.nested),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Text(
                    channelLabel(session.channel),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              ),
            ),
          if (session.chatOnly)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Tooltip(
                message: l.chatOnlyMode,
                child: Icon(LucideIcons.messageCircle,
                    size: 16, color: Theme.of(context).colorScheme.outline),
              ),
            ),
          if (!slideActions) _SessionMenu(session: session),
          ?trailing,
        ],
      ),
      onTap: onTap,
      // Long-press menu mirrors the swipe actions — the discoverable
      // channel; drawer rows (no swipe) get it too, their ⋯ menu
      // stays as the visual affordance.
      onLongPress: () => showRowActionsMenu(context, [
        RowAction(
          icon: LucideIcons.penLine,
          label: l.chatRename,
          onRun: () => _SessionMenu.run(context, ref, session, 'rename'),
        ),
        RowAction(
          icon: LucideIcons.trash2,
          label: l.chatDelete,
          destructive: true,
          onRun: () => _SessionMenu.run(context, ref, session, 'delete'),
        ),
      ]),
    );
    if (!slideActions) return tile;
    final scheme = Theme.of(context).colorScheme;
    return Slidable(
      key: ValueKey('session-${session.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) => _SessionMenu.run(context, ref, session, 'rename'),
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            icon: LucideIcons.penLine,
            label: l.chatRename,
          ),
          SlidableAction(
            onPressed: (_) => _SessionMenu.run(context, ref, session, 'delete'),
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            icon: LucideIcons.trash2,
            label: l.chatDelete,
          ),
        ],
      ),
      child: tile,
    );
  }
}



class _SessionMenu extends ConsumerWidget {
  const _SessionMenu({required this.session});

  final ChatSessionInfo session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return RowMenuButton(
      onSelected: (action) => run(context, ref, session, action),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: Text(l.chatRename)),
        PopupMenuItem(value: 'delete', child: Text(l.chatDelete)),
      ],
    );
  }

  static Future<void> run(BuildContext context, WidgetRef ref,
      ChatSessionInfo session, String action) async {
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(sessionsProvider.notifier);
    switch (action) {
      case 'rename':
        await promptRename(context, ref, l, session);
      case 'delete':
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
          final wasActive = ref.read(chatStoreProvider).activeKey ==
              '${ref.read(agentsProvider).selectedId}|${session.id}';
          await notifier.delete(session.id);
          if (wasActive) await ref.read(chatStoreProvider.notifier).newChat();
        } catch (e) {
          if (context.mounted) showApiError(context, e);
        }
    }
  }

  static Future<void> promptRename(BuildContext context, WidgetRef ref,
      AppLocalizations l, ChatSessionInfo session) async {
    if (!context.mounted) return;
    // Full-page editor instead of the old dialog — same surface as the
    // KB edits.
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => KbEditorPage(
        heading: l.chatRename,
        hint: l.chatRename,
        initialText: session.title,
        onSave: (text, _, _, _, {status}) async {
          if (text.trim().isEmpty) return false;
          try {
            await ref.read(sessionsProvider.notifier).rename(session.id, text.trim());
            return true;
          } catch (e) {
            if (context.mounted) showApiError(context, e);
            return false;
          }
        },
      ),
    ));
  }
}

/// Todo panel: single data source = the server's todo.md, refetched on
/// turn end by the chat controller.
Future<void> showTodoSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _TodoSheet(),
  );
}

class _TodoSheet extends ConsumerWidget {
  const _TodoSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final activeKey = ref.watch(chatStoreProvider.select((s) => s.activeKey));
    final agentId = splitSessionKey(activeKey)?.agentId;
    final sessionId = splitSessionKey(activeKey)?.sessionId;
    final todo = agentId == null || sessionId == null
        ? null
        : ref.watch(todoProvider((agentId, sessionId)));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(l.chatTodo, style: Theme.of(context).textTheme.titleMedium)),
                  if (agentId != null && sessionId != null)
                    IconButton(
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      onPressed: () => ref.invalidate(todoProvider((agentId, sessionId))),
                    ),
                ],
              ),
            ),
            Flexible(
              child: todo == null
                  ? const SizedBox.shrink()
                  : todo.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: SkeletonList(itemCount: 4),
                      ),
                      error: (_, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l.chatHistoryError,
                            style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
                      ),
                      data: (data) {
                        if (data.items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(l.chatTodoEmpty, style: TextStyle(color: scheme.outline)),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: data.items.length,
                          itemBuilder: (context, i) {
                            final item = data.items[i];
                            final style = item.done
                                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: scheme.outline,
                                    color: scheme.outline,
                                  )
                                : Theme.of(context).textTheme.bodyMedium;
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                item.cancelled
                                    ? LucideIcons.circleMinus
                                    : item.done
                                        ? LucideIcons.squareCheckBig
                                        : LucideIcons.square,
                                size: 20,
                                color: item.cancelled || item.done
                                    ? scheme.outline
                                    : scheme.primary,
                              ),
                              title: Text(item.text, style: style),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Agent workspace files (where a turn's attachments land): list +
/// delete, per GET/DELETE /api/agents/{id}/files.
Future<void> showFilesSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FilesSheet(),
  );
}

class _FilesSheet extends ConsumerStatefulWidget {
  const _FilesSheet();

  @override
  ConsumerState<_FilesSheet> createState() => _FilesSheetState();
}

class _FilesSheetState extends ConsumerState<_FilesSheet> {
  Future<AgentFileListing>? _future;
  String? _agentId;

  /// Expanded folder keys (relative paths — stable across refreshes,
  /// web FileTreeView parity). Seeded once when the tree first lands:
  /// root folders open, deeper levels collapsed.
  final Set<String> _expanded = {};
  bool _expandedSeeded = false;

  /// The open chat's session — files scope to that conversation's
  /// workspace subtree, not the whole agent (fileScopeForRequest).
  String? get _sessionId =>
      splitSessionKey(ref.read(chatStoreProvider).activeKey)?.sessionId;

  @override
  void initState() {
    super.initState();
    _agentId = ref.read(agentsProvider).selectedId;
    _reload();
  }

  void _reload() {
    final agentId = _agentId;
    final sessionId = _sessionId;
    if (agentId == null || sessionId == null || sessionId.isEmpty) {
      // No session open — nothing to scope to; show the empty state
      // rather than falling back to the agent-wide listing.
      setState(() {
        _future = null;
      });
      return;
    }
    final future = ref.read(agentFilesRepoProvider).list(agentId, sessionId: sessionId);
    // Block body on purpose: an arrow closure would return the assigned
    // Future and trip setState's callback-returned-a-Future assertion —
    // exactly the crash seen on device (sheet dies in initState).
    setState(() {
      _future = future;
    });
  }

  /// Depth-tagged visible rows: expanded folders' children inline,
  /// collapsed ones hidden (one flat list, no nested scroll views).
  List<(WsFileNode, int)> _flatten(List<WsFileNode> nodes, int depth) => [
        for (final n in nodes) ...[
          (n, depth),
          if (n.isDir && _expanded.contains(n.relPath)) ..._flatten(n.children, depth + 1),
        ],
      ];

  void _seedExpansion(List<WsFileNode> roots) {
    if (_expandedSeeded) return;
    _expandedSeeded = true;
    _expanded.addAll([for (final n in roots) if (n.isDir) n.relPath]);
  }

  Future<void> _delete(AgentFile f) async {
    if (!await confirmDelete(context)) return;
    try {
      await ref.read(agentFilesRepoProvider).delete(_agentId!, f, sessionId: _sessionId);
      if (mounted) _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  /// Tap previews route through the shared workspace previewer (same
  /// path as chat-message file links).
  Future<void> _open(BuildContext context, AgentFile f) async {
    final agentId = _agentId;
    if (agentId == null) return;
    await openWorkspaceFilePreview(context, ref,
        agentId: agentId, path: f.path, sessionId: _sessionId, displayName: f.name);
  }

  /// In-sheet feedback line — snackbars from inside a modal sheet route
  /// never surface (they render behind the sheet), so progress/errors
  /// show here instead. [busy] swaps the icon for a spinner.
  String? _notice;
  bool _noticeBusy = false;
  Timer? _noticeTimer;

  void _setNotice(String? text, {bool busy = false, Duration? autoClear}) {
    _noticeTimer?.cancel();
    _noticeTimer = null;
    setState(() {
      _notice = text;
      _noticeBusy = busy;
    });
    if (text != null && autoClear != null) {
      _noticeTimer = Timer(autoClear, () => _setNotice(null));
    }
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  /// Streams the file into the temp dir and returns the staged copy.
  /// Shared by share-out and local download — big media never round-trips
  /// through memory. [AgentFile.path] is server-sourced from the sheet's
  /// own listing, so it downloads as-is (same as delete).
  Future<File> _stage(AgentFile f) async {
    final repo = ref.read(agentFilesRepoProvider);
    final safeName = f.name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    await dir.create(recursive: true);
    final target = File('${dir.path}/$safeName');
    await repo.downloadTo(_agentId!, f.path, target.path, sessionId: _sessionId);
    return target;
  }

  /// Share-out: stage the file, then hand it to the system share sheet.
  /// A gateway link would be useless outside the app (cookie auth), so
  /// receivers always get the bytes.
  Future<void> _share(AgentFile f) async {
    if (_agentId == null) return;
    final l = AppLocalizations.of(context)!;
    _setNotice(l.sharePreparing, busy: true);
    try {
      final staged = await _stage(f);
      _setNotice(null);
      if (!mounted) return;
      await shareLocalFile(staged);
    } catch (e) {
      _setNotice(apiErrorMessage(e, l), autoClear: const Duration(seconds: 4));
    }
  }

  /// Local download: stage the file, then copy it into the shared
  /// Download/ folder via MediaStore (system download manager visible).
  /// Completion surfaces as a system toast (WeChat-style — visible even
  /// if the user leaves the sheet), busy/errors stay on the in-sheet strip.
  Future<void> _download(AgentFile f) async {
    if (_agentId == null) return;
    final l = AppLocalizations.of(context)!;
    _setNotice(l.downloadPreparing, busy: true);
    try {
      final staged = await _stage(f);
      if (!mounted) return;
      await saveLocalFileToDownloads(staged);
      _setNotice(null);
      await Fluttertoast.showToast(msg: l.downloadDone);
    } catch (e) {
      _setNotice(apiErrorMessage(e, l), autoClear: const Duration(seconds: 4));
    }
  }

  String _fmtSize(int bytes) => bytes < 1024
      ? '${bytes}B'
      : bytes < 1024 * 1024
          ? '${(bytes / 1024).toStringAsFixed(1)}KB'
          : '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: _noticeBusy
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(LucideIcons.check,
                              size: 14, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_notice!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: FutureBuilder<AgentFileListing>(
          future: _future,
          builder: (context, snap) => snap.connectionState == ConnectionState.waiting
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: SkeletonList(itemCount: 5),
                )
              : snap.hasError
                  ? ErrorPane(message: l.chatHistoryError)
                  : (snap.data?.files.isEmpty ?? true)
                      ? EmptyState(icon: LucideIcons.folderOpen, message: l.kbEmpty)
                      : Builder(builder: (context) {
                          final tree = buildWsFileTree(snap.data!.files);
                          _seedExpansion(tree);
                          final rows = _flatten(tree, 0);
                          return ListView(
                            shrinkWrap: true,
                            children: [
                              for (final (node, depth) in rows)
                                if (node.isDir)
                                  _FolderRow(
                                    node: node,
                                    depth: depth,
                                    expanded: _expanded.contains(node.relPath),
                                    onToggle: () => setState(() {
                                          if (_expanded.contains(node.relPath)) {
                                            _expanded.remove(node.relPath);
                                          } else {
                                            _expanded.add(node.relPath);
                                          }
                                        }),
                                  )
                                else
                                  Slidable(
                                    key: ValueKey('wsfile-${node.file!.path}'),
                                    endActionPane: ActionPane(
                                      motion: const DrawerMotion(),
                                      extentRatio: 0.25,
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) => _delete(node.file!),
                                          backgroundColor: theme.colorScheme.error,
                                          foregroundColor: theme.colorScheme.onError,
                                          icon: LucideIcons.trash2,
                                          label: l.chatDelete,
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding:
                                          EdgeInsets.only(left: 16 + depth * 14.0, right: 16),
                                      leading: Icon(LucideIcons.fileText,
                                          size: 20, color: theme.colorScheme.outline),
                                      title: Text(node.name,
                                          maxLines: 1, overflow: TextOverflow.ellipsis),
                                      subtitle: Text(
                                        '${_fmtSize(node.size)} · ${formatShortDate(DateTime.fromMillisecondsSinceEpoch(node.modTimeMs))}',
                                        maxLines: 1),
                                      trailing: IconButton(
                                        tooltip: l.shareFileOut,
                                        icon: Icon(LucideIcons.share2,
                                            size: 18, color: theme.colorScheme.outline),
                                        onPressed: () => _share(node.file!),
                                      ),
                                      onTap: () => _open(context, node.file!),
                                      onLongPress: () => showRowActionsMenu(context, [
                                        RowAction(
                                          icon: LucideIcons.download,
                                          label: l.downloadFile,
                                          onRun: () => _download(node.file!),
                                        ),
                                        RowAction(
                                          icon: LucideIcons.trash2,
                                          label: l.chatDelete,
                                          destructive: true,
                                          onRun: () => _delete(node.file!),
                                        ),
                                      ]),
                                    ),
                                  ),
                            ],
                          );
                        }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folder row: chevron + folder icon + name; tap toggles. No swipe
/// delete — the backend delete endpoint is per-file.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.onToggle,
  });

  final WsFileNode node;
  final int depth;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.only(left: 16 + depth * 14.0, right: 16),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(
                expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.folder, size: 18, color: theme.colorScheme.outline),
              const SizedBox(width: 10),
              Expanded(
                child: Text(node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.onSurface)),
              ),
              Text('${node.children.length}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
