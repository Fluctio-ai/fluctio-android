import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../l10n/app_localizations.dart';

/// Agent picker for chat app bars (session list + conversation) — one
/// owner instead of two drifting copies. [subtitle] carries the open
/// session title on the conversation surface; omit it on the list.
class AgentPickerTitle extends ConsumerWidget {
  const AgentPickerTitle({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final agents = ref.watch(agentsProvider);
    final selected = agents.selected;
    if (selected == null) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      initialValue: selected.id,
      onSelected: (id) => ref.read(agentsProvider.notifier).select(id),
      itemBuilder: (_) => [
        for (final a in agents.agents)
          PopupMenuItem(
            value: a.id,
            child: Row(
              children: [
                Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
                if (a.model.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(a.model,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                    child: Text(selected.name,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis)),
                const Icon(LucideIcons.chevronDown),
              ],
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
      ),
    );
  }
}

/// No-agents empty state shared by the chat surfaces.
class NoAgentsView extends ConsumerWidget {
  const NoAgentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bot, size: 44, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(l.chatNoAgent, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => ref.read(agentsProvider.notifier).load(),
            child: Text(l.chatLoadAgents),
          ),
        ],
      ),
    );
  }
}
