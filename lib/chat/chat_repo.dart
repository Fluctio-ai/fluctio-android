import 'dart:convert';
import 'dart:typed_data';

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
      parseRows((await _dio.get('/api/agents')).data, key: 'agents', fromJson: AgentInfo.fromJson);

  Future<List<ChatSessionInfo>> sessions(String agentId) async => parseRows(
      (await _dio.get('/api/chat/sessions', queryParameters: {'agentId': agentId})).data,
      key: 'sessions',
      fromJson: ChatSessionInfo.fromJson);

  Future<List<ProjectInfo>> projects(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/projects')).data,
      key: 'projects',
      fromJson: ProjectInfo.fromJson);

  /// Global skill catalog (`GET /api/skills`, bare-array payload).
  Future<List<SkillInfo>> globalSkills() async =>
      parseRows((await _dio.get('/api/skills')).data, fromJson: SkillInfo.fromJson);

  /// Skills installed in the agent's own home (`GET /api/agents/{id}/skills`).
  /// Owner-only endpoint — callers degrade to the global list on failure.
  Future<List<SkillInfo>> agentSkills(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/skills')).data,
      fromJson: SkillInfo.fromJson);

  Future<void> createProject(String agentId, String name, {String description = ''}) =>
      _dio.post('/api/agents/$agentId/projects',
          data: {'name': name, if (description.isNotEmpty) 'description': description});

  Future<void> updateProject(String agentId, String projectId,
          {required String name, String description = ''}) =>
      _dio.patch('/api/agents/$agentId/projects/$projectId',
          data: {'name': name, if (description.isNotEmpty) 'description': description});

  /// 409 when the project still owns chats; [sessionCount] from the error
  /// body (0 = none/absent). Other failures rethrow.
  Future<int> deleteProject(String agentId, String projectId) async {
    try {
      await _dio.delete('/api/agents/$agentId/projects/$projectId');
      return 0;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final body = e.response?.data;
        return body is Map ? (body['sessionCount'] as num?)?.toInt() ?? -1 : -1;
      }
      rethrow;
    }
  }

  Future<HistoryPage> history(String agentId, String sessionId, {int before = 0, int limit = 50}) async {
    final res = await _dio.get('/api/chat/history', queryParameters: {
      'agentId': agentId,
      'sessionId': sessionId,
      if (before > 0) 'before': before,
      'limit': limit,
    });
    return parseObject(res.data, HistoryPage.fromJson) ??
        const HistoryPage(messages: [], earliestSeq: 0, hasMore: false);
  }

  Future<TodoData> todo(String agentId, String sessionId) async =>
      parseObject(
          (await _dio.get('/api/chat/todo',
                  queryParameters: {'agentId': agentId, 'sessionId': sessionId}))
              .data,
          TodoData.fromJson) ??
      TodoData.empty;

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

  /// Two-step attachment upload (web parity, api.ts:1454 → handlers.go:
  /// handleAgentFileUpload): multipart files land in the workspace dir the
  /// session's sandbox mounts (`projects/<pid>/` for project chats,
  /// `sessions/<sid>/` otherwise) before the message fires — the chat request
  /// then carries only breadcrumb text, so file size is bounded by the
  /// server's multipart handling, not by a base64-inflated JSON body.
  Future<void> uploadAttachments(
    String agentId,
    String sessionId,
    List<PendingAttachment> files, {
    String? projectId,
    CancelToken? cancelToken,
  }) async {
    final form = FormData();
    for (final f in files) {
      final (mime, bytes) = _parseDataUrl(f.url);
      form.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(bytes, filename: f.name, contentType: DioMediaType.parse(mime)),
      ));
    }
    await _dio.post(
      '/api/agents/$agentId/files',
      queryParameters: {
        if (sessionId.isNotEmpty) 'sessionId': sessionId,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      },
      data: form,
      cancelToken: cancelToken,
    );
  }

  /// Split a `data:<mime>;base64,<payload>` URL (the shape this app builds)
  /// back into parts for the multipart body.
  static (String, Uint8List) _parseDataUrl(String url) {
    final comma = url.indexOf(',');
    final header = comma > 5 ? url.substring(5, comma) : '';
    final semi = header.indexOf(';');
    final mime = semi > 0 ? header.substring(0, semi) : '';
    return (mime.isEmpty ? 'application/octet-stream' : mime,
        base64Decode(url.substring(comma + 1)));
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

  /// Fork at [forkSeq] (contract §5; web chat-screen.tsx handleFork): the
  /// child session inherits the source archive up to forkSeq as a
  /// read-only prefix. Returns the new session key, or null when the
  /// server didn't create one.
  Future<String?> forkSession(String agentId, String sourceSessionKey, int forkSeq) async {
    final res = await _dio.post('/api/chat/sessions/fork',
        data: {'agentId': agentId, 'sourceSessionKey': sourceSessionKey, 'forkSeq': forkSeq});
    return res.data is Map ? (res.data['sessionKey'] as String?) : null;
  }
}
