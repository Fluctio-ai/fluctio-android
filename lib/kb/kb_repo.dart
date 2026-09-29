import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../chat/chat_controller.dart';
import 'kb_models.dart';

/// Selected agent convenience — KB data is per-agent, so every provider
/// keys off this.
String kbAgentId(Ref ref) => ref.watch(agentsProvider.select((a) => a.selectedId ?? ''));

final kbSourcesProvider = FutureProvider.autoDispose
    .family<List<KbSource>, String>((ref, agentId) async {
  final repo = KbRepo(ref.watch(apiClientProvider));
  return repo.sources(agentId);
});

final kbTodosProvider =
    FutureProvider.autoDispose.family<List<KbSource>, String>((ref, agentId) async {
  final repo = KbRepo(ref.watch(apiClientProvider));
  return repo.todos(agentId);
});

final kbBookmarksProvider =
    FutureProvider.autoDispose.family<List<KbBookmark>, String>((ref, agentId) async {
  final repo = KbRepo(ref.watch(apiClientProvider));
  return repo.bookmarks(agentId);
});

/// Typed wrappers over the KB surface (docs/api/API.md §7). Save paths
/// return a duplicate marker when the server deduped the write.
class KbRepo {
  KbRepo(this._dio);
  final Dio _dio;

  Future<List<KbSource>> sources(String agentId) async =>
      _rows(await _dio.get('/api/agents/$agentId/kb/sources'), KbSource.fromJson);

  Future<List<KbSource>> todos(String agentId, {String status = ''}) async => _rows(
      await _dio.get('/api/agents/$agentId/kb/todos',
          queryParameters: {if (status.isNotEmpty) 'status': status}),
      KbSource.fromJson);

  Future<List<KbEntry>> entries(String agentId, String sourceId) async => _rows(
      await _dio.get('/api/agents/$agentId/kb/sources/$sourceId/entries'),
      KbEntry.fromJson);

  Future<List<KbSearchResult>> search(String agentId, String query, {int limit = 12}) async {
    final res = await _dio.post('/api/agents/$agentId/kb/search',
        data: {'query': query, 'limit': limit});
    return _rows(res, KbSearchResult.fromJson);
  }

  Future<void> deleteSource(String agentId, String sourceId) =>
      _dio.delete('/api/agents/$agentId/kb/sources/$sourceId');

  // ---- flash ----

  /// 200 with `deduped` means the server skipped the write as a
  /// duplicate of an existing flash.
  Future<bool> saveFlash(String agentId, String content) async {
    final res = await _dio.post('/api/agents/$agentId/kb/flash', data: {'content': content});
    return res.data is Map && res.data['deduped'] == true;
  }

  Future<void> updateFlash(String agentId, String sourceId, String content) =>
      _dio.patch('/api/agents/$agentId/kb/flash/$sourceId', data: {'content': content});

  // ---- todo ----

  Future<bool> saveTodo(
    String agentId,
    String content, {
    String status = 'pending',
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final res = await _dio.post('/api/agents/$agentId/kb/todo', data: {
      'content': content,
      'status': status,
      if (startAt != null) 'start_at': startAt.toIso8601String(),
      if (endAt != null) 'end_at': endAt.toIso8601String(),
    });
    return res.data is Map && res.data['deduped'] == true;
  }

  Future<void> updateTodo(
    String agentId,
    String sourceId, {
    String? content,
    String? status,
    DateTime? startAt,
    DateTime? endAt,
    bool clearDates = false,
  }) =>
      _dio.patch('/api/agents/$agentId/kb/todos/$sourceId', data: {
        if (content != null && content.isNotEmpty) 'content': content,
        if (status != null && status.isNotEmpty) 'status': status,
        // clearDates sends empty strings so the server drops the dates
        // (only non-empty fields land otherwise — empty string is
        // explicitly set vs omitted).
        if (startAt != null || clearDates) 'start_at': startAt?.toIso8601String() ?? '',
        if (endAt != null || clearDates) 'end_at': endAt?.toIso8601String() ?? '',
      });

  // ---- bookmarks ----

  Future<List<KbBookmark>> bookmarks(String agentId) async =>
      _rows(await _dio.get('/api/agents/$agentId/kb/bookmarks'), KbBookmark.fromJson);

  Future<void> saveBookmark(String agentId, String url, {String title = '', String summary = ''}) =>
      _dio.post('/api/agents/$agentId/kb/bookmarks', data: {
        'url': url,
        if (title.isNotEmpty) 'title': title,
        if (summary.isNotEmpty) 'summary': summary,
      });

  Future<void> updateBookmark(String agentId, String id, {String? title, String? summary}) =>
      _dio.patch('/api/agents/$agentId/kb/bookmarks/$id', data: {
        if (title != null && title.isNotEmpty) 'title': title,
        if (summary != null && summary.isNotEmpty) 'summary': summary,
      });

  Future<void> deleteBookmark(String agentId, String id) =>
      _dio.delete('/api/agents/$agentId/kb/bookmarks/$id');

  Future<void> promoteBookmark(String agentId, String id) =>
      _dio.post('/api/agents/$agentId/kb/bookmarks/$id/promote');

  // ---- article insights ----

  Future<KbInsights?> insights(String agentId, String sourceId) async {
    final res = await _dio.get('/api/agents/$agentId/kb/sources/$sourceId/insights');
    return res.data is Map ? KbInsights.fromJson(Map<String, dynamic>.from(res.data as Map)) : null;
  }

  Future<KbInsights?> generateInsights(String agentId, String sourceId) async {
    final res =
        await _dio.post('/api/agents/$agentId/kb/sources/$sourceId/insights/generate');
    return res.data is Map ? KbInsights.fromJson(Map<String, dynamic>.from(res.data as Map)) : null;
  }
}

List<T> _rows<T>(Response res, T Function(Map<String, dynamic>) fromJson) {
  final data = res.data;
  if (data is! List) return [];
  return [for (final r in data) if (r is Map) fromJson(Map<String, dynamic>.from(r))];
}
