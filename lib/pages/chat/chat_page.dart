import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_engine.dart';
import '../../chat/slash_commands.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import 'typing_dots.dart';
import '../../theme/tokens.dart';
import '../app_drawer.dart';
import 'chat_dashboard.dart';
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

  /// Chat-only toggle inside the composer. Sessions that only exist
  /// locally (generated key, no first message yet) can't be toggled —
  /// the PATCH needs a persisted session row.
  Future<void> _toggleChatOnly(BuildContext context, bool on) async {
    final l = AppLocalizations.of(context)!;
    final key = ref.read(chatStoreProvider).activeKey;
    if (key == null) return;
    final sessionId = key.substring(key.indexOf('|') + 1);
    final exists = ref.read(sessionsProvider).value?.any((s) => s.id == sessionId);
    if (exists != true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.chatOnlyNeedsMessage)));
      return;
    }
    try {
      await ref.read(sessionsProvider.notifier).setChatOnly(sessionId, on);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorNetwork)));
      }
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
      return Scaffold(appBar: AppBar(title: Text(l.navChat)), body: const SkeletonListView());
    }
    if (agents.agents.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navChat)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.bot, size: 40, color: theme.colorScheme.outline),
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
    final sessionTitle = ref
        .watch(sessionsProvider)
        .value
        ?.where((s) => s.id == activeSessionId)
        .firstOrNull
        ?.title;
    final activeSession = ref
        .watch(sessionsProvider)
        .value
        ?.where((s) => s.id == activeSessionId)
        .firstOrNull;
    final chatOnly = activeSession?.chatOnly ?? false;
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
                    const Icon(LucideIcons.chevronDown),
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
            icon: const Icon(LucideIcons.listTodo),
          ),
        ],
      ),
      body: active == null
          ? const SkeletonListView(itemCount: 4)
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
                  // Fresh conversation: the dashboard IS the empty state
                  // (web ChatDashboard); typing hides it, any entry
                  // swaps back to the transcript.
                  child: _input.text.isEmpty &&
                          _pendingImages.isEmpty &&
                          !active.turnActive &&
                          !active.historyLoading &&
                          active.entries.isEmpty
                      ? const ChatDashboard()
                      // Keyed by session: entrance-animation bookkeeping lives
                      // in MessageList's state and must reset on switch.
                      : MessageList(
                          key: ValueKey(ref.watch(chatStoreProvider).activeKey), state: active),
                ),
                _SlashPalette(
                  matches: matchSlashCommands(_input.text),
                  enabled: !active.turnActive || _input.text.trim().isNotEmpty,
                  onPick: (cmd) {
                    _input.clear();
                    setState(() {});
                    ref.read(chatStoreProvider.notifier).send(cmd.invoke);
                  },
                ),
                if (active.turnActive && active.awaitingFirstDelta)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      children: [
                        const TypingDots(),
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
                  chatOnly: chatOnly,
                  onToggleChatOnly: (on) => _toggleChatOnly(context, on),
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

/// `/` command palette above the composer — the mobile equivalent of the
/// web composer's slash menu; picking an entry sends it directly.
class _SlashPalette extends StatelessWidget {
  const _SlashPalette({required this.matches, required this.enabled, required this.onPick});

  final List<SlashCommand> matches;
  final bool enabled;
  final ValueChanged<SlashCommand> onPick;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty || !enabled) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 4,
        borderRadius: AppRadius.cardBorder,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 264),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: matches.length,
            itemBuilder: (context, i) {
              final cmd = matches[i];
              return InkWell(
                onTap: () => onPick(cmd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        cmd.invoke,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontFamily: 'monospace', color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cmd.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
          Icon(LucideIcons.wifiOff, size: 14, color: theme.colorScheme.outline),
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
