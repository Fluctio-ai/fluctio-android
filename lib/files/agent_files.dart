import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// Agent identity files live at the workspace ROOT (no "/") and are never
/// turn output — web SYSTEM_FILES parity (chat-screen.tsx:228). Shared by
/// the files listing filter and the produced-file extractor.
const systemWorkspaceFileNames = {
  'SOUL.md', 'IDENTITY.md', 'USER.md', 'BOOTSTRAP.md',
  'MEMORY.md', 'HEARTBEAT.md', 'AGENTS.md', 'TOOLS.md', 'agent.json',
};

bool isSystemWorkspaceFile(String path) =>
    !path.contains('/') && systemWorkspaceFileNames.contains(path);

/// Segment-by-segment encoding for workspace paths handed to URL
/// consumers (WebView / NetworkImage need legal URIs; "/" separators
/// survive).
String encodeWorkspacePath(String p) =>
    [for (final s in p.split('/')) Uri.encodeComponent(s)].join('/');

/// One agent workspace file (GET /api/agents/{id}/files →
/// {"files":[{path,size,modTime}], "scopePrefixes":[...]};
/// handlers_agents.go — the key is "path", scopePrefixes are peeled off
/// for the display name).
class AgentFile {
  const AgentFile({required this.path, required this.name, required this.size, required this.modTimeMs});

  /// Full workspace path — the API key for GET/DELETE.
  final String path;

  /// Display name (scope prefixes peeled).
  final String name;

  final int size;
  final int modTimeMs;

  AgentFile._fromRow(Map<String, dynamic> j, List<String> scopePrefixes)
      : path = j['path'] as String? ?? '',
        name = _displayName(j['path'] as String? ?? '', scopePrefixes),
        size = (j['size'] as num?)?.toInt() ?? 0,
        modTimeMs = (j['modTime'] as num?)?.toInt() ?? 0;

  static String _displayName(String path, List<String> prefixes) {
    for (final p in prefixes) {
      if (p.isNotEmpty && path.startsWith(p)) return path.substring(p.length);
    }
    return path;
  }

  @visibleForTesting
  factory AgentFile.forTest(String path, List<String> scopePrefixes,
      {int size = 0, int modTimeMs = 0}) {
    return AgentFile._fromRow({'path': path, 'size': size, 'modTime': modTimeMs}, scopePrefixes);
  }
}

/// Listing result: files plus the backend-resolved scope prefixes for
/// this chat (loose: ["sessions/<sid>/"], project:
/// ["projects/<pid>/<sid>/", "projects/<pid>/"]). The SHALLOWEST prefix
/// (last entry) is the workspace root /workspace/ links resolve against
/// (web chat-screen parity).
class AgentFileListing {
  // Non-const: the lazy pathSet cache below can't live on a const class.
  AgentFileListing(this.files, this.scopePrefixes);

  final List<AgentFile> files;
  final List<String> scopePrefixes;

  /// Full paths as a set — the exists-oracle for produced-file
  /// resolution. Computed once per listing instance (the provider shares
  /// it across the panel, sheet, and every tool card) instead of per
  /// consumer per build.
  late final Set<String> pathSet = {for (final f in files) f.path};

  String get workspaceRoot =>
      scopePrefixes.isNotEmpty ? scopePrefixes.last : '';
}

/// One node of the workspace file tree — a synthesized folder or a file
/// leaf. Mirrors the web FileTreeNode (chat-screen.tsx:4177).
class WsFileNode {
  WsFileNode.dir(this.name, this.relPath)
      : file = null,
        size = 0,
        modTimeMs = 0;

  WsFileNode.leaf(AgentFile this.file, this.relPath)
      : name = relPath.split('/').last,
        size = file.size,
        modTimeMs = file.modTimeMs;
  final String name;

  /// Folder: path relative to the scope root (stable expansion key);
  /// leaf: the file's already-stripped relative path.
  final String relPath;

  /// Non-null = file leaf (carries the full workspace path for
  /// preview/delete); null = synthesized directory.
  final AgentFile? file;
  final int size;
  final int modTimeMs;
  final List<WsFileNode> children = [];

