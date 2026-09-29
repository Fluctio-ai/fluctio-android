import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_controller.dart';
import 'package:fluctio_android/main.dart';

/// Agents pre-resolved (empty) so the Chat tab renders its static
/// "no agents" view instead of a spinner that never lets pumpAndSettle
/// settle.
class _LoadedAgents extends AgentsController {
  @override
  AgentsState build() => const AgentsState(loaded: true);
}

void main() {
  testWidgets('renders the 5-tab shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [agentsProvider.overrideWith(_LoadedAgents.new)],
        child: const FluctioApp(),
      ),
    );
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
