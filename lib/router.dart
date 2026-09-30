import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'auth/auth_state.dart';
import 'pages/chat/chat_page.dart';
import 'pages/kb/article_detail_page.dart';
import 'pages/kb/articles_page.dart';
import 'pages/kb/bookmarks_page.dart';
import 'pages/kb/card_review_page.dart';
import 'pages/kb/cards_page.dart';
import 'pages/kb/flash_page.dart';
import 'pages/kb/notes_page.dart';
import 'pages/kb/todos_page.dart';
import 'pages/profile_page.dart';
import 'pages/session_list_page.dart';
import 'pages/setup_page.dart';
import 'pages/wiki_page.dart';
import 'pages/workflow_page.dart';

/// Web-parity navigation: no bottom bar — the chat surface IS the app
/// root (a fresh conversation, like `/agents/<id>/chat/`), everything
/// else is reached from the drawer (knowledge entries, projects, chat
/// history) or pushed from there (wiki / workflow / settings). The
/// redirect gates everything on the auth state machine; `/setup`
/// (address + login) sits outside.
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
      GoRoute(path: '/', builder: (_, _) => const ChatPage()),
      GoRoute(path: '/c/:sid', builder: (_, _) => const ChatPage()),
      // Full conversation list — the drawer's "see all chats" target
      // (web /agents/<id>/chats).
      GoRoute(path: '/chats', builder: (_, _) => const SessionListPage()),
      // /kb is the articles view itself (web /agents/<id>/knowledge/);
      // the other KB views hang off it like the web's sibling routes.
      GoRoute(path: '/kb', builder: (_, _) => const KbArticlesPage(), routes: [
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
      GoRoute(path: '/wiki', builder: (_, _) => const WikiPage()),
      GoRoute(path: '/workflow', builder: (_, _) => const WorkflowPage()),
      GoRoute(path: '/me', builder: (_, _) => const ProfilePage()),
    ],
  );
});
