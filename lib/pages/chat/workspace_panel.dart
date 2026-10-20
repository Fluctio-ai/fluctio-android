import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../auth/auth_controller.dart';
import '../../files/agent_files.dart';
import '../../files/file_preview.dart';
import '../../files/workspace_files.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/breakpoints.dart';
import '../kb/kb_text_view_page.dart';
import 'chat_image.dart';

/// Docked workspace panel state (tablet split layout only — nothing reads
/// this on the phone). [open] defaults true per the product call: the
/// files panel is part of the landscape chat surface, not a hidden extra.
/// [previewPath] is the file previewing inline (null = the tree shows) —
/// tree-row taps and inline transcript cards both drive it through the
/// controller, so no widget-local state can disagree with the provider.
class WorkspacePanelState {
  const WorkspacePanelState({this.open = true, this.previewPath});

  final bool open;

  /// Full workspace path of the inline-previewed file; null = tree mode.
  final String? previewPath;
}

class WorkspacePanelController extends Notifier<WorkspacePanelState> {
  @override
  WorkspacePanelState build() => const WorkspacePanelState();

  void toggle() => setOpen(!state.open);

  void setOpen(bool open) =>
      state = WorkspacePanelState(open: open, previewPath: state.previewPath);

  /// Preview a file inline: reveal the panel (if collapsed) and show it.
  /// Inline transcript cards and the smart opener both land here.
  void openFile(String path) =>
      state = WorkspacePanelState(open: true, previewPath: path);

  /// Preview header's back: return to the tree, panel stays open.
  void closePreview() => state = WorkspacePanelState(open: state.open);
}

final workspacePanelProvider =
    NotifierProvider<WorkspacePanelController, WorkspacePanelState>(
        WorkspacePanelController.new);

/// The ONE file-open routing policy for the chat surface: tablet split
/// with an inline-capable file → reveal the docked panel and preview
/// inside it; anything else → the full-screen push previewer. Transcript
/// file cards and the panel's own tree rows both go through here.
void openWorkspaceFileSmart(
  BuildContext context,
  WidgetRef ref, {
  required String agentId,
  required String path,
  String? sessionId,
  String? displayName,
}) {
  final name = displayName ?? path.split('/').last;
  if (isChatSplit(context) && canInlinePreview(name)) {
    ref.read(workspacePanelProvider.notifier).openFile(path);
    return;
  }
  openWorkspaceFilePreview(context, ref,
      agentId: agentId, path: path, sessionId: sessionId, displayName: name);
}

/// The docked right-hand workspace panel of the tablet landscape chat
/// (web WorkspacePanel parity): file tree by default, inline preview on
/// selection (image / text-markdown / pdf render in place; other types
/// fall back to the full-screen push preview).
class WorkspacePanel extends ConsumerWidget {
  const WorkspacePanel({
    super.key,
    required this.agentId,
    required this.sessionId,
  });

  final String agentId;

  /// Empty while no session is open yet (fresh-chat gap) — the provider
  /// returns an empty listing and the view shows its empty state.
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final previewPath =
        ref.watch(workspacePanelProvider.select((s) => s.previewPath));

    return Container(
      // No left border — the chat page's drag handle IS the separator.
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 12),
                if (previewPath != null) ...[
                  IconButton(
                    tooltip: l.cardBack,
                    icon: const Icon(LucideIcons.arrowLeft, size: 18),
                    onPressed: () =>
                        ref.read(workspacePanelProvider.notifier).closePreview(),
                  ),
                  Expanded(
                    child: Text(previewPath.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                  ),
                ] else ...[
                  Icon(LucideIcons.folderOpen,
                      size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.chatWorkspace,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall),
                  ),
                  if (sessionId.isNotEmpty)
                    IconButton(
                      tooltip: l.chatRefresh,
                      icon: const Icon(LucideIcons.refreshCw, size: 16),
                      onPressed: () =>
                          refreshWorkspaceFiles(ref, agentId, sessionId),
                    ),
                ],
                IconButton(
                  tooltip: l.chatFiles,
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () =>
                      ref.read(workspacePanelProvider.notifier).setOpen(false),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: previewPath != null
                ? _InlineFilePreview(
                    key: ValueKey(previewPath),
                    agentId: agentId,
                    sessionId: sessionId,
                    path: previewPath,
                  )
                : WorkspaceFilesView(
                    agentId: agentId,
                    sessionId: sessionId,
                    // The shared smart opener: inline-capable files preview
                    // in place (the panel is up, so split holds); html /
                    // media / unknown fall through to the push previews.
                    onOpen: (f) => openWorkspaceFileSmart(context, ref,
                        agentId: agentId,
                        path: f.path,
                        sessionId: sessionId,
                        displayName: f.name),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Inline preview for the panel: image via the authenticated gateway,
/// text/markdown via [KbTextView], pdf via pdfrx. Fetches start once in
/// initState (keyed by path from the parent) so rebuilds don't refetch.
/// [canInlinePreview] gates what reaches here.
class _InlineFilePreview extends ConsumerStatefulWidget {
  const _InlineFilePreview({
    super.key,
    required this.agentId,
    required this.sessionId,
    required this.path,
  });

  final String agentId;
  final String sessionId;

  /// Full workspace path of the previewed file.
  final String path;

  @override
  ConsumerState<_InlineFilePreview> createState() => _InlineFilePreviewState();
}

class _InlineFilePreviewState extends ConsumerState<_InlineFilePreview> {
  Future<String>? _textFuture;
  Future<Uint8List>? _bytesFuture;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(agentFilesRepoProvider);
    final ext = workspaceFileExt(widget.path);
    if (ext == 'pdf') {
      // Convert once here — Uint8List.fromList in build would re-copy the
      // whole pdf on every parent rebuild (streaming deltas, panel drag).
      _bytesFuture = repo
          .fetchBytes(widget.agentId, widget.path, sessionId: widget.sessionId)
          .then(Uint8List.fromList);
    } else if (!isImageFileName(widget.path)) {
      // Not an image, not a pdf → text family (canInlinePreview gated).
      _textFuture = repo.fetchText(widget.agentId, widget.path,
          sessionId: widget.sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    if (_textFuture != null) {
      return KbTextView(future: _textFuture, pathLine: widget.path);
    }
    final bytesFuture = _bytesFuture;
    if (bytesFuture != null) {
      return FutureBuilder<Uint8List>(
        future: bytesFuture,
        builder: (context, snap) => snap.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : snap.hasError
                ? Center(
                    child: Text(l.chatHistoryError,
                        style: TextStyle(color: theme.colorScheme.error)))
                : PdfViewer.data(snap.data ?? Uint8List(0),
                    sourceName: widget.path),
      );
    }
    // Image — authenticated through the session cookie like the chat
    // transcript's images.
    final auth = ref.watch(authControllerProvider);
    final url = workspaceFileGatewayUrl(auth.baseUrl, widget.agentId, widget.path);
    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: Image(
          image: chatImageProvider(url, baseUrl: auth.baseUrl, cookie: auth.sid),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              Icon(LucideIcons.imageOff, size: 40, color: theme.colorScheme.outline),
        ),
      ),
    );
  }
}
