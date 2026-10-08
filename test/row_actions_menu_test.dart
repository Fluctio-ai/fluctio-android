import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/ui/row_actions_menu.dart';

void main() {
  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: const Scaffold(body: Center(child: Text('anchor'))),
      ));

  testWidgets('shows the actions at the touch point, runs after dismiss',
      (tester) async {
    var renamed = false;
    var deleted = false;
    await pumpHost(tester);
    lastPointerDown = const Offset(100, 200);
    // Not awaited: the menu's future completes only when it dismisses,
    // which the taps below trigger.
    unawaited(showRowActionsMenu(tester.element(find.text('anchor')), [
      RowAction(icon: Icons.edit, label: 'Rename', onRun: () => renamed = true),
      RowAction(
          icon: Icons.delete,
          label: 'Delete',
          destructive: true,
          onRun: () => deleted = true),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // The menu is gone before the action runs — pushed routes (editor,
    // confirm dialog) must land on the page, not on top of the menu.
    expect(find.text('Rename'), findsNothing);
    expect(deleted, isTrue);
    expect(renamed, isFalse);
    lastPointerDown = null;
  });

  testWidgets('anchors past the screen edge clamp back inside',
      (tester) async {
    var ran = false;
    await pumpHost(tester);
    lastPointerDown = const Offset(1e6, 1e6);
    unawaited(showRowActionsMenu(tester.element(find.text('anchor')), [
      RowAction(icon: Icons.delete, label: 'Delete', onRun: () => ran = true),
    ]));
    await tester.pumpAndSettle();
    final topLeft = tester.getTopLeft(find.text('Delete'));
    expect(topLeft.dx, lessThan(800));
    expect(topLeft.dy, lessThan(600));

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(ran, isTrue);
    lastPointerDown = null;
  });
}
