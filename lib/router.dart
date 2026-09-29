import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_state.dart';
import 'l10n/app_localizations.dart';
import 'pages/chat/chat_page.dart';
import 'pages/kb/article_detail_page.dart';
import 'pages/kb/articles_page.dart';
import 'pages/kb/bookmarks_page.dart';
import 'pages/kb/card_review_page.dart';
import 'pages/kb/cards_page.dart';
import 'pages/kb/flash_page.dart';
import 'pages/kb/notes_page.dart';
import 'pages/kb/todos_page.dart';
import 'pages/kb_page.dart';
import 'pages/profile_page.dart';
import 'pages/projects_page.dart';
import 'pages/session_list_page.dart';
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
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const SessionListPage()),
            GoRoute(path: '/c/:sid', builder: (_, _) => const ChatPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/kb', builder: (_, _) => const KbPage(), routes: [
              GoRoute(path: 'articles', builder: (_, _) => const KbArticlesPage(), routes: [
                GoRoute(
                  path: ':sid',
                  builder: (_, state) => KbArticleDetailPage(
                    sourceId: state.pathParameters['sid'] ?? '',
                    title: state.uri.queryParameters['title'] ?? '',
                  ),
                ),
              ]),
              GoRoute(path: 'flash', builder: (_, _) => const KbFlashPage()),
              GoRoute(path: 'todos', builder: (_, _) => const KbTodosPage()),
              GoRoute(path: 'bookmarks', builder: (_, _) => const KbBookmarksPage()),
              GoRoute(path: 'cards', builder: (_, _) => const KbCardsPage(), routes: [
                GoRoute(path: 'review', builder: (_, _) => const KbCardReviewPage()),
              ]),
              GoRoute(path: 'notes', builder: (_, _) => const KbNotesPage()),
            ]),
          ]),
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
          NavigationDestination(icon: const Icon(LucideIcons.messageCircle), selectedIcon: const Icon(Icons.forum), label: l.navChat),
          NavigationDestination(icon: const Icon(LucideIcons.bookOpen), selectedIcon: const Icon(Icons.menu_book), label: l.navKnowledge),
          NavigationDestination(icon: const Icon(LucideIcons.folder), selectedIcon: const Icon(Icons.folder), label: l.navProjects),
          NavigationDestination(icon: const Icon(LucideIcons.circleUser), selectedIcon: const Icon(Icons.person), label: l.navMe),
        ],
      ),
    );
  }
}
