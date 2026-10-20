import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_engine.dart';
import '../../chat/models.dart';
import '../../chat/slash_commands.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/breakpoints.dart';
import '../../ui/pane_divider.dart';
import '../../ui/load_states.dart';
import '../../theme/tokens.dart';
import '../app_drawer.dart';
import '../../router.dart';
import '../../share/share_receiver.dart';
import 'chat_dashboard.dart';
import 'composer.dart';
import 'message_list.dart';
import 'panels.dart';
import 'workspace_panel.dart';

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

class _ChatPageState extends ConsumerState<ChatPage>
    with WidgetsBindingObserver, RouteAware {
  final _input = TextEditingController();
  final List<String> _pendingImages = [];
  final List<PendingAttachment> _pendingFiles = [];

  /// Shared cap for the vision images + workspace files strips.
  static const _maxAttachments = 8;

  /// One-file ceiling. The multipart upload itself streams, but the
  /// picked file lives in memory as bytes + a base64 data URL until the
  /// send fires — 50MB is where that peaks near 200MB of heap.
  static const _maxFileBytes = 50 * 1024 * 1024;

  /// Whole-strip ceiling (approximated from data-URL length) — keeps the
  /// combined in-memory payload from ballooning across many files.
  static const _maxTotalBytes = 110 * 1024 * 1024;
  bool _routeSessionOpened = false;

  /// Docked workspace panel width (tablet split layout). Right-anchored;
  /// the drag handle adjusts it. A ValueNotifier keeps per-frame drag
  /// rebuilds scoped to the panel box — the transcript/composer subtree
  /// doesn't rebuild per pointer-move.
  final ValueNotifier<double> _panelWidth = ValueNotifier(380);

  void _onPanelDrag(double dx) {
    // Right-ANCHORED panel: the divider is its left edge, so dragging
    // right (positive dx) narrows it — the mirror of the left-anchored
    // master-detail lists.
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width * 0.5).clamp(300.0, 640.0);
    _panelWidth.value = (_panelWidth.value - dx).clamp(300.0, maxW);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RouteAware registration needs the route, which only exists here.
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<void>);
    // Catch up on a share that arrived while this page wasn't listening
    // (build's ref.listen only fires on changes, never replays current
    // state).
    _checkPendingShare();
  }

  /// Gatekeeper for inbound shares: one still awaiting a choice goes to
  /// the picker; one targeted at the open session is absorbed into the
  /// composer here (exactly once). Only fires on a genuine entry to this
  /// page — a go_router rebuild re-creates a stale ChatPage beneath a
  /// pushed route, and that instance must not push the picker again.
  void _checkPendingShare() {
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    final share = ref.read(pendingShareProvider);
    if (share == null) return;
    if (share.targetKey == null) {
      // Awaiting a destination (e.g. login just completed under a share
      // that arrived while logged out) — hand it to the picker.
      context.push('/share-target');
      return;
    }
    _absorbShare(share);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    _panelWidth.dispose();
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

  /// Popped back onto the chat surface (todos / wiki / any pushed page
  /// above) — a turn that was still streaming gets its subscribe
  /// connection re-anchored; a settled transcript re-enters as-is.
  @override
  void didPopNext() => ref.read(chatStoreProvider.notifier).resumeIfTurning();

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

  /// Image extensions route into the vision `images` channel; the rest
  /// become workspace `attachments`. Aligned with the web picker, which
  /// has no accept filter at all (chat-screen.tsx:3398).
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'bmp'};

  /// Re-encoded to fit the vision budget (raw camera files are huge);
  /// formats where a jpeg re-encode loses animation/alpha ship as-is.
  static const _reencodeExtensions = {'jpg', 'jpeg', 'heic', 'heif', 'bmp'};

  /// Common non-image types so data URLs carry a real content type; the
  /// server mostly keys off the filename, so the fallback is harmless.
  static const _mimeByExt = {
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'csv': 'text/csv',
    'json': 'application/json',
    'xml': 'application/xml',
    'html': 'text/html',
    'zip': 'application/zip',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'mp4': 'video/mp4',
  };

  Future<void> _pickAttachments() async {
    final l = AppLocalizations.of(context);
    try {
      // 10.x API — 11.x drops .platform but assumes the host enables
      // AGP built-in Kotlin, which this project deliberately doesn't
      // (gradle.properties android.builtInKotlin=false).
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return; // user dismissed the picker
      String? notice;
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        if (_pendingImages.length + _pendingFiles.length >= _maxAttachments) {
          notice = l?.chatAttachLimit;
          break;
        }
        if (f.size > _maxFileBytes) {
          notice = l?.chatFileTooLarge(f.name);
          continue;
        }
        if (_pendingBytes() + f.size > _maxTotalBytes) {
          notice = l?.chatAttachTotalTooLarge;
          continue;
        }
        final ext = f.extension?.toLowerCase() ?? '';
        if (_imageExtensions.contains(ext)) {
          var payload = bytes;
          var mime = 'image/${ext == 'jpg' ? 'jpeg' : ext}';
          if (_reencodeExtensions.contains(ext)) {
            final out = await _reencode(f.path);
            if (out != null) {
              payload = out;
              mime = 'image/jpeg';
            }
          }
          setState(() => _pendingImages.add('data:$mime;base64,${base64Encode(payload)}'));
        } else {
          setState(() => _pendingFiles.add(PendingAttachment(
            name: f.name,
            url: 'data:${_mimeByExt[ext] ?? 'application/octet-stream'};base64,${base64Encode(bytes)}',
          )));
        }
      }
      if (notice != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
      }
    } catch (_) {
      if (mounted && l != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.chatPickAttachmentError)));
      }
    }
  }

  /// Inbound share from another app (share_receiver): images/files join
  /// the pending strip under the same caps as the file picker, text
  /// joins the input. Matches on the share's own [PendingShare.targetKey]
  /// against the currently-open session; the picker drives openSession
  /// itself, so by absorb time the active session is already the target.
  void _absorbShare(PendingShare? share) {
    if (share == null || share.targetKey == null) return;
    if (share.targetKey != ref.read(chatStoreProvider).activeKey) return;
    ref.read(pendingShareProvider.notifier).clear();
    // The store's activeKey is this share's target — latch so a reused
    // element with a stale widget.openSid doesn't re-open a different
    // session on the next build (keeps the transcript in sync with the
    // just-absorbed share).
    _routeSessionOpened = true;
    final l = AppLocalizations.of(context);
    String? notice;
    setState(() {
      for (final img in share.images) {
        if (_pendingImages.length + _pendingFiles.length >= _maxAttachments) {
          notice = l?.chatAttachLimit;
          break;
        }
        _pendingImages.add(img);
      }
      for (final f in share.files) {
        if (_pendingImages.length + _pendingFiles.length >= _maxAttachments) {
          notice = l?.chatAttachLimit;
          break;
        }
        if (f.url.length * 3 ~/ 4 > _maxFileBytes) {
          notice = l?.chatFileTooLarge(f.name);
          continue;
        }
        if (_pendingBytes() + f.url.length * 3 ~/ 4 > _maxTotalBytes) {
          notice = l?.chatAttachTotalTooLarge;
          continue;
        }
        _pendingFiles.add(f);
      }
      if (share.text.isNotEmpty) {
        _input.text = _input.text.isEmpty ? share.text : '${_input.text}\n${share.text}';
      }
    });
    if (notice != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice!)));
    }
  }

  /// Approximate bytes held by the pending file strip (base64 length ×
  /// 3/4 — the constant inflation ratio makes it exact enough for a cap).
  int _pendingBytes() =>
      _pendingFiles.fold(0, (sum, a) => sum + a.url.length * 3 ~/ 4);

  /// Shrink a picked photo for the vision channel (1568px box, q70 — the
  /// knobs the old image_picker path used). Null = codec refused the
  /// file, caller keeps the original bytes.
  Future<Uint8List?> _reencode(String? path) async {
    if (path == null) return null;
    try {
      return await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 1568,
        minHeight: 1568,
        quality: 70,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      return null;
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty && _pendingFiles.isEmpty) return;
    HapticFeedback.lightImpact();
    // Ride the local chat-only override on the first send (the row
    // doesn't exist yet for a PATCH; the server persists params.chatOnly).
    final key = ref.read(chatStoreProvider).activeKey;
    final pendingOnly =
        key == null ? null : _chatOnlyLocal[key.substring(key.indexOf('|') + 1)];
    ref.read(chatStoreProvider.notifier).send(text,
        images: List.of(_pendingImages),
        attachments: List.of(_pendingFiles),
        chatOnly: pendingOnly);
    _input.clear();
    setState(() {
      _pendingImages.clear();
      _pendingFiles.clear();
    });
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
    // Shares resolved to a session land in its composer. A reused element
    // (same route) absorbs here; a freshly-built one (page swap) covers it
    // in didChangeDependencies — together they catch both paths.
    ref.listen(pendingShareProvider, (_, next) => _absorbShare(next));
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
    final activeSession = activeSessionId == null
        ? null
        : ref.watch(sessionsProvider).value
            ?.where((s) => s.id == activeSessionId)
            .firstOrNull;
    final sessionTitle = activeSession?.title;
    // Web parity (chat-screen.tsx:1399-1409): a session whose channel is
    // an IM (wechat/telegram/…) opens read-only — this app's send path
    // can't deliver into the upstream messenger, so composing here would
    // write an orphan turn the IM user never sees.
    final readOnly = activeSession?.isImChannel ?? false;
    final chatOnly = activeSessionId == null
        ? false
        : (_chatOnlyLocal[activeSessionId] ?? (activeSession?.chatOnly ?? false));
    final titleText = activeSessionId == null
        ? l.chatNew
        : (sessionTitle == null || sessionTitle.isEmpty ? l.chatNew : sessionTitle);
    final subText =
        '${selected.name}${selected.model.isEmpty ? '' : ' · ${selected.model}'}';
    // Tablet landscape (breakpoints.dart): the AppShell mounts the
    // permanent sidebar ABOVE this page (web app-shell parity), so the
    // page only owns its own chrome — modal drawer off, header inline in
    // the chat column, workspace panel docked right of the transcript.
    final wide = hasPermanentSidebar(context);
    final split = isChatSplit(context);
    final panelOpen = ref.watch(workspacePanelProvider.select((s) => s.open));
    // The session title leads (user preference); agent switching lives in
    // the drawer/sidebar header. Title gutters come from the global
    // AppBarTheme. Inline (wide) use: no status-bar padding, no leading
    // (the permanent sidebar replaces the drawer hamburger).
    AppBar chatHeader({required bool inline}) => AppBar(
          primary: !inline,
          automaticallyImplyLeading: !inline,
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
                    // Split layout: toggle the docked panel (highlighted
                    // while open); elsewhere: the modal sheet.
                    isSelected: split && panelOpen,
                    onPressed: () => split
                        ? ref.read(workspacePanelProvider.notifier).toggle()
                        : showFilesSheet(context),
                    icon: const Icon(LucideIcons.folderOpen),
                  ),
                  IconButton(
                    tooltip: l.chatTodo,
                    onPressed: () => showTodoSheet(context),
                    icon: const Icon(LucideIcons.listTodo),
                  ),
                ],
        );
    Widget chatBody() {
      if (active == null) return const SkeletonListView(itemCount: 4);
      return Row(
                children: [
                  Expanded(
                    child: Column(
                children: [
                  if (wide) chatHeader(inline: true),
                  if (active.phase == TurnPhase.reconnecting) _ReconnectBanner(hint: active.statusHint),
                  Expanded(
                    // Keyed by session: entrance-animation bookkeeping lives
                    // in MessageList's state and must reset on switch.
                    child: _input.text.isEmpty &&
                            _pendingImages.isEmpty &&
                            !active.turnActive &&
                            !active.historyLoading &&
                            active.entries.isEmpty
                        ? const ChatDashboard()
                        : MessageList(
                            key: ValueKey(ref.watch(chatStoreProvider).activeKey),
                            state: active,
                            jumpSeq: widget.jumpSeq),
                  ),
                  _SlashPalette(
                    matches: readOnly ? const [] : matchSlashCommands(_input.text),
                    enabled: !active.turnActive || _input.text.trim().isNotEmpty,
                    onPick: (cmd) {
                      _input.clear();
                      setState(() {});
                      ref.read(chatStoreProvider.notifier).send(cmd.invoke);
                    },
                  ),
                  // The fade layer sits UNDER the composer card and hugs
                  // its top edge (z: transcript < fade < card) — user
                  // feedback: move the whole band down behind the card
                  // so no gap remains; the card covers the band's last
                  // few px. Visible part above the card ≈ 32px (card
                  // margin 8 + transcript 24); only the top ~18% fades,
                  // the rest is opaque so parked text cannot read
                  // through. Same band for every session — composing
                  // and read-only (IM) alike (user feedback: uniform
                  // fade); the IM case only locks the composer. The
                  // "thinking…" hint no longer lives here — it moved
                  // into the composer's tool row (user feedback: every
                  // layered take in the band read as a bar behind the
                  // text).
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -16,
                        left: 0,
                        right: 0,
                        height: 32,
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
                                stops: const [0.0, 0.35, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Composer(
                        controller: _input,
                        state: active,
                        pendingImages: _pendingImages,
                        pendingFiles: _pendingFiles,
                        chatOnly: chatOnly,
                        readOnly: readOnly,
                        onToggleChatOnly: (on) => _toggleChatOnly(context, on),
                        onChanged: () => setState(() {}),
                        onPickAttachments: _pickAttachments,
                        onRemoveImage: (i) => setState(() => _pendingImages.removeAt(i)),
                        onRemoveFile: (i) => setState(() => _pendingFiles.removeAt(i)),
                        onSend: _send,
                        onSteer: _steer,
                        onStop: () => ref.read(chatStoreProvider.notifier).stop(),
                      ),
                    ],
                  ),
                ],
                    ),
                  ),
                  if (split && panelOpen) ...[
                    PaneDivider(onDrag: _onPanelDrag),
                    ValueListenableBuilder<double>(
                      valueListenable: _panelWidth,
                      // The panel builds once; only the sizing box
                      // re-layouts around it per drag frame.
                      child: WorkspacePanel(
                          agentId: selected.id,
                          sessionId: activeSessionId ?? ''),
                      builder: (context, w, child) =>
                          SizedBox(width: w, child: child),
                    ),
                  ],
                ],
              );
    }

    // Double-back-to-exit lives on the AppShell now: with the ShellRoute,
    // a back at the inner navigator's bottom routes to the ROOT navigator,
    // so a PopScope here is never consulted (it silently stopped working
    // when the shell landed).
    return Scaffold(
        // The shell's permanent sidebar replaces the modal drawer on wide
        // layouts.
        drawer: AppDrawer.adaptive(context),
        // Swipe-right-to-open-drawer from mid-screen (ticket 13, revised
        // per user feedback): the default ~20px left-edge zone is hard to
        // hit and sits inside gesture-nav's system-back strip. A 55%-wide
        // start zone lets a right thumb drag from the middle — clear of
        // both system back edges. The arena still awards vertical-dominant
        // scrolls to the transcript.
        // (edge width is moot on wide — adaptive() gives no drawer)
        drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
        // Wide: no global appBar — the header renders inside the chat
        // column (chatHeader below) so it never spans the sidebar/panel.
        appBar: wide ? null : chatHeader(inline: false),
        // SafeArea only on wide (no Scaffold appBar to absorb the status
        // bar); the phone path keeps its exact pre-shell layout.
        // SafeArea only on wide (no Scaffold appBar to absorb the status
        // bar); the phone path keeps its exact pre-shell layout.
        body: wide
            ? SafeArea(top: true, bottom: false, child: chatBody())
            : chatBody(),
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
