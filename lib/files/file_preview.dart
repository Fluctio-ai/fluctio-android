import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import '../pages/chat/chat_image.dart';
import '../pages/chat/image_viewer.dart';
import '../ui/load_states.dart';
import '../ui/path_line.dart';
import '../util/open_url.dart';
import '../util/app_toast.dart';
import 'media_proxy.dart';
import 'media_viewer.dart';
import 'code_viewer.dart';
import 'file_kind.dart';
import '../pages/kb/kb_text_view_page.dart';
import '../webview/web_container.dart';
import 'agent_files.dart';

// File-kind classification (extension sets, image/markdown/text tests,
// highlight modes) lives in file_kind.dart; re-exported so every preview
// surface can keep importing this file.
export 'file_kind.dart';

/// Authenticated gateway URL for one workspace file — the panel's inline
/// image preview needs the same URL the pushed previews build.
String workspaceFileGatewayUrl(String baseUrl, String agentId, String path) =>
    '$baseUrl${WebRoutes.agentFile(agentId, path)}';

/// The ONE text-family preview body behind both surfaces (docked panel
/// inline + full-screen push): markdown renders through the transcript
/// reader (KbTextView owns its skeleton/error chrome), every other text
/// file through the code viewer. Adding a text family reroutes HERE and
/// nowhere else — the two surfaces cannot diverge.
Widget textPreviewBody(
  BuildContext context,
  String name,
  Future<String> text, {
  String? pathLine,
}) =>
    isMarkdownFileName(name)
        ? KbTextView(future: text, pathLine: pathLine)
        : FutureBuilder<String>(
            future: text,
            builder: (context, snap) =>
                snap.connectionState != ConnectionState.done
                    ? const SkeletonProse()
                    : snap.hasError
                        ? ErrorPane(
                            message:
                                AppLocalizations.of(context)!.chatHistoryError)
                        : Column(
                            children: [
                              if (pathLine != null) PathLine(pathLine),
                              Expanded(
                                child: CodeViewer(
                                    content: snap.data ?? '', fileName: name),
                              ),
                            ],
                          ),
          );

/// Opens one workspace file for preview, routed by extension — the one
/// shared path behind the files sheet rows and chat-message file links.
/// [sessionId] is optional: the files sheet scopes to its chat, message
/// links preview agent-wide (the owner may read every file).
Future<void> openWorkspaceFilePreview(
  BuildContext context,
  WidgetRef ref, {
  required String agentId,
  required String path,
  String? sessionId,
  String? displayName,
}) async {
  final name = displayName ?? path.split('/').last;
  final ext = workspaceFileExt(name);
  const htmlExts = {'html', 'htm'};
  const videoExts = {'mp4', 'mov', 'm4v', 'mkv', 'webm'};
  const audioExts = {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'};
  final repo = ref.read(agentFilesRepoProvider);
  // Message links are relative to the AI's sandbox mount — which is the
  // DEEP scope prefix (projects/<pid>/<sid>/), not the project root —
  // so a shallow-rooted guess can miss. Probe the original path, then
  // prefix-swap candidates, and use the first that exists.
  path = await _resolveExisting(repo, agentId, path, sessionId);
  String gatewayUrl(String path) => workspaceFileGatewayUrl(
      ref.read(authControllerProvider).baseUrl, agentId, path);
  try {
    if (isImageFileName(name)) {
      final auth = ref.read(authControllerProvider);
      if (!context.mounted) return;
      openImageViewer(
        context,
        [chatImageProvider(gatewayUrl(path), baseUrl: auth.baseUrl, cookie: auth.sid)],
      );
      return;
    }
    if (videoExts.contains(ext) || audioExts.contains(ext)) {
      // Stream through the local proxy — players can't carry the
      // session cookie themselves; the proxy authenticates upstream
      // (Range passthrough, so seeking works without a full download).
      final auth = ref.read(authControllerProvider);
      MediaProxy.instance.configure(ref.read(apiClientProvider), auth.sid);
      final url = await MediaProxy.instance.urlFor(agentId, path);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          title: name,
          url: url,
          kind: videoExts.contains(ext) ? 'video' : 'audio',
        ),
      ));
      return;
    }
    if (htmlExts.contains(ext)) {
      // The WebView container renders html natively (cookie injected).
      // Probe first via dio — a 404 inside the WebView is undiagnosable
      // (raw backend JSON, no URL); the probe funnels failures into the
      // URL-showing snackbar below.
      await repo.fetchBytes(agentId, path, sessionId: sessionId);
      if (!context.mounted) return;
      openWebContainer(context, name, WebRoutes.agentFile(agentId, path));
      return;
    }
    if (ext == 'pdf') {
      // Native pdfium rendering (pdfrx) — WebView can't embed pdfs.
      final bytes = await repo.fetchBytes(agentId, path, sessionId: sessionId);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(name)),
          body: PdfViewer.data(Uint8List.fromList(bytes), sourceName: name),
        ),
      ));
      return;
    }
    if (isTextFileName(name)) {
      // The future flows straight into the body factory (KbTextView owns
      // the loading/error chrome for markdown; the code branch skeletons
      // inside the factory).
      final text = repo.fetchText(agentId, path, sessionId: sessionId);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (pageContext) => Scaffold(
          appBar: AppBar(title: Text(name)),
          body: textPreviewBody(pageContext, name, text, pathLine: path),
        ),
      ));
      return;
    }
    if (context.mounted) {
      AppToast.show(AppLocalizations.of(context)!.fileNoPreview);
    }
  } catch (e) {
    if (context.mounted) {
      // Show the resolved path + full URL (selectable) — link-resolution
      // bugs are only diagnosable when the actual request is visible.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: SelectableText(
          '$e\npath: $path\nurl: ${gatewayUrl(path)}',
        ),
      ));
    }
  }
}

