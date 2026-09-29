/// KB wire models (docs/api/API.md §7, internal/kb/types.go). Times are
/// ISO strings on the wire; parsed defensively everywhere.
library;

class KbSource {
  const KbSource({
    required this.id,
    required this.title,
    this.type = 'article',
    this.status = '',
    this.sourceType = '',
    this.sourceRef = '',
    this.entryCount = 0,
    this.totalChars = 0,
    this.startAt,
    this.endAt,
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  final String title;

  /// article (default) | flash | todo
  final String type;

  /// todo lifecycle: pending | in_progress | done | cancelled
  final String status;
  final String sourceType;
  final String sourceRef;
  final int entryCount;
  final int totalChars;
  final DateTime? startAt;
  final DateTime? endAt;
  final String createdAt;
  final String updatedAt;

  factory KbSource.fromJson(Map<String, dynamic> j) => KbSource(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        type: j['type'] as String? ?? 'article',
        status: j['status'] as String? ?? '',
        sourceType: j['source_type'] as String? ?? '',
        sourceRef: j['source_ref'] as String? ?? '',
        entryCount: (j['entry_count'] as num?)?.toInt() ?? 0,
        totalChars: (j['total_chars'] as num?)?.toInt() ?? 0,
        startAt: DateTime.tryParse(j['start_at'] as String? ?? ''),
        endAt: DateTime.tryParse(j['end_at'] as String? ?? ''),
        createdAt: j['created_at'] as String? ?? '',
        updatedAt: j['updated_at'] as String? ?? '',
      );
}

class KbEntry {
  const KbEntry({required this.chunkIndex, required this.content});

  final int chunkIndex;
  final String content;

  factory KbEntry.fromJson(Map<String, dynamic> j) => KbEntry(
        chunkIndex: (j['chunk_index'] as num?)?.toInt() ?? 0,
        content: j['content'] as String? ?? '',
      );
}

class KbSearchResult {
  const KbSearchResult({
    required this.sourceId,
    required this.sourceTitle,
    required this.snippet,
    required this.rank,
  });

  final String sourceId;
  final String sourceTitle;
  final String snippet;
  final double rank;

  factory KbSearchResult.fromJson(Map<String, dynamic> j) => KbSearchResult(
        sourceId: j['source_id'] as String? ?? '',
        sourceTitle: j['source_title'] as String? ?? '',
        snippet: j['snippet'] as String? ?? j['content'] as String? ?? '',
        rank: (j['rank'] as num?)?.toDouble() ?? 0,
      );
}

class KbBookmark {
  const KbBookmark({
    required this.id,
    required this.url,
    required this.title,
    this.summary = '',
    this.promotedTo = '',
    this.createdAt = '',
  });

  final String id;
  final String url;
  final String title;
  final String summary;
  final String promotedTo;
  final String createdAt;

  bool get promoted => promotedTo.isNotEmpty;

  factory KbBookmark.fromJson(Map<String, dynamic> j) => KbBookmark(
        id: j['id'] as String? ?? '',
        url: j['url'] as String? ?? '',
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        promotedTo: j['promoted_to_article_id'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}

/// Deep-reading payload, rendered in a compact mobile layout: core
/// summary, chapters, curated quotes, actions.
class KbInsights {
  const KbInsights({
    required this.core,
    required this.chapters,
    required this.quotes,
    required this.actions,
  });

  final String core;
  final List<({String title, String body})> chapters;
  final List<({String text, String tag})> quotes;
  final List<String> actions;

  factory KbInsights.fromJson(Map<String, dynamic> j) {
    final summary = j['summary'];
    String core = '';
    final chapters = <({String title, String body})>[];
    if (summary is Map) {
      core = summary['core'] as String? ?? '';
      final raw = summary['chapters'];
      if (raw is List) {
        for (final c in raw) {
          if (c is Map) {
            chapters.add((title: c['title'] as String? ?? '', body: c['body'] as String? ?? ''));
          }
        }
      }
    }
    final quotes = <({String text, String tag})>[];
    final rawQuotes = j['quotes'];
    if (rawQuotes is List) {
      for (final q in rawQuotes) {
        if (q is Map) {
          quotes.add((text: q['text'] as String? ?? '', tag: q['tag'] as String? ?? ''));
        }
      }
    }
    final actions = <String>[];
    final rawActions = j['actions'];
    if (rawActions is List) {
      actions.addAll(rawActions.whereType<String>());
    }
    return KbInsights(core: core, chapters: chapters, quotes: quotes, actions: actions);
  }
}
