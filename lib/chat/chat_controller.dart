import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/sse.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'chat_engine.dart';
import 'chat_repo.dart';
import 'models.dart';

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
      state = AsyncValue.data(await ref.read(chatRepoProvider).sessions(agentId));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
}

final chatStoreProvider = NotifierProvider<ChatStoreController, ChatStore>(ChatStoreController.new);

class _LiveStream {
  _LiveStream(this.cancelToken);
  final CancelToken cancelToken;
}

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
  final Map<String, _LiveStream> _sends = {};
  final Set<String> _opened = {};
  _LiveStream? _subscribe;
  StreamSubscription<SseFrame>? _subscribeSub;
  Timer? _subscribeRetry;
  int _retryDelaySeconds = 1;
  Timer? _flush;
  bool _disposed = false;
  final _random = Random();

  @override
  ChatStore build() {
    // onDispose must not touch state (Riverpod forbids it mid-dispose) —
    // only the stream handles die here; the auth listener resets state.
    ref.onDispose(_disposeStreams);
    ref.listen(agentsProvider, (prev, next) {
      if (next.selectedId != null && next.selectedId != prev?.selectedId) {
        _openRemembered(next.selectedId!);
      }
    });
    ref.listen(authControllerProvider.select((s) => s.status), (prev, next) {
      if (prev == AuthStatus.loggedIn && next != AuthStatus.loggedIn) _teardown();
    });
    // This notifier builds lazily — if agents finished loading before the
    // first read (fast connection, warm providers), the listener above
    // already missed the selectedId transition. Catch up from the current
    // state instead of waiting for a change that already happened.
    final readyAgentId = ref.read(agentsProvider).selectedId;
    if (readyAgentId != null && ref.read(authControllerProvider).status == AuthStatus.loggedIn) {
      _openRemembered(readyAgentId);
    }
    return const ChatStore();
  }

  // ---- session lifecycle ----

  ChatEngine _engineFor(String agentId, String sessionId) =>
      _engines['$agentId|$sessionId'] ??= ChatEngine();

  (String, String) _split(String key) {
    final i = key.indexOf('|');
    return (key.substring(0, i), key.substring(i + 1));
  }

  Future<void> _openRemembered(String agentId) async {
    final remembered = await ref.read(configStoreProvider).chatSession(agentId);
    await openSession(agentId, remembered.isEmpty ? _generateSessionKey() : remembered);
  }

  /// New session keys follow the web convention `s-<millis>-<rand>`
  /// (chat/page.tsx:24) so server-side session files stay recognizable.
  String _generateSessionKey() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
    return 's-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  Future<void> openSession(String agentId, String sessionId) async {
    final key = '$agentId|$sessionId';
    if (state.activeKey == key) return;
    _stopSubscribe();
    state = ChatStore(activeKey: key, chats: state.chats);
    await ref.read(configStoreProvider).setChatSession(agentId, sessionId);
    final engine = _engineFor(agentId, sessionId);
    if (_opened.add(key)) {
      engine.beginHistoryLoad();
      _publish();
      try {
        final page = await ref.read(chatRepoProvider).history(agentId, sessionId);
        engine.loadHistory(page, older: false);
      } catch (_) {
        engine.loadHistory(const HistoryPage(messages: [], earliestSeq: 0, hasMore: false),
            older: false);
        engine.addLocalNotice(NoticeKind.historyError, '', NoticeTone.error);
      }
      _publish();
    }
    _startSubscribe(agentId, sessionId);
  }

  Future<void> newChat() async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    await openSession(agentId, _generateSessionKey());
  }

  Future<void> loadMore() async {    final key = state.activeKey;
    if (key == null) return;
    final engine = _engines[key];
    final earliest = engine?.earliestSeq;
    if (engine == null || !engine.historyHasMore || earliest == null) return;
    if (engine.snapshot().loadMoreRunning) return;
    final (agentId, sessionId) = _split(key);
    engine.setLoadMoreRunning(true);
    _publish();
    try {
      final page = await ref.read(chatRepoProvider).history(agentId, sessionId, before: earliest);
      engine.loadHistory(page, older: true);
    } catch (_) {
      // Older pages are best-effort; scrolling up again retries.
    }
    engine.setLoadMoreRunning(false);
    _publish();
  }

  void toggleTool(String key) {
    final activeKey = state.activeKey;
    if (activeKey == null) return;
    _engines[activeKey]?.toggleTool(key);
    _publish();
  }

  /// App foregrounded: backgrounding reaps the subscribe socket, and
  /// nothing else re-opens it for an already-open session — live events
  /// would stop until a restart. Reconnect here; `since=lastSeq` replay
  /// picks up everything missed while backgrounded.
  void onAppResumed() {
    final key = state.activeKey;
    if (key == null || _disposed) return;
    final (agentId, sessionId) = _split(key);
    _ensureSubscribe(agentId, sessionId);
  }

  // ---- sending ----

  Future<void> send(String text, {List<String> images = const []}) async {
    final key = state.activeKey;
    if (key == null || text.trim().isEmpty) return;
    final engine = _engines[key];
    if (engine == null || engine.phase != TurnPhase.idle) return;
    engine.beginSend(text, images);
    _publish();
    final (agentId, sessionId) = _split(key);
    unawaited(_runSend(agentId, sessionId, text, images, rollback: false));
  }

  /// Resend the failed trailing user bubble verbatim; the server drops
  /// the dead original first (rollbackPendingUser, handlers.go:1377).
  Future<void> resendFailed() async {
    final key = state.activeKey;
    if (key == null) return;
    final engine = _engines[key];
    if (engine == null) return;
    final failed = engine.takeFailedUser();
    if (failed == null) return;
    engine.beginSend(failed.text, failed.imageUrls);
    _publish();
    final (agentId, sessionId) = _split(key);
    unawaited(_runSend(agentId, sessionId, failed.text, failed.imageUrls, rollback: true));
  }

  /// Regenerate: resend the last user turn; rollback makes it a no-op for
  /// already-answered turns (the message is simply re-appended).
  Future<void> regenerate() async {
    final key = state.activeKey;
    if (key == null) return;
    final engine = _engines[key];
    if (engine == null || engine.phase != TurnPhase.idle) return;
    final last = engine.takeLastUserForRegenerate();
    if (last == null || last.text.trim().isEmpty) return;
    engine.beginSend(last.text, last.images);
    _publish();
    final (agentId, sessionId) = _split(key);
    unawaited(_runSend(agentId, sessionId, last.text, last.images, rollback: true));
  }

  Future<void> _runSend(
    String agentId,
    String sessionId,
    String text,
    List<String> images, {
    required bool rollback,
  }) async {
    final key = '$agentId|$sessionId';
    final engine = _engineFor(agentId, sessionId);
    final live = _LiveStream(CancelToken());
    _sends[key] = live;
    var gotFrame = false;
    try {
      final frames = ref.read(chatRepoProvider).sse.post(
            '/api/chat/stream',
            body: {
              'agentId': agentId,
              'sessionId': sessionId,
              'message': text,
              if (images.isNotEmpty) 'images': images,
              'rollbackPendingUser': rollback,
              'params': {'lang': PlatformDispatcher.instance.locale.languageCode},
            },
            cancelToken: live.cancelToken,
          );
      await for (final frame in frames) {
        gotFrame = true;
        _apply(agentId, sessionId, frame, tag: '·P');
      }
      // Server closed the stream. A healthy turn ends with a `done` frame
      // (engine already idle); anything else means the connection was cut
      // mid-turn — reconnect via subscribe, never render "stopped".
      if (!live.cancelToken.isCancelled && engine.phase != TurnPhase.idle) {
        engine.markReconnecting();
        _publish();
        _ensureSubscribe(agentId, sessionId);
      }
    } catch (e) {
      if (live.cancelToken.isCancelled) return; // explicit stop / teardown
      if (!gotFrame) {
        final message = await sseErrorText(e);
        engine.failLastSend();
        if (message != null && message.isNotEmpty) {
          engine.addLocalNotice(NoticeKind.serverError, message, NoticeTone.error);
        }
        _publish();
      } else {
        engine.markReconnecting();
        _publish();
        _ensureSubscribe(agentId, sessionId);
      }
    } finally {
      if (identical(_sends[key], live)) _sends.remove(key);
    }
  }

  // ---- steer / stop ----

  Future<void> steer(String text) async {
    final key = state.activeKey;
    if (key == null || text.trim().isEmpty) return;
    final engine = _engines[key];
    if (engine == null) return;
    engine.beginSteer(text);
    _publish();
    final (agentId, sessionId) = _split(key);
    try {
      final buffered = await ref.read(chatRepoProvider).steer(agentId, sessionId, text);
      if (!buffered) {
        engine.dropSteer(text);
        _publish();
        await send(text);
      }
    } catch (_) {
      engine.dropSteer(text);
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
    _publish();
    // Drop the POST connection first; its cancel is deliberate, not a
    // disconnect-to-stop.
    _sends[key]?.cancelToken.cancel('stop');
    final (agentId, sessionId) = _split(key);
    try {
      final stopped = await ref.read(chatRepoProvider).stop(agentId, sessionId);
      if (stopped) {
        engine.addLocalNotice(NoticeKind.stopped, '', NoticeTone.warn);
        engine.settleStopped();
        _publish();
        _onTurnDone(agentId, sessionId);
      }
      // 409 (nothing in flight): the turn likely finished between tap and
      // call — `done` events already landed via the subscribe connection.
    } catch (_) {
      // The stop call itself failed (offline?) — the turn keeps running
      // server-side; subscribe carries its finish. Never claim stopped.
      engine.markReconnecting();
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
    if (effects.turnDone) _onTurnDone(agentId, sessionId);
    if (effects.title != null) ref.read(sessionsProvider.notifier).reload();
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
    if (_disposed || state.activeKey != '$agentId|$sessionId') return; // stale retry
    _stopSubscribe();
    final live = _LiveStream(CancelToken());
    _subscribe = live;
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
          cancelToken: live.cancelToken,
        )
        .listen(
          (frame) {
            _retryDelaySeconds = 1;
            _apply(agentId, sessionId, frame, tag: '·S');
          },
          onError: (Object _) {
            if (live.cancelToken.isCancelled || _disposed) return;
            _scheduleReconnect(agentId, sessionId);
          },
          onDone: () {
            if (live.cancelToken.isCancelled || _disposed) return;
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
      if (state.activeKey == '$agentId|$sessionId') {
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
    _subscribe?.cancelToken.cancel('switch');
    _subscribe = null;
  }

  /// Cancels every live connection and forgets all sessions. No state
  /// writes — safe inside ref.onDispose.
  void _disposeStreams() {
    _disposed = true;
    _stopSubscribe();
    for (final live in _sends.values) {
      live.cancelToken.cancel('teardown');
    }
    _sends.clear();
    _flush?.cancel();
    _flush = null;
    _engines.clear();
    _opened.clear();
  }

  /// Logout reset: streams down + a fresh store.
  void _teardown() {
    _disposeStreams();
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

  void _publish() {
    final chats = Map.of(state.chats);
    for (final e in _engines.entries) {
      chats[e.key] = e.value.snapshot();
    }
    state = ChatStore(activeKey: state.activeKey, chats: chats);
  }
}
