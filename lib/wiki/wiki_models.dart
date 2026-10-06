import 'dart:ui';

/// Wire models for the wiki surface (contract §8, handlers_wiki.go).
/// Page ids come in two shapes — UUIDs and `page_type:slug` pairs (the
/// form `[[wiki links]]` embed) — both resolve server-side, so the
/// client treats [WikiPageInfo.id] as opaque.
class WikiPageInfo {
  const WikiPageInfo({
    required this.id,
    required this.pageType,
    required this.slug,
    required this.title,
    this.summary = '',
    this.body,
    this.updatedAt,
    this.revision = 0,
  });

  final String id;
  final String pageType;
  final String slug;
  final String title;
  final String summary;

  /// Present from GET pages/{id} and the graph payload; the list
  /// endpoint also carries it but the tab views never read it.
  final String? body;
  final DateTime? updatedAt;
  final int revision;

  factory WikiPageInfo.fromJson(Map<String, dynamic> j) => WikiPageInfo(
        id: (j['id'] ?? '') as String,
        pageType: (j['page_type'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        summary: (j['summary'] ?? '') as String,
        body: j['body'] as String?,
        updatedAt: DateTime.tryParse((j['updated_at'] ?? '') as String),
        revision: (j['revision'] as num?)?.toInt() ?? 0,
      );
}

class WikiStatsInfo {
  const WikiStatsInfo({
    required this.pageCounts,
    required this.totalPages,
    required this.totalEdges,
  });

  final Map<String, int> pageCounts;
  final int totalPages;
  final int totalEdges;

  factory WikiStatsInfo.fromJson(Map<String, dynamic> j) => WikiStatsInfo(
        pageCounts: {
          for (final e in ((j['page_counts'] ?? const {}) as Map).entries)
            e.key as String: (e.value as num?)?.toInt() ?? 0,
        },
        totalPages: (j['total_pages'] as num?)?.toInt() ?? 0,
        totalEdges: (j['total_edges'] as num?)?.toInt() ?? 0,
      );
}

class WikiEdgeInfo {
  const WikiEdgeInfo({required this.src, required this.dst});

  final String src;
  final String dst;

  factory WikiEdgeInfo.fromJson(Map<String, dynamic> j) => WikiEdgeInfo(
        src: (j['src_page_id'] ?? '') as String,
        dst: (j['dst_page_id'] ?? '') as String,
      );
}

class WikiGraphInfo {
  const WikiGraphInfo({required this.nodes, required this.edges});

  final List<WikiPageInfo> nodes;
  final List<WikiEdgeInfo> edges;

  factory WikiGraphInfo.fromJson(Map<String, dynamic> j) => WikiGraphInfo(
        nodes: [
          for (final n in ((j['nodes'] ?? const []) as List))
            WikiPageInfo.fromJson(n as Map<String, dynamic>),
        ],
        edges: [
          for (final e in ((j['edges'] ?? const []) as List))
            WikiEdgeInfo.fromJson(e as Map<String, dynamic>),
        ],
      );
}

/// Node palette per brightness — mirrors the web engine's GraphTheme
/// (wiki/page.tsx graphTheme): node fills share the chart-ring family,
/// selection rides the surge-cyan brand axis.
class WikiGraphPalette {
  const WikiGraphPalette._(
    this._typeColors,
    this.fallbackNode,
    this.label,
    this.edge,
    this.selectedBorder,
  );

  factory WikiGraphPalette.of(Brightness brightness) => brightness == Brightness.dark
      ? const WikiGraphPalette._(
          {
            'overview': Color(0xFF22D3EE),
            'entity': Color(0xFF60A5FA),
            'concept': Color(0xFF2DD4BF),
            'source': Color(0xFFA78BFA),
            'query': Color(0xFFFB7185),
          },
          Color(0xFF6B7280),
          Color(0xFFE5E7EB),
          Color(0xFF555555),
          Color(0xFF22D3EE),
        )
      : const WikiGraphPalette._(
          {
            'overview': Color(0xFF0891B2),
            'entity': Color(0xFF1D4ED8),
            'concept': Color(0xFF0D9488),
            'source': Color(0xFF7C3AED),
            'query': Color(0xFFE11D48),
          },
          Color(0xFF6B7280),
          Color(0xFF1F2937),
          Color(0xFF9CA3AF),
          Color(0xFF0E7490),
        );

  final Map<String, Color> _typeColors;
  final Color fallbackNode;
  final Color label;
  final Color edge;
  final Color selectedBorder;

  Color node(String pageType) => _typeColors[pageType] ?? fallbackNode;
}
