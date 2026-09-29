import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import 'app_drawer.dart';
import 'chat/panels.dart';

/// Chat tab root: the session list, one tap from any conversation —
/// the mobile take on the web's always-visible sidebar. Tapping a row
/// opens the conversation at `/c/<sessionId>` in the same branch, so
/// the back gesture / leading arrow returns here.
class SessionListPage extends ConsumerWidget {
  const SessionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agents = ref.watch(agentsProvider);

    if (!agents.loaded) {
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(title: Text(l.navChat)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (agents.agents.isEmpty) {
      return Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(title: Text(l.navChat)),
        body: Center(
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
        ),
      );
    }

    final selected = agents.selected!;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: PopupMenuButton<String>(
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(selected.name, style: theme.textTheme.titleMedium),
                const Icon(LucideIcons.chevronDown),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l.chatNew,
            onPressed: () async {
              final sid = await ref.read(chatStoreProvider.notifier).newChat();
              if (sid.isNotEmpty && context.mounted) {
                context.go('/c/${Uri.encodeComponent(sid)}');
              }
            },
            icon: const Icon(LucideIcons.messageSquarePlus),
          ),
        ],
      ),
      body: _SessionListView(agentId: selected.id),
    );
  }
}

class _SessionListView extends ConsumerWidget {
  const _SessionListView({required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sessions = ref.watch(sessionsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(sessionsProvider.notifier).reload(),
      child: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView( // keep the indicator draggable
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(l.chatHistoryError,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
        data: (list) {
          if (list.isEmpty) {
            return ListView( // keep the indicator draggable
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(LucideIcons.messageCircle, size: 44, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(l.chatNoSessions, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return SessionTile(
                session: s,
                selected:
                    ref.watch(chatStoreProvider.select((st) => st.activeKey)) ==
                        '$agentId|${s.id}',
                onTap: () {
                  ref.read(chatStoreProvider.notifier).openSession(agentId, s.id);
                  context.go('/c/${Uri.encodeComponent(s.id)}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
