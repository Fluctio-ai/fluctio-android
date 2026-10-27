import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'diary_models.dart';

final diaryRepoProvider = Provider<DiaryRepo>((ref) => DiaryRepo(ref.watch(apiClientProvider)));

/// One month's entries, keyed (agentId, "YYYY-MM").
final diaryMonthProvider = FutureProvider.autoDispose
    .family<List<DailyDiary>, (String, String)>((ref, t) async {
  return ref.watch(diaryRepoProvider).month(t.$1, t.$2);
});

/// One day's entry; null = no row for that date (404).
final diaryEntryProvider = FutureProvider.autoDispose
    .family<DailyDiary?, (String, String)>((ref, t) async {
  return ref.watch(diaryRepoProvider).entry(t.$1, t.$2);
});

/// The live shelved-topics ledger for the dashboard pane
/// (GET /api/agents/{id}/diary/shelved).
final diaryShelvedProvider =
    FutureProvider.autoDispose.family<DiaryShelvedView, String>((ref, agentId) {
  return ref.watch(diaryRepoProvider).shelved(agentId);
});

/// Live shelved-ledger view (docs/api/API.md §8): enabled:false when the
/// agent hasn't opted in — the pane hides entirely instead of rendering
/// an empty teaser.
class DiaryShelvedView {
  const DiaryShelvedView({required this.enabled, this.items = const []});

  final bool enabled;
  final List<DiaryShelved> items;
}

/// Dates with a manual generation in flight — shared by the calendar
/// page's generate row and the detail page's regenerate action (the web
/// parent view owns the same single flag). Plain Notifier, not
/// autoDispose: the poll loop must outlive page navigation.
final diaryGeneratingProvider =
    NotifierProvider<DiaryGenController, Set<String>>(DiaryGenController.new);

class DiaryGenController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  bool isOn(String date) => state.contains(date);

  /// POST generate, then poll GET until the row lands (new day) or its
  /// generatedAt advances (regenerate) — the server runs the LLM async
  /// and upserts when done. Mirrors diary-view.tsx: 3s interval, 120s
  /// cap, 409 swallowed (another run already going → just keep polling).
  Future<void> start(String agentId, String date) async {
    if (state.contains(date)) return;
    state = {...state, date};
    final repo = ref.read(diaryRepoProvider); // captured pre-await
    try {
      String beforeAt = '';
      try {
        beforeAt = (await repo.entry(agentId, date))?.generatedAt ?? '';
      } catch (_) {}
      try {
        await repo.generate(agentId, date);
      } on DioException catch (e) {
        if (e.response?.statusCode != 409) rethrow;
      }
      final deadline = DateTime.now().add(const Duration(seconds: 120));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 3));
        try {
          final d = await repo.entry(agentId, date);
          if (d != null && !d.generating && d.generatedAt != beforeAt) break;
        } catch (_) {}
      }
    } catch (_) {
      // Silent like the web — the button resets, the user can retry.
    } finally {
      if (ref.mounted) state = {for (final d in state) if (d != date) d};
    }
  }
}

/// Typed wrappers over the diary surface (docs/api/API.md §8).
class DiaryRepo {
  DiaryRepo(this._dio);
  final Dio _dio;

  /// Entries for [ym] ("YYYY-MM"), newest first.
  Future<List<DailyDiary>> month(String agentId, String ym) async => parseRows(
      (await _dio.get('/api/agents/$agentId/diary',
          queryParameters: {'from': '$ym-01', 'to': '$ym-31'}))
          .data,
      fromJson: DailyDiary.fromJson);

  /// One day; null when the server has no row (404) — including while
  /// another user-triggered run is going, unless ours is (then the
  /// server answers 200 with the generating stub instead).
  Future<DailyDiary?> entry(String agentId, String date) async {
    try {
      return parseObject(
          (await _dio.get('/api/agents/$agentId/diary/$date')).data, DailyDiary.fromJson);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Fire-and-forget manual generation (202); the caller polls [entry].
  Future<void> generate(String agentId, String date) =>
      _dio.post('/api/agents/$agentId/diary/generate', data: {'date': date});

  /// The live shelved ledger. Fail-closed like the web (api.ts
  /// getDiaryShelved): any failure answers enabled:false so the opt-in
  /// pane just never appears.
  Future<DiaryShelvedView> shelved(String agentId) async {
    try {
      final data = (await _dio.get('/api/agents/$agentId/diary/shelved')).data;
      if (data is! Map) return const DiaryShelvedView(enabled: false);
      final j = Map<String, dynamic>.from(data);
      return DiaryShelvedView(
        enabled: j['enabled'] == true,
        items: [
          for (final s in (j['items'] as List? ?? const []))
            if (s is Map) DiaryShelved.fromJson(Map<String, dynamic>.from(s)),
        ],
      );
    } catch (_) {
      return const DiaryShelvedView(enabled: false);
    }
  }
}
