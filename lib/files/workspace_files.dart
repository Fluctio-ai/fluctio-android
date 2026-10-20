import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../share/share_out.dart';
import '../ui/dialogs.dart';
import '../ui/load_states.dart';
import '../ui/row_actions_menu.dart';
import '../util/dates.dart';
import 'agent_files.dart';

/// Session-scoped workspace listing — the ONE data source behind both
/// files surfaces (phone bottom sheet / tablet docked panel) and the
/// exists-oracle for produced-file cards. Root-level agent identity files
/// (SOUL.md …) are filtered — web WorkspacePanel parity.
///
/// An empty sessionId yields an EMPTY listing, never the agent-wide tree
/// (the API treats a missing sessionId as no scope) — hosts then simply
/// render the empty state instead of each guarding separately.
final workspaceFilesProvider =
    FutureProvider.family<AgentFileListing, (String, String)>((ref, key) async {
  if (key.$2.isEmpty) return AgentFileListing(const [], const []);
  final listing = await ref.watch(agentFilesRepoProvider).list(key.$1, sessionId: key.$2);
  return AgentFileListing(
    [for (final f in listing.files) if (!isSystemWorkspaceFile(f.path)) f],
    listing.scopePrefixes,
  );
});

/// Panel refresh button and post-delete reload (the turn-end hook
/// inlines its own invalidate — it holds a Ref, this helper takes the
/// widget side).
void refreshWorkspaceFiles(WidgetRef ref, String agentId, String sessionId) =>
    ref.invalidate(workspaceFilesProvider((agentId, sessionId)));

/// Compact byte count for file rows / produced-file cards.
String formatWorkspaceSize(int bytes) => bytes < 1024
    ? '${bytes}B'
    : bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(1)}KB'
        : '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';

/// Shared workspace file tree: expansion state, folder/file rows, and the
/// per-file actions (open via [onOpen], delete, share-out, download) with
/// the in-surface notice strip. Used by the phone bottom sheet and the
/// tablet docked panel — behavior stays identical across both.
class WorkspaceFilesView extends ConsumerStatefulWidget {
  const WorkspaceFilesView({
    super.key,
    required this.agentId,
    required this.sessionId,
    required this.onOpen,
  });

  final String agentId;
  final String sessionId;

  /// File-row tap. The sheet pushes the full-screen preview; the docked
  /// panel previews inline.
  final ValueChanged<AgentFile> onOpen;

  @override
  ConsumerState<WorkspaceFilesView> createState() => _WorkspaceFilesViewState();
}

class _WorkspaceFilesViewState extends ConsumerState<WorkspaceFilesView> {
  /// Expanded folder keys (relative paths — stable across refreshes, web
  /// FileTreeView parity). Seeded once when the tree first lands: root
  /// folders open, deeper levels collapsed.
  final Set<String> _expanded = {};
  bool _expandedSeeded = false;

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
      await ref
          .read(agentFilesRepoProvider)
          .delete(widget.agentId, f, sessionId: widget.sessionId);
      if (mounted) refreshWorkspaceFiles(ref, widget.agentId, widget.sessionId);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  /// In-surface feedback line — snackbars from inside a modal sheet route
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
  /// through memory. [AgentFile.path] is server-sourced from the listing,
  /// so it downloads as-is (same as delete).
  Future<File> _stage(AgentFile f) async {
    final repo = ref.read(agentFilesRepoProvider);
    final safeName = f.name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    await dir.create(recursive: true);
    final target = File('${dir.path}/$safeName');
    await repo.downloadTo(widget.agentId, f.path, target.path, sessionId: widget.sessionId);
    return target;
  }

  /// Share-out: stage the file, then hand it to the system share sheet.
  /// A gateway link would be useless outside the app (cookie auth), so
  /// receivers always get the bytes.
  Future<void> _share(AgentFile f) async {
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
  /// if the user leaves), busy/errors stay on the in-surface strip.
  Future<void> _download(AgentFile f) async {
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final listing = ref.watch(workspaceFilesProvider((widget.agentId, widget.sessionId)));
    return Column(
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
                      : Icon(LucideIcons.check, size: 14, color: theme.colorScheme.primary),
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
          child: listing.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SkeletonList(itemCount: 5),
            ),
            error: (_, _) => ErrorPane(message: l.chatHistoryError),
            data: (data) {
              if (data.files.isEmpty) {
                return EmptyState(icon: LucideIcons.folderOpen, message: l.kbEmpty);
              }
              final tree = buildWsFileTree(data.files);
              _seedExpansion(tree);
              final rows = _flatten(tree, 0);
              // builder, not children: this view is now permanently
              // mounted in the docked panel, so rows must stay lazy.
              return ListView.builder(
                shrinkWrap: true,
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final (node, depth) = rows[i];
                  if (node.isDir) {
                    return WorkspaceFolderRow(
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
                    );
                  }
                  return Slidable(
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
                        '${formatWorkspaceSize(node.size)} · ${formatShortDate(DateTime.fromMillisecondsSinceEpoch(node.modTimeMs))}',
                        maxLines: 1),
                      trailing: IconButton(
                        tooltip: l.shareFileOut,
                        icon: Icon(LucideIcons.share2,
                            size: 18, color: theme.colorScheme.outline),
                        onPressed: () => _share(node.file!),
                      ),
                      onTap: () => widget.onOpen(node.file!),
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Folder row: chevron + folder icon + name; tap toggles. No swipe
/// delete — the backend delete endpoint is per-file.
class WorkspaceFolderRow extends StatelessWidget {
  const WorkspaceFolderRow({
    super.key,
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
