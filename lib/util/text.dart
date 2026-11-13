import 'package:characters/characters.dart';

/// Grapheme-safe truncation for one-liners (notification bodies, note
/// titles, debug labels). Dart strings are UTF-16 — a code-unit substring
/// can split a surrogate pair mid-emoji, and the lone half renders as
/// mojibake once encoded (native notification text) or shown (labels).
/// Capping rides characters (grapheme clusters) so emoji stay whole.
String truncateChars(String s, int max, {String suffix = '…'}) {
  final chars = s.characters;
  return chars.length > max ? '${chars.take(max).string}$suffix' : s;
}
