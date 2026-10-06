import 'package:flutter_test/flutter_test.dart';
import 'package:fluctio_android/wiki/wiki_links.dart';

void main() {
  test('plain link resolves title via resolver', () {
    final out = rewriteWikiLinks(
        'See [[entity:wal]] for details.',
        (id) => {'entity:wal': 'WAL'}[id] ?? id);
    expect(out, 'See [WAL](wikilink:entity:wal) for details.');
  });

  test('alias wins over resolved title', () {
    final out =
        rewriteWikiLinks('[[entity:wal|日志先行]]', (_) => 'should-not-be-used');
    expect(out, '[日志先行](wikilink:entity:wal)');
  });

  test('unknown target falls back to the raw id', () {
    final out = rewriteWikiLinks('[[concept:x]]', (id) => id);
    expect(out, '[concept:x](wikilink:concept:x)');
  });

  test('non-wiki text and markdown links stay untouched', () {
    const src = 'Plain [[brackets]] without shape and [md](https://x) stay.';
    expect(rewriteWikiLinks(src, (id) => id), src);
  });

  test('wikiLinkTarget splits scheme', () {
    expect(wikiLinkTarget('wikilink:entity:wal'), 'entity:wal');
    expect(wikiLinkTarget('https://example.com'), isNull);
  });
}
