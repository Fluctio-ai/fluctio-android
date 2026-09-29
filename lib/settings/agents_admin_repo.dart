import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// Agent-admin repo (ticket 08, docs/api/API.md §6/§9): the agent scope
/// view + full config blob, field-level PUT patch, and the per-agent
/// subresources the settings tabs drive. Unknown/loose shapes parse
/// defensively — several payloads are free-form blobs rendered by the
/// generic JSON form.
class AgentsAdminRepo {
  AgentsAdminRepo(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> agent(String id) async {
    final res = await _dio.get('/api/agents/$id');
    return res.data is Map ? Map<String, dynamic>.from((res.data as Map)['agent'] as Map? ?? {}) : {};
  }

  Future<Map<String, dynamic>> agentConfig(String id) async {
    final res = await _dio.get('/api/agents/$id/config');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
  }

  /// Field-level patch; only non-null keys are sent.
  Future<void> updateAgent(String id, Map<String, dynamic> patch) =>
      _dio.put('/api/agents/$id', data: patch);

  Future<List<String>> builtinModels() async {
    final res = await _dio.get('/api/models/builtin');
    final data = res.data;
    if (data is List) return data.whereType<String>().toList();
    if (data is Map && data['models'] is List) {
      return (data['models'] as List).whereType<String>().toList();
    }
    return [];
  }

  // ---- scoped blobs (vectorization / privacy / recall-tuning) ----

  Future<Map<String, dynamic>> scopedGet(String path) async {
    final res = await _dio.get(path);
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {};
  }

  Future<void> scopedPut(String path, Map<String, dynamic> blob) =>
      _dio.put(path, data: blob);

  // ---- skills ----

  Future<List<Map<String, dynamic>>> skills(String agentId) async =>
      _mapRows(await _dio.get('/api/agents/$agentId/skills'));

  Future<void> deleteSkill(String agentId, String name) =>
      _dio.delete('/api/agents/$agentId/skills/${Uri.encodeComponent(name)}');

  Future<void> reloadSkills(String agentId) =>
      _dio.post('/api/agents/$agentId/skills/reload');

  // ---- plugins overlay ----

  Future<List<Map<String, dynamic>>> pluginRegistry() async =>
      _mapRows(await _dio.get('/api/plugins'));

  // ---- scheduler (per-agent cron) ----

  Future<List<Map<String, dynamic>>> cronJobs(String agentId) async =>
      _mapRows(await _dio.get('/api/agents/$agentId/cron'));

  Future<void> toggleCron(String agentId, String jobId) =>
      _dio.put('/api/agents/$agentId/cron/$jobId');

  Future<void> deleteCron(String agentId, String jobId) =>
      _dio.delete('/api/agents/$agentId/cron/$jobId');

  // ---- regex hooks ----

  Future<List<Map<String, dynamic>>> regexHooks(String agentId) async =>
      _mapRows(await _dio.get('/api/agents/$agentId/regex-hooks'));

  Future<void> deleteRegexHook(String agentId, String hookId) =>
      _dio.delete('/api/agents/$agentId/regex-hooks/$hookId');

  // ---- channels (read-only binding list) ----

  Future<List<Map<String, dynamic>>> channels(String agentId) async =>
      _mapRows(await _dio.get('/api/agents/$agentId/channels'));
}

List<Map<String, dynamic>> _mapRows(Response res) {
  final data = res.data;
  List? rows;
  if (data is List) {
    rows = data;
  } else if (data is Map) {
    // {"jobs": [...]} / {"hooks": [...]} / {"skills": [...]} wrappers.
    for (final key in ['jobs', 'hooks', 'skills', 'plugins', 'channels', 'items', 'list']) {
      if (data[key] is List) {
        rows = data[key] as List;
        break;
      }
    }
  }
  if (rows == null) return [];
  return [for (final r in rows) if (r is Map) Map<String, dynamic>.from(r)];
}

final agentsAdminRepoProvider =
    Provider<AgentsAdminRepo>((ref) => AgentsAdminRepo(ref.watch(apiClientProvider)));
