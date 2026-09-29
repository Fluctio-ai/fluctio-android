import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/main.dart';

void main() {
  testWidgets('renders the 5-tab shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FluctioApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    // Test bindings default to en_US, so the nav labels resolve in English.
    // "Chat" appears twice (tab label + ChatPage AppBar title), the rest once.
    expect(find.text('Chat'), findsNWidgets(2));
    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Wiki'), findsOneWidget);
    expect(find.text('Workflows'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
