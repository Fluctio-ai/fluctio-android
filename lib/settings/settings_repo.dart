import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// Settings surface repo (ticket 08/09): agent admin subresources + the
/// system-level blob endpoints. Shapes that are free-form render through
/// the generic JSON form; list endpoints unwrap their known envelope key
/// (falling back to a bare list).
class SettingsRepo {
  SettingsRepo(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> agent(String id) async {
    final res = await _dio.get('/api/agents/$id');
    return res.data is Map
        ? Map<String, dynamic>.from((res.data as Map)['agent'] as Map? ?? {})
        : {};
  }

  Future<Map<String, dynamic>> agentConfig(String id) async =>
      parseObject((await _dio.get('/api/agents/$id/config')).data, (m) => m) ?? {};

  /// Field-level patch; only non-null keys are sent.
  Future<void> updateAgent(String id, Map<String, dynamic> patch) =>
      _dio.put('/api/agents/$id', data: patch);

  Future<List<String>> builtinModels() async {
    final data = (await _dio.get('/api/models/builtin')).data;
    if (data is List) return data.whereType<String>().toList();
    if (data is Map && data['models'] is List) {
      return (data['models'] as List).whereType<String>().toList();
    }
    return [];
  }

  // ---- scoped blobs (vectorization / privacy / recall-tuning / usage) ----

  Future<Map<String, dynamic>> scopedGet(String path) async =>
      parseObject((await _dio.get(path)).data, (m) => m) ?? {};

  Future<void> scopedPut(String path, Map<String, dynamic> blob) =>
      _dio.put(path, data: blob);

  /// User-level config blobs save via POST (e.g. /api/config).
  Future<void> postBlob(String path, Map<String, dynamic> blob) =>
      _dio.post(path, data: blob);

  // ---- skills ----

  Future<List<Map<String, dynamic>>> skills(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/skills')).data,
      key: 'skills',
      fromJson: (m) => m);

  Future<void> deleteSkill(String agentId, String name) =>
      _dio.delete('/api/agents/$agentId/skills/${Uri.encodeComponent(name)}');

  Future<void> reloadSkills(String agentId) =>
      _dio.post('/api/agents/$agentId/skills/reload');

  // ---- plugins overlay ----

  Future<List<Map<String, dynamic>>> pluginRegistry() async => parseRows(
      (await _dio.get('/api/plugins')).data,
      key: 'plugins',
      fromJson: (m) => m);

  // ---- providers (模型服务) ----

  Future<List<Map<String, dynamic>>> providers() async => parseRows(
      (await _dio.get('/api/providers')).data,
      key: 'providers',
      fromJson: (m) => m);

  Future<void> saveProvider({String? id, required Map<String, dynamic> body}) => id == null
      ? _dio.post('/api/providers',
          data: {'scope': '', 'scopeId': '', ...body})
      : _dio.put('/api/providers/$id', data: body);

  // ---- scheduler (per-agent cron) ----

  Future<List<Map<String, dynamic>>> cronJobs(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/cron')).data,
      key: 'jobs',
      fromJson: (m) => m);

  Future<void> toggleCron(String agentId, String jobId) =>
      _dio.put('/api/agents/$agentId/cron/$jobId');

  Future<void> deleteCron(String agentId, String jobId) =>
      _dio.delete('/api/agents/$agentId/cron/$jobId');

  // ---- regex hooks ----

  Future<List<Map<String, dynamic>>> regexHooks(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/regex-hooks')).data,
      key: 'hooks',
      fromJson: (m) => m);

  Future<void> deleteRegexHook(String agentId, String hookId) =>
      _dio.delete('/api/agents/$agentId/regex-hooks/$hookId');

  // ---- channels (read-only binding list) ----

  Future<List<Map<String, dynamic>>> channels(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/channels')).data,
      key: 'channels',
      fromJson: (m) => m);
}

final settingsRepoProvider =
    Provider<SettingsRepo>((ref) => SettingsRepo(ref.watch(apiClientProvider)));
