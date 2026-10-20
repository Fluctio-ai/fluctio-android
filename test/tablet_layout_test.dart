import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_controller.dart';
import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/chat/models.dart';
import 'package:fluctio_android/files/agent_files.dart';
import 'package:fluctio_android/files/workspace_files.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/app_drawer.dart';
import 'package:fluctio_android/pages/app_shell.dart';
import 'package:fluctio_android/pages/chat/chat_page.dart';
import 'package:fluctio_android/pages/chat/workspace_panel.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// One loaded agent, selected — ChatPage proceeds past its empty states.
class _OneAgent extends AgentsController {
  @override
  AgentsState build() => const AgentsState(
        agents: [AgentInfo(id: 'a1', name: 'Agent One')],
        selectedId: 'a1',
        loaded: true,
      );
}

/// An active session with one settled user entry — the transcript renders
/// MessageList (not the dashboard) and the workspace panel gets a scope.
class _FakeChatStore extends ChatStoreController {
  @override
  ChatStore build() => const ChatStore(
        activeKey: 'a1|s1',
        chats: {
          'a1|s1': ChatUiState(entries: [UserEntry(key: 'u1', text: 'hi')]),
        },
      );
}

/// Same session, plus a settled write_file tool call — the produced-file
/// card should resolve against the session scope prefix and render.
class _FakeChatStoreWithTool extends ChatStoreController {
  @override
  ChatStore build() => const ChatStore(
        activeKey: 'a1|s1',
        chats: {
          'a1|s1': ChatUiState(entries: [
            UserEntry(key: 'u1', text: 'write me a file'),
            ToolEntry(
              key: 't1',
              name: 'write_file',
              arguments: '{"path": "a.md"}',
              result: 'Written 3 bytes',
            ),
          ]),
        },
      );
}

/// Tablet landscape / phone adaptation of the app shell + chat surface:
/// wide tablet embeds the permanent sidebar (AppShell) and docks the
/// workspace panel (default open); phone keeps both out.
void main() {
  /// Pumps AppShell(path: '/') around ChatPage — the same composition the
  /// ShellRoute produces — with the given store fake.
  Widget app({required ChatStoreController Function() store}) {
    return ProviderScope(
      overrides: [
        agentsProvider.overrideWith(_OneAgent.new),
        chatStoreProvider.overrideWith(store),
        workspaceFilesProvider(('a1', 's1'))
            .overrideWith((ref) async => AgentFileListing(const [], const [])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppShell(path: '/', child: ChatPage()),
      ),
    );
  }

  void setSurface(WidgetTester tester, Size physical, double dpr) {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = dpr;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('tablet landscape: sidebar embedded + workspace panel docked open',
      (tester) async {
    // 1280x800 logical — shortestSide 800 ≥ 600, width ≥ 1000.
    setSurface(tester, const Size(2560, 1600), 2.0);
    await tester.pumpWidget(app(store: _FakeChatStore.new));
    await tester.pump();

    expect(find.byType(WorkspacePanel), findsOneWidget);
    expect(find.byType(AppDrawer), findsOneWidget);
    // Embedded sidebar — no modal Drawer is built until opened.
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('phone portrait: no panel, no embedded sidebar', (tester) async {
    // 400x800 logical — compact.
    setSurface(tester, const Size(800, 1600), 2.0);
    await tester.pumpWidget(app(store: _FakeChatStore.new));
    await tester.pump();

    expect(find.byType(WorkspacePanel), findsNothing);
    expect(find.byType(AppDrawer), findsNothing);
  });

  testWidgets('tablet portrait: sidebar embedded, panel stays hidden', (tester) async {
    // 800x1280 logical — tablet, but width < 1000 keeps the chat single
    // column (panel only docks in landscape-width layouts).
    setSurface(tester, const Size(1600, 2560), 2.0);
    await tester.pumpWidget(app(store: _FakeChatStore.new));
    await tester.pump();

    expect(find.byType(AppDrawer), findsOneWidget);
    expect(find.byType(WorkspacePanel), findsNothing);
  });

  testWidgets('write_file tool card surfaces the produced file inline',
      (tester) async {
    setSurface(tester, const Size(800, 1600), 2.0); // phone layout
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentsProvider.overrideWith(_OneAgent.new),
          chatStoreProvider.overrideWith(_FakeChatStoreWithTool.new),
          // The live listing is the exists-oracle: a.md sits under the
          // session scope, so the card must resolve to the prefixed path.
          workspaceFilesProvider(('a1', 's1')).overrideWith((ref) async =>
              AgentFileListing(
                  [AgentFile.forTest('sessions/s1/a.md', const ['sessions/s1/'])],
                  const ['sessions/s1/'])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppShell(path: '/', child: ChatPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('a.md'), findsOneWidget);
    expect(find.text('3B'), findsOneWidget);
  });
}
