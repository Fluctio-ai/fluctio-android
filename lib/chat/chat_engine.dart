import 'models.dart';

/// Phase of the in-flight (or just-finished) turn. A network drop never
/// maps back to [idle]: the turn keeps running server-side on a detached
/// context (handlers.go:1409) and the UI reconnects via subscribe. Only
/// an explicit stop or a `done` event settles the phase.
enum TurnPhase { idle, sending, streaming, reconnecting, stopping }

/// Structured notice kinds — the UI owns the localized copy; `text` carries
/// the server-provided body when there is one.
enum NoticeKind { serverError, stopped, compaction, turnAborted, historyError, offlineCache }

enum NoticeTone { info, warn, error }

sealed class UiEntry {
  const UiEntry({required this.key});
  final String key;
}

class UserEntry extends UiEntry {
  const UserEntry({
    required super.key,
    required this.text,
    this.imageUrls = const [],
    this.pendingSteer = false,
    this.failed = false,
    this.ts = 0,
  });

  final String text;
  final List<String> imageUrls;
  final bool pendingSteer;
  final bool failed;

  /// Unix ms — history entries carry the server timestamp, live entries
  /// are stamped locally (wire frames carry none). 0 = unknown.
  final int ts;

  UserEntry copyWith({
    String? text,
    List<String>? imageUrls,
    bool? pendingSteer,
    bool? failed,
    int? ts,
  }) =>
      UserEntry(
        key: key,
        text: text ?? this.text,
        imageUrls: imageUrls ?? this.imageUrls,
        pendingSteer: pendingSteer ?? this.pendingSteer,
        failed: failed ?? this.failed,
        ts: ts ?? this.ts,
      );
}

class AssistantEntry extends UiEntry {
  const AssistantEntry({required super.key, required this.text, this.streaming = false, this.ts = 0});

  final String text;
  final bool streaming;
  final int ts;

  AssistantEntry copyWith({String? text, bool? streaming, int? ts}) => AssistantEntry(
        key: key,
        text: text ?? this.text,
        streaming: streaming ?? this.streaming,
        ts: ts ?? this.ts,
      );
}

class ToolEntry extends UiEntry {
  const ToolEntry({
    required super.key,
    required this.name,
    this.arguments = '',
    this.result,
    this.expanded = false,
  });

  final String name;
  final String arguments;
  final String? result;
  final bool expanded;

  ToolEntry copyWith({String? name, String? arguments, String? result, bool? expanded}) => ToolEntry(
        key: key,
        name: name ?? this.name,
        arguments: arguments ?? this.arguments,
        result: result ?? this.result,
        expanded: expanded ?? this.expanded,
      );
}

class NoticeEntry extends UiEntry {
  const NoticeEntry({required super.key, required this.kind, required this.text, required this.tone});

  final NoticeKind kind;
  final String text;
  final NoticeTone tone;
}

class AuthPromptOption {
  const AuthPromptOption({required this.cmd, required this.labelZh, required this.labelEn});

  final String cmd;
  final String labelZh;
  final String labelEn;

  String label(String localeLanguageCode) => localeLanguageCode == 'zh' ? labelZh : labelEn;
}

class AuthPromptEntry extends UiEntry {
  const AuthPromptEntry({
    required super.key,
    required this.description,
    required this.options,
    this.answered = false,
  });

  final String description;
  final List<AuthPromptOption> options;
  final bool answered;

  AuthPromptEntry copyWith({bool? answered}) => AuthPromptEntry(
        key: key,
        description: description,
        options: options,
        answered: answered ?? this.answered,
      );
}

class ChatUiState {
  const ChatUiState({
    this.entries = const [],
    this.phase = TurnPhase.idle,
    this.statusHint = '',
    this.lastSeq = -1,
    this.historyLoading = false,
    this.historyHasMore = false,
    this.earliestSeq,
    this.loadMoreRunning = false,
    this.debugFrames = 0,
    this.debugLastEvent = '',
    this.debugLastBus = '',
    this.debugTypeCounts = const {},
  });

