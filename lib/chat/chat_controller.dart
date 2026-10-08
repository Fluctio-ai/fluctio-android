import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;

import '../cache/chat_cache.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/sse.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'chat_engine.dart';
import 'chat_repo.dart';
import 'models.dart';
import 'slash_commands.dart';

// ---------------------------------------------------------------------------
// Agents
// ---------------------------------------------------------------------------

class AgentsState {
  const AgentsState({this.agents = const [], this.selectedId, this.loaded = false});

  final List<AgentInfo> agents;
  final String? selectedId;
  final bool loaded;

  AgentInfo? get selected {
    final id = selectedId;
    if (id == null) return null;
    for (final a in agents) {
      if (a.id == id) return a;
    }
    return null;
  }
}

final agentsProvider = NotifierProvider<AgentsController, AgentsState>(AgentsController.new);

class AgentsController extends Notifier<AgentsState> {
  @override
  AgentsState build() {
    ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      if (next == AuthStatus.loggedIn && prev != AuthStatus.loggedIn) {
        load();
      } else if (prev == AuthStatus.loggedIn && next != AuthStatus.loggedIn) {
        state = const AgentsState();
      }
    });
    if (ref.read(authControllerProvider).status == AuthStatus.loggedIn) {
      load();
    }
    return const AgentsState();
  }

  Future<void> load() async {
    try {
      final agents = await ref.read(chatRepoProvider).agents();
      if (agents.isEmpty) {
        state = AgentsState(agents: agents, loaded: true);
        return;
      }
      // Keep the current selection when it still exists; otherwise fall
      // back to the remembered one, then the first agent.
      final saved = await ref.read(configStoreProvider).chatAgentId();
      final String selectedId;
      if (state.selectedId != null && agents.any((a) => a.id == state.selectedId)) {
        selectedId = state.selectedId!;
      } else if (saved != null && agents.any((a) => a.id == saved)) {
        selectedId = saved;
      } else {
        selectedId = agents.first.id;
      }
      state = AgentsState(agents: agents, selectedId: selectedId, loaded: true);
      if (saved != selectedId) {
        await ref.read(configStoreProvider).setChatAgentId(selectedId);
      }
    } catch (_) {
      state = AgentsState(agents: state.agents, selectedId: state.selectedId, loaded: true);
    }
  }

  Future<void> select(String id) async {
    if (state.selectedId == id) return;
    state = AgentsState(agents: state.agents, selectedId: id, loaded: true);
    await ref.read(configStoreProvider).setChatAgentId(id);
  }
}

// ---------------------------------------------------------------------------
// Sessions (per selected agent)
// ---------------------------------------------------------------------------

final sessionsProvider =
    NotifierProvider<SessionsController, AsyncValue<List<ChatSessionInfo>>>(
        SessionsController.new);

