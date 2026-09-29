import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../chat/chat_controller.dart';

/// The chat-route navigation contract in one place: opening or creating a
/// session always routes to `/c/<sessionId>` in the chat branch (back
/// gesture returns to the session list).
void openChatSession(BuildContext context, WidgetRef ref, String agentId, String sessionId) {
  ref.read(chatStoreProvider.notifier).openSession(agentId, sessionId);
  context.go('/c/${Uri.encodeComponent(sessionId)}');
}

/// New chat → immediately route into it.
Future<void> openNewChat(BuildContext context, WidgetRef ref) async {
  final sid = await ref.read(chatStoreProvider.notifier).newChat();
  if (sid.isNotEmpty && context.mounted) {
    context.go('/c/${Uri.encodeComponent(sid)}');
  }
}
