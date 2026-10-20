import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/markdown.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// normalizeMarkdownBlocks — the pre-render pass that fixes LLM output
/// shapes gpt_markdown's GFM parser rejects: a table glued to the
/// preceding paragraph gains the blank line GFM requires; setext H1
/// becomes ATX; fenced code is never touched.
void main() {
  test('glued table gains a blank line before it', () {
    expect(
      normalizeMarkdownBlocks('结论：\n| a | b |\n| --- | --- |\n| 1 | 2 |'),
      '结论：\n\n| a | b |\n| --- | --- |\n| 1 | 2 |',
    );
  });

  test('already-separated table is untouched', () {
    const md = 'para\n\n| a |\n| --- |\n| 1 |';
    expect(normalizeMarkdownBlocks(md), md);
  });

  test('table glued to another table row is untouched (no previous prose)', () {
    const md = '| a | b |\n| --- | --- |';
    expect(normalizeMarkdownBlocks(md), md);
  });

  test('alignment colons still count as separator', () {
    expect(
      normalizeMarkdownBlocks('x\n| a |\n| :---: |\n| 1 |'),
      'x\n\n| a |\n| :---: |\n| 1 |',
    );
  });

  test('separator-looking line after prose without pipe does nothing', () {
    const md = 'plain text\nnot a table here';
    expect(normalizeMarkdownBlocks(md), md);
  });

  test('pipes inside a fenced code block are never separated', () {
    const md = 'text\n```\n| a | b |\n| --- | --- |\n```';
    expect(normalizeMarkdownBlocks(md), md);
  });

  test('setext H1 becomes ATX H1', () {
    expect(
      normalizeMarkdownBlocks('标题\n======\nbody'),
      '# 标题\nbody',
    );
  });

  test('setext dashes are left alone (hr ambiguity)', () {
    const md = 'text\n---\nmore';
    expect(normalizeMarkdownBlocks(md), md);
  });

  test('fast path: no pipe and no equals returns input unchanged', () {
    const md = '# plain\ndocument';
    expect(normalizeMarkdownBlocks(md), md);
  });

  testWidgets('end-to-end: glued table renders as a Table widget through chatTranscript',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: SingleChildScrollView(
            // The exact shape the user hit: LLM emits the table right
            // under its lead-in sentence, no blank line.
            child: chatTranscript(context, '对比如下：\n| 项 | 值 |\n| --- | --- |\n| a | 1 |\n'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
  });
}