/// Probes [path] and prefix-swapped candidates against the chat's scope
/// prefixes; returns the first that HEADs 200, else the original.
Future<String> _resolveExisting(
    AgentFilesRepo repo, String agentId, String path, String? sessionId) async {
  Future<bool> ok(String p) async {
    if (p.isEmpty) return false;
    try {
      await repo.head(agentId, p, sessionId: sessionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  if (await ok(path)) return path;
  try {
    final listing = await repo.list(agentId, sessionId: sessionId);
    final prefixes = listing.scopePrefixes;
    final deep = prefixes.isNotEmpty ? prefixes.first : '';
    final shallow = listing.workspaceRoot;
    final tail = shallow.isNotEmpty && path.startsWith(shallow)
        ? path.substring(shallow.length)
        : path;
    for (final cand in {deep + tail, shallow + tail, deep + path}) {
      if (cand != path && await ok(cand)) return cand;
    }
  } catch (_) {}
  return path;
}

/// Routes a tapped chat-message link: gateway file URLs preview
/// natively; workspace-relative links resolve against THIS chat's
/// workspace root (the shallowest scope prefix, web chat-screen
/// parity); everything else goes to the browser.
Future<void> openChatLink(BuildContext context, WidgetRef ref, String href) async {
  final auth = ref.read(authControllerProvider);
  var p = href;
  if (auth.baseUrl.isNotEmpty && p.startsWith(auth.baseUrl)) {
    p = p.substring(auth.baseUrl.length);
  }
  final gatewayFile = RegExp(r'^/api/agents/([^/]+)/files/(.+)$').firstMatch(p);
  if (gatewayFile != null) {
    final decoded = Uri.decodeComponent(gatewayFile[2]!);
    await openWorkspaceFilePreview(context, ref,
        agentId: gatewayFile[1]!, path: decoded, displayName: decoded.split('/').last);
    return;
  }
  if (href.contains('://')) {
    openExternalUrl(href);
    return;
  }
  // Workspace-relative: the /workspace/ breadcrumb (or a bare relative
  // href). Resolve against the chat's workspace root — project chats
  // root at projects/<pid>/, loose chats at sessions/<sid>/; the root
  // comes from the listing's scopePrefixes (last = shallowest).
  var rel = Uri.decodeComponent(href);
  for (final prefix in const ['/workspace/', 'workspace/']) {
    if (rel.startsWith(prefix)) {
      rel = rel.substring(prefix.length);
      break;
    }
  }
  final parts = splitSessionKey(ref.read(chatStoreProvider).activeKey);
  final agentId = parts?.agentId ?? ref.read(agentsProvider).selectedId;
  if (agentId == null || rel.isEmpty || !RegExp(r'\.[A-Za-z0-9]{1,6}$').hasMatch(rel)) {
    openExternalUrl(href);
    return;
  }
  try {
    final listing =
        await ref.read(agentFilesRepoProvider).list(agentId, sessionId: parts?.sessionId);
    var path = rel;
    // Already-rooted paths pass through; bare relatives join the root.
    if (!rel.startsWith('sessions/') && !rel.startsWith('projects/')) {
      path = listing.workspaceRoot + rel;
    }
    if (context.mounted) {
      await openWorkspaceFilePreview(context, ref,
          agentId: agentId, path: path, sessionId: parts?.sessionId,
          displayName: rel.split('/').last);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: SelectableText('link: $href\n$e'),
      ));
    }
  }
}
