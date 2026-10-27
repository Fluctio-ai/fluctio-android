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

/// One shelved ("回头再说") topic on the rolling cross-diary ledger
/// (docs/api/API.md §8, internal/store/diary.go DiaryShelved): deferred
/// and never returned to — each day's Pass 3 inherits the previous
/// ledger, settles entries picked back up (resolved, shown that day
/// then retired), and drops open entries past the shelved window.
/// session/seq is the #seq-N deep link back into the deferred context.
class DiaryShelved {
  const DiaryShelved({
    required this.topic,
    this.context = '',
    this.since = '',
    this.session = '',
    this.seq = 0,
    this.status = 'open',
  });

  final String topic;

  /// One line: the situation when deferred.
  final String context;

  /// YYYY-MM-DD first shelved.
  final String since;

  /// Deep-link target back into the deferred conversation.
  final String session;
  final int seq;

  /// "open" | "resolved".
  final String status;

  bool get resolved => status == 'resolved';

  /// Whole days from [since] to today (UTC+8 frame, like the server's
  /// date strings); 0 for unparseable/future dates (web daysSince).
  int get daysOpen {
    final s = DateTime.tryParse('${since}T00:00:00');
    if (s == null) return 0;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final days = DateTime.utc(now.year, now.month, now.day)
        .difference(DateTime.utc(s.year, s.month, s.day))
        .inDays;
    return days < 0 ? 0 : days;
  }

  factory DiaryShelved.fromJson(Map<String, dynamic> j) => DiaryShelved(
        topic: j['topic'] as String? ?? '',
        context: j['context'] as String? ?? '',
        since: j['since'] as String? ?? '',
        session: j['session'] as String? ?? '',
        seq: (j['seq'] as num?)?.toInt() ?? 0,
        status: j['status'] as String? ?? 'open',
      );
}

class DailyDiary {
  const DailyDiary({
    required this.date,
    this.overview = '',
    this.themes = const [],
    this.blindspots = const [],
    this.shelved = const [],
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

  /// The shelved-topics ledger carried by this day's entry (opt-in Pass
  /// 3; empty when the feature is off or the day had none).
  final List<DiaryShelved> shelved;
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
  /// Shelved is a rolling ledger, not the day's content: it never counts
  /// here (web genDateIsEmpty keys on themes+blindspots only).
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
        shelved: [
          for (final s in (j['shelved'] as List? ?? const []))
            if (s is Map) DiaryShelved.fromJson(Map<String, dynamic>.from(s)),
        ],
        archives: [for (final a in (j['archives'] as List? ?? const [])) if (a is String) a],
        model: j['model'] as String? ?? '',
        generatedAt: j['generatedAt'] as String? ?? '',
        generating: j['generating'] == true,
      );
}