  final List<UiEntry> entries;
  final TurnPhase phase;
  final String statusHint;
  final int lastSeq;
  final bool historyLoading;
  final bool historyHasMore;
  final int? earliestSeq;
  final bool loadMoreRunning;

  /// On-screen diagnostics (debug builds): raw SSE frames seen by this
  /// session's engine and the last frame's type@seq.
  final int debugFrames;
  final String debugLastEvent;

  /// Type → count histogram of received frames (diagnostics).
  final Map<String, int> debugTypeCounts;

  /// Last non-empty legacy bus frame text (diagnostics).
  final String debugLastBus;

  bool get turnActive => phase != TurnPhase.idle;

  /// Show the "thinking" indicator while the turn runs but no streaming
  /// bubble is on screen yet.
  bool get awaitingFirstDelta =>
      phase != TurnPhase.stopping &&
      (entries.isEmpty || entries.last is! AssistantEntry || !(entries.last as AssistantEntry).streaming);
}

/// Side effects a frame asks the controller to perform — repo calls the
/// pure engine can't make (refresh session metadata / todo after a turn).
class FrameEffects {
  const FrameEffects({this.turnDone = false, this.titleKey, this.title});
  final bool turnDone;
  final String? titleKey;
  final String? title;
}

/// Pure transcript + turn reducer for one (agent, session). Frames from
/// the POST stream and the parallel subscribe connection both land in
/// [applyFrame]; seq ordering dedups the overlap (handlers.go:1494) —
/// content_delta arrives with seq -1 and is never dropped.
class ChatEngine {
  final List<UiEntry> _entries = <UiEntry>[];
  TurnPhase _phase = TurnPhase.idle;
  String _statusHint = '';
  int _lastSeq = -1;
  int? _earliestSeq;
  bool _hasMore = false;
  bool _historyLoading = false;
  bool _loadMoreRunning = false;
  int _counter = 0;
  int _debugFrames = 0;
  String _debugLastEvent = '';
  String _debugLastBus = '';
  final Map<String, int> _debugTypeCounts = {};

  String _key(String prefix) => '$prefix-${_counter++}';

  ChatUiState snapshot() => ChatUiState(
        entries: List.unmodifiable(_entries),
        phase: _phase,
        statusHint: _statusHint,
        lastSeq: _lastSeq,
        historyLoading: _historyLoading,
        historyHasMore: _hasMore,
        earliestSeq: _earliestSeq,
        loadMoreRunning: _loadMoreRunning,
        debugFrames: _debugFrames,
        debugLastEvent: _debugLastEvent,
        debugLastBus: _debugLastBus,
        debugTypeCounts: Map.unmodifiable(_debugTypeCounts),
      );

  TurnPhase get phase => _phase;

  int get lastSeq => _lastSeq;

  int? get earliestSeq => _earliestSeq;

  bool get historyHasMore => _hasMore;

  // ---- send / steer / stop transitions (controller-driven) ----

