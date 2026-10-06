// Lightweight markdown lint for the KB editor — a VSCode-ish check
// layer limited to the constructs that actually break the app's md
// renderer: unclosed code/math fences, unpaired inline math dollars,
// and ragged table separators. Pure functions over lines; the editor
// re-runs this per keystroke (O(lines), documents here are small).

/// Issue kind — message text is resolved by the caller's l10n.
enum MdIssueKind {
  unclosedCodeFence,
  unclosedMathFence,
  oddDollars,
  tableColumns;

  /// True when the document will render broken; warnings are stylistic.
  bool get isError => this != oddDollars;
}

class MdIssue {
  const MdIssue(this.line, this.kind);

  /// 0-based line index the issue is reported on.
  final int line;
  final MdIssueKind kind;

  /// True when the document will render broken; warnings are stylistic.
  bool get isError => kind.isError;

  @override
  bool operator ==(Object other) =>
      other is MdIssue && other.line == line && other.kind == kind;

  @override
  int get hashCode => Object.hash(line, kind);
}

final _codeFence = RegExp(r'^\s{0,3}(```+|~~~+)');
final _mathFence = RegExp(r'^\$\$\s*$');
final _tableSep = RegExp(r'^\s*\|?\s*:?-{3,}.*\|');
final _inlineCode = RegExp(r'`[^`\n]*`');

/// Scans [text] and returns one issue per detected problem, in line
/// order. Fence state ignores everything inside already-open fences
/// (an odd ``` inside a math block doesn't count), mirroring how the
/// renderer actually parses.
List<MdIssue> lintMarkdown(String text) {
  final lines = text.split('\n');
  final issues = <MdIssue>[];
  String? codeMarker; // '```' / '~~~' while inside a fenced code block.
  var inMath = false;
  var mathStart = -1;

  String? headerLine; // previous non-blank line, for table checks.

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    if (codeMarker != null) {
      if (line.trimLeft().startsWith(codeMarker)) codeMarker = null;
      continue;
    }
    if (inMath) {
      if (_mathFence.hasMatch(line)) inMath = false;
      continue;
    }

    final fence = _codeFence.firstMatch(line);
    if (fence != null) {
      codeMarker = fence[1];
      headerLine = null;
      continue;
    }
    if (_mathFence.hasMatch(line)) {
      inMath = true;
      mathStart = i;
      headerLine = null;
      continue;
    }

    // Table: a separator row's pipe count must match the header's.
    if (_tableSep.hasMatch(line) && headerLine != null && headerLine.contains('|')) {
      final headerCols = _pipeCount(headerLine);
      final sepCols = _pipeCount(line);
      if (headerCols != sepCols) {
        issues.add(MdIssue(i, MdIssueKind.tableColumns));
      }
    }

    // Unpaired inline math dollars (excluding inline code spans).
    final stripped = line.replaceAll(_inlineCode, '');
    final dollars = '\$'.allMatches(stripped).length;
    if (dollars.isOdd) {
      issues.add(MdIssue(i, MdIssueKind.oddDollars));
    }

    headerLine = line.trim().isEmpty ? null : line;
  }

  if (codeMarker != null) {
    issues.add(MdIssue(lines.length - 1, MdIssueKind.unclosedCodeFence));
  }
  if (inMath) {
    issues.add(MdIssue(mathStart, MdIssueKind.unclosedMathFence));
  }
  return issues;
}

int _pipeCount(String line) => '|'.allMatches(line).length;
