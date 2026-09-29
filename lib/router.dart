import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_state.dart';
import 'l10n/app_localizations.dart';
import 'pages/chat/chat_page.dart';
import 'pages/kb_page.dart';
import 'pages/profile_page.dart';
import 'pages/projects_page.dart';
import 'pages/setup_page.dart';
import 'pages/wiki_page.dart';
import 'pages/workflow_page.dart';

/// Bottom-tab navigation per the mobile prototype: 对话 / 知识库 / 项目 /
/// 我的. Wiki and Workflows are pushed sub-routes (from the KB grid and
/// 我的/抽屉 respectively); `/setup` (address + login) sits outside the
/// shell; the redirect gates everything on the auth state machine.
final routerProvider = Provider<GoRouter>((ref) {
  // GoRouter wants a Listenable; bridge auth-state changes into it.
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final onSetup = state.matchedLocation == '/setup';
      switch (auth.status) {
        case AuthStatus.loading:
          return null;
        case AuthStatus.loggedIn:
          return onSetup ? '/' : null;
        case AuthStatus.needSetup:
        case AuthStatus.loggedOut:
          return onSetup ? null : '/setup';
      }
    },
    routes: [
      GoRoute(path: '/setup', builder: (_, _) => const SetupPage()),
      GoRoute(path: '/wiki', builder: (_, _) => const WikiPage()),
      GoRoute(path: '/workflow', builder: (_, _) => const WorkflowPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => RootShell(shell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const ChatPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/kb', builder: (_, _) => const KbPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/me', builder: (_, _) => const ProfilePage())]),
        ],
      ),
    ],
  );
});

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
          NavigationDestination(icon: const Icon(Icons.folder_outlined), selectedIcon: const Icon(Icons.folder), label: l.navProjects),
          NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: l.navMe),
        ],
      ),
    );
  }
}
