import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Projects tab per the prototype: cards for the selected agent's
/// projects (GET /api/agents/{id}/projects). Create/edit and project-
/// scoped chats land with the M2 tickets.
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final projects = agentId == null ? null : ref.watch(projectsProvider(agentId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navProjects),
        actions: [
          IconButton(
            tooltip: l.chatNew,
            icon: const Icon(LucideIcons.plus),
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('M2'))),
          ),
        ],
      ),
      body: projects == null
          ? const Center(child: CircularProgressIndicator())
          : projects.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.chatHistoryError,
                        style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => agentId == null
                          ? null
                          : ref.invalidate(projectsProvider(agentId)),
                      child: Text(l.chatLoadAgents),
                    ),
                  ],
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.folder, size: 44, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(l.projectsEmpty, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: surfaceCardDecoration(theme.colorScheme),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: AppRadius.cardBorder,
                            ),
                            child: Icon(LucideIcons.folder,
                                size: 22, color: theme.colorScheme.onPrimaryContainer),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall),
                                if (p.description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      p.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
