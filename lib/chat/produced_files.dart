import 'dart:convert';

import '../files/agent_files.dart';

/// A workspace file a turn deliberately produced (write_file /
/// deliver_file / image_gen) — surfaced as an inline card under the tool
/// call, and as the tap target that opens the docked panel preview.
class ProducedFile {
  const ProducedFile(this.path, {this.size});

  /// Full workspace path (scope prefix already resolved).
  final String path;
  final int? size;
}

/// The tool names that can produce workspace files — the gate tool cards
/// check before extracting (the switch below encodes the same list; this
/// keeps call sites from duplicating it).
bool toolCallProducesFiles(String name) =>
    name == 'write_file' || name == 'deliver_file' || name == 'image_gen';

final _writtenRe = RegExp(r'^Written (\d+) bytes');
final _deliveredRe = RegExp(r'^(Delivered \d+ bytes|Already in visible workspace)');
final _deliveredSizeRe = RegExp(r'^Delivered (\d+) bytes');
final _imageGenRe = RegExp(r'/workspace/([^\s)]+)');
final _parentEscapeRe = RegExp(r'^(\.\./)+');

/// Pulls workspace paths out of one tool call record (name + arguments +
/// result) — the files a turn *deliberately* produced. Port of the web
/// extractProducedFiles (chat-screen.tsx:268): the source is the
/// persisted tool record, NOT filesystem mtime, so attribution survives
/// redeploys that rewrite mtimes.
///
/// [scopePrefixes] mirrors listAgentFiles' prefixes (most-specific first;
/// shallowest last = the "/workspace" root). [exists] is the live-listing
/// oracle — the first prefix candidate that exists wins; without one the
/// most-specific prefix is the best guess (fixed at turn end when the
/// listing lands, same as the web reconcile).
List<ProducedFile> extractProducedFiles(
  String name,
  String arguments,
  String? result,
  List<String> scopePrefixes, {
  bool Function(String path)? exists,
}) {
  final res = result ?? '';
  final out = <ProducedFile>[];
  final seen = <String>{};

  void add(String rawRel, [int? size]) {
    // Absolute paths (write_file to /etc/…) aren't workspace artifacts.
    // isSystemWorkspaceFile matches on the bare name, so check before
    // prefixing.
    if (rawRel.isEmpty || rawRel.startsWith('/') || isSystemWorkspaceFile(rawRel)) return;
    // "../x" explicitly addresses the project-shared layer: strip the
    // escape segments and resolve against the SHALLOWEST prefix (the
    // project root) instead of the chat's own dir.
    final rel = rawRel.replaceAll(_parentEscapeRe, '');
    String full = '';
    if (rel != rawRel) {
      if (scopePrefixes.isNotEmpty) full = scopePrefixes.last + rel;
    } else {
      for (final p in scopePrefixes) {
        final cand = p + rel;
        if (exists == null || exists(cand)) {
          full = cand;
          break;
        }
      }
    }
    if (full.isEmpty) full = (scopePrefixes.isEmpty ? '' : scopePrefixes.first) + rel;
    if (seen.contains(full)) return;
    seen.add(full);
    out.add(ProducedFile(full, size: size));
  }

  Map<String, dynamic> args = const {};
  try {
    final decoded = jsonDecode(arguments.isEmpty ? '{}' : arguments);
    if (decoded is Map<String, dynamic>) args = decoded;
  } catch (_) {
    // Bad args JSON — nothing extractable.
  }

  switch (name) {
    case 'write_file':
      // One match serves both the gate and the size capture.
      final m = _writtenRe.firstMatch(res);
      if (m != null) {
        add(args['path'] is String ? args['path'] as String : '',
            int.tryParse(m.group(1)!));
      }
    case 'deliver_file':
      // Result: "Delivered <n> bytes to <abs>" or "Already in visible
      // workspace: <abs>". The visible name comes from arguments.dest;
      // fall back to basename(src) when dest was omitted.
      if (!_deliveredRe.hasMatch(res)) break;
      final dest = args['dest'] is String ? args['dest'] as String : '';
      final src = args['src'] is String ? args['src'] as String : '';
      final dm = _deliveredSizeRe.firstMatch(res);
      add(dest.isNotEmpty ? dest : src.split('/').last,
          dm == null ? null : int.tryParse(dm.group(1)!));
    case 'image_gen':
      // persistImageGenOutput rewrites the result markdown to
      // ![](/workspace/<name>) — no size carried.
      for (final m in _imageGenRe.allMatches(res)) {
        add(m.group(1)!);
      }
  }
  return out;
}
