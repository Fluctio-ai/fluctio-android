import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/sse.dart';
import 'models.dart';

final chatRepoProvider = Provider<ChatRepo>((ref) => ChatRepo(ref.watch(apiClientProvider)));

/// Thin typed wrappers over the chat surface (docs/api/API.md §4–6).
/// Session keys travel as path segments, so they are URL-encoded.
class ChatRepo {
  ChatRepo(this._dio);
  final Dio _dio;

  SseClient get sse => SseClient(_dio);

  Future<List<AgentInfo>> agents() async =>
      _rows(await _dio.get('/api/agents'), 'agents', AgentInfo.fromJson);

  Future<List<ChatSessionInfo>> sessions(String agentId) async =>
      _rows(await _dio.get('/api/chat/sessions', queryParameters: {'agentId': agentId}),
          'sessions', ChatSessionInfo.fromJson);

  Future<HistoryPage> history(String agentId, String sessionId, {int before = 0, int limit = 50}) async {
    final res = await _dio.get('/api/chat/history', queryParameters: {
      'agentId': agentId,
      'sessionId': sessionId,
      if (before > 0) 'before': before,
      'limit': limit,
    });
    return res.data is Map
        ? HistoryPage.fromJson(Map<String, dynamic>.from(res.data as Map))
        : const HistoryPage(messages: [], earliestSeq: 0, hasMore: false);
  }

  Future<TodoData> todo(String agentId, String sessionId) async {
    final res = await _dio.get('/api/chat/todo',
        queryParameters: {'agentId': agentId, 'sessionId': sessionId});
    return res.data is Map
        ? TodoData.fromJson(Map<String, dynamic>.from(res.data as Map))
        : TodoData.empty;
  }

  /// Explicit stop (handlers.go:1261). True = a turn was cancelled;
  /// false = 409, nothing in flight. Other failures rethrow.
  Future<bool> stop(String agentId, String sessionId) async {
    try {
      await _dio.post('/api/chat/stop', data: {'agentId': agentId, 'sessionId': sessionId});
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return false;
      rethrow;
    }
  }

  /// Steer an in-flight turn (handlers.go:1181). True = buffered into the
  /// running turn; false = 409, no active turn. Other failures rethrow.
  Future<bool> steer(String agentId, String sessionId, String message) async {
    try {
      await _dio.post('/api/chat/steer',
          data: {'agentId': agentId, 'sessionId': sessionId, 'message': message});
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return false;
      rethrow;
    }
  }

  Future<void> renameSession(String agentId, String key, String title) =>
      _dio.put('/api/chat/sessions/${Uri.encodeComponent(key)}',
          data: {'agentId': agentId, 'title': title});

  Future<void> deleteSession(String agentId, String key) => _dio.delete(
        '/api/chat/sessions/${Uri.encodeComponent(key)}',
        queryParameters: {'agentId': agentId},
      );

  Future<void> setChatOnly(String agentId, String key, bool on) => _dio.patch(
        '/api/chat/sessions/${Uri.encodeComponent(key)}/chat-only',
        data: {'agentId': agentId, 'chatOnly': on},
      );
}

List<T> _rows<T>(Response res, String key, T Function(Map<String, dynamic>) fromJson) {
  final data = res.data;
  if (data is! Map) return [];
  final rows = data[key];
  if (rows is! List) return [];
  return [for (final r in rows) if (r is Map) fromJson(Map<String, dynamic>.from(r))];
}
