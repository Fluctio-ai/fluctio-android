import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/turn_notify.dart';

/// Notification-body truncation rule. The mojibake case: Dart strings are
/// UTF-16, and a naive substring can cut a surrogate pair (emoji, rare
/// CJK ext-B+ chars) in half — the lone half survives into the native
/// notification text and renders as garbage once encoded for the OS.
void main() {
  group('turnNotifySnippet', () {
    test('long ascii line caps at 80 with an ellipsis', () {
      expect(turnNotifySnippet('a' * 100), '${'a' * 80}…');
    });

    test('multi-line reply keeps only the first line', () {
      expect(turnNotifySnippet('首行\n第二行\n第三行'), '首行');
    });

    test('exact-80 graphemes pass through untouched', () {
      expect(turnNotifySnippet('a' * 80), 'a' * 80);
    });

    test('no lone surrogates when an emoji sits at the cap', () {
      // 79 ASCII + 🎉: UTF-16 length 81 — a substring(0, 80) cut keeps
      // the emoji's high half alone. Grapheme capping keeps it whole.
      final s = turnNotifySnippet('${'a' * 79}🎉');
      expect(s, '${'a' * 79}🎉');
      expect(_hasLoneSurrogate(s), isFalse,
          reason: 'cap boundary must not split the emoji');
    });

    test('no lone surrogates when the cut lands between emoji', () {
      // 78 ASCII + three 🎉: every cap position keeps whole emoji.
      final s = turnNotifySnippet('${'a' * 78}🎉🎉🎉');
      expect(_hasLoneSurrogate(s), isFalse);
      expect(s, endsWith('…'));
    });
  });
}

bool _hasLoneSurrogate(String s) =>
    s.runes.any((r) => r >= 0xD800 && r <= 0xDFFF);
