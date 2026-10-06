import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math;

import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/chat/markdown.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// The full transcript pipeline (gpt_markdown + theme + shared
/// stylesheet + mermaid builder): every structural markdown shape the
/// user's docs contain must render without exception. Ported from the
/// flutter_markdown era — these cases are the renderer regression net.
void main() {
  Widget themedHost(String data, ThemeData theme) => MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: SingleChildScrollView(
              child: transcriptMarkdown(context, data),
            ),
          ),
        ),
      );

  for (final (name, theme) in [('dark', AppTheme.dark()), ('light', AppTheme.light())]) {
    testWidgets('mixed inline and block math renders ($name)', (tester) async {
      await tester.pumpWidget(themedHost(
        // Adjacent literals, not '+', per lint.
        r'Inline $E = mc^2$ here.'
        '\n\n'
        r'$$\frac{a}{b} + \sum_{i=0}^{n} x_i$$',
        theme,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(Math), findsNWidgets(2));
    });
  }

  // Real-world md shapes: math nested in headings, lists, tables,
  // blockquotes, code blocks, and edge fences.
  const structuralCases = <String, String>{
    'heading': '# Formula \$E = mc^2\$ inside a heading\n',
    'bullet list': '- item with \$a_i\$ inline\n- plain item\n',
    'ordered list': '1. first \$x_1\$\n2. second\n',
    'table': '| name | formula |\n| --- | --- |\n| energy | \$E = mc^2\$ |\n',
    'blockquote': '> quoted \$\\alpha + \\beta\$\n',
    'code block': '```\ncode \$x\$ untouched\n```\n',
    'unclosed math fence': '\$\$\n\\frac{a}{b} no closing fence\n',
    'empty block': '\$\$\n\$\$\n',
    'adjacent blocks': '\$\$\na\n\$\$\n\$\$\nb\n\$\$\n',
    'block after list': '- one\n- two\n\n\$\$\n\\int_0^1 x\\,dx\n\$\$\n',
    'text around block': 'before\ntext\n\$\$\n\\pi\n\$\$\nafter\n',
    'strikethrough': '~~struck \$q\$ out~~\n',
    'mermaid block': '```mermaid\ngraph TD; A-->B;\n```\n',
    'wide table': '| a | b |\n| --- | --- |\n| 长文本内容测试宽度 | v |\n',
  };

  for (final entry in structuralCases.entries) {
    testWidgets('structural: ${entry.key}', (tester) async {
      await tester.pumpWidget(themedHost(entry.value, AppTheme.dark()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  // Real user doc (workspace md) that crashed on device in the
  // flutter_markdown era: dense inline math with \div \times \cdot \frac,
  // < and > inside math, \ space, CJK brackets, ✓ marks, numbered items.
  const userDoc = r'''#### T02-A-11（答案：13次）

【错答分析】空白未做。按"净位移"列不等式，注意第 $n$ 次倒退速度为 $12.5n$，累积为等差和。

【解题步骤】
1. 唐老鸭跑完10000米需 $10000\div100=100$ 分钟；要获胜需米老鼠在100分钟内到不了10000米。
2. 设发出 $k$ 次指令，米老鼠前进时间 $=100-k$ 分钟；第 $n$ 次指令使其以 $125\times\frac{10n}{100}=12.5n$ 米/分倒退1分钟，累计倒退 $12.5\times\frac{k(k+1)}{2}$。
3. 终点处净位移 $=125(100-k)-12.5\cdot\frac{k(k+1)}{2}<10000$，即 $k^2+21k-400>0$。
4. 试算：$k=12$：$125\times88-12.5\times78=11000-975=10025>10000$（米老鼠先到，输）；$k=13$：$125\times87-12.5\times91=10875-1137.5=9737.5<10000$（赢）。

验算：$k=13$ 时 $\ 169+273-400=42>0$ ✓（$k=12$ 时 $=-4<0$）。将指令安排在前段发出，米老鼠位置单调升到最后，100分钟时不到10000米即可保证全程未到 ✓。

【提示】每次指令使米老鼠损失"1分钟前进＋一次倒退位移"，倒退速度逐次加快。''';

  testWidgets('user workspace doc renders without exception', (tester) async {
    await tester.pumpWidget(themedHost(userDoc, AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('bare comparison operators in TeX', (tester) async {
    await tester
        .pumpWidget(themedHost(r'$9737.5<10000$ and $k^2+21k-400>0$', AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsNWidgets(2));
  });

  testWidgets('control space normalizes to thin space without fallback text',
      (tester) async {
    // `\ ` must be rewritten to `\,` by latexWorkaround — raw control
    // space is a missing-glyph box.
    await tester.pumpWidget(themedHost(r'$a\ b$ and $wT\ \Rightarrow\ T=5$', AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsNWidgets(2));
  });

  // Single-line $$...$$ blocks (common in AI output) must become block
  // math with no stray dollar signs.
  testWidgets(r'single-line dollar fences render as block math', (tester) async {
    await tester.pumpWidget(themedHost(
      r'$$\frac53=\frac{20}{30-w}+\frac{20+\frac{20w}{30-w}}{30} \Rightarrow 30=\frac{600+20w}{30-w} \Rightarrow w=6$$',
      AppTheme.dark(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('renders inline math', (tester) async {
    await tester.pumpWidget(themedHost(r'The identity $E = mc^2$ holds.', AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('renders block math between dollar fences', (tester) async {
    await tester.pumpWidget(themedHost(
        'before\n\n\$\$\n\\frac{a}{b} + \\sum_{i=0}^{n} x_i\n\$\$\n\nafter',
        AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('unparseable TeX degrades without crashing', (tester) async {
    await tester.pumpWidget(themedHost(r'Broken: $\notARealCommand{x}$ end', AppTheme.dark()));
    await tester.pumpAndSettle();
    // No exception may escape to the framework; the raw LaTeX or a
    // notice must be visible instead.
    expect(tester.takeException(), isNull);
  });

  testWidgets('regular text with a lone dollar sign stays untouched', (tester) async {
    await tester
        .pumpWidget(themedHost(r'Price: \$5 and \$10 costs five dollars.', AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('native \\( \\) and \\[ \\] delimiters work too', (tester) async {
    await tester.pumpWidget(
        themedHost(r'Inline \(a+b\) and block \[\frac{a}{b}\] formulas.', AppTheme.dark()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsWidgets);
  });

  // The routing hook for openChatLink: urls arrive verbatim —
  // https links, gateway paths and workspace relatives alike. Must go
  // through onLinkTap (tap-time), never a span builder (build-time —
  // the regression this guards: every rebuild used to fire the route).
  testWidgets('onLinkTap never fires during build', (tester) async {
    final urls = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: SingleChildScrollView(
            child: transcriptMarkdown(
              context,
              'See [docs](https://example.com/a) and [local](/workspace/a.md).',
              onTapLink: urls.add,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(urls, isEmpty); // Build and settle must not fire the route.
    // NOTE: an actual tap firing is not simulatable in the widget-test
    // env (custom RenderBidiParagraph hit-testing); verified on device.
  });

  testWidgets('streaming rebuild with growing tail stays consistent', (tester) async {
    await tester.pumpWidget(themedHost(r'Answer: $x^2$ and ', AppTheme.dark()));
    for (var i = 0; i < 5; i++) {
      await tester.pumpWidget(
          themedHost(r'Answer: $x^2$ and more text $y_i^2$ ' * (i + 1), AppTheme.dark()));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsWidgets);
  });
}
