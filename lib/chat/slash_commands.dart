/// Built-in slash commands surfaced when the composer text starts with
/// `/` — a 1:1 mirror of the web composer's BUILTIN_COMMANDS
/// (chat-screen.tsx:138), itself a mirror of internal/agent/slash.go.
/// Keep the three tables in sync. Skills (global catalog + this agent's
/// installs) join the menu via [matchSlashCommands]'s skills parameter.
library;

import 'models.dart';

class SlashCommand {
  const SlashCommand(this.name, this.description, {this.isSkill = false});

  final String name;
  final String description;

  /// Entry comes from the skill catalog rather than the built-in table —
  /// renders with a skill badge and inserts `/<name> ` into the composer
  /// (skills take a prompt after the name) instead of dispatching.
  final bool isSkill;

  String get invoke => '/$name';
}

const slashCommands = <SlashCommand>[
  SlashCommand('new', 'Clear session history'),
  SlashCommand('reset', 'Clear session history'),
  SlashCommand('retry', 'Re-run last message'),
  SlashCommand('undo', 'Undo last turn'),
  SlashCommand('compact', 'Compress context window'),
  SlashCommand('status', 'Agent status & memory info'),
  SlashCommand('usage', 'Billing usage and session stats'),
  SlashCommand('insights', 'Activity insights (last N days)'),
  SlashCommand('personality', 'List or switch personality'),
  SlashCommand('model', 'Show or switch LLM model'),
  SlashCommand('bookmark', 'Save a web URL as a bookmark'),
  SlashCommand('plan', 'Plan mode: numbered plan, no tool calls'),
  SlashCommand('goal', 'Persistent multi-turn objective'),
  SlashCommand('help', 'Show command help'),
  SlashCommand('version', 'Show version'),
];

/// Commands + skills matching the typed `/query` — fuzzy on name OR
/// description (web parity, chat-screen.tsx:945); the bare `/` shows
/// everything. Commands first, skills after.
List<SlashCommand> matchSlashCommands(String text, {List<SkillInfo> skills = const []}) {
  if (!text.startsWith('/')) return const [];
  final query = text.substring(1).toLowerCase();
  bool fuzzy(String name, String description) => query.isEmpty ||
      name.toLowerCase().contains(query) ||
      description.toLowerCase().contains(query);
  return [
    for (final c in slashCommands)
      if (fuzzy(c.name, c.description)) c,
    for (final s in skills)
      if (fuzzy(s.name, s.description))
        SlashCommand(s.name, s.description, isSkill: true),
  ];
}

/// Commands still sendable from an IM-channel (read-only) session —
/// pure status queries that don't mutate the transcript. 1:1 mirror of
/// the web READ_ONLY_SLASH_COMMANDS (chat-screen.tsx:155).
const readOnlySafeSlashCommands = {'help', 'status', 'usage', 'insights', 'version'};

/// True when [text] is `/name …` with a read-only-safe name (web parity,
/// chat-screen.tsx:987-993).
bool isReadOnlySafeSlashCommand(String text) {
  final match = RegExp(r'^/(\w+)').firstMatch(text.trim());
  return match != null && readOnlySafeSlashCommands.contains(match.group(1));
}