  void beginSend(String text, List<String> images) {
    _entries.add(UserEntry(
      key: _key('u'),
      text: text,
      imageUrls: List.of(images),
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    _statusHint = '';
    _phase = TurnPhase.sending;
  }

  void markStreaming() {
    if (_phase == TurnPhase.sending) _phase = TurnPhase.streaming;
  }

  /// The POST failed before any frame landed: keep the user bubble with a
  /// resend affordance. The retry sends `rollbackPendingUser: true`, which
  /// drops that same trailing unanswered user turn server-side before the
  /// fresh append (handlers.go:1377).
  void failLastSend() {
    _phase = TurnPhase.idle;
    _statusHint = '';
    for (var i = _entries.length - 1; i >= 0; i--) {
      final e = _entries[i];
      if (e is UserEntry && !e.pendingSteer) {
        _entries[i] = e.copyWith(failed: true);
        return;
      }
    }
  }

  void beginSteer(String text) => _entries.add(UserEntry(
        key: _key('u'),
        text: text,
        pendingSteer: true,
        ts: DateTime.now().millisecondsSinceEpoch,
      ));

  /// Steer rejected (409 — no active turn): drop the optimistic bubble;
  /// the caller falls back to a normal send.
  void dropSteer(String text) {
    for (final e in _entries.reversed) {
      if (e is UserEntry && e.pendingSteer) {
        if (e.text == text) _entries.remove(e);
        return;
      }
    }
  }

  UserEntry? takeFailedUser() {
    for (final e in _entries.reversed) {
      if (e is UserEntry && e.failed) {
        _entries.remove(e);
        return e;
      }
    }
    return null;
  }

  /// Regenerate: hand back the last real user turn so the controller can
  /// resend it (with rollback — a no-op once it has been answered).
  ({String text, List<String> images})? takeLastUserForRegenerate() {
    for (final e in _entries.reversed) {
      if (e is UserEntry && !e.pendingSteer) return (text: e.text, images: e.imageUrls);
    }
    return null;
  }

  void markStopping() => _phase = TurnPhase.stopping;

  void markReconnecting() {
    if (_phase == TurnPhase.sending || _phase == TurnPhase.streaming || _phase == TurnPhase.stopping) {
      _phase = TurnPhase.reconnecting;
    }
  }

  /// Explicit stop confirmed by the server: settle the turn locally. Late
  /// events from the still-open subscribe connection are seq-deduped or
  /// appended harmlessly.
  void settleStopped() => _finishTurn();

  void addLocalNotice(NoticeKind kind, String text, NoticeTone tone) =>
      _entries.add(NoticeEntry(key: _key('n'), kind: kind, text: text, tone: tone));

  void markAuthAnswered() {
    for (final e in _entries.reversed) {
      if (e is AuthPromptEntry) {
        if (!e.answered) _entries[_entries.indexOf(e)] = e.copyWith(answered: true);
        return;
      }
    }
  }

  /// Expand/collapse a tool card in place (pure UI state, rides along
  /// with the transcript so history and live turns behave identically).
  void toggleTool(String key) {
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (e is ToolEntry && e.key == key) {
        _entries[i] = e.copyWith(expanded: !e.expanded);
        return;
      }
    }
  }

  // ---- history ----

  void beginHistoryLoad() {
    _historyLoading = true;
  }

  void setLoadMoreRunning(bool value) => _loadMoreRunning = value;

  void loadHistory(HistoryPage page, {required bool older}) {
    final batch = <UiEntry>[];
    for (final m in page.messages) {
      _mapHistoryMessage(m, batch);
    }
    if (older) {
      _entries.insertAll(0, batch);
    } else {
      _entries
        ..clear()
        ..addAll(batch);
      _phase = TurnPhase.idle;
      _statusHint = '';
    }
    _historyLoading = false;
    _hasMore = page.hasMore;
    _earliestSeq = page.earliestSeq > 0 ? page.earliestSeq : null;
    for (final m in page.messages) {
      final seq = m.seq;
      if (seq != null && seq > _lastSeq) _lastSeq = seq;
    }
    final latest = page.latestSeq;
    if (latest != null && latest > _lastSeq) _lastSeq = latest;
  }

  /// Offline cache replay (ticket 11): cached recent messages become
  /// entries directly, headed by an offline banner; the seq cursor stays
  /// at -1 so a later online history load re-syncs cleanly.
  void loadCachedMessages(List<dynamic> messages) {
    _entries.clear();
    _entries.add(const NoticeEntry(
        key: 'cache-banner', kind: NoticeKind.offlineCache, text: '', tone: NoticeTone.info));
    for (final m in messages) {
      if (m.kind.isNotEmpty) {
        _entries.add(NoticeEntry(
          key: _key('n'),
          kind: switch (m.kind) {
            'serverError' => NoticeKind.serverError,
            'stopped' => NoticeKind.stopped,
            'compaction' => NoticeKind.compaction,
            'turnAborted' => NoticeKind.turnAborted,
            _ => NoticeKind.historyError,
          },
          text: m.content,
          tone: NoticeTone.warn,
        ));
      } else if (m.role == 'user') {
        _entries.add(UserEntry(key: _key('u'), text: m.content, imageUrls: m.imageUrls, ts: m.ts));
      } else if (m.role == 'assistant') {
        _entries.add(AssistantEntry(key: _key('a'), text: m.content, ts: m.ts));
      }
    }
    _historyLoading = false;
    _hasMore = false;
    _phase = TurnPhase.idle;
  }

  void _mapHistoryMessage(HistoryMessage m, List<UiEntry> batch) {
    switch (m.kind) {
      case 'turn_aborted_notice':
        batch.add(NoticeEntry(key: _key('n'), kind: NoticeKind.turnAborted, text: m.content, tone: NoticeTone.warn));
        return;
      case 'compaction_notice':
        batch.add(NoticeEntry(key: _key('n'), kind: NoticeKind.compaction, text: m.content, tone: NoticeTone.info));
        return;
    }
    switch (m.role) {
      case 'user':
        if (m.content.isEmpty && m.imageUrls.isEmpty) return;
        batch.add(UserEntry(key: _key('u'), text: m.content, imageUrls: m.imageUrls, ts: m.timestamp));
      case 'assistant':
        if (m.content.isNotEmpty) {
          batch.add(AssistantEntry(key: _key('a'), text: m.content, ts: m.timestamp));
        }
        for (final tc in m.toolCalls) {
          batch.add(ToolEntry(key: 'tc-${tc.id}', name: tc.name, arguments: tc.arguments));
        }
      case 'tool':
        // Pair with the call card the preceding assistant entry created;
        // unmatched results (partial page window) become standalone cards.
        final target = 'tc-${m.toolCallId}';
        for (final e in batch.reversed) {
          if (e is ToolEntry && e.key == target && e.result == null) {
            batch[batch.indexOf(e)] = e.copyWith(result: m.content);
            return;
          }
        }
        for (final e in _entries.reversed) {
          if (e is ToolEntry && e.key == target && e.result == null) {
            _entries[_entries.indexOf(e)] = e.copyWith(result: m.content);
            return;
          }
        }
        batch.add(ToolEntry(key: target, name: m.name, result: m.content));
    }
  }

  // ---- SSE frames ----

  FrameEffects applyFrame(int? frameId, Map<String, dynamic> payload, {String tag = ''}) {
    _debugFrames++;
    final dbgType = payload['type'] as String? ?? 'bus';
    _debugTypeCounts['$dbgType$tag'] = (_debugTypeCounts['$dbgType$tag'] ?? 0) + 1;
    if (dbgType == 'bus') {
      final t = payload['text'];
      if (t is String && t.isNotEmpty) {
        _debugLastBus = t.length > 48 ? t.substring(0, 48) : t;
      }
    }
    _debugLastEvent = '$dbgType$tag@${payload['seq'] ?? frameId ?? '-'}';
    final rawSeq = payload['seq'];
    final seq = rawSeq is int ? rawSeq : rawSeq is num ? rawSeq.toInt() : null;
    if (seq != null && seq >= 0) {
      if (seq <= _lastSeq) {
        _debugTypeCounts['DROPPED$tag'] = (_debugTypeCounts['DROPPED$tag'] ?? 0) + 1;
        return const FrameEffects(); // replay overlap
      }
      _lastSeq = seq;
    } else if (frameId != null && frameId >= 0) {
      if (frameId <= _lastSeq) return const FrameEffects();
      _lastSeq = frameId;
    }
    final type = payload['type'];
    final data = payload['data'];
    final map = data is Map ? data : const <String, dynamic>{};
    switch (type) {
      case 'content_delta':
        final delta = map['delta'];
        if (delta is String && delta.isNotEmpty) _appendDelta(delta);
      case 'content':
        final content = map['content'];
        _commitContent(content is String ? content : '');
      case 'tool_call':
        final id = map['id'];
        _entries.add(ToolEntry(
          key: 'tc-${id ?? _key('t')}',
          name: map['name'] as String? ?? '',
          arguments: map['arguments'] as String? ?? '',
        ));
      case 'tool_result':
        final id = map['id'];
        _attachToolResult(
          'tc-${id ?? _key('t')}',
          map['name'] as String? ?? '',
          map['result'] as String? ?? '',
        );
      case 'steer':
        _echoSteer(map['content'] as String? ?? '');
      case 'session_title':
        return FrameEffects(titleKey: map['sessionKey'] as String?, title: map['title'] as String?);
      case 'compaction_notice':
        _entries.add(NoticeEntry(
          key: _key('n'),
          kind: NoticeKind.compaction,
          text: map['content'] as String? ?? '',
          tone: NoticeTone.info,
        ));
      case 'reconnecting':
        final attempt = map['attempt'];
        if (attempt is int) _statusHint = '$attempt';
      case 'auth_prompt':
        _entries.add(AuthPromptEntry(
          key: _key('auth'),
          description: map['description'] as String? ?? '',
          options: _authOptions(map['options']),
        ));
      case 'error':
        _notice(map['message'] as String? ?? '', NoticeKind.serverError, NoticeTone.error);
      case 'done':
        _finishTurn();
        return const FrameEffects(turnDone: true);
      default:
        // Frames without a `type` envelope are legacy bus traffic —
        // typing indicators from other tabs, pre-hub cron replies. The
        // web client ignores them; rendering them dumps "Typing…" noise
        // into the transcript, so we ignore them too.
        break;
    }
    return const FrameEffects();
  }

  void _appendDelta(String delta) {
    final last = _entries.isNotEmpty ? _entries.last : null;
    if (last is AssistantEntry && last.streaming) {
      _entries[_entries.length - 1] = last.copyWith(text: last.text + delta);
    } else {
      _entries.add(AssistantEntry(
        key: _key('a'),
        text: delta,
        streaming: true,
        ts: DateTime.now().millisecondsSinceEpoch,
      ));
      markStreaming();
    }
  }

  void _commitContent(String content) {
    // Find the (single) in-progress delta bubble, skipping over entries a
    // mid-stream steer echo may have appended, and replace it with the
    // authoritative full text. Only one streaming bubble exists at a time.
    for (var i = _entries.length - 1; i >= 0; i--) {
      final e = _entries[i];
      if (e is! AssistantEntry) continue;
      if (e.streaming) {
        _entries[i] = e.copyWith(text: content, streaming: false);
        return;
      }
      break; // newest assistant entry is committed → this is a new segment
    }
    if (content.isNotEmpty) {
      _entries.add(AssistantEntry(
        key: _key('a'),
        text: content,
        ts: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _attachToolResult(String key, String name, String result) {
    for (final e in _entries.reversed) {
      if (e is ToolEntry && e.key == key && e.result == null) {
        _entries[_entries.indexOf(e)] = e.copyWith(result: result);
        return;
      }
    }
    _entries.add(ToolEntry(key: key, name: name, result: result));
  }

  void _echoSteer(String content) {
    if (content.isEmpty) return;
    for (var i = _entries.length - 1; i >= 0; i--) {
      final e = _entries[i];
      if (e is! UserEntry) continue;
      if (!e.pendingSteer) break;
      if (e.text == content) {
        _entries[i] = e.copyWith(pendingSteer: false);
        return;
      }
    }
    _entries.add(UserEntry(
      key: _key('u'),
      text: content,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _notice(String text, NoticeKind kind, NoticeTone tone) =>
      _entries.add(NoticeEntry(key: _key('n'), kind: kind, text: text, tone: tone));

  void _finishTurn() {
    for (var i = _entries.length - 1; i >= 0; i--) {
      final e = _entries[i];
      if (e is AssistantEntry && e.streaming) {
        _entries[i] = e.copyWith(streaming: false);
        break;
      }
      if (e is AssistantEntry) break;
    }
    _phase = TurnPhase.idle;
    _statusHint = '';
  }

  List<AuthPromptOption> _authOptions(Object? raw) {
    final out = <AuthPromptOption>[];
    if (raw is List) {
      for (final o in raw) {
        if (o is Map) {
          final cmd = o['cmd'];
          if (cmd is String && cmd.isNotEmpty) {
            out.add(AuthPromptOption(
              cmd: cmd,
              labelZh: o['label_zh'] as String? ?? cmd,
              labelEn: o['label_en'] as String? ?? cmd,
            ));
          }
        }
      }
    }
    return out;
  }
}
