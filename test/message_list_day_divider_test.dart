import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/message_list.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// Day-divider pills + bare time-of-day bubble labels (web formatDayDivider
/// / formatTime parity): a pill precedes the first turn of each new
/// calendar day, per-bubble labels carry HH:mm only.
void main() {
  // Local timestamps relative to "now" so the day comparison matches
  // regardless of the machine's timezone.
  int ts(int dayOffset, int hour, int minute) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: dayOffset));
    return d.add(Duration(hours: hour, minutes: minute)).millisecondsSinceEpoch;
  }

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

  testWidgets('a new calendar day inserts a divider, labels are bare HH:mm',
      (tester) async {
    await tester.pumpWidget(harness([
      UserEntry(key: 'u1', text: '昨天那条', ts: ts(1, 9, 15)),
      UserEntry(key: 'u2', text: '今天这条', ts: ts(0, 10, 30)),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsOneWidget); // divider marks the NEW day's first turn
    expect(find.text('昨天'), findsNothing); // the session's first turn owns no divider
    expect(find.text('10:30'), findsOneWidget);
    expect(find.text('09:15'), findsOneWidget);
  });

  testWidgets('same-day turns stay divider-free', (tester) async {
    await tester.pumpWidget(harness([
      UserEntry(key: 'u1', text: '第一条', ts: ts(0, 9, 15)),
      UserEntry(key: 'u2', text: '第二条', ts: ts(0, 10, 30)),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsNothing);
    expect(find.text('昨天'), findsNothing);
    expect(find.text('10:30'), findsOneWidget);
  });
}
