import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/composer.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// The thinking chip must keep the rounded-chip geometry: its border
/// painter spans the whole 36×36 chip (pad + glyph + pad). Regression
/// (user report 2026-11-24): hosting the painter inside the padded
/// container sized the paint area to the bare glyph, collapsing the
/// border into a sliver around the brain icon. Also renders light and
/// dark captures to build/thinking-badge-{light,dark}.png for eyeballing.
void main() {
  Widget harness(bool dark) => MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: SafeArea(
            child: Composer(
              controller: TextEditingController(),
              // sending + no streaming bubble = thinking chip on.
              state: const ChatUiState(phase: TurnPhase.sending),
              pendingImages: const [],
              pendingFiles: const [],
              chatOnly: false,
              readOnly: false,
              readOnlyChannel: '',
              onToggleChatOnly: (_) {},
              onChanged: () {},
              onPickAttachments: () {},
              onRemoveImage: (_) {},
              onRemoveFile: (_) {},
              onSend: () {},
              onSteer: () {},
              onStop: () {},
            ),
          ),
        ),
      );

  Future<Size> pumpAndCapture(WidgetTester tester, String name) async {
    await tester.pumpWidget(harness(name == 'dark'));
    // The badge loops forever — one frame, no settle.
    await tester.pump();

    // Nearest Container ancestor of the glyph = the chip itself; the
    // chip must keep the paperclip button's geometry (user ask: same
    // shape as the attach button — 10 pad + 16 glyph + 10 pad + 1px
    // border each side).
    final chip = find.ancestor(
        of: find.byIcon(LucideIcons.brain), matching: find.byType(Container));
    expect(chip, findsWidgets);
    final size = tester.getSize(chip.first);
    final paperclip = find.ancestor(
        of: find.byIcon(LucideIcons.paperclip), matching: find.byType(Container));
    expect(size.width, tester.getSize(paperclip.first).width,
        reason: 'chip width must match the attach button beside it');
    expect(size.height, 36);

    // PNG encoding needs real async (fake-async env hangs on it).
    await tester.runAsync(() async {
      final image =
          await captureImage(find.byType(Composer).evaluate().first);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/thinking-badge-$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    return size;
  }

  testWidgets('light theme: chip paint area stays 36×36', (tester) async {
    await pumpAndCapture(tester, 'light');
  });

  testWidgets('dark theme: chip paint area stays 36×36', (tester) async {
    await pumpAndCapture(tester, 'dark');
  });
}
