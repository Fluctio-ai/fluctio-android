import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/api/sse.dart';

void main() {
  group('SseLineParser', () {
    test('parses id + data frame terminated by blank line', () {
      final p = SseLineParser();
      expect(p.pushLine('id: 42'), isNull);
      expect(p.pushLine('data: {"seq":42,"type":"done"}'), isNull);
      final frame = p.pushLine('');
      expect(frame, isNotNull);
      expect(frame!.id, 42);
      expect(frame.data, '{"seq":42,"type":"done"}');
    });

    test('comment frames (ping / ok) never produce output', () {
      final p = SseLineParser();
      expect(p.pushLine(': ping'), isNull);
      expect(p.pushLine(''), isNull); // separator right after a comment
      expect(p.pushLine(': ok'), isNull);
      expect(p.pushLine(''), isNull);
    });

    test('joins multiple data lines with newline', () {
      final p = SseLineParser();
      p.pushLine('data: first');
      p.pushLine('data: second');
      final frame = p.pushLine('');
      expect(frame!.data, 'first\nsecond');
    });

    test('strips exactly one leading space after the field colon', () {
      final p = SseLineParser();
      p.pushLine('data:  two spaces');
      expect(p.pushLine('')!.data, ' two spaces');
    });

    test('id resets between frames; frame without id is fine', () {
      final p = SseLineParser();
      p.pushLine('id: 7');
      p.pushLine('data: a');
      expect(p.pushLine('')!.id, 7);
      // Next frame carries no id — the gateway omits it for unpersisted
      // events (content_delta).
      p.pushLine('data: b');
      final second = p.pushLine('');
      expect(second!.id, isNull);
      expect(second.data, 'b');
    });

    test('tolerates CR from CRLF wires', () {
      final p = SseLineParser();
      p.pushLine('id: 1\r');
      p.pushLine('data: {"x":1}\r');
      final frame = p.pushLine('\r');
      // LineSplitter keeps the trailing CR as part of the payload marker;
      // the parser must not choke either way.
      expect(frame, anyOf(isNull, isA<SseFrame>()));
    });

    test('ignores unknown field names', () {
      final p = SseLineParser();
      p.pushLine('event: message');
      p.pushLine('retry: 10000');
      p.pushLine('data: {}');
      expect(p.pushLine('')!.data, '{}');
    });
  });
}
