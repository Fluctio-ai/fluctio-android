import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/message_list.dart';
import 'package:fluctio_android/theme/app_theme.dart';
import 'package:fluctio_android/util/dates.dart';

/// The meta row (time / regenerate) must sit the SAME distance under
/// every assistant bubble. Regression: the last reply's row also
/// carries the regenerate button; with the row center-aligned, the
/// button's taller box floated the whole meta line further from the
/// bubble than on earlier replies (user report 2026-11-23).
void main() {
  Widget harness(List<UiEntry> entries) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: MessageList(state: ChatUiState(entries: entries)),
          ),
        ),
      );

  testWidgets('meta row hugs every bubble at the same distance', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(harness([
      AssistantEntry(key: 'a1', text: '第一条回复', ts: now - 60000),
      // Last reply: its meta row also renders the regenerate button.
      AssistantEntry(key: 'a2', text: '最后一条回复', ts: now),
    ]));
    await tester.pumpAndSettle();

    // Assistant bubbles = the containers tinted secondaryContainer WITH
    // the hairline border (the pull-for-latest pill reuses the fill
    // without a border).
    final bubbles = find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).color == const Color(0xFFF5F5F5) &&
        (w.decoration! as BoxDecoration).border != null);
    expect(bubbles, findsNWidgets(2));

    double gapBelow(Finder time) {
      final tTop = tester.getTopLeft(time).dy;
      final above = <Rect>[
        for (var i = 0; i < bubbles.evaluate().length; i++)
          tester.getRect(bubbles.at(i)),
      ]..sort((a, b) => b.bottom.compareTo(a.bottom));
      final bubble = above.firstWhere((r) => r.bottom <= tTop + 0.01);
      return tTop - bubble.bottom;
    }

    final gap1 = gapBelow(find.text(formatTimeOfDay(
        DateTime.fromMillisecondsSinceEpoch(now - 60000))));
    final gap2 = gapBelow(find.text(
        formatTimeOfDay(DateTime.fromMillisecondsSinceEpoch(now))));
    expect(gap2 - gap1, lessThan(0.5));
  });

  testWidgets('time and regenerate label share one baseline', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(harness([
      AssistantEntry(key: 'a1', text: '回复', ts: now),
    ]));
    await tester.pumpAndSettle();

    // ABSOLUTE baseline positions (global coords): the shared strut
    // aligns the boxes, but a hosting widget can still sink the label
    // by centering it inside a taller box (a Material button's
    // density-based minimumSize did exactly that — visually "next
    // line"). Top-of-widget + in-widget baseline distance must
    // coincide for both texts.
    double absoluteBaseline(Finder f) =>
        tester.getTopLeft(f).dy +
        tester
            .renderObject<RenderParagraph>(f)
            .computeDistanceToActualBaseline(TextBaseline.alphabetic);

    final timeBaseline = absoluteBaseline(find.text(
        formatTimeOfDay(DateTime.fromMillisecondsSinceEpoch(now))));
    final labelBaseline = absoluteBaseline(find.text('重新生成'));
    expect((timeBaseline - labelBaseline).abs(), lessThan(0.5));
  });
}
