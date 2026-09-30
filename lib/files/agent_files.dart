import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

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
  Future<List<AgentFile>> list(String agentId, {String? sessionId}) async {
    final res = await _dio.get('/api/agents/$agentId/files',
        queryParameters: _query(sessionId));
    final data = res.data is Map ? res.data as Map : const {};
    final raw = data['files'];
    final prefixes = (data['scopePrefixes'] is List ? data['scopePrefixes'] as List : const [])
        .whereType<String>()
        .toList();
    return [
      for (final f in raw is List ? raw : const [])
        if (f is Map) AgentFile._fromRow(f.cast<String, dynamic>(), prefixes),
    ];
  }

  Future<void> delete(String agentId, AgentFile f, {String? sessionId}) =>
      // Paths are server-sourced workspace paths — not encoded so the
      // {path...} wildcard route still sees directory separators.
      _dio.delete('/api/agents/$agentId/files/${f.path}',
          queryParameters: _query(sessionId));

  /// Plain-text fetch for previewing text files.
  Future<String> fetchText(String agentId, AgentFile f, {String? sessionId}) async =>
      (await _dio.get('/api/agents/$agentId/files/${f.path}',
              queryParameters: _query(sessionId),
              options: Options(responseType: ResponseType.plain)))
          .data as String;
}
