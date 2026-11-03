// Quick-reply options: the ```options fenced-block protocol.
//
// Mirrors web/src/lib/reply-options.ts (which mirrors Go
// internal/agent/replyoptions.go) — same caps, same swallow of
// unterminated blocks — so the app bubble, the web bubble and the
// Go-side IM delivery all agree on what the block means.
// Rendering-time split: AssistantEntry.text keeps the raw text
// (copy / long-press / SQLite cache stay lossless); the bubble renders
// the stripped text plus a tappable chip row. Tapping a chip just sends
// that text through the normal composer path (steer while a turn is
// running, send otherwise) — no new reply channel.

import 'dart:convert';

const int _maxCount = 4;
const int _maxRunes = 40;

final RegExp _closedBlockRE = RegExp(r'```options[ \t]*\r?\n([\s\S]*?)\r?\n```');
final RegExp _openBlockRE = RegExp(r'```options[ \t]*\r?\n[\s\S]*');
final RegExp _blankRunRE = RegExp(r'\n{3,}');

/// Splits [raw] into the bubble text (block stripped) and the quick-reply
/// options (max [_maxCount], each trimmed and at most [_maxRunes] code
/// points, deduped). Malformed bodies are stripped but contribute
/// nothing; an unterminated opener (mid-stream) is swallowed whole so
/// raw JSON never flashes.
({String text, List<String> options}) splitReplyOptions(String raw) {
  if (!raw.contains('```options')) return (text: raw, options: const []);

  // Insertion-ordered set: dedupe while keeping first-seen order.
  final options = <String>{};

  var text = raw.replaceAllMapped(_closedBlockRE, (m) {
    try {
      final parsed = jsonDecode(m.group(1)!);
      if (parsed is List) {
        for (final o in parsed) {
          if (o is! String) continue;
          final v = o.trim();
          if (v.isEmpty || v.runes.length > _maxRunes || !options.add(v)) continue;
        }
      }
    } catch (_) {
      // Unparseable body: strip, contribute nothing.
    }
    return '';
  });

  // Unterminated opener (mid-stream): swallow so raw JSON never flashes;
  // the closed-block replace above wins once the fence completes.
  text = text.replaceAll(_openBlockRE, '');
  // Collapse the 3+ blank runs a stripped block leaves behind.
  text = text.replaceAll(_blankRunRE, '\n\n');
  return (text: text.trim(), options: options.take(_maxCount).toList());
}
