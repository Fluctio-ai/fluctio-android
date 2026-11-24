import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/ui/tap_to_unfocus.dart';

/// User reports 2026-11-24: on the search-list pages the IME stayed up
/// after tapping outside the field, and kept focus through list
/// scrolls. Both gestures must release the field's focus.
void main() {
  Widget harness(FocusNode focus) => MaterialApp(
        home: Scaffold(
          body: TapToUnfocus(
            child: Column(
              children: [
                TextField(focusNode: focus),
                Expanded(
                  child: ListView(
                    children: const [SizedBox(height: 800)],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('tap on empty list space releases focus', (tester) async {
    final focus = FocusNode();
    await tester.pumpWidget(harness(focus));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    // A tap the ListView itself doesn't claim bubbles to the wrapper.
    await tester.tap(find.byType(ListView));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('a scroll drag releases focus', (tester) async {
    final focus = FocusNode();
    await tester.pumpWidget(harness(focus));
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });
}
