import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../todo/todo_reminders.dart';
import 'kb_models.dart';

final kbRepoProvider = Provider<KbRepo>((ref) => KbRepo(
    ref.watch(apiClientProvider),
    // Alarm consistency invariant lives in the data layer: every todo
    // write re-syncs the reminders, so no call site can forget it.
    () => ref.read(todoReminderServiceProvider).sync()));

final kbSourcesProvider =
    FutureProvider.autoDispose.family<List<KbSource>, String>((ref, agentId) async {
  return ref.watch(kbRepoProvider).sources(agentId);
});

final kbTodosProvider =
    FutureProvider.autoDispose.family<List<KbSource>, String>((ref, agentId) async {
  return ref.watch(kbRepoProvider).todos(agentId);
});

final kbBookmarksProvider =
    FutureProvider.autoDispose.family<List<KbBookmark>, String>((ref, agentId) async {
  return ref.watch(kbRepoProvider).bookmarks(agentId);
});

final kbNotesProvider =
    FutureProvider.autoDispose.family<List<KbNote>, String>((ref, agentId) async {
  return ref.watch(kbRepoProvider).notes(agentId);
});

/// Typed wrappers over the KB surface (docs/api/API.md §7). Save paths
/// return a duplicate marker when the server deduped the write.
class KbRepo {
  KbRepo(this._dio, [this._onTodoWrite]);
  final Dio _dio;

  /// Fired after any write that may change the todo set (the reminder
  /// service re-syncs its alarms). `deleteSource` is shared with
  /// articles/flash — a delete there costs one idempotent resync.
  final void Function()? _onTodoWrite;
  void _todoWritten() => _onTodoWrite?.call();

  Future<List<KbSource>> sources(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/kb/sources')).data,
      fromJson: KbSource.fromJson);

  Future<List<KbSource>> todos(String agentId, {String status = ''}) async => parseRows(
      (await _dio.get('/api/agents/$agentId/kb/todos',
              queryParameters: {if (status.isNotEmpty) 'status': status}))
          .data,
      fromJson: KbSource.fromJson);

  Future<List<KbEntry>> entries(String agentId, String sourceId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/kb/sources/$sourceId/entries')).data,
      fromJson: KbEntry.fromJson);

  /// Full text of a KB source — its entry chunks in order, one per line
  /// (the join the web flash/todo editors do). Shared by the todo/flash
  /// tiles and editors so the rule lives in one place.
  Future<String> fullText(String agentId, String sourceId) async =>
      (await entries(agentId, sourceId)).map((e) => e.content).join('\n');

  Future<List<KbSearchResult>> search(String agentId, String query, {int limit = 12}) async =>
      parseRows(
          (await _dio.post('/api/agents/$agentId/kb/search',
              data: {'query': query, 'limit': limit}))
              .data,
          fromJson: KbSearchResult.fromJson);

  /// Fetch + ingest a URL as an article source (contract §7
  /// POST /kb/ingest/url) — the share target's "save as article".
  Future<void> ingestUrl(String agentId, String url, {String title = ''}) =>
      _dio.post('/api/agents/$agentId/kb/ingest/url', data: {
        'url': url,
        if (title.isNotEmpty) 'title': title,
      });

