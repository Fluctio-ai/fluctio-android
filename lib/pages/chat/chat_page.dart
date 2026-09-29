import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_engine.dart';
import '../../l10n/app_localizations.dart';
import 'composer.dart';
import 'message_list.dart';
import 'panels.dart';

/// Chat tab: agent picker in the app bar, transcript, composer, and the
/// sessions / todo sheets. The transcript state lives in
/// [chatStoreProvider]; this page only owns input-ephemeral state (text
/// field, pending images).
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final List<String> _pendingImages = [];

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final l = AppLocalizations.of(context);
    try {
      final files = await ImagePicker().pickMultiImage(imageQuality: 70, maxWidth: 1568, limit: 4);
      for (final f in files) {
        if (_pendingImages.length >= 4) break;
        final bytes = await f.readAsBytes();
        final mime = f.mimeType ?? 'image/jpeg';
        setState(() => _pendingImages.add('data:$mime;base64,${base64Encode(bytes)}'));
      }
    } catch (_) {
      if (mounted && l != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatPickImageError)));
      }
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;
    ref
        .read(chatStoreProvider.notifier)
        .send(text, images: List.of(_pendingImages));
    _input.clear();
    setState(_pendingImages.clear);
  }

  void _steer() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    ref.read(chatStoreProvider.notifier).steer(text);
    _input.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agents = ref.watch(agentsProvider);
    final active = ref.watch(chatStoreProvider).active;

    if (!agents.loaded) {
      return Scaffold(appBar: AppBar(title: Text(l.navChat)), body: const Center(child: CircularProgressIndicator()));
    }
    if (agents.agents.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navChat)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(l.chatNoAgent, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.read(agentsProvider.notifier).load(),
                child: Text(l.chatLoadAgents),
              ),
            ],
          ),
        ),
      );
    }

    final selected = agents.selected!;
    return Scaffold(
      appBar: AppBar(
        title: PopupMenuButton<String>(
          initialValue: selected.id,
          onSelected: (id) => ref.read(agentsProvider.notifier).select(id),
          itemBuilder: (_) => [
            for (final a in agents.agents)
              PopupMenuItem(
                value: a.id,
                child: Row(
                  children: [
                    Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                    if (a.model.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(a.model,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(selected.name, style: theme.textTheme.titleMedium),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l.chatTodo,
            onPressed: () => showTodoSheet(context),
            icon: const Icon(Icons.checklist),
          ),
          IconButton(
            tooltip: l.chatSessions,
            onPressed: () => showSessionsSheet(context),
            icon: const Icon(Icons.forum_outlined),
          ),
        ],
      ),
      body: active == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (active.phase == TurnPhase.reconnecting) _ReconnectBanner(hint: active.statusHint),
                Expanded(child: MessageList(state: active)),
                if (active.turnActive && active.awaitingFirstDelta)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(l.chatThinking,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                Composer(
                  controller: _input,
                  state: active,
                  pendingImages: _pendingImages,
                  onChanged: () => setState(() {}),
                  onPickImages: _pickImages,
                  onRemoveImage: (i) => setState(() => _pendingImages.removeAt(i)),
                  onSend: _send,
                  onSteer: _steer,
                  onStop: () => ref.read(chatStoreProvider.notifier).stop(),
                ),
              ],
            ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.wifi_off_outlined, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(
            hint.isEmpty ? l.chatReconnecting : '${l.chatReconnecting} · $hint',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
