import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const ChatPage({super.key, this.openSid = '', this.jumpSeq});

  /// Session to open on entry (the /c/:sid route parameter; '' = keep
  /// whatever the store holds). Consumed once — later rebuilds of the
  /// same element don't re-open.
  final String openSid;

  /// #seq-N anchor handed to the transcript (diary deep links).
  final int? jumpSeq;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final List<String> _pendingImages = [];
  bool _routeSessionOpened = false;
  DateTime? _lastBackAt;

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

  /// Chat-only local overrides (web chatOnlyLocal parity): the chip is
  /// flippable on a brand-new chat before any session row exists; the
  /// override rides params.chatOnly on the first send and the sync
  /// method below persists it once the row lands.
  final Map<String, bool> _chatOnlyLocal = {};

  /// Chat-only toggle inside the composer — optimistic flip, any time.
  Future<void> _toggleChatOnly(BuildContext context, bool on) async {
    final key = ref.read(chatStoreProvider).activeKey;
    if (key == null) return;
    final sessionId = key.substring(key.indexOf('|') + 1);
    setState(() => _chatOnlyLocal[sessionId] = on);
    _syncChatOnly();
  }

  /// Single writer (web parity): whenever a local override meets its
  /// persisted session row, push it once and drop the override —
  /// overrides for chats with no row yet just wait; they ride
  /// params.chatOnly on send. A failed push drops the override too,
  /// reverting the chip to the row's truth.
  void _syncChatOnly() {
    for (final e in _chatOnlyLocal.entries.toList()) {
      final row = ref
          .read(sessionsProvider)
          .value
          ?.where((s) => s.id == e.key)
          .firstOrNull;
      if (row == null) continue;
      void drop() {
        if (mounted) setState(() => _chatOnlyLocal.remove(e.key));
      }

      if (row.chatOnly == e.value) {
        drop(); // already persisted (params channel) — just clear
        continue;
      }
      () async {
        try {
          await ref.read(sessionsProvider.notifier).setChatOnly(e.key, e.value);
        } catch (_) {}
        drop();
      }();
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
    HapticFeedback.lightImpact();
    // Ride the local chat-only override on the first send (the row
    // doesn't exist yet for a PATCH; the server persists params.chatOnly).
    final key = ref.read(chatStoreProvider).activeKey;
    final pendingOnly =
        key == null ? null : _chatOnlyLocal[key.substring(key.indexOf('|') + 1)];
    ref.read(chatStoreProvider.notifier).send(text,
        images: List.of(_pendingImages), chatOnly: pendingOnly);
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
    // Session rows landing (first send persisted) drive the chat-only
    // override sync — the listener pattern from the Riverpod race notes.
    ref.listen(sessionsProvider, (_, _) => _syncChatOnly());

    if (!agents.loaded) {
      return Scaffold(appBar: AppBar(title: Text(l.navChat)), body: const SkeletonListView());
    }
    // /c/:sid entry (deep links, session list): open the routed session
    // once agents are resolvable. Post-frame — openSession writes store
    // state synchronously and this frame is still mid-build.
    if (!_routeSessionOpened && widget.openSid.isNotEmpty && agents.selectedId != null) {
      _routeSessionOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(chatStoreProvider.notifier).openSession(agents.selectedId!, widget.openSid);
        }
      });
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
    final chatOnly = activeSessionId == null
        ? false
        : (_chatOnlyLocal[activeSessionId] ?? (activeSession?.chatOnly ?? false));
    final titleText = activeSessionId == null
        ? l.chatNew
        : (sessionTitle == null || sessionTitle.isEmpty ? l.chatNew : sessionTitle);
    final subText =
        '${selected.name}${selected.model.isEmpty ? '' : ' · ${selected.model}'}';
    return PopScope(
      // Double-back-to-exit on the root: one stray tap shouldn't kill
      // the transcript mid-session. A drawer open consumes back first
      // (Navigator local history), so this only sees the bare root.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackAt != null && now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackAt = now;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.exitAgain), duration: const Duration(seconds: 2)));
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        // Swipe-right-to-open-drawer from mid-screen (ticket 13, revised
        // per user feedback): the default ~20px left-edge zone is hard to
        // hit and sits inside gesture-nav's system-back strip. A 55%-wide
        // start zone lets a right thumb drag from the middle — clear of
        // both system back edges. The arena still awards vertical-dominant
        // scrolls to the transcript.
        drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
        appBar: AppBar(
          // The session title leads (user preference); agent switching
          // lives in the drawer header. Title gutters come from the
          // global AppBarTheme.
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titleText,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium),
              Text(subText,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          actions: activeSessionId == null || activeSessionId.isEmpty
              ? null
              : [
                  IconButton(
                    tooltip: l.chatFiles,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showFilesSheet(context),
                    icon: const Icon(LucideIcons.folderOpen),
                  ),
                  IconButton(
                    tooltip: l.chatTodo,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => showTodoSheet(context),
                    icon: const Icon(LucideIcons.listTodo),
                  ),
                ],
        ),
        body: active == null
            ? const SkeletonListView(itemCount: 4)
            : Column(
                children: [
                  if (active.phase == TurnPhase.reconnecting) _ReconnectBanner(hint: active.statusHint),
                  Expanded(
                    // Soft fade where the surface meets the composer:
                    // content dissolves into the background instead of
                    // hitting the card's hard top edge (user feedback).
                    // A fixed-height background-gradient strip rather
                    // than a full-viewport ShaderMask — same look, no
                    // saveLayer on the streaming hot path.
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _input.text.isEmpty &&
                                  _pendingImages.isEmpty &&
                                  !active.turnActive &&
                                  !active.historyLoading &&
                                  active.entries.isEmpty
                              ? const ChatDashboard()
                              // Keyed by session: entrance-animation bookkeeping lives
                              // in MessageList's state and must reset on switch.
                              : MessageList(
                                  key: ValueKey(ref.watch(chatStoreProvider).activeKey),
                                  state: active,
                                  jumpSeq: widget.jumpSeq),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          // Tall enough to swallow a whole resting line
                          // (body 15sp × 1.7 lh ≈ 25px, more with system
                          // text scaling). Only the top ~15% fades — a
                          // long translucent ramp kept parked text
                          // readable inside the band and read as content
                          // bleeding through (user feedback, twice); the
                          // rest stays fully opaque.
                          height: 34,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    theme.scaffoldBackgroundColor.withValues(alpha: 0),
                                    theme.scaffoldBackgroundColor,
                                    theme.scaffoldBackgroundColor,
                                  ],
                                  stops: const [0.0, 0.15, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
