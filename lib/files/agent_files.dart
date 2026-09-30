import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// One agent workspace file (GET /api/agents/{id}/files →
/// {"files":[{name,size,modTime}]}; handlers_agents.go).
class AgentFile {
  const AgentFile({required this.name, required this.size, required this.modTimeMs});

  final String name;
  final int size;
  final int modTimeMs;

  factory AgentFile.fromJson(Map<String, dynamic> j) => AgentFile(
        name: j['name'] as String? ?? '',
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

  Future<void> delete(String agentId, String name) =>
      _dio.delete('/api/agents/$agentId/files/${Uri.encodeComponent(name)}');
}
