import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/util/markdown_lint.dart';

void main() {
  test('clean document has no issues', () {
    expect(lintMarkdown('# Title\n\ntext with \$x^2\$ math\n\n```\ncode\n```\n'), isEmpty);
    expect(lintMarkdown(''), isEmpty);
  });

  test('unclosed code fence reports the last line', () {
    final issues = lintMarkdown('text\n\n```\ncode');
    expect(issues, hasLength(1));
    expect(issues.single.kind, MdIssueKind.unclosedCodeFence);
    expect(issues.single.isError, isTrue);
    expect(issues.single.line, 3); // last line of the document
  });

  test('unclosed math fence reports the opening line', () {
    final issues = lintMarkdown('a\n\n\$\$\n\\frac{1}{2}\n\nmore');
    expect(issues, hasLength(1));
    expect(issues.single.kind, MdIssueKind.unclosedMathFence);
    expect(issues.single.line, 2); // the $$ opener
  });

  test('odd inline dollars warn per line', () {
    final issues = lintMarkdown('broken \$x math\n\nok \$a\$\n');
    expect(issues, hasLength(1));
    expect(issues.single.kind, MdIssueKind.oddDollars);
    expect(issues.single.isError, isFalse);
    expect(issues.single.line, 0);
  });

  test('dollars inside code fences and inline code are ignored', () {
    expect(lintMarkdown('```\ncode \$ not math\n```\n'), isEmpty);
    expect(lintMarkdown('a `code \$span` b\n'), isEmpty);
  });

  test('math fence swallows stray backticks inside it', () {
    // An odd ``` inside a $$ block must not open a code fence.
    expect(lintMarkdown('\$\$\na ``` b\n\$\$\n'), isEmpty);
  });

  test('table separator column mismatch is an error', () {
    final issues = lintMarkdown('| a | b | c |\n| --- | --- |\n| 1 | 2 | 3 |');
    expect(issues, hasLength(1));
    expect(issues.single.kind, MdIssueKind.tableColumns);
    expect(issues.single.line, 1); // the separator row
    expect(issues.single.isError, isTrue);
  });

  test('matching table is clean', () {
    expect(lintMarkdown('| a | b | c |\n| --- | --- | --- |\n| 1 | 2 | 3 |'), isEmpty);
  });

  test('separator after blank line (no header) is ignored', () {
    expect(lintMarkdown('para\n\n| --- | --- |\n'), isEmpty);
  });
}
