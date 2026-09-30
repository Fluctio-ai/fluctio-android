import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Light local cache (ticket 11): session list + per-session recent
/// messages in SQLite so the app opens readable in airplane mode.
/// Sessions are small rows; messages store the rendered entry shape
/// (role/kind/content/images/ts) for a 1:1 reconstruction on cache hits.
class ChatCache {
  ChatCache._(this._db);

  final Database _db;

  static ChatCache? _instance;

  static Future<ChatCache> instance() async {
    if (_instance != null) return _instance!;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'fluctio_cache.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_sessions (
            agent_id TEXT NOT NULL,
            session_id TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            preview TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL DEFAULT 0,
            chat_only INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (agent_id, session_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_messages (
            agent_id TEXT NOT NULL,
            session_id TEXT NOT NULL,
            idx INTEGER NOT NULL,
            role TEXT NOT NULL,
            kind TEXT NOT NULL DEFAULT '',
            content TEXT NOT NULL DEFAULT '',
            image_urls TEXT NOT NULL DEFAULT '[]',
            ts INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (agent_id, session_id, idx)
          )
        ''');
      },
    );
    return _instance = ChatCache._(db);
  }

  /// Whole-list replace for one agent.
  Future<void> replaceSessions(String agentId, List<CachedSession> sessions) async {
    await _db.transaction((txn) async {
      await txn.delete('cached_sessions', where: 'agent_id = ?', whereArgs: [agentId]);
      for (final s in sessions) {
        await txn.insert('cached_sessions', {
          'agent_id': agentId,
          'session_id': s.sessionId,
          'title': s.title,
          'preview': s.preview,
          'updated_at': s.updatedAt,
          'chat_only': s.chatOnly ? 1 : 0,
        });
      }
    });
  }

  Future<List<CachedSession>> loadSessions(String agentId) async {
    final rows = await _db.query('cached_sessions',
        where: 'agent_id = ?',
        whereArgs: [agentId],
        orderBy: 'updated_at DESC');
    return [
      for (final r in rows)
        CachedSession(
          sessionId: r['session_id'] as String,
          // Rows written before the chat-history fix may hold stale
          // "Instance of …" strings — blank them so tiles fall back to
          // their placeholders instead of object toStrings.
          title: (r['title'] as String).startsWith('Instance of') ? '' : r['title'] as String,
          preview:
              (r['preview'] as String).startsWith('Instance of') ? '' : r['preview'] as String,
          updatedAt: r['updated_at'] as int,
          chatOnly: (r['chat_only'] as int) == 1,
        ),
    ];
  }

  /// Whole-session message replace (recent messages only — what the
  /// engine currently holds).
  Future<void> replaceMessages(String agentId, String sessionId, List<CachedMessage> messages) async {
    await _db.transaction((txn) async {
      await txn.delete('cached_messages',
          where: 'agent_id = ? AND session_id = ?', whereArgs: [agentId, sessionId]);
      for (var i = 0; i < messages.length; i++) {
        final m = messages[i];
        await txn.insert('cached_messages', {
          'agent_id': agentId,
          'session_id': sessionId,
          'idx': i,
          'role': m.role,
          'kind': m.kind,
          'content': m.content,
          'image_urls': jsonEncode(m.imageUrls),
          'ts': m.ts,
        });
      }
    });
  }

  Future<List<CachedMessage>> loadMessages(String agentId, String sessionId) async {
    final rows = await _db.query('cached_messages',
        where: 'agent_id = ? AND session_id = ?',
        whereArgs: [agentId, sessionId],
        orderBy: 'idx ASC');
    return [
      for (final r in rows)
        CachedMessage(
          role: r['role'] as String,
          kind: r['kind'] as String,
          content: r['content'] as String,
          imageUrls: (jsonDecode(r['image_urls'] as String) as List?)?.whereType<String>().toList() ?? const [],
          ts: r['ts'] as int,
        ),
    ];
  }
}

class CachedSession {
  const CachedSession({
    required this.sessionId,
    required this.title,
    required this.preview,
    required this.updatedAt,
    required this.chatOnly,
  });

  final String sessionId;
  final String title;
  final String preview;
  final int updatedAt;
  final bool chatOnly;
}

class CachedMessage {
  const CachedMessage({
    required this.role,
    required this.kind,
    required this.content,
    required this.imageUrls,
    required this.ts,
  });

  /// user | assistant | notice
  final String role;
  /// '' | turn_aborted_notice | compaction_notice
  final String kind;
  final String content;
  final List<String> imageUrls;
  final int ts;
}
