import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../chat/chat_controller.dart';
import '../chat/chat_repo.dart';
import '../chat/models.dart';
import '../l10n/app_localizations.dart';
import '../ui/load_states.dart';
import '../theme/tokens.dart';
import 'chat/chat_image.dart';
import 'chat/panels.dart';

/// Drawer mirroring the web agent sidebar (app-sidebar.tsx): agent
/// header, 智能体 group (new chat / workflow), 知识库 tile grid, expandable
/// 项目 with their child chats, 对话 (loose chats) with a see-all link,
/// and 设置 in the footer. One navigation surface instead of the old
/// bottom tab bar.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  final Set<String> _expandedProjects = {};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agents = ref.watch(agentsProvider);
    final agent = agents.selected;
    final sessions = ref.watch(sessionsProvider);
    final projects = agent == null ? null : ref.watch(projectsProvider(agent.id));

    final loose = sessions.value?.where((s) => s.projectId.isEmpty).toList() ?? const <ChatSessionInfo>[];
    final byProject = <String, List<ChatSessionInfo>>{};
    for (final s in sessions.value ?? const <ChatSessionInfo>[]) {
      if (s.projectId.isEmpty) continue;
      byProject.putIfAbsent(s.projectId, () => []).add(s);
    }

    return Drawer(
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _AgentHeader(agent: agent),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _SectionLabel(l.drawerGroupAgent),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: Row(children: [
                      Expanded(
                        child: _ActionTile(
                          icon: LucideIcons.plus,
                          label: l.chatNew,
                          onTap: () => _newChat(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionTile(
                          icon: LucideIcons.workflow,
                          label: l.navWorkflow,
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/workflow');
                          },
                        ),
                      ),
                    ]),
                  ),
                  _SectionLabel(l.navKnowledge),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _KbGrid(onTapNamed: _openKb),
                  ),
                  _SectionLabel(l.navProjects, action: l.newProject, onAction: () => _createProject(context)),
                  ...?projects?.when(
                    data: (list) => [
                      if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Text(l.noProjects,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ),
                      for (final p in list)
                        _ProjectRow(
                          project: p,
                          expanded: _expandedProjects.contains(p.id),
                          onToggle: () => setState(() => _expandedProjects.contains(p.id)
                              ? _expandedProjects.remove(p.id)
                              : _expandedProjects.add(p.id)),
                          sessions: byProject[p.id] ?? const [],
                          onOpenSession: (sid) => _openSession(context, sid),
                          onNewChatInProject: () => _newChatInProject(context, p.id),
                          onEdit: () => _editProject(context, p),
                          onDelete: () => _deleteProject(context, p),
                        ),
                    ],
                    loading: () => const [Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkeletonList(itemCount: 3))],
                    error: (_, _) => const [SizedBox.shrink()],
                  ),
                  _SectionLabel(l.drawerChats),
                  if (loose.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(l.chatNoSessions,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    ),
                  for (final s in loose.take(10)) _sessionRow(s),
                  if (loose.length > 10)
                    ListTile(
                      dense: true,
                      leading: const Icon(LucideIcons.ellipsis, size: 18),
                      title: Text(l.seeAllChats),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/chats');
                      },
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            ListTile(
              dense: true,
              leading: const Icon(LucideIcons.settings, size: 20),
              title: Text(l.navSettings),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/me');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openKb(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.push(route);
  }

  Future<void> _newChat(BuildContext context) async {
    Navigator.of(context).pop();
    final sid = await ref.read(chatStoreProvider.notifier).newChat();
    if (sid.isNotEmpty && context.mounted) {
      context.go('/c/${Uri.encodeComponent(sid)}');
    }
  }

  Future<void> _newChatInProject(BuildContext context, String projectId) async {
    Navigator.of(context).pop();
    final sid = await ref.read(chatStoreProvider.notifier).newChatInProject(projectId);
    if (sid.isNotEmpty && context.mounted) {
      context.go('/c/${Uri.encodeComponent(sid)}');
    }
  }

  void _openSession(BuildContext context, String sid) {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    Navigator.of(context).pop();
    ref.read(chatStoreProvider.notifier).openSession(agentId, sid);
    context.go('/c/${Uri.encodeComponent(sid)}');
  }

  /// Session row wired for the drawer: opens on tap, highlights when it
  /// is the open conversation.
  Widget _sessionRow(ChatSessionInfo s) {
    final agentId = ref.read(agentsProvider).selectedId;
    return SessionTile(
      session: s,
      selected: ref.watch(chatStoreProvider.select((st) => st.activeKey)) ==
          (agentId == null ? null : '$agentId|${s.id}'),
      onTap: () => _openSession(context, s.id),
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final fields = await _projectDialog(context, title: l.newProject);
    if (fields == null || fields.$1.trim().isEmpty) return;
    try {
      final agentId = ref.read(agentsProvider).selectedId!;
      await ref.read(chatRepoProvider).createProject(agentId, fields.$1.trim(),
          description: fields.$2.trim());
      ref.invalidate(projectsProvider(agentId));
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _editProject(BuildContext context, ProjectInfo project) async {
    final l = AppLocalizations.of(context)!;
    final fields = await _projectDialog(context,
        title: l.editProject, initialName: project.name, initialDescription: project.description);
    if (fields == null || fields.$1.trim().isEmpty) return;
    try {
      final agentId = ref.read(agentsProvider).selectedId!;
      await ref.read(chatRepoProvider)
          .updateProject(agentId, project.id, name: fields.$1.trim(), description: fields.$2.trim());
      ref.invalidate(projectsProvider(agentId));
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _deleteProject(BuildContext context, ProjectInfo project) async {
    final l = AppLocalizations.of(context)!;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteProjectTitle),
        content: Text(l.deleteProjectConfirm(project.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.deleteProject)),
        ],
      ),
    );
    if (yes != true) return;
    try {
      final agentId = ref.read(agentsProvider).selectedId!;
      final blocked = await ref.read(chatRepoProvider).deleteProject(agentId, project.id);
      if (blocked > 0 && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.projectDeleteBlocked(blocked))));
        return;
      }
      ref.invalidate(projectsProvider(agentId));
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  // Notifications land as snackbars through the drawer's Scaffold context
  // only after the drawer itself closed, so go through the root messenger.
  void _showError(BuildContext context, Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }

  /// Name + description dialog; null = cancelled.
  Future<(String, String)?> _projectDialog(
    BuildContext context, {
    required String title,
    String initialName = '',
    String initialDescription = '',
  }) {
    final l = AppLocalizations.of(context)!;
    final name = TextEditingController(text: initialName);
    final description = TextEditingController(text: initialDescription);
    return showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: InputDecoration(labelText: l.projectNameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: InputDecoration(labelText: l.projectDescriptionLabel),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((name.text, description.text)),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
  }
}

class _AgentHeader extends ConsumerWidget {
  const _AgentHeader({required this.agent});

  final AgentInfo? agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Plain identity strip — agent switching lives in the chat app bar's
    // title dropdown, so the drawer copy was redundant.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          const AgentAvatar(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(agent?.name ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(agent?.model.isEmpty == false ? agent!.model : '',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: AppRadius.controlBorder,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.plus, size: 13),
                    const SizedBox(width: 4),
                    Text(action!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.controlBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: AppRadius.controlBorder,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// 知识库 3-column tile grid — the drawer take on the web NavKnowledge
/// grid (nav-knowledge.tsx): one entry per view, no intermediate hub
/// page.
class _KbGrid extends StatelessWidget {
  const _KbGrid({required this.onTapNamed});

  /// route name: 'articles' / 'notes' / … ; 'diary' signals coming soon.
  final void Function(BuildContext context, String route) onTapNamed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final entries = <(String, IconData, String)>[
      (l.kbArticles, LucideIcons.fileText, '/kb/articles'),
      (l.kbNotes, LucideIcons.stickyNote, '/kb/notes'),
      (l.kbIdeas, LucideIcons.lightbulb, '/kb/flash'),
      (l.kbTodos, LucideIcons.squareCheckBig, '/kb/todos'),
      (l.kbDiary, LucideIcons.calendarDays, ''),
      (l.kbBookmarks, LucideIcons.bookmark, '/kb/bookmarks'),
      (l.kbCards, LucideIcons.layers, '/kb/cards'),
      (l.kbWiki, LucideIcons.bookMarked, '/wiki'),
    ];
    Widget tileAt(int j) => _KbTile(label: entries[j].$1, icon: entries[j].$2, onTap: () {
          if (entries[j].$3.isEmpty) {
            // Close the drawer first — a snackbar behind the open
            // drawer scrim is invisible.
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            messenger.showSnackBar(SnackBar(content: Text(l.comingSoon)));
          } else {
            onTapNamed(context, entries[j].$3);
          }
        });
    return Container(
      // Web nav-knowledge.tsx container (nav-tile.tsx): a rounded,
      // bordered, tinted box so the grid reads as one group.
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i += 3)
            Row(
              children: [
                // Fixed thirds — a short last row keeps 1/3-wide cells
                // (blank slots) instead of stretching its two tiles.
                for (var j = i; j < i + 3; j++)
                  Expanded(child: j < entries.length ? tileAt(j) : const SizedBox.shrink()),
              ],
            ),
        ],
      ),
    );
  }
}