  bool get isDir => file == null;
}

/// Flatten the listing into a nested tree. [AgentFile.name] already
/// carries the prefix-stripped relative path, so its `/` segments are
/// the folder levels (web buildFileTree, chat-screen.tsx:4193); leaves
/// keep their full path for preview/delete. Folders sort before files,
/// then by name.
List<WsFileNode> buildWsFileTree(List<AgentFile> files) {
  final root = WsFileNode.dir('', '');
  for (final f in files) {
    final parts = f.name.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) continue;
    var node = root;
    for (var i = 0; i < parts.length; i++) {
      final isLeaf = i == parts.length - 1;
      final name = parts[i];
      final relPath = parts.sublist(0, i + 1).join('/');
      WsFileNode? child;
      if (isLeaf) {
        for (final c in node.children) {
          if (!c.isDir && c.name == name) child = c;
        }
      } else {
        for (final c in node.children) {
          if (c.isDir && c.name == name) child = c;
        }
      }
      child ??= () {
        final n = isLeaf ? WsFileNode.leaf(f, relPath) : WsFileNode.dir(name, relPath);
        node.children.add(n);
        return n;
      }();
      node = child;
    }
  }
  _sortWsNodes(root.children);
  return root.children;
}

void _sortWsNodes(List<WsFileNode> nodes) {
  nodes.sort((a, b) {
    if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  for (final n in nodes) {
    if (n.isDir) _sortWsNodes(n.children);
  }
}

final agentFilesRepoProvider =
    Provider<AgentFilesRepo>((ref) => AgentFilesRepo(ref.watch(apiClientProvider)));

class AgentFilesRepo {
  AgentFilesRepo(this._dio);

  final Dio _dio;

  Map<String, dynamic> _query(String? sessionId) =>
      {if (sessionId != null && sessionId.isNotEmpty) 'sessionId': sessionId};

  /// [sessionId] scopes the listing to that chat's workspace subtree —
  /// without it the owner sees every file under the agent.
  Future<AgentFileListing> list(String agentId, {String? sessionId}) async {
    final res = await _dio.get('/api/agents/$agentId/files',
        queryParameters: _query(sessionId));
    final data = res.data is Map ? res.data as Map : const {};
    final raw = data['files'];
    final prefixes = (data['scopePrefixes'] is List ? data['scopePrefixes'] as List : const [])
        .whereType<String>()
        .toList();
    return AgentFileListing(
      [
        for (final f in raw is List ? raw : const [])
          if (f is Map) AgentFile._fromRow(f.cast<String, dynamic>(), prefixes),
      ],
      prefixes,
    );
  }

  Future<void> delete(String agentId, AgentFile f, {String? sessionId}) =>
      // Paths are server-sourced workspace paths — not encoded so the
      // {path...} wildcard route still sees directory separators.
      _dio.delete('/api/agents/$agentId/files/${f.path}',
          queryParameters: _query(sessionId));

  /// Existence probe (HEAD) for path-candidate resolution.
  Future<void> head(String agentId, String path, {String? sessionId}) =>
      _dio.head('/api/agents/$agentId/files/$path', queryParameters: _query(sessionId));

  /// Plain-text fetch for previewing text files.
  Future<String> fetchText(String agentId, String path, {String? sessionId}) async =>
      (await _dio.get('/api/agents/$agentId/files/$path',
              queryParameters: _query(sessionId),
              options: Options(responseType: ResponseType.plain)))
          .data as String;

  /// Binary fetch for previewing pdf files.
  Future<List<int>> fetchBytes(String agentId, String path, {String? sessionId}) async =>
      (await _dio.get('/api/agents/$agentId/files/$path',
              queryParameters: _query(sessionId),
              options: Options(responseType: ResponseType.bytes)))
          .data as List<int>;

  /// Streams a file straight to disk (share-out) — big media shouldn't
  /// round-trip through memory.
  Future<void> downloadTo(String agentId, String path, String savePath,
          {String? sessionId}) =>
      _dio.download('/api/agents/$agentId/files/$path', savePath,
          queryParameters: _query(sessionId));
}
