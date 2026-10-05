import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/composer.dart';

/// IM-channel (read-only) sessions: the composer goes inert and only the
/// web read-only-safe slash commands still send (chat-screen.tsx:1408-1414).
void main() {
  Future<void> pumpComposer(WidgetTester tester,
      {String text = '', required bool readOnly, VoidCallback? onSend}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Composer(
          controller: TextEditingController(text: text),
          state: const ChatUiState(),
          pendingImages: const [],
          pendingFiles: const [],
          chatOnly: false,
          readOnly: readOnly,
          onToggleChatOnly: (_) {},
          onChanged: () {},
          onPickAttachments: () {},
          onRemoveImage: (_) {},
          onRemoveFile: (_) {},
          onSend: onSend ?? () {},
          onSteer: () {},
          onStop: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('read-only composer shows the IM hint, send stays inert for plain text',
      (tester) async {
    var sent = false;
    await pumpComposer(tester, text: 'hello', readOnly: true, onSend: () => sent = true);
    final l = AppLocalizations.of(tester.element(find.byType(Composer)))!;
    expect(find.text(l.chatImReadOnlyHint), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pump();
    expect(sent, isFalse);
  });

  testWidgets('read-only composer still sends the safe slash commands', (tester) async {
    var sent = false;
    await pumpComposer(tester, text: '/status', readOnly: true, onSend: () => sent = true);

    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pump();
    expect(sent, isTrue);
  });

  testWidgets('composing session keeps the normal hint', (tester) async {
    await pumpComposer(tester, readOnly: false);
    final l = AppLocalizations.of(tester.element(find.byType(Composer)))!;
    expect(find.text(l.chatEmpty), findsOneWidget);
    expect(find.text(l.chatImReadOnlyHint), findsNothing);
  });
}
