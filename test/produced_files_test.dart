import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/produced_files.dart';

/// Port-of-web extractProducedFiles coverage (chat-screen.tsx:268):
/// write_file / deliver_file / image_gen records, scope-prefix resolution
/// with and without the exists-oracle, system-file and absolute-path
/// skips, dedupe.
void main() {
  const prefixes = ['projects/p1/s1/', 'projects/p1/'];
  final existing = {
    'projects/p1/s1/report.md',
    'projects/p1/shared.md',
    'projects/p1/s1/imagegen_1_a.png',
  };
  bool exists(String p) => existing.contains(p);

  test('write_file resolves against the first existing scope prefix', () {
    final out = extractProducedFiles(
      'write_file',
      '{"path": "report.md"}',
      'Written 123 bytes',
      prefixes,
      exists: exists,
    );
    expect(out, hasLength(1));
    expect(out.single.path, 'projects/p1/s1/report.md');
    expect(out.single.size, 123);
  });

  test('write_file without oracle takes the most-specific prefix', () {
    final out = extractProducedFiles(
      'write_file',
      '{"path": "draft.md"}',
      'Written 5 bytes',
      prefixes,
    );
    expect(out.single.path, 'projects/p1/s1/draft.md');
  });

  test('write_file skips non-write results, absolute paths, system files', () {
    expect(
      extractProducedFiles('write_file', '{"path":"a.md"}', 'Error: denied', prefixes),
      isEmpty,
    );
    expect(
      extractProducedFiles('write_file', '{"path":"/etc/passwd"}', 'Written 1 bytes', prefixes),
      isEmpty,
    );
    expect(
      extractProducedFiles('write_file', '{"path":"SOUL.md"}', 'Written 1 bytes', prefixes),
      isEmpty,
    );
  });

  test('deliver_file uses dest, falls back to basename(src)', () {
    final out = extractProducedFiles(
      'deliver_file',
      '{"src": "/tmp/out/shared.md", "dest": "shared.md"}',
      'Delivered 42 bytes to /data/shared.md',
      prefixes,
      exists: exists,
    );
    expect(out.single.path, 'projects/p1/shared.md');
    expect(out.single.size, 42);

    final noDest = extractProducedFiles(
      'deliver_file',
      '{"src": "/tmp/out/chart.png"}',
      'Already in visible workspace: /x/chart.png',
      prefixes,
      exists: (_) => false,
    );
    // No candidate exists → most-specific prefix as the best guess.
    expect(noDest.single.path, 'projects/p1/s1/chart.png');
    expect(noDest.single.size, isNull);
  });

  test('"../" escape resolves against the SHALLOWEST prefix (project root)', () {
    final out = extractProducedFiles(
      'write_file',
      '{"path": "../shared.md"}',
      'Written 9 bytes',
      prefixes,
      exists: exists,
    );
    expect(out.single.path, 'projects/p1/shared.md');
  });

  test('image_gen pulls every /workspace/ path from the result markdown', () {
    final out = extractProducedFiles(
      'image_gen',
      '{}',
      'Done\n![](/workspace/imagegen_1_a.png)',
      prefixes,
      exists: exists,
    );
    expect(out.single.path, 'projects/p1/s1/imagegen_1_a.png');
  });

  test('dedupes repeats within one call; other tools produce nothing', () {
    final twice = extractProducedFiles(
      'write_file',
      '{"path": "report.md"}',
      'Written 1 bytes',
      prefixes,
      exists: exists,
    );
    expect(twice, hasLength(1));
    expect(extractProducedFiles('exec', '{}', 'ok', prefixes), isEmpty);
    expect(
      extractProducedFiles('write_file', 'not-json', 'Written 1 bytes', prefixes),
      isEmpty,
    );
  });
}
