import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/util/text.dart';

/// Grapheme-safe truncation — see lib/util/text.dart. The mojibake trap:
/// UTF-16 code-unit cuts split surrogate pairs (emoji) in half.
void main() {
  test('long ascii text caps with the ellipsis suffix', () {
    expect(truncateChars('a' * 30, 24), '${'a' * 24}…');
  });

  test('text at or under the cap passes through unchanged', () {
    expect(truncateChars('a' * 24, 24), 'a' * 24);
    expect(truncateChars('a' * 23, 24), 'a' * 23);
    expect(truncateChars('', 24), '');
  });

  test('empty suffix (debug labels)', () {
    expect(truncateChars('a' * 60, 48, suffix: ''), 'a' * 48);
  });

  test('no lone surrogates when an emoji sits at the cap', () {
    // 23 ASCII + 🎉: UTF-16 length 25 — a substring(0, 24) cut keeps the
    // emoji's high half alone; the grapheme cap keeps it whole.
    final s = truncateChars('${'a' * 23}🎉', 24);
    expect(s, '${'a' * 23}🎉');
    expect(s.runes.any((r) => r >= 0xD800 && r <= 0xDFFF), isFalse);
  });
}
