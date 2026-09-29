import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'l10n/app_localizations.dart';
import 'pages/chat_page.dart';
import 'pages/kb_page.dart';
import 'pages/settings_page.dart';
import 'pages/wiki_page.dart';
import 'pages/workflow_page.dart';

/// Bottom-tab navigation — the mobile replacement for the web sidebar:
/// 对话 / 知识库 / Wiki / 工作流 / 设置. Agent and session management live
/// inside the Chat tab.
final appRouter = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => RootShell(shell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const ChatPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/kb', builder: (_, _) => const KbPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/wiki', builder: (_, _) => const WikiPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/workflow', builder: (_, _) => const WorkflowPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsPage())]),
      ],
    ),
  ],
);

class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(
          index,
          // Tapping the active tab pops back to the branch root, like
          // the web sidebar's collapse-to-root behavior.
          initialLocation: index == shell.currentIndex,
        ),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.forum_outlined), selectedIcon: const Icon(Icons.forum), label: l.navChat),
          NavigationDestination(icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: l.navKnowledge),
          NavigationDestination(icon: const Icon(Icons.travel_explore_outlined), selectedIcon: const Icon(Icons.travel_explore), label: l.navWiki),
          NavigationDestination(icon: const Icon(Icons.account_tree_outlined), selectedIcon: const Icon(Icons.account_tree), label: l.navWorkflow),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: l.navSettings),
        ],
      ),
    );
  }
}
