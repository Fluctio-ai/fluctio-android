import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import 'chat/chat_image.dart';
import 'chat/panels.dart';

/// Left navigation drawer per the mobile prototype: agent header, quick
/// actions (new chat / workflows), then sections — knowledge base,
/// projects, chat history — and settings in the footer.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agents = ref.watch(agentsProvider);
    final agent = agents.selected;
    final sessions = ref.watch(sessionsProvider);
    final projects = agent == null ? null : ref.watch(projectsProvider(agent.id));

    return Drawer(
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            // Header: selected agent.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  AgentAvatar(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(agent?.name ?? l.appName,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(l.drawerRole, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            // Quick actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionChip(
                      icon: Icons.add_comment_outlined,
                      label: l.chatNew,
                      onTap: () {
                        Navigator.of(context).pop();
                        ref.read(chatStoreProvider.notifier).newChat();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionChip(
                      icon: Icons.account_tree_outlined,
                      label: l.navWorkflow,
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/workflow');
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  _SectionTitle(l.navKnowledge, onTap: () {
                    Navigator.of(context).pop();
                    context.go('/kb');
                  }, actionIcon: Icons.chevron_right),
                  _SectionTitle(l.navProjects, onTap: () {
                    Navigator.of(context).pop();
                    context.go('/projects');
                  }, actionIcon: Icons.chevron_right),
                  ...?projects?.when(
                    data: (list) => [
                      for (final p in list.take(4))
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder_outlined, size: 18),
                          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go('/projects');
                          },
                        ),
                    ],
                    loading: () => const [SizedBox.shrink()],
                    error: (_, _) => const [SizedBox.shrink()],
                  ),
                  _SectionTitle(l.drawerChatHistory),
                  sessions.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, _) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(l.chatHistoryError,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(l.chatNoSessions,
                              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                        );
                      }
                      final agentId = agents.selectedId;
                      return Column(
                        children: [
                          for (final s in list)
                            SessionTile(
                              session: s,
                              selected: ref.watch(chatStoreProvider
                                      .select((st) => st.activeKey)) ==
                                  '$agentId|${s.id}',
                              onTap: () {
                                if (agentId != null) {
                                  Navigator.of(context).pop();
                                  ref.read(chatStoreProvider.notifier).openSession(agentId, s.id);
                                }
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            ListTile(
              dense: true,
              leading: const Icon(Icons.settings_outlined, size: 20),
              title: Text(l.navSettings),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/me');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.onTap, this.actionIcon});

  final String text;
  final VoidCallback? onTap;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
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
            if (actionIcon != null) Icon(actionIcon, size: 16, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}
