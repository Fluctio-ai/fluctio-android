import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'wiki_models.dart';

final wikiRepoProvider = Provider<WikiRepo>((ref) => WikiRepo(ref.watch(apiClientProvider)));

/// Typed wrappers over the wiki surface (contract §8). Page ids travel
/// as path segments — `type:slug` ids get the `:` URL-encoded, both
/// shapes resolve server-side (handlers_wiki.go:104).
class WikiRepo {
  WikiRepo(this._dio);
  final Dio _dio;

  Future<WikiStatsInfo> stats(String agentId) async =>
      WikiStatsInfo.fromJson(
          (await _dio.get('/api/agents/$agentId/wiki/stats')).data as Map<String, dynamic>);

  /// One page-slice of the inventory. limit ≤ 500 (handler clamps).
  Future<({List<WikiPageInfo> pages, int total})> pages(String agentId,
      {String type = '', int limit = 500, int offset = 0}) async {
    final res = await _dio.get('/api/agents/$agentId/wiki/pages', queryParameters: {
      if (type.isNotEmpty) 'type': type,
      'limit': limit,
      'offset': offset,
    });
    final body = res.data;
    final rows = body is Map && body['pages'] is List ? body['pages'] as List : const [];
    return (
      pages: [for (final r in rows) WikiPageInfo.fromJson(r as Map<String, dynamic>)],
      total: (body is Map ? (body['total'] as num?)?.toInt() : null) ?? rows.length,
    );
  }

  Future<WikiPageInfo> page(String agentId, String pageId) async =>
      WikiPageInfo.fromJson((await _dio
              .get('/api/agents/$agentId/wiki/pages/${Uri.encodeComponent(pageId)}'))
          .data as Map<String, dynamic>);

  Future<WikiGraphInfo> graph(String agentId) async =>
      WikiGraphInfo.fromJson(
          (await _dio.get('/api/agents/$agentId/wiki/graph')).data as Map<String, dynamic>);

  Future<void> delete(String agentId, String pageId) async =>
      _dio.delete('/api/agents/$agentId/wiki/pages/${Uri.encodeComponent(pageId)}');

  /// Contract §8 — **endpoint pending on the backend** (UpsertPage
  /// exists internally, no HTTP route yet). Fails with 404 until the
  /// fastclaw handler lands; the caller surfaces the failure.
  Future<void> save(String agentId, String pageId,
      {required String title, required String body}) async {
    await _dio.put('/api/agents/$agentId/wiki/pages/${Uri.encodeComponent(pageId)}',
        data: {'title': title, 'body': body});
  }
}

/// The tab's one-shot inventory: every page + stats in a single
/// snapshot, paged 500/call (the web pane also groups client-side over
/// the full list; search/filtering stay local). Safety cap 2000 pages —
/// a wiki past that needs server-side search, which the API lacks.
class WikiInventory {
  const WikiInventory({required this.pages, this.stats});

  final List<WikiPageInfo> pages;
  final WikiStatsInfo? stats;
}

final wikiInventoryProvider =
    FutureProvider.family<WikiInventory, String>((ref, agentId) async {
  final repo = ref.watch(wikiRepoProvider);
  // Stats are cosmetic — a failure must not kill the page list.
  WikiStatsInfo? stats;
  try {
    stats = await repo.stats(agentId);
  } catch (_) {}
  final all = <WikiPageInfo>[];
  var offset = 0;
  var total = 1;
  while (offset < total && offset < 2000) {
    final batch = await repo.pages(agentId, offset: offset);
    all.addAll(batch.pages);
    total = batch.total;
    if (batch.pages.isEmpty) break;
    offset += batch.pages.length;
  }
  return WikiInventory(pages: all, stats: stats);
});
