/// Diary wire models (docs/api/API.md §8, internal/store/diary.go).
/// Dates are plain YYYY-MM-DD UTC+8 strings — never parsed into instants
/// on the wire path (only the detail header renders one as a label).
library;

/// Clickable #seq-N reference: the session plus the seq range it spans.
class DiarySegRef {
  const DiarySegRef({required this.session, required this.start, required this.end});

  final String session;
  final int start;
  final int end;

  factory DiarySegRef.fromJson(Map<String, dynamic> j) => DiarySegRef(
        session: j['session'] as String? ?? '',
        start: (j['start'] as num?)?.toInt() ?? 0,
        end: (j['end'] as num?)?.toInt() ?? 0,
      );
}

/// One topic group distilled from the day's conversations.
class DiaryTheme {
  const DiaryTheme({
    required this.title,
    this.summary = '',
    this.points = const [],
    this.segments = const [],
  });

  final String title;
  final String summary;
  final List<String> points;
  final List<DiarySegRef> segments;

  factory DiaryTheme.fromJson(Map<String, dynamic> j) => DiaryTheme(
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        points: [for (final p in (j['points'] as List? ?? const [])) if (p is String) p],
        segments: [
          for (final s in (j['segments'] as List? ?? const []))
            if (s is Map) DiarySegRef.fromJson(Map<String, dynamic>.from(s)),
        ],
      );
}

/// One "you might have missed" point — important but not followed up.
class DiaryBlindspot {
  const DiaryBlindspot({required this.point, this.reason = ''});

  final String point;
  final String reason;

  factory DiaryBlindspot.fromJson(Map<String, dynamic> j) => DiaryBlindspot(
        point: j['point'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
      );
}

class DailyDiary {
  const DailyDiary({
    required this.date,
    this.overview = '',
    this.themes = const [],
    this.blindspots = const [],
    this.archives = const [],
    this.model = '',
    this.generatedAt = '',
    this.generating = false,
  });

  final String date;

  /// Overview prose + theme groups + flagged blindspots + archive lines.
  final String overview;
  final List<DiaryTheme> themes;
  final List<DiaryBlindspot> blindspots;
  final List<String> archives;

  /// The model that distilled this entry (footer metadata on the web).
  final String model;

  /// ISO timestamp — compared as a string to detect a regeneration pass.
  final String generatedAt;

  /// True only on the generating stub (GET while a manual run is in
  /// flight): `{agentId, date, generating:true}` with nothing else set.
  final bool generating;

  /// A row that was generated but carries nothing — the day had no
  /// conversation summaries (red-frame calendar marker on the web).
  bool get isEmptyDay => themes.isEmpty && blindspots.isEmpty;

  factory DailyDiary.fromJson(Map<String, dynamic> j) => DailyDiary(
        date: j['date'] as String? ?? '',
        overview: j['overview'] as String? ?? '',
        themes: [
          for (final t in (j['themes'] as List? ?? const []))
            if (t is Map) DiaryTheme.fromJson(Map<String, dynamic>.from(t)),
        ],
        blindspots: [
          for (final b in (j['blindspots'] as List? ?? const []))
            if (b is Map) DiaryBlindspot.fromJson(Map<String, dynamic>.from(b)),
        ],
        archives: [for (final a in (j['archives'] as List? ?? const [])) if (a is String) a],
        model: j['model'] as String? ?? '',
        generatedAt: j['generatedAt'] as String? ?? '',
        generating: j['generating'] == true,
      );
}