class _KbTile extends StatelessWidget {
  const _KbTile({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.controlBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(height: 5),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable project row with its child chats inline (web
/// NavProjectsList): tap toggles, ⋯ offers new-chat-in-project / edit /
/// delete.
class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.expanded,
    required this.onToggle,
    required this.sessions,
    required this.onOpenSession,
    required this.onNewChatInProject,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectInfo project;
  final bool expanded;
  final VoidCallback onToggle;
  final List<ChatSessionInfo> sessions;
  final ValueChanged<String> onOpenSession;
  final VoidCallback onNewChatInProject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(expanded ? LucideIcons.folderOpen : LucideIcons.folder, size: 18),
          title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: PopupMenuButton<String>(
            onSelected: (a) => switch (a) {
              'new' => onNewChatInProject(),
              'edit' => onEdit(),
              _ => onDelete(),
            },
            icon: Icon(LucideIcons.ellipsisVertical, size: 18, color: Theme.of(context).colorScheme.outline),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'new', child: Text(l.newChatInProject)),
              PopupMenuItem(value: 'edit', child: Text(l.editProject)),
              PopupMenuItem(value: 'delete', child: Text(l.deleteProject)),
            ],
          ),
          onTap: onToggle,
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              children: [
                for (final s in sessions)
                  SessionTile(
                    session: s,
                    selected: false,
                    onTap: () => onOpenSession(s.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
