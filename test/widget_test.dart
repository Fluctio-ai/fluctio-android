import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/auth/auth_controller.dart';
import 'package:fluctio_android/auth/auth_state.dart';
import 'package:fluctio_android/chat/chat_controller.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/chat/chat_page.dart';
import 'package:fluctio_android/router.dart';

/// Agents pre-resolved (empty) so the chat root renders its static
/// "no agents" view instead of a spinner that never lets pumpAndSettle
/// settle.
class _LoadedAgents extends AgentsController {
  @override
  AgentsState build() => const AgentsState(loaded: true);
}

/// Auth pre-resolved (loggedIn) so the router's boot gate lets `/` through:
/// the real restore() runs from main(), which this test bypasses — without
/// the override the router parks on /boot forever and ChatPage never mounts.
class _LoggedInAuth extends AuthController {
  @override
  AuthState build() => const AuthState.loggedIn(
      baseUrl: 'http://localhost:1', allowSelfSigned: false, sid: 'test');
}

/// Minimal harness that mounts just the real router. Deliberately NOT
/// FluctioApp: its root-lifetime notification services (server-notification
/// SSE, todo-reminder 15-min periodic timer) activate on loggedIn and their
/// pending timers/network calls would hang pumpAndSettle in the test
/// binding — none of them is what this test is about.
class _RouterHarness extends ConsumerWidget {
  const _RouterHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        routerConfig: ref.watch(routerProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
}

void main() {
  testWidgets('app root is the chat surface — no bottom tab bar (web parity)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentsProvider.overrideWith(_LoadedAgents.new),
          authControllerProvider.overrideWith(_LoggedInAuth.new),
        ],
        child: const _RouterHarness(),
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
