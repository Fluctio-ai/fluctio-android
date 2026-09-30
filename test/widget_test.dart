import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_controller.dart';
import 'package:fluctio_android/main.dart';
import 'package:fluctio_android/pages/chat/chat_page.dart';

/// Agents pre-resolved (empty) so the chat root renders its static
/// "no agents" view instead of a spinner that never lets pumpAndSettle
/// settle.
class _LoadedAgents extends AgentsController {
  @override
  AgentsState build() => const AgentsState(loaded: true);
}

void main() {
  testWidgets('app root is the chat surface — no bottom tab bar (web parity)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [agentsProvider.overrideWith(_LoadedAgents.new)],
        child: const FluctioApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The bottom navigation (对话/知识库/项目/我的) is gone; navigation
    // lives in the drawer instead.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(ChatPage), findsOneWidget);
    // Test bindings default to en_US.
    expect(find.text('No agents available'), findsOneWidget);
  });
}
