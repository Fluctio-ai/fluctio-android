import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../auth/auth_controller.dart';
import '../chat/chat_controller.dart';
import '../pages/chat/chat_image.dart';
import '../pages/chat/image_viewer.dart';
import '../l10n/app_localizations.dart';
import '../util/open_url.dart';
import 'media_viewer.dart';
import '../pages/kb/kb_text_view_page.dart';
import '../webview/web_container.dart';
import 'agent_files.dart';

/// Re-encodes a decoded path segment-by-segment (keeping "/" separators)
/// for URLs handed to WebView/NetworkImage, which need legal URIs.
String _encodePath(String p) =>
    [for (final s in p.split('/')) Uri.encodeComponent(s)].join('/');

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
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  const imgExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'svg'};
  const htmlExts = {'html', 'htm'};
  const videoExts = {'mp4', 'mov', 'm4v', 'mkv', 'webm'};
  const audioExts = {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'};
  const textExts = {
    'txt', 'md', 'markdown', 'json', 'csv', 'log', 'yaml', 'yml', 'xml',
    'dart', 'py', 'js', 'ts', 'go', 'rs', 'java', 'kt',
    'c', 'cpp', 'h', 'sh', 'toml', 'ini', 'conf', 'sql',
  };
  final repo = ref.read(agentFilesRepoProvider);
  final file = AgentFile(path: path, name: name, size: 0, modTimeMs: 0);
  try {
    if (imgExts.contains(ext)) {
      final auth = ref.read(authControllerProvider);
      openImageViewer(
        context,
        chatImageProvider('${auth.baseUrl}/api/agents/$agentId/files/${_encodePath(path)}',
            baseUrl: auth.baseUrl, cookie: auth.sid),
      );
      return;
    }
    if (videoExts.contains(ext) || audioExts.contains(ext)) {
      // Native players (video_player / just_audio) — media needs real
      // streaming, not a WebView; the cookie rides the request headers.
      final auth = ref.read(authControllerProvider);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          title: name,
          url: '${auth.baseUrl}/api/agents/$agentId/files/${_encodePath(path)}',
          kind: videoExts.contains(ext) ? 'video' : 'audio',
          cookie: auth.sid,
        ),
      ));
      return;
    }
    if (htmlExts.contains(ext)) {
      // The WebView container renders html natively (cookie injected) —
      // running it through the markdown viewer mangles the tags.
      openWebContainer(context, name, '/api/agents/$agentId/files/${_encodePath(path)}');
      return;
    }
    if (ext == 'pdf') {
      // Native pdfium rendering (pdfrx) — WebView can't embed pdfs.
      final bytes = await repo.fetchBytes(agentId, file, sessionId: sessionId);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(name)),
          body: PdfViewer.data(Uint8List.fromList(bytes), sourceName: name),
        ),
      ));
      return;
    }
    if (textExts.contains(ext)) {
      final text = await repo.fetchText(agentId, file, sessionId: sessionId);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => KbTextViewPage(
          title: name,
          loadContent: () async => text,
          pathLine: path,
        ),
      ));
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.fileNoPreview)));
    }
  } catch (e) {
    if (context.mounted) {
      // Show the resolved path + full URL (selectable) — link-resolution
      // bugs are only diagnosable when the actual request is visible.
      final auth = ref.read(authControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: SelectableText(
          '$e\npath: $path\nurl: ${auth.baseUrl}/api/agents/$agentId/files/${_encodePath(path)}',
        ),
      ));
    }
  }
}

/// Routes a tapped chat-message link: gateway file URLs and bare
/// workspace-looking paths preview natively; everything else goes to the
/// browser as before.
void openChatLink(BuildContext context, WidgetRef ref, String href) {
  final auth = ref.read(authControllerProvider);
  var p = href;
  if (auth.baseUrl.isNotEmpty && p.startsWith(auth.baseUrl)) {
    p = p.substring(auth.baseUrl.length);
  }
  final gatewayFile = RegExp(r'^/api/agents/([^/]+)/files/(.+)$').firstMatch(p);
  if (gatewayFile != null) {
    // href arrives percent-encoded (CJK filenames); the files API keys
    // objects by the decoded path — decode once, re-encode per use.
    final decoded = Uri.decodeComponent(gatewayFile[2]!);
    openWorkspaceFilePreview(context, ref,
        agentId: gatewayFile[1]!, path: decoded, displayName: decoded.split('/').last);
    return;
  }
  // Bare workspace path (no scheme, has a file extension) — try the
  // selected agent's workspace before punting to the browser. Message
  // breadcrumbs carry the absolute form "/workspace/X" (annotateMessage
  // WithAttachments), while the files API wants the bare "X" — decode,
  // then strip the prefix.
  var bare = Uri.decodeComponent(href);
  for (final prefix in const ['/workspace/', 'workspace/']) {
    if (bare.startsWith(prefix)) {
      bare = bare.substring(prefix.length);
      break;
    }
  }
  final agentId = ref.read(agentsProvider).selectedId;
  // Ends in a file extension — CJK names included (the char class above
  // the fix only matched ASCII and silently dropped Chinese names to the
  // browser branch).
  if (agentId != null &&
      !href.contains('://') &&
      RegExp(r'\.[A-Za-z0-9]{1,6}$').hasMatch(bare)) {
    openWorkspaceFilePreview(context, ref, agentId: agentId, path: bare);
    return;
  }
  openExternalUrl(href);
}