class SessionsController extends Notifier<AsyncValue<List<ChatSessionInfo>>> {
  @override
  AsyncValue<List<ChatSessionInfo>> build() {
    ref.listen(agentsProvider, (prev, next) {
      if (prev?.selectedId != next.selectedId) reload();
    });
    ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      if (next == AuthStatus.loggedIn && prev != AuthStatus.loggedIn) reload();
    });
    // This notifier builds lazily (first watch happens when the drawer
    // opens, long after agents loaded) — the listeners above already
    // missed the selectedId transition. Catch up from current state.
    if (ref.read(agentsProvider).selectedId != null) {
      reload();
    }
    return const AsyncValue.loading();
  }

  String get _agentId => ref.read(agentsProvider).selectedId ?? '';

  Future<void> reload() async {
    final agentId = _agentId;
    if (agentId.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final sessions = await ref.read(chatRepoProvider).sessions(agentId);
      state = AsyncValue.data(sessions);
      // Light cache (ticket 11): keep the list readable offline. Best
      // effort — cache failures (no sqlite platform in tests, disk full)
      // must never break the live path.
      unawaited(ChatCache.instance().then((cache) => cache.replaceSessions(
            agentId,
            [
              for (final s in sessions)
                CachedSession(
                  sessionId: s.id,
                  title: s.title,
                  preview: s.preview,
                  updatedAt: s.updatedAt,
                  chatOnly: s.chatOnly,
                  channel: s.channel,
                ),
            ],
          )).catchError((_) {}));
    } catch (e, st) {
      // Offline: fall back to the cached list instead of an error wall.
      try {
        final cached = await ChatCache.instance().then((c) => c.loadSessions(agentId));
        state = AsyncValue.data([
          for (final c in cached)
            ChatSessionInfo(
              id: c.sessionId,
              title: c.title,
              preview: c.preview,
              updatedAt: c.updatedAt,
              chatOnly: c.chatOnly,
              channel: c.channel,
            ),
        ]);
      } catch (_) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> rename(String key, String title) async {
    await ref.read(chatRepoProvider).renameSession(_agentId, key, title);
    await reload();
  }

  Future<void> delete(String key) async {
    await ref.read(chatRepoProvider).deleteSession(_agentId, key);
    await reload();
  }

  Future<void> setChatOnly(String key, bool on) async {
    await ref.read(chatRepoProvider).setChatOnly(_agentId, key, on);
    await reload();
  }
}

// ---------------------------------------------------------------------------
// Projects (per selected agent) — powers the drawer section + projects tab.
// ---------------------------------------------------------------------------

final projectsProvider = FutureProvider.family<List<ProjectInfo>, String>((ref, agentId) {
  return ref.watch(chatRepoProvider).projects(agentId);
});

// ---------------------------------------------------------------------------
// Todo panel (single data source: the server's todo.md, refetched at
// turn end — contract §5, handlers.go:1701)
// ---------------------------------------------------------------------------

final todoProvider = FutureProvider.family<TodoData, (String, String)>((ref, key) {
  return ref.watch(chatRepoProvider).todo(key.$1, key.$2);
});

// ---------------------------------------------------------------------------
// Chat store — transcript + turn lifecycle per (agent, session)
// ---------------------------------------------------------------------------

class ChatStore {
  const ChatStore({this.activeKey, this.chats = const {}});

  /// `'<agentId>|<sessionId>'` — both ids are free of `|`.
  final String? activeKey;
  final Map<String, ChatUiState> chats;

  ChatUiState? get active => activeKey == null ? null : chats[activeKey];

  String? get activeAgentId => splitSessionKey(activeKey)?.agentId;

  String? get activeSessionId => splitSessionKey(activeKey)?.sessionId;
}

/// Splits `'<agentId>|<sessionId>'`; null when [key] is null or malformed.
/// The single owner of the composite-key parsing (every consumer goes
/// through here or [sessionKeyOf]).
({String agentId, String sessionId})? splitSessionKey(String? key) {
  if (key == null) return null;
  final i = key.indexOf('|');
  if (i <= 0 || i == key.length - 1) return null;
  return (agentId: key.substring(0, i), sessionId: key.substring(i + 1));
}

/// Joins the composite key. Both ids must be free of `|`.
String sessionKeyOf(String agentId, String sessionId) => '$agentId|$sessionId';

final chatStoreProvider = NotifierProvider<ChatStoreController, ChatStore>(ChatStoreController.new);

/// Owns one [ChatEngine] per session and wires both SSE paths onto it:
/// - POST /api/chat/stream — the send connection; one-shot per turn.
/// - GET /api/chat/subscribe — kept open for the *active* session only;
///   replays seq>since on reconnect, so a turn survives disconnects and
///   finishes rendered from either path (contract §4).
///
/// A network drop never settles a turn locally — only `done` or an
/// explicit stop does (断连≠Stop).
class ChatStoreController extends Notifier<ChatStore> {
  final Map<String, ChatEngine> _engines = {};
  final Map<String, CancelToken> _sends = {};
  final Set<String> _opened = {};
  /// Session keys minted by [newChatInProject] awaiting their first turn —
  /// the chatRequest `projectId` hint binds the not-yet-persisted session
  /// row to its project (contract §3); dropped once the row exists.
  final Map<String, String> _pendingProject = {};
  CancelToken? _subscribe;
  StreamSubscription<SseFrame>? _subscribeSub;
  Timer? _subscribeRetry;
  int _retryDelaySeconds = 1;
  Timer? _flush;
  bool _disposed = false;
  bool _everBuilt = false;
  /// Engines whose snapshot changed since the last publish — only these
  /// get re-snapshotted (each snapshot copies the transcript), so an
  /// 80ms tick during streaming costs one transcript copy, not one per
  /// open session.
  final Set<String> _dirty = {};
  final _random = Random();

  @override
  ChatStore build() {
    // A rebuild (any agentsProvider state write — the picker, a reload)
    // is NOT the end of this controller: reset the disposed flag the
    // onDispose below set, so live plumbing keeps working afterwards.
    // Without this, one agent switch killed subscribe forever — the
    // "bubbles stop appearing" symptom class (ticket 04 坑②).
    _disposed = false;
    ref.onDispose(_disposeStreams);
    final prev = _everBuilt ? state : const ChatStore();
    _everBuilt = true;
    ref.listen(agentsProvider, (prev, next) {
      if (next.selectedId != null && next.selectedId != prev?.selectedId) {
        _openFresh(next.selectedId!);
      }
    });
    ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      if (prev == AuthStatus.loggedIn && next != AuthStatus.loggedIn) _teardown();
    });
    // This notifier builds lazily — if agents finished loading before the
    // first read (fast connection, warm providers), the listener above
    // already missed the selectedId transition. Catch up from the current
    // state instead of waiting for a change that already happened. (No
    // auth gate: a resolved selectedId implies login, and logout resets
    // everything via _teardown — same contract the listener follows.)
    final readyAgentId = ref.read(agentsProvider).selectedId;
    if (readyAgentId == null) return prev;
    if (prev.activeAgentId == readyAgentId) {
      // Rebuild while a session of this agent is open: keep the
      // transcript as-is (the engines survive) and just rewire the
      // subscribe connection the onDispose above tore down.
      final parts = splitSessionKey(prev.activeKey);
      if (parts != null) _ensureSubscribe(parts.agentId, parts.sessionId);
      return prev;
    }
    // First build / agent switch: land on a fresh conversation like the
    // web agent home (/agents/<id>/chat/), not the remembered session.
    // Deferred to a microtask — openSession's first act is a synchronous
    // state write, and writes during build are discarded by Riverpod
    // (the lazy-build catch-up race this class keeps re-learning).
    final agentId = readyAgentId;
    scheduleMicrotask(() {
      if (ref.mounted) _openFresh(agentId);
    });
    return prev;
  }

  // ---- session lifecycle ----

  ChatEngine _engineFor(String agentId, String sessionId) =>
      _engines[sessionKeyOf(agentId, sessionId)] ??= ChatEngine();

  /// Web parity: landing on an agent (startup, agent switch) opens a
  /// fresh conversation — the mobile take on `/agents/<id>/chat/`.
  Future<void> _openFresh(String agentId) async {
    await openSession(agentId, _generateSessionKey());
  }

  /// New session keys follow the web convention `s-<millis>-<rand>`
  /// (chat/page.tsx:24) so server-side session files stay recognizable.
  String _generateSessionKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
    return 's-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  Future<void> openSession(String agentId, String sessionId) async {
    final key = sessionKeyOf(agentId, sessionId);
    if (state.activeKey == key) return;
    _stopSubscribe();
    state = ChatStore(activeKey: key, chats: state.chats);
    await ref.read(configStoreProvider).setChatSession(agentId, sessionId);
    // The container may be gone when the continuation lands (fast tests,
    // app shutdown) — Riverpod 3 throws on any ref/state use after
    // dispose, and the escaping error poisons unrelated work.
    if (!ref.mounted) return;
    final engine = _engineFor(agentId, sessionId);
    if (_opened.add(key)) {
      engine.beginHistoryLoad();
      _markDirty(key);
      _publish();
      try {
        final page = await ref.read(chatRepoProvider).history(agentId, sessionId);
        engine.loadHistory(page, older: false);
      } catch (_) {
        // Offline (ticket 11): render the cached recent messages instead
        // of an error wall; the cache note explains it's not live data.
        try {
          final cached = await ChatCache.instance().then((c) => c.loadMessages(agentId, sessionId));
          engine.loadCachedMessages(cached);
        } catch (_) {
          engine.addLocalNotice(NoticeKind.historyError, '', NoticeTone.error);
        }
      }
      _markDirty(key);
      _publish();
    }
    _startSubscribe(agentId, sessionId);
  }

  Future<String> newChat() async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return '';
    final key = _generateSessionKey();
    await openSession(agentId, key);
    return key;
  }

  /// New chat pre-bound to a project: the first turn's chatRequest carries
  /// the projectId hint so the server writes the session row into
  /// `projects/<pid>/` (web sidebar's "New chat in project",
  /// nav-projects-list.tsx:236).
  Future<String> newChatInProject(String projectId) async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return '';
    final key = _generateSessionKey();
    _pendingProject[sessionKeyOf(agentId, key)] = projectId;
    await openSession(agentId, key);
    return key;
  }

  /// Fork the open session at assistant turn [seq] and land on the child
  /// (web parity, chat-screen.tsx handleFork): the child inherits the
  /// source archive up to seq, its prefix replaying with seq<0. Returns
  /// false on a rejected fork (no active session / bad seq / no key) —
  /// network errors rethrow for the caller to surface.
  Future<bool> fork(int seq) async {
    final parts = splitSessionKey(state.activeKey);
    if (parts == null || seq < 0) return false;
    final newKey =
        await ref.read(chatRepoProvider).forkSession(parts.agentId, parts.sessionId, seq);
    if (!ref.mounted || newKey == null || newKey.isEmpty) return false;
    await openSession(parts.agentId, newKey);
    ref.read(sessionsProvider.notifier).reload();
    return true;
  }

  Future<void> loadMore() async {
    final key = state.activeKey;
    if (key == null) return;
    final engine = _engines[key];
    final earliest = engine?.earliestSeq;
    if (engine == null || !engine.historyHasMore || earliest == null) return;
    if (engine.loadMoreRunning) return;
    final parts = splitSessionKey(key);
    if (parts == null) return;
    final (agentId, sessionId) = (parts.agentId, parts.sessionId);
    engine.setLoadMoreRunning(true);
    _markDirty(key);
    _publish();
    try {
      final page = await ref.read(chatRepoProvider).history(agentId, sessionId, before: earliest);
      engine.loadHistory(page, older: true);
    } catch (_) {
      // Older pages are best-effort; scrolling up again retries.
    }
    engine.setLoadMoreRunning(false);
    _markDirty(key);
    _publish();
  }

  void toggleTool(String key) {
    final activeKey = state.activeKey;
    if (activeKey == null) return;
    _engines[activeKey]?.toggleTool(key);
    _markDirty(activeKey);
    _publish();
  }

  /// App foregrounded: backgrounding reaps the subscribe socket, and
  /// nothing else re-opens it for an already-open session — live events
  /// would stop until a restart. Reconnect here; `since=lastSeq` replay
  /// picks up everything missed while backgrounded.
  void onAppResumed() {
    final key = state.activeKey;
    if (key == null || _disposed) return;
    final parts = splitSessionKey(key);
    if (parts == null) return;
    final (agentId, sessionId) = (parts.agentId, parts.sessionId);
    _ensureSubscribe(agentId, sessionId);
  }

  // ---- sending ----

  /// Open session belongs to an IM channel — read-only over the app
  /// compose path (web parity, chat-screen.tsx:1408).
  bool _isReadOnlySession(String sessionId) =>
      ref.read(sessionsProvider).value
          ?.where((s) => s.id == sessionId)
          .firstOrNull
          ?.isImChannel ??
      false;

  /// IM-channel sessions reject sends — a write here would land in the
  /// session but never reach the upstream messenger. Only the
  /// read-only-safe slash commands pass (chat-screen.tsx:1832-1841).
  bool _blockedByReadOnly(String sessionId, String text) =>
      _isReadOnlySession(sessionId) && !isReadOnlySafeSlashCommand(text);

  Future<void> send(String text,
      {List<String> images = const [], List<PendingAttachment> attachments = const [], bool? chatOnly}) async {
    final key = state.activeKey;
    if (key == null || (text.trim().isEmpty && images.isEmpty && attachments.isEmpty)) return;
    final engine = _engines[key];
    if (engine == null || engine.phase != TurnPhase.idle) return;
    final parts = splitSessionKey(key);
    if (parts == null) return;
    if (_blockedByReadOnly(parts.sessionId, text)) return;
    engine.beginSend(text, images, attachments: attachments);
    _markDirty(key);
    _publish();
    final (agentId, sessionId) = (parts.agentId, parts.sessionId);
    unawaited(_runSend(agentId, sessionId, text, images, attachments,
        rollback: false, chatOnly: chatOnly));
  }

  /// Resend the failed trailing user bubble verbatim; the server drops
  /// the dead original first (rollbackPendingUser, handlers.go:1377).
  Future<void> resendFailed() async {
    final key = state.activeKey;
    if (key == null) return;
    final parts = splitSessionKey(key);
    if (parts == null) return;
    if (_isReadOnlySession(parts.sessionId)) return;
    final engine = _engines[key];
    if (engine == null) return;
    final failed = engine.takeFailedUser();
    if (failed == null) return;
    // Cache-replayed attachments carry names only (bytes never enter the
    // SQLite row) — resend just those still holding a data URL.
    final attachments = failed.attachments.where((a) => a.url.isNotEmpty).toList();
    engine.beginSend(failed.text, failed.imageUrls, attachments: attachments);
    _markDirty(key);
    _publish();
    final (agentId, sessionId) = (parts.agentId, parts.sessionId);
    unawaited(_runSend(agentId, sessionId, failed.text, failed.imageUrls, attachments,
        rollback: true));
  }

  /// Regenerate: resend the last user turn; rollback makes it a no-op for
  /// already-answered turns (the message is simply re-appended).
  Future<void> regenerate() async {
    final key = state.activeKey;
    if (key == null) return;
    final engine = _engines[key];
    if (engine == null || engine.phase != TurnPhase.idle) return;
    final parts = splitSessionKey(key);
    if (parts == null) return;
    // IM-channel sessions: regenerating would append an orphan turn the
    // upstream messenger user never sees — refuse before takeLastUser
    // (which consumes the message).
    if (_isReadOnlySession(parts.sessionId)) return;
    final last = engine.takeLastUserForRegenerate();
    if (last == null ||
        (last.text.trim().isEmpty && last.images.isEmpty && last.attachments.isEmpty)) {
      return;
    }
    final attachments = last.attachments.where((a) => a.url.isNotEmpty).toList();
    engine.beginSend(last.text, last.images, attachments: attachments);
    _markDirty(key);
    _publish();
    final (agentId, sessionId) = (parts.agentId, parts.sessionId);
    unawaited(_runSend(agentId, sessionId, last.text, last.images, attachments,
        rollback: true));
  }

  Future<void> _runSend(
    String agentId,
    String sessionId,
    String text,
    List<String> images,
    List<PendingAttachment> attachments, {
    required bool rollback,
    bool? chatOnly,
  }) async {
    final key = sessionKeyOf(agentId, sessionId);
    final engine = _engineFor(agentId, sessionId);
    final cancel = CancelToken();
    _sends[key] = cancel;
    // Project hint: only meaningful while the session row doesn't exist
    // (contract §3 — the server overwrites it afterwards). Dropped after
    // the first accepted frame, i.e. once the row is persisted.
    final projectHint = _pendingProject[key];
    var gotFrame = false;
    try {
      // Two-step attachment flow (web parity, chat-screen.tsx:1867): the
      // files ride a multipart upload into the session workspace dir
      // first, so the message carries only the breadcrumb text. Inline
      // `attachments` would base64-inflate the JSON body and cap sizes
      // at client-memory levels. Upload failures land in the same
      // catch below as a dead POST — failed-bubble resend path.
      var messageText = text;
      if (attachments.isNotEmpty) {
        await ref.read(chatRepoProvider).uploadAttachments(
              agentId,
              sessionId,
              attachments,
              projectId: projectHint,
              cancelToken: cancel,
            );
        final breadcrumb = attachmentBreadcrumb(attachments);
        messageText = text.isEmpty ? breadcrumb : '$breadcrumb\n$text';
      }
      final frames = ref.read(chatRepoProvider).sse.post(
            '/api/chat/stream',
            body: {
              'agentId': agentId,
              'sessionId': sessionId,
              'message': messageText,
              if (images.isNotEmpty) 'images': images,
              'rollbackPendingUser': rollback,
              'projectId': ?projectHint,
              'params': {
                'lang': PlatformDispatcher.instance.locale.languageCode,
                // Web parity (params channel): the server persists this
                // onto the brand-new session row — first turn runs pure
                // even before the row exists for a PATCH.
                if (chatOnly == true) 'chatOnly': true,
              },
            },
            cancelToken: cancel,
          );
      await for (final frame in frames) {
        gotFrame = true;
        if (projectHint != null) _pendingProject.remove(key);
        _apply(agentId, sessionId, frame, tag: '·P');
      }
      // Server closed the stream. A healthy turn ends with a `done` frame
      // (engine already idle); anything else means the connection was cut
      // mid-turn — reconnect via subscribe, never render "stopped".
      if (!cancel.isCancelled && engine.phase != TurnPhase.idle) {
        engine.markReconnecting();
        _markDirty(key);
        _publish();
        _ensureSubscribe(agentId, sessionId);
      }
    } catch (e) {
      if (cancel.isCancelled) return; // explicit stop / teardown
      if (!gotFrame) {
        final message = await sseErrorText(e);
        engine.failLastSend();
        if (message != null && message.isNotEmpty) {
          engine.addLocalNotice(NoticeKind.serverError, message, NoticeTone.error);
        }
        _markDirty(key);
        _publish();
      } else {
        engine.markReconnecting();
        _markDirty(key);
        _publish();
        _ensureSubscribe(agentId, sessionId);
      }
    } finally {
      if (identical(_sends[key], cancel)) _sends.remove(key);
    }
  }

  // ---- steer / stop ----

  Future<void> steer(String text) async {
    final key = state.activeKey;
    if (key == null || text.trim().isEmpty) return;
    final engine = _engines[key];
    if (engine == null) return;
    engine.beginSteer(text);
    _markDirty(key);
    _publish();
    final parts = splitSessionKey(key);
    if (parts == null) return;
    final (agentId, sessionId) = (parts.agentId, parts.sessionId);
    try {
      final buffered = await ref.read(chatRepoProvider).steer(agentId, sessionId, text);
      if (!buffered) {
        engine.dropSteer(text);
        _markDirty(key);
        _publish();
        await send(text);
      }
    } catch (_) {
      engine.dropSteer(text);
      _markDirty(key);
      _publish();
      await send(text);
    }
  }

  /// auth_prompt answered by tapping an option — same path as a steer of
  /// the option's /cmd (web convention, chat-screen.tsx:2553).
  Future<void> answerAuth(String cmd) async {
    final key = state.activeKey;
    final engine = key == null ? null : _engines[key];
    engine?.markAuthAnswered();
    if (engine != null && engine.phase != TurnPhase.idle) {
      await steer(cmd);
    } else {
      await send(cmd);
    }
  }

  Future<void> stop() async {
    final key = state.activeKey;
    if (key == null) return;
    final engine = _engines[key];
    if (engine == null || engine.phase == TurnPhase.idle) return;
    engine.markStopping();
    _markDirty(key);
    _publish();
    // Drop the POST connection first; its cancel is deliberate, not a
    // disconnect-to-stop.
    _sends[key]?.cancel('stop');
    final parts = splitSessionKey(key);
    if (parts == null) return;
    final (agentId, sessionId) = (parts.agentId, parts.sessionId);
    try {
      final stopped = await ref.read(chatRepoProvider).stop(agentId, sessionId);
      if (stopped) {
        engine.addLocalNotice(NoticeKind.stopped, '', NoticeTone.warn);
        engine.settleStopped();
        _markDirty(key);
        _publish();
        _onTurnDone(agentId, sessionId);
      }
      // 409 (nothing in flight): the turn likely finished between tap and
      // call — `done` events already landed via the subscribe connection.
    } catch (_) {
      // The stop call itself failed (offline?) — the turn keeps running
      // server-side; subscribe carries its finish. Never claim stopped.
      engine.markReconnecting();
      _markDirty(key);
      _publish();
    }
  }

  // ---- SSE plumbing ----

  void _apply(String agentId, String sessionId, SseFrame frame, {String tag = ''}) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(frame.data);
      payload = decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return; // non-JSON data line — ignore
    }
    final engine = _engineFor(agentId, sessionId);
    engine.markStreaming();
    final effects = engine.applyFrame(frame.id, payload, tag: tag);
    _markDirty(sessionKeyOf(agentId, sessionId));
    if (effects.turnDone) _onTurnDone(agentId, sessionId);
    if (effects.titleChanged) ref.read(sessionsProvider.notifier).reload();
    _schedulePublish();
  }

  void _onTurnDone(String agentId, String sessionId) {
    ref.read(sessionsProvider.notifier).reload();
    ref.invalidate(todoProvider((agentId, sessionId)));
  }

  void _startSubscribe(String agentId, String sessionId) {
    _retryDelaySeconds = 1;
    _ensureSubscribe(agentId, sessionId);
  }

  void _ensureSubscribe(String agentId, String sessionId) {
    if (_disposed || state.activeKey != sessionKeyOf(agentId, sessionId)) return; // stale retry
    _stopSubscribe();
    final cancel = CancelToken();
    _subscribe = cancel;
    _subscribeSub = ref
        .read(chatRepoProvider)
        .sse
        .get(
          '/api/chat/subscribe',
          {
            'agentId': agentId,
            'sessionId': sessionId,
            // Resume cursor; -1 would replay the whole persistent log.
            'since': _engineFor(agentId, sessionId).lastSeq,
          },
          cancelToken: cancel,
        )
        .listen(
          (frame) {
            _retryDelaySeconds = 1;
            _apply(agentId, sessionId, frame, tag: '·S');
          },
          onError: (Object _) {
            if (cancel.isCancelled || _disposed) return;
            _scheduleReconnect(agentId, sessionId);
          },
          onDone: () {
            if (cancel.isCancelled || _disposed) return;
            _scheduleReconnect(agentId, sessionId);
          },
          cancelOnError: true,
        );
  }

  void _scheduleReconnect(String agentId, String sessionId) {
    _subscribe = null;
    _subscribeSub = null;
    final delay = _retryDelaySeconds;
    _retryDelaySeconds = min(delay * 2, 30);
    _subscribeRetry?.cancel();
    _subscribeRetry = Timer(Duration(seconds: delay), () {
      if (_disposed) return;
      if (state.activeKey == sessionKeyOf(agentId, sessionId)) {
        _ensureSubscribe(agentId, sessionId);
      }
    });
  }

  void _stopSubscribe() {
    _subscribeRetry?.cancel();
    _subscribeRetry = null;
    // Cancel the subscription before the token — cancelling the token
    // first makes dio deliver a cancel error to the still-live
    // subscription, which escaped as an unhandled exception at teardown.
    _subscribeSub?.cancel();
    _subscribeSub = null;
    _subscribe?.cancel('switch');
    _subscribe = null;
  }

  /// Rebuild-safe teardown for ref.onDispose: stop the subscribe socket
  /// and the publish/cache timers, but keep the engines (pure transcript
  /// state) and in-flight sends — a provider rebuild must not blank the
  /// open transcript or abort a running turn. Must not touch state
  /// (Riverpod forbids it mid-dispose).
  void _disposeStreams() {
    _disposed = true;
    _stopSubscribe();
    _flush?.cancel();
    _flush = null;
    _cacheWrite?.cancel();
    _cacheWrite = null;
  }

  /// Logout reset: streams down, sends cancelled, everything forgotten.
  void _teardown() {
    _disposeStreams();
    for (final cancel in _sends.values) {
      cancel.cancel('teardown');
    }
    _sends.clear();
    _engines.clear();
    _opened.clear();
    _pendingProject.clear();
    state = const ChatStore();
  }

  // ---- publishing (throttled) ----

  /// content_delta arrives at token pace; publishing per frame would
  /// rebuild the transcript ~20×/s. Coalesce to ≤12 fps.
  void _schedulePublish() {
    _flush ??= Timer(const Duration(milliseconds: 80), () {
      _flush = null;
      _publish();
    });
  }

  void _markDirty(String key) => _dirty.add(key);

  /// Snapshots only engines marked dirty since the last publish (each
  /// snapshot copies that session's transcript); everything else rides
  /// along in the previous chats map.
  void _publish() {
    if (!ref.mounted) return; // late continuation after dispose
    if (_dirty.isEmpty) {
      state = ChatStore(activeKey: state.activeKey, chats: state.chats);
      return;
    }
    final chats = Map.of(state.chats);
    for (final key in _dirty) {
      final engine = _engines[key];
      if (engine != null) chats[key] = engine.snapshot();
    }
    _dirty.clear();
    state = ChatStore(activeKey: state.activeKey, chats: chats);
    _scheduleCacheWrite();
  }

  Timer? _cacheWrite;

  /// Recent messages land in the light cache on a 2s debounce (token
  /// streams fire constantly; SQLite only needs settled states). The
  /// timer may fire after the provider (or the whole container) is
  /// disposed — capture the key/engine now and never touch `state`/`ref`
  /// inside the callback (Riverpod 3 throws on a dead ref, and the
  /// escaping error poisons whatever test runs next).
  void _scheduleCacheWrite() {
    _cacheWrite?.cancel();
    final key = state.activeKey;
    final parts = splitSessionKey(key);
    final engine = parts == null ? null : _engines[key];
    if (parts == null || engine == null) return;
    final (agentId, sessionId) = (parts.agentId, parts.sessionId);
    _cacheWrite = Timer(const Duration(seconds: 2), () {
      final messages = <CachedMessage>[];
      for (final e in engine.entries) {
        if (e is UserEntry) {
          messages.add(CachedMessage(
              role: 'user', kind: '', content: e.text, imageUrls: e.imageUrls, attachments: e.attachments, ts: e.ts));
        } else if (e is AssistantEntry) {
          messages.add(CachedMessage(role: 'assistant', kind: '', content: e.text, imageUrls: const [], ts: e.ts));
        } else if (e is NoticeEntry) {
          messages.add(CachedMessage(
              role: 'notice', kind: e.kind.name, content: e.text, imageUrls: const [], ts: 0));
        }
      }
      if (messages.isNotEmpty) {
        ChatCache.instance()
            .then((c) => c.replaceMessages(agentId, sessionId, messages))
            .catchError((_) {});
      }
    });
  }
}
