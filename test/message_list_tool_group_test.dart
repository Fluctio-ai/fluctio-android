import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/message_list.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// Tool groups (web ToolRoundsBundle parity): a run of consecutive tool
/// entries renders as ONE collapsible card with an aggregate header; a
/// lone tool call keeps the flat per-call card. Settled results only in
/// the pumpAndSettle tests — running tools carry looping animations
/// (TypingDots / spinner) that never settle.
void main() {
  Widget harness(List<UiEntry> entries, {Set<String> open = const {}}) =>
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: MessageList(
                state: ChatUiState(entries: entries, openToolGroups: open)),
          ),
        ),
      );

  testWidgets('consecutive tool calls collapse into one aggregate card',
      (tester) async {
    await tester.pumpWidget(harness([
      const ToolEntry(key: 'tc-a', name: 'exec', result: 'r'),
      const ToolEntry(key: 'tc-b', name: 'write_file', result: 'r'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('在 1 轮中使用了 2 个工具'), findsOneWidget);
    // Collapsed by default: the per-call rows stay hidden.
    expect(find.text('exec'), findsNothing);
    expect(find.text('write_file'), findsNothing);
  });

  testWidgets('a lone tool call keeps the flat per-call card', (tester) async {
    await tester.pumpWidget(harness([
      const ToolEntry(key: 'tc-a', name: 'exec', result: 'r'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('exec'), findsOneWidget);
    expect(find.text('在 1 轮中使用了 1 个工具'), findsNothing);
  });

  testWidgets('opening the group reveals one row per call', (tester) async {
    await tester.pumpWidget(harness([
      const ToolEntry(key: 'tc-a', name: 'exec', result: 'ok'),
      const ToolEntry(key: 'tc-b', name: 'write_file', result: 'ok'),
    ], open: {'tc-a'}));
    await tester.pumpAndSettle();

    expect(find.text('exec'), findsOneWidget);
    expect(find.text('write_file'), findsOneWidget);
  });

  testWidgets('a run split by assistant text forms separate groups',
      (tester) async {
    await tester.pumpWidget(harness([
      const ToolEntry(key: 'tc-a', name: 'exec', result: 'r'),
      const ToolEntry(key: 'tc-b', name: 'exec', result: 'r'),
      const AssistantEntry(key: 'a1', text: '中间的说明'),
      const ToolEntry(key: 'tc-c', name: 'exec', result: 'r'),
    ]));
    await tester.pumpAndSettle();

    // Two groups (2-call bundle + lone card), plus the text bubble.
    expect(find.text('在 1 轮中使用了 2 个工具'), findsOneWidget);
    expect(find.text('exec'), findsOneWidget); // the lone flat card
    expect(find.text('中间的说明'), findsOneWidget);
  });

  testWidgets('while running, the header carries the progress counts',
      (tester) async {
    await tester.pumpWidget(harness([
      const ToolEntry(key: 'tc-a', name: 'exec', result: 'r'),
      const ToolEntry(key: 'tc-b', name: 'exec'),
    ]));
    // No pumpAndSettle: the running spinner loops forever by design.
    await tester.pump();
    await tester.pump();

    expect(find.text('正在运行工具…（1/2，共 1 轮）'), findsOneWidget);
  });
}
