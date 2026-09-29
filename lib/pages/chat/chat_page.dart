import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_engine.dart';
import '../../l10n/app_localizations.dart';
import '../app_drawer.dart';
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

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final List<String> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding kills the subscribe socket; the chat store reconnects
    // on resume so live events (and anything missed) flow again without a
    // restart.
    if (state == AppLifecycleState.resumed) {
      ref.read(chatStoreProvider.notifier).onAppResumed();
    }
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
    final store = ref.watch(chatStoreProvider);
    final activeSessionId = store.activeKey?.substring(store.activeKey!.indexOf('|') + 1);
    // Sub-line = the open session's title, so switching sessions from the
    // drawer gives immediate visual confirmation (empty/new sessions show
    // "New chat").
    final sessionTitle = ref
        .watch(sessionsProvider)
        .value
        ?.where((s) => s.id == activeSessionId)
        .firstOrNull
        ?.title;
    final subtitle = activeSessionId == null
        ? selected.model
        : (sessionTitle == null || sessionTitle.isEmpty ? l.chatNew : sessionTitle);
    return Scaffold(
      drawer: const AppDrawer(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(selected.name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
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
        ],
      ),
      body: active == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (kDebugMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'dbg f=${active.debugFrames} last=${active.debugLastEvent} '
                      'ph=${active.phase.name} seq=${active.lastSeq}\n'
                      '${active.debugTypeCounts.entries.map((e) => '${e.key}:${e.value}').join(' ')}\n'
                      'bus=${active.debugLastBus}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 10,
                      ),
                    ),
                  ),
                if (active.phase == TurnPhase.reconnecting) _ReconnectBanner(hint: active.statusHint),
                Expanded(
                  // Keyed by session: entrance-animation bookkeeping lives
                  // in MessageList's state and must reset on switch.
                  child: MessageList(key: ValueKey(ref.watch(chatStoreProvider).activeKey), state: active),
                ),
                if (!active.turnActive && !active.historyLoading && active.entries.isEmpty)
                  _QuickSuggestions(onSend: (text) {
                    ref.read(chatStoreProvider.notifier).send(text);
                  }),
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

class _QuickSuggestions extends StatelessWidget {
  const _QuickSuggestions({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chips = [l.chatSuggest1, l.chatSuggest2, l.chatSuggest3];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          label: Text(chips[i], style: TextStyle(fontSize: 13, color: theme.colorScheme.onSecondaryContainer)),
          backgroundColor: theme.colorScheme.secondaryContainer,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
          onPressed: () => onSend(chips[i]),
        ),
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
