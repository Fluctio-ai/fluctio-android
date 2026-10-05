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
    this.channel = '',
    this.thumbnailUrl = '',
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  final String id;
  final String title;
  final String preview;
  final bool chatOnly;
  final String projectId;

  /// Owning IM channel (wechat/telegram/…). Empty or `web` = a chat this
  /// app can compose into; anything else is read-only — the app/web send
  /// path can't deliver into upstream messengers (web parity,
  /// chat-screen.tsx:1399-1414).
  final String channel;
  final String thumbnailUrl;
  final int createdAt;
  final int updatedAt;

  bool get isImChannel => channel.isNotEmpty && channel != 'web';

  factory ChatSessionInfo.fromJson(Map<String, dynamic> json) => ChatSessionInfo(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        preview: json['preview'] as String? ?? '',
        chatOnly: json['chatOnly'] as bool? ?? false,
        projectId: json['projectId'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Human-readable channel name for badges/tooltips — mirrors the web
/// channelLabel (channel-icon.tsx:45). Brand names stay untranslated.
String channelLabel(String channel) => switch (channel) {
      'wechat' => 'WeChat',
      'qq' => 'QQ',
      'feishu' => 'Feishu',
      'telegram' => 'Telegram',
      'discord' => 'Discord',
      'slack' => 'Slack',
      'line' => 'LINE',
      _ => 'Web',
    };

class ProjectInfo {
  const ProjectInfo({required this.id, required this.name, this.description = ''});

  final String id;
  final String name;
  final String description;

  factory ProjectInfo.fromJson(Map<String, dynamic> json) => ProjectInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
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

/// One entry of the chat request's `attachments` field (API.md §4,
/// handlers.go:1034): a non-image file inlined as a data URL. The server
/// materializes it into the session workspace and appends the
/// `[Attached: /workspace/X]` breadcrumb — it never rides the vision
/// `images` channel (a pdf there fails the whole turn upstream).
class PendingAttachment {
  const PendingAttachment({required this.name, required this.url});

  /// Sanitized on the server into the on-disk filename the agent sees.
  final String name;
  final String url;

  Map<String, dynamic> toJson() => {'url': url, 'name': name};

  factory PendingAttachment.fromJson(Map<String, dynamic> json) => PendingAttachment(
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

/// `[Attached: /workspace/X]` lines prepended to the outgoing text when
/// attachments were uploaded ahead of the message (web parity,
/// chat-screen.tsx:1920). The server's StripAttachedPrefix removes them
/// again on history reads, and preMaterialized() then skips duplicate
/// server-side materialization.
String attachmentBreadcrumb(List<PendingAttachment> attachments) =>
    [for (final a in attachments) '[Attached: /workspace/${a.name}]'].join('\n');

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
