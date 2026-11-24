import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/message_list.dart';
import 'package:fluctio_android/pages/chat/typing_dots.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// Regression (user report 2026-11-24): while a turn streamed, sending
/// another message (steer) rendered a "Thinking…" caption INSIDE the
/// user bubble — it read as text the user had sent, and the refreshed
/// transcript (which never carries it) made it vanish. The pending
/// state must stay dots-only, never on-bubble text.
void main() {
  testWidgets('a pending steer bubble carries dots, not "Thinking…" text',
      (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: MessageList(state: ChatUiState(entries: [
            UserEntry(key: 'u1', text: '第一条', ts: now - 60000),
            UserEntry(key: 'u2', text: '追问', pendingSteer: true, ts: now),
          ])),
        ),
      ),
    ));
    // TypingDots loops forever — a single frame, no settle.
    await tester.pump();

    expect(find.text('追问'), findsOneWidget);
    expect(find.text('思考中…'), findsNothing);
    expect(find.byType(TypingDots), findsOneWidget);
  });
}
