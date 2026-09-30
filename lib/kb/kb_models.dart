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

/// Spaced-repetition flashcard (kb_cards; docs/api/API.md §7).
class KbCard {
  const KbCard({
    required this.id,
    required this.question,
    required this.answer,
    this.status = 'active',
    this.dueAt,
    this.reviewCount = 0,
    this.lapseCount = 0,
    this.sourceType = '',
  });

  final String id;
  final String question;
  final String answer;
  final String status;
  final DateTime? dueAt;
  final int reviewCount;
  final int lapseCount;
  final String sourceType;

  factory KbCard.fromJson(Map<String, dynamic> j) => KbCard(
        id: j['id'] as String? ?? '',
        question: j['question'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        status: j['status'] as String? ?? 'active',
        dueAt: DateTime.tryParse(j['due_at'] as String? ?? ''),
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
        lapseCount: (j['lapse_count'] as num?)?.toInt() ?? 0,
        sourceType: j['source_type'] as String? ?? '',
      );
}

class KbCardStats {
  const KbCardStats({
    this.dueToday = 0,
    this.active = 0,
    this.mastered = 0,
    this.archived = 0,
    this.streakDays = 0,
  });

  final int dueToday;
  final int active;
  final int mastered;
  final int archived;
  final int streakDays;

  factory KbCardStats.fromJson(Map<String, dynamic> j) => KbCardStats(
        dueToday: (j['due_today'] as num?)?.toInt() ?? 0,
        active: (j['active'] as num?)?.toInt() ?? 0,
        mastered: (j['mastered'] as num?)?.toInt() ?? 0,
        archived: (j['archived'] as num?)?.toInt() ?? 0,
        streakDays: (j['streak_days'] as num?)?.toInt() ?? 0,
      );
}

/// Personal note: markdown body, upsert semantics on save.
class KbNote {
  const KbNote({required this.id, required this.title, this.contentMd = '', this.updatedAt = ''});

  final String id;
  final String title;
  final String contentMd;
  final String updatedAt;

  factory KbNote.fromJson(Map<String, dynamic> j) => KbNote(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        contentMd: j['content_md'] as String? ?? '',
        updatedAt: j['updated_at'] as String? ?? '',
      );
}

class KbNoteAttachment {
  const KbNoteAttachment({required this.id, required this.fileName, this.mime = '', this.size = 0});

  final String id;
  final String fileName;
  final String mime;
  final int size;

  factory KbNoteAttachment.fromJson(Map<String, dynamic> j) => KbNoteAttachment(
        id: j['id'] as String? ?? '',
        fileName: j['file_name'] as String? ?? '',
        mime: j['mime'] as String? ?? '',
        size: (j['size'] as num?)?.toInt() ?? 0,
      );
}

class KbInsights {
  const KbInsights({
    required this.core,
    required this.chapters,
    required this.quotes,
    required this.actions,
    this.sproutsIntro = '',
    this.sprouts = const [],
    this.echoSeed = '',
    this.echoSeedComment = '',
    this.echoItems = const [],
  });

  final String core;
  final List<({String title, String body})> chapters;
  final List<({String text, String tag})> quotes;
  final List<String> actions;

  /// Sprouts (知识延展, InsightSprouts in fastclaw kb/types.go): intro
  /// plus seeds with their Aha moments, and the optional cross-domain
  /// echo validating one seed quote across other lenses.
  final String sproutsIntro;
  final List<({String emoji, String title, String seed, String body, String aha})> sprouts;
  final String echoSeed;
  final String echoSeedComment;
  final List<({String perspective, String label, String quote, String source})> echoItems;

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
    String sproutsIntro = '';
    final sprouts = <({String emoji, String title, String seed, String body, String aha})>[];
    final rawSprouts = j['sprouts'];
    if (rawSprouts is Map) {
      sproutsIntro = rawSprouts['intro'] as String? ?? '';
      final items = rawSprouts['items'];
      if (items is List) {
        for (final s in items) {
          if (s is Map) {
            sprouts.add((
              emoji: s['emoji'] as String? ?? '',
              title: s['title'] as String? ?? '',
              seed: s['seed'] as String? ?? '',
              body: s['body'] as String? ?? '',
              aha: s['aha'] as String? ?? '',
            ));
          }
        }
      }
    }
    String echoSeed = '';
    String echoSeedComment = '';
    final echoItems =
        <({String perspective, String label, String quote, String source})>[];
    final echo = rawSprouts is Map ? rawSprouts['echo'] : null;
    if (echo is Map) {
      echoSeed = echo['seed_quote'] as String? ?? '';
      echoSeedComment = echo['seed_comment'] as String? ?? '';
      final rawEchoItems = echo['items'];
      if (rawEchoItems is List) {
        for (final e in rawEchoItems) {
          if (e is Map) {
            echoItems.add((
              perspective: e['perspective'] as String? ?? '',
              label: e['label'] as String? ?? '',
              quote: e['quote'] as String? ?? '',
              source: e['source'] as String? ?? '',
            ));
          }
        }
      }
    }
    return KbInsights(
      core: core,
      chapters: chapters,
      quotes: quotes,
      actions: actions,
      sproutsIntro: sproutsIntro,
      sprouts: sprouts,
      echoSeed: echoSeed,
      echoSeedComment: echoSeedComment,
      echoItems: echoItems,
    );
  }
}