  Future<void> deleteSource(String agentId, String sourceId) async {    await _dio.delete('/api/agents/$agentId/kb/sources/$sourceId');
    _todoWritten();
  }

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
      if (startAt != null) 'start_at': startAt.toUtc().toIso8601String(),
      if (endAt != null) 'end_at': endAt.toUtc().toIso8601String(),
    });
    _todoWritten();
    return res.data is Map && res.data['deduped'] == true;
  }

  Future<void> updateTodo(
    String agentId,
    String sourceId, {
    String? content,
    String? status,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    // The backend PATCH drops every empty/non-present field
    // (handlers_kb.go: only non-empty fields land) — clearing a date or
    // a bookmark summary is a server-side capability the client cannot
    // synthesize, so the repo simply omits fields it doesn't set.
    await _dio.patch('/api/agents/$agentId/kb/todos/$sourceId', data: {
      if (content != null && content.isNotEmpty) 'content': content,
      if (status != null && status.isNotEmpty) 'status': status,
      if (startAt != null) 'start_at': startAt.toUtc().toIso8601String(),
      if (endAt != null) 'end_at': endAt.toUtc().toIso8601String(),
    });
    _todoWritten();
  }

  // ---- bookmarks ----

  Future<List<KbBookmark>> bookmarks(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/kb/bookmarks')).data,
      fromJson: KbBookmark.fromJson);

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

  Future<KbInsights?> insights(String agentId, String sourceId) async =>
      parseObject(
          (await _dio.get('/api/agents/$agentId/kb/sources/$sourceId/insights')).data,
          KbInsights.fromJson);

  Future<KbInsights?> generateInsights(String agentId, String sourceId) async => parseObject(
      (await _dio.post('/api/agents/$agentId/kb/sources/$sourceId/insights/generate')).data,
      KbInsights.fromJson);

  // ---- cards (ticket 06) ----

  /// Card library (non-queue): first page by filter.
  Future<List<KbCard>> cardList(String agentId,
          {String filter = 'active', int limit = 100}) async =>
      parseRows(
          (await _dio.get('/api/agents/$agentId/kb/cards',
                  queryParameters: {'filter': filter, 'limit': limit}))
              .data,
          fromJson: KbCard.fromJson);

  /// Review queue: most-overdue first.
  Future<List<KbCard>> cardQueue(String agentId, {int limit = 50}) async => parseRows(
      (await _dio.get('/api/agents/$agentId/kb/cards',
              queryParameters: {'queue': '1', 'limit': limit}))
          .data,
      fromJson: KbCard.fromJson);

  Future<KbCardStats> cardStats(String agentId) async =>
      parseObject((await _dio.get('/api/agents/$agentId/kb/cards/stats')).data,
              KbCardStats.fromJson) ??
          const KbCardStats();

  Future<KbCard> reviewCard(String agentId, String cardId, String grade) async =>
      parseObject(
          (await _dio.post('/api/agents/$agentId/kb/cards/$cardId/review',
              data: {'grade': grade}))
              .data,
          KbCard.fromJson)!;

  Future<void> saveCard(String agentId, String question, String answer) =>
      _dio.post('/api/agents/$agentId/kb/cards',
          data: {'question': question, 'answer': answer});

  Future<void> archiveCard(String agentId, String cardId, bool archived) => archived
      ? _dio.post('/api/agents/$agentId/kb/cards/$cardId/archive')
      : _dio.post('/api/agents/$agentId/kb/cards/$cardId/restore');

  Future<void> deleteCard(String agentId, String cardId) =>
      _dio.delete('/api/agents/$agentId/kb/cards/$cardId');

  // ---- notes (ticket 06) ----

  Future<List<KbNote>> notes(String agentId) async => parseRows(
      (await _dio.get('/api/agents/$agentId/kb/notes')).data,
      key: 'notes',
      fromJson: KbNote.fromJson);

  /// Upsert: empty id creates, non-empty updates. Returns the note id.
  Future<String> saveNote(String agentId,
      {String id = '', required String title, required String contentMd}) async {
    final res = await _dio.post('/api/agents/$agentId/kb/notes',
        data: {'id': id, 'title': title, 'content_md': contentMd});
    return res.data is Map ? (res.data as Map)['id'] as String? ?? '' : '';
  }

  Future<void> deleteNote(String agentId, String noteId) =>
      _dio.delete('/api/agents/$agentId/kb/notes/$noteId');

  Future<List<KbNoteAttachment>> noteAttachments(String agentId, String noteId) async =>
      parseRows(
          (await _dio.get('/api/agents/$agentId/kb/notes/$noteId/attachments')).data,
          fromJson: KbNoteAttachment.fromJson);
}
