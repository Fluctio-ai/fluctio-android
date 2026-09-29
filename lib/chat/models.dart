/// Wire models for the chat surface (docs/api/API.md §4–6). Shapes mirror
/// the gateway handlers; every field parses defensively — the contract is
/// versioned and additive.
library;

class AgentInfo {
  const AgentInfo({
    required this.id,
    required this.name,
    this.description = '',
    this.model = '',
    this.avatarUrl = '',
  });

  final String id;
  final String name;
  final String description;
  final String model;
  final String avatarUrl;

  factory AgentInfo.fromJson(Map<String, dynamic> json) => AgentInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? json['id'] as String? ?? '',
        description: json['description'] as String? ?? '',
        model: json['model'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ?? '',
      );
}

/// One row of `GET /api/chat/sessions` (WebSession, session/manager.go:1057).
class ChatSessionInfo {
  const ChatSessionInfo({
    required this.id,
    this.title = '',
    this.preview = '',
    this.chatOnly = false,
    this.projectId = '',
    this.thumbnailUrl = '',
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final String id;
  final String title;
  final String preview;
  final bool chatOnly;
  final String projectId;
  final String thumbnailUrl;
  final int createdAt;
  final int updatedAt;

  factory ChatSessionInfo.fromJson(Map<String, dynamic> json) => ChatSessionInfo(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        preview: json['preview'] as String? ?? '',
        chatOnly: json['chatOnly'] as bool? ?? false,
        projectId: json['projectId'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

class TodoItem {
  const TodoItem({required this.text, this.done = false, this.cancelled = false});

  final String text;
  final bool done;
  final bool cancelled;
}

/// `GET /api/chat/todo` payload (handlers.go:1701). A missing todo.md is
/// `{"items":[],"raw":""}` — not an error.
class TodoData {
  const TodoData({this.items = const [], this.raw = ''});
  final List<TodoItem> items;
  final String raw;

  static const empty = TodoData();

  factory TodoData.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <TodoItem>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map) {
          final text = e['text'];
          if (text is! String || text.isEmpty) continue;
          items.add(TodoItem(
            text: text,
            done: e['done'] as bool? ?? false,
            cancelled: e['cancelled'] as bool? ?? false,
          ));
        }
      }
    }
    return TodoData(items: items, raw: json['raw'] as String? ?? '');
  }
}

class ToolCallData {
  const ToolCallData({required this.id, required this.name, this.arguments = ''});

  final String id;
  final String name;
  final String arguments;

  factory ToolCallData.fromJson(Map<String, dynamic> json) => ToolCallData(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        arguments: json['arguments'] as String? ?? '',
      );
}

/// One `GET /api/chat/history` entry (agent/loop.go:1838). `kind` is set
/// only on notice entries (`turn_aborted_notice` / `compaction_notice`),
/// which carry no seq; fork-inherited entries carry negative seqs.
class HistoryMessage {
  const HistoryMessage({
    required this.role,
    this.kind,
    this.content = '',
    this.seq,
    this.timestamp = 0,
    this.imageUrls = const [],
    this.senderName,
    this.toolCalls = const [],
    this.name = '',
    this.toolCallId = '',
  });

  final String role;
  final String? kind;
  final String content;
  final int? seq;
  final int timestamp;
  final List<String> imageUrls;
  final String? senderName;
  final List<ToolCallData> toolCalls;
  final String name;
  final String toolCallId;

  factory HistoryMessage.fromJson(Map<String, dynamic> json) {
    final rawCalls = json['toolCalls'];
    final calls = <ToolCallData>[];
    if (rawCalls is List) {
      for (final c in rawCalls) {
        if (c is Map) calls.add(ToolCallData.fromJson(Map<String, dynamic>.from(c)));
      }
    }
    return HistoryMessage(
      role: json['role'] as String? ?? '',
      kind: json['kind'] as String?,
      content: json['content'] as String? ?? '',
      seq: (json['seq'] as num?)?.toInt(),
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
      imageUrls: (json['imageUrls'] as List?)?.whereType<String>().toList() ?? const [],
      senderName: json['senderName'] as String?,
      toolCalls: calls,
      name: json['name'] as String? ?? '',
      toolCallId: json['toolCallId'] as String? ?? '',
    );
  }
}

/// `GET /api/chat/history` page: `{history, earliestSeq, hasMore,
/// latestEventSeq?}` — latestEventSeq is the resume cursor for subscribe.
class HistoryPage {
  const HistoryPage({
    required this.messages,
    required this.earliestSeq,
    required this.hasMore,
    this.latestSeq,
  });

  final List<HistoryMessage> messages;
  final int earliestSeq;
  final bool hasMore;
  final int? latestSeq;

  factory HistoryPage.fromJson(Map<String, dynamic> json) {
    final raw = json['history'];
    final messages = <HistoryMessage>[];
    if (raw is List) {
      for (final m in raw) {
        if (m is Map) messages.add(HistoryMessage.fromJson(Map<String, dynamic>.from(m)));
      }
    }
    return HistoryPage(
      messages: messages,
      earliestSeq: (json['earliestSeq'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] as bool? ?? false,
      latestSeq: (json['latestEventSeq'] as num?)?.toInt(),
    );
  }
}
