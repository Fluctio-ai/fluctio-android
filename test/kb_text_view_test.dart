import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart' show SliverGptMarkdown;
import 'package:val_latex_flutter/val_latex_flutter.dart' show Math;

import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/kb/kb_text_view_page.dart';

/// The workspace/KB md viewer's lazy path: a formula-heavy document
/// must render segment-by-segment (only visible formulas build), and
/// scrolling must keep building without exceptions.
void main() {
  // 80 paragraphs of six inline-math lines plus a block formula each
  // (~720 lines → many segments). Inline and block branches both run
  // under the lazy sliver list.
  String formulaHeavyDoc() => [
        for (var i = 0; i < 80; i++)
          [
            for (var j = 0; j < 6; j++)
              'P$i line $j holds \$x^{$j}\$ and \$E_$i = mc^2\$ here.',
            '\$\$',
            r'\int_0^1 x\,dx = \frac{1}{2}',
            '\$\$',
          ].join('\n'),
      ].join('\n\n');

  Widget host(String content) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: KbTextViewPage(
            title: 'doc',
            loadContent: () async => content,
          ),
        ),
      );

  testWidgets('long formula-heavy document builds lazily', (tester) async {
    await tester.pumpWidget(host(formulaHeavyDoc()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The lazy sliver path is taken…
    expect(find.byType(SliverGptMarkdown), findsOneWidget);
    // …and only the visible segments' math built — 960 formulas exist
    // in the source; a one-shot build would have all of them mounted.
    final built = find.byType(Math).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(960));
  });

  testWidgets('scrolling to the end keeps rendering formulas', (tester) async {
    await tester.pumpWidget(host(formulaHeavyDoc()));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.textContaining('P79 line 5'),
      find.byType(Scrollable),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsWidgets);
  });
}
