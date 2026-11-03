import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/reply_options.dart';

void main() {
  group('splitReplyOptions', () {
    test('no block: text returned as-is (no trim)', () {
      final r = splitReplyOptions('  plain text\n\nno fence here  ');
      expect(r.text, '  plain text\n\nno fence here  ');
      expect(r.options, isEmpty);
    });

    test('closed block: text stripped, options parsed', () {
      final r = splitReplyOptions('想先测哪个？\n\n```options\n["查天气", "没事了"]\n```\n');
      expect(r.text, '想先测哪个？');
      expect(r.options, ['查天气', '没事了']);
    });

    test('malformed JSON: block stripped, no options', () {
      final r = splitReplyOptions('a\n\n```options\n[broken\n```\nb');
      expect(r.text, 'a\n\nb');
      expect(r.options, isEmpty);
    });

    test('non-string / empty / whitespace items skipped', () {
      final r = splitReplyOptions('```options\n[1, null, {"x":1}, "  ", "ok"]\n```');
      expect(r.options, ['ok']);
    });

    test('items trimmed then deduped (within and across blocks)', () {
      final r = splitReplyOptions(
          '```options\n[" a ", "a"]\n```\nmid\n```options\n["a", "b"]\n```');
      expect(r.options, ['a', 'b']);
      expect(r.text, 'mid');
    });

    test('over-40-rune items skipped; rune (not UTF-16 unit) semantics', () {
      final long = 'a' * 41;
      final emoji39 = '😀' * 39; // 39 code points, 78 UTF-16 units
      final emoji41 = '😀' * 41;
      final r = splitReplyOptions(
          '```options\n["$long", "$emoji39", "$emoji41", "ok"]\n```');
      expect(r.options, [emoji39, 'ok']);
    });

    test('caps at 4 options', () {
      final r = splitReplyOptions('```options\n["1", "2", "3", "4", "5", "6"]\n```');
      expect(r.options, ['1', '2', '3', '4']);
      expect(r.text, isEmpty);
    });

    test('unterminated opener swallowed (mid-stream, raw JSON never flashes)', () {
      final r = splitReplyOptions('正文\n\n```options\n["发个语音播报", "查今');
      expect(r.text, '正文');
      expect(r.options, isEmpty);
    });

    test('unterminated opener after a closed block leaves the closed one intact', () {
      final r = splitReplyOptions('```options\n["a"]\n```\ntail\n```options\n["b');
      expect(r.text, 'tail');
      expect(r.options, ['a']);
    });

    test('3+ blank runs left by stripping collapse to one blank line', () {
      final r = splitReplyOptions('para one\n\n```options\n["a"]\n```\n\n\n\npara two');
      expect(r.text, 'para one\n\npara two');
    });

    test('CRLF fences and trailing spaces after the info string parse', () {
      final r = splitReplyOptions('q\r\n\r\n```options \r\n["a"]\r\n```\r\n');
      expect(r.text, 'q');
      expect(r.options, ['a']);
    });

    test('block in the middle: sides join with collapsed blank line', () {
      final r = splitReplyOptions('before\n\n```options\n["a"]\n```\n\nafter');
      expect(r.text, 'before\n\nafter');
    });
  });
}
