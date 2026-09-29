import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:fluctio_android/chat/math_render.dart';

void main() {
  Widget host(String data) => MaterialApp(
        home: Scaffold(
          body: MarkdownBody(
            data: data,
            extensionSet: md.ExtensionSet.gitHubWeb,
            inlineSyntaxes: mathInlineSyntaxes,
            blockSyntaxes: mathBlockSyntaxes,
            builders: mathBuilders,
          ),
        ),
      );

  testWidgets('renders inline math', (tester) async {
    await tester.pumpWidget(host(r'The identity $E = mc^2$ holds.'));
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('renders block math between dollar fences', (tester) async {
    const dollar = '\$\$';
    await tester.pumpWidget(
        host('before\n\n$dollar\n\\frac{a}{b} + \\sum_{i=0}^{n} x_i\n$dollar\n\nafter'));
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('unparseable TeX falls back to the raw LaTeX text', (tester) async {
    await tester.pumpWidget(host(r'Broken: $\notARealCommand{x}$ end'));
    await tester.pumpAndSettle();
    // The Math widget may stay as the shell — what matters is the raw
    // LaTeX being visible and no exception escaping to the framework.
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text(r'\notARealCommand{x}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('regular text with a lone dollar sign stays untouched', (tester) async {
    await tester.pumpWidget(host('It costs 5 dollars.'));
    await tester.pumpWidget(host(r'Price: \$5 and \$10'));
    await tester.pumpAndSettle();
    expect(find.byType(Math), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
