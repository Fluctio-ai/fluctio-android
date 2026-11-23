import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/message_list.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// The bubble split: raw text keeps the fence (copy/cache), the rendered
/// bubble shows the stripped prose plus one tappable chip per option.
/// Chips stay live on the latest reply and go stale once a newer user
/// turn starts (rendered disabled — the transcript keeps the record).
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

  testWidgets('assistant bubble strips the options block and renders chips',
      (tester) async {
    await tester.pumpWidget(harness(const [
      AssistantEntry(
        key: 'a1',
        text: '想先测哪个？\n\n```options\n["查天气", "没事了"]\n```\n',
      ),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('想先测哪个'), findsOneWidget);
    expect(find.text('查天气'), findsOneWidget);
    expect(find.text('没事了'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chips on the latest assistant reply stay tappable',
      (tester) async {
    await tester.pumpWidget(harness(const [
      AssistantEntry(
        key: 'a1',
        text: '想先测哪个？\n\n```options\n["查天气"]\n```\n',
      ),
    ]));
    await tester.pumpAndSettle();

    final chip = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '查天气'));
    expect(chip.onPressed, isNotNull);
  });

  testWidgets('chips go stale once a newer user turn starts', (tester) async {
    await tester.pumpWidget(harness(const [
      AssistantEntry(
        key: 'a1',
        text: '想先测哪个？\n\n```options\n["查天气"]\n```\n',
      ),
      UserEntry(key: 'u1', text: '我自己打字问别的'),
    ]));
    await tester.pumpAndSettle();

    // Still rendered (the transcript keeps the record) but disabled —
    // tapping must not send/steer from a stale bubble.
    final chip = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '查天气'));
    expect(chip.onPressed, isNull);
  });
}
