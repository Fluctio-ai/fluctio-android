import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_controller.dart';
import 'package:fluctio_android/chat/chat_engine.dart';
import 'package:fluctio_android/chat/models.dart';
import 'package:fluctio_android/files/agent_files.dart';
import 'package:fluctio_android/files/workspace_files.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/app_shell.dart';
import 'package:fluctio_android/pages/chat/chat_page.dart';
import 'package:fluctio_android/theme/app_theme.dart';

/// Composer focus release (user feedback 2026-11-21): tapping anywhere in
/// the transcript drops the composer's focus — the keyboard otherwise
/// never yields and parks over the conversation.

/// Same fakes as tablet_layout_test: one loaded agent, one active session
/// with a settled entry so the transcript renders MessageList.
class _OneAgent extends AgentsController {
  @override
  AgentsState build() => const AgentsState(
        agents: [AgentInfo(id: 'a1', name: 'Agent One')],
        selectedId: 'a1',
        loaded: true,
      );
}

class _FakeChatStore extends ChatStoreController {
  @override
  ChatStore build() => const ChatStore(
        activeKey: 'a1|s1',
        chats: {
          'a1|s1': ChatUiState(entries: [UserEntry(key: 'u1', text: 'hi')]),
        },
      );
}

void main() {
  testWidgets('tapping the transcript drops the composer focus', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        agentsProvider.overrideWith(_OneAgent.new),
        chatStoreProvider.overrideWith(_FakeChatStore.new),
        workspaceFilesProvider(('a1', 's1'))
            .overrideWith((ref) async => AgentFileListing(const [], const [])),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppShell(path: '/', child: ChatPage()),
      ),
    ));
    await tester.pump();

    // Focus the composer (enterText focuses the field), then tap a blank
    // transcript spot above the reverse list's single bubble.
    await tester.enterText(find.byType(TextField), 'draft');
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull, reason: 'composer field did not take focus');

    await tester.tapAt(const Offset(200, 180));
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, isNot(same(focused)),
        reason: 'tapping the transcript must unfocus the composer');
  });
}
