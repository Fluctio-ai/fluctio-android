import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/message_list.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// The bubble split: raw text keeps the fence (copy/cache), the rendered
/// bubble shows the stripped prose plus one tappable chip per option.
void main() {
  testWidgets('assistant bubble strips the options block and renders chips',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: MessageList(
            state: ChatUiState(entries: [
              AssistantEntry(
                key: 'a1',
                text: '想先测哪个？\n\n```options\n["查天气", "没事了"]\n```\n',
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('想先测哪个'), findsOneWidget);
    expect(find.text('查天气'), findsOneWidget);
    expect(find.text('没事了'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
