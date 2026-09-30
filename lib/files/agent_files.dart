import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// One agent workspace file (GET /api/agents/{id}/files →
/// {"files":[{path,size,modTime}]}; handlers_agents.go — the key is
/// "path"; the basename is derived for display).
class AgentFile {
  const AgentFile({required this.path, required this.size, required this.modTimeMs});

  /// Full workspace path — the API key for GET/DELETE.
  final String path;

  /// Display basename (last path segment).
  String get name => path.split('/').last;

  final int size;
  final int modTimeMs;

  factory AgentFile.fromJson(Map<String, dynamic> j) => AgentFile(
        path: j['path'] as String? ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
        modTimeMs: (j['modTime'] as num?)?.toInt() ?? 0,
      );
}

final agentFilesRepoProvider =
    Provider<AgentFilesRepo>((ref) => AgentFilesRepo(ref.watch(apiClientProvider)));

class AgentFilesRepo {
  AgentFilesRepo(this._dio);

  final Dio _dio;

  Future<List<AgentFile>> list(String agentId) async {
    final res = await _dio.get('/api/agents/$agentId/files');
    final raw = res.data is Map ? res.data['files'] : null;
    final list = raw is List ? raw : const [];
    return [
      for (final f in list)
        if (f is Map) AgentFile.fromJson(f.cast<String, dynamic>()),
    ];
  }

  Future<void> delete(String agentId, AgentFile f) =>
      // Paths are server-sourced workspace paths — not encoded so the
      // {path...} wildcard route still sees directory separators.
      _dio.delete('/api/agents/$agentId/files/${f.path}');

  /// Plain-text fetch for previewing text files.
  Future<String> fetchText(String agentId, AgentFile f) async =>
      (await _dio.get('/api/agents/$agentId/files/${f.path}',
              options: Options(responseType: ResponseType.plain)))
          .data as String;
}
