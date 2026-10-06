import 'package:flutter_test/flutter_test.dart';
import 'package:fluctio_android/wiki/wiki_models.dart';

void main() {
  test('page parses type:slug id, RFC3339 dates, null body', () {
    final p = WikiPageInfo.fromJson({
      'id': 'entity:wal',
      'agent_id': 'a1',
      'page_type': 'entity',
      'slug': 'wal',
      'title': 'WAL',
      'summary': 'Write-ahead logging',
      'source_ids': ['s1'],
      'tags': ['db'],
      'created_at': '2026-10-01T08:00:00Z',
      'updated_at': '2026-10-02T09:30:00Z',
      'revision': 3,
    });
    expect(p.id, 'entity:wal');
    expect(p.pageType, 'entity');
    expect(p.slug, 'wal');
    expect(p.title, 'WAL');
    expect(p.summary, 'Write-ahead logging');
    expect(p.body, isNull);
    expect(p.updatedAt, DateTime.parse('2026-10-02T09:30:00Z'));
    expect(p.revision, 3);
  });

  test('page tolerates missing optional fields', () {
    final p = WikiPageInfo.fromJson({'id': 'u1', 'page_type': 'concept', 'slug': 'x', 'title': 'X'});
    expect(p.summary, '');
    expect(p.revision, 0);
    expect(p.updatedAt, isNull);
  });

  test('stats parses counts', () {
    final s = WikiStatsInfo.fromJson({
      'page_counts': {'entity': 12, 'concept': 3},
      'total_pages': 15,
      'total_edges': 40,
    });
    expect(s.pageCounts['entity'], 12);
    expect(s.totalPages, 15);
    expect(s.totalEdges, 40);
  });

  test('graph parses nodes and edges; null edges tolerated', () {
    final g = WikiGraphInfo.fromJson({
      'nodes': [
        {
          'id': 'entity:a',
          'page_type': 'entity',
          'slug': 'a',
          'title': 'A',
        },
        {
          'id': 'concept:b',
          'page_type': 'concept',
          'slug': 'b',
          'title': 'B',
        },
      ],
      'edges': [
        {'src_page_id': 'entity:a', 'dst_page_id': 'concept:b', 'relation': 'related', 'weight': 1},
      ],
    });
    expect(g.nodes.length, 2);
    expect(g.edges.single.src, 'entity:a');
    expect(g.edges.single.dst, 'concept:b');

    final empty = WikiGraphInfo.fromJson({'nodes': [], 'edges': null});
    expect(empty.nodes, isEmpty);
    expect(empty.edges, isEmpty);
  });
}
