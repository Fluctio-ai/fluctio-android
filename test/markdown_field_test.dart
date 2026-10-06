import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:re_editor/re_editor.dart'
    show
        CodeEditor,
        CodeLineEditingController,
        CodeLineSelection,
        DefaultCodeLineNumber;

import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/kb/markdown_field.dart';

/// MarkdownField in isolation: the VSCode-style editing surface with
/// highlight, line-number gutter, and a lint strip driven by the
/// controller's text (cursor moves must not lint or notify).
void main() {
  Widget host(CodeLineEditingController c,
      {ValueChanged<String>? onChanged}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MarkdownField(
            controller: c, autofocus: false, onChanged: onChanged),
      ),
    );
  }

  testWidgets('renders the editor with a line-number gutter', (tester) async {
    final c = CodeLineEditingController.fromText('# hello\n\nbody');
    addTearDown(c.dispose);
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CodeEditor), findsOneWidget);
    // The gutter is self-painted (LeafRenderObjectWidget), not Text.
    expect(find.byType(DefaultCodeLineNumber), findsOneWidget);
  });

  testWidgets('lint strip appears for an unclosed fence', (tester) async {
    final c = CodeLineEditingController.fromText('```\ncode');
    addTearDown(c.dispose);
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
  });

  testWidgets('clean document shows no lint strip', (tester) async {
    final c = CodeLineEditingController.fromText('plain text\n\nall good');
    addTearDown(c.dispose);
    await tester.pumpWidget(host(c));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(LucideIcons.triangleAlert), findsNothing);
  });

  testWidgets('text changes notify once, cursor moves do not', (tester) async {
    final c = CodeLineEditingController.fromText('ok \$a\$');
    addTearDown(c.dispose);
    var notified = 0;
    await tester.pumpWidget(host(c, onChanged: (_) => notified++));
    await tester.pumpAndSettle();
    expect(notified, 0); // initial setup notifications are text-neutral

    c.text = 'broken \$a';
    await tester.pumpAndSettle();
    expect(notified, 1);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);

    // A pure selection change must not re-notify or re-lint.
    c.selection = const CodeLineSelection.collapsed(index: 0, offset: 2);
    await tester.pumpAndSettle();
    expect(notified, 1);
  });
}
