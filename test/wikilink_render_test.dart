import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/chat/markdown.dart';
import 'package:fluctio_android/theme/app_theme.dart';
import 'package:fluctio_android/wiki/wiki_links.dart';

/// Sentinel for the wiki-link scheme lesson (2026-10-06): gpt_markdown
/// 1.3.1 renders `[label](custom-scheme:…)` as literal source text on
/// device while mailto/tel/relative/absolute URLs all link (verified
/// against the running app; plusparse itself parses both to MdLink, so
/// the gate is in the render layer). Wiki links therefore use the web's
/// relative `/wiki-link/` form — this test guards the two halves we can
/// assert cheaply: the parser builds MdLink for it, and the widget
/// pipeline doesn't throw. If gpt_markdown ever starts accepting custom
/// schemes again, this is where you'd notice.
void main() {
  test('plusparse builds MdLink for the /wiki-link/ form', () {
    final doc = Plusparse.parse('关联 [数据库](/wiki-link/entity:database)。');
    final urls = <String>[];
    void walk(dynamic n) {
      if (n is MdLink) urls.add(n.url);
      try {
        final kids = n.children;
        if (kids is List) kids.forEach(walk);
      } catch (_) {} // leaf nodes (MdText etc.) carry no children
    }
    doc.children.forEach(walk);
    expect(urls, contains('/wiki-link/entity:database'));
  });

  testWidgets('rewritten body renders through the shared bundle unharmed',
      (tester) async {
    final body = rewriteWikiLinks(
        '# 标题\n\n关联 [[entity:database]]。', (id) => '数据库');
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: SingleChildScrollView(child: transcriptMarkdown(context, body)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
