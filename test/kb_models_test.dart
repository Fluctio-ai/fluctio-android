import 'package:fluctio_android/kb/kb_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// KBSource wire shape (docs/api/API.md §7, internal/kb/types.go).
void main() {
  test('insights_generated_at parses the deep-read flag (empty = unprocessed)', () {
    final s = KbSource.fromJson({
      'id': 's1',
      'title': 't',
      'insights_generated_at': '2026-11-21T08:00:00Z',
    });
    expect(s.insightsGeneratedAt, '2026-11-21T08:00:00Z');
    expect(KbSource.fromJson({'id': 's2', 'title': 't'}).insightsGeneratedAt, '');
  });
}
