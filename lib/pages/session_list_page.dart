import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import '../ui/load_states.dart';
import 'app_drawer.dart';
import 'chat/panels.dart';

/// Full conversation list (`/chats`) — the drawer's "see all chats"
/// target, the mobile take on the web `/agents/<id>/chats` page. Tapping
/// a row opens the conversation at `/c/<sessionId>`, so the back gesture
/// / leading arrow returns here.
class SessionListPage extends ConsumerWidget {
  const SessionListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agents = ref.watch(agentsProvider);

    if (!agents.loaded) {
      return Scaffold(
        drawer: AppDrawer.adaptive(context),
        appBar: AppBar(title: Text(l.navChat)),
        body: const SkeletonListView(),
      );
    }
    if (agents.agents.isEmpty) {
      return Scaffold(
        drawer: AppDrawer.adaptive(context),
        appBar: AppBar(title: Text(l.navChat)),
        body: EmptyState(
          icon: LucideIcons.bot,
          message: l.chatNoAgent,
          action: FilledButton(
            onPressed: () => ref.read(agentsProvider.notifier).load(),
            child: Text(l.chatLoadAgents),
          ),
        ),
      );
    }

    final selected = agents.selected!;
    return Scaffold(
      drawer: AppDrawer.adaptive(context),
      appBar: AppBar(
        title: PopupMenuButton<String>(
          // Same gate as the drawer's agent header — a single agent has
          // nothing to switch, and a lone-option menu reads as a stub.
          enabled: agents.agents.length > 1,
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
                if (agents.agents.length > 1) const Icon(LucideIcons.chevronDown),
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

class _SessionListView extends ConsumerStatefulWidget {
  const _SessionListView({required this.agentId});

  final String agentId;

  @override
  ConsumerState<_SessionListView> createState() => _SessionListViewState();
}

class _SessionListViewState extends ConsumerState<_SessionListView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sessions = ref.watch(sessionsProvider);
    // Local keyword filter (title / preview, case-insensitive) — the
    // list is already fully loaded, no server round-trip needed.
    final q = _search.text.trim().toLowerCase();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.chatSearchHint,
              prefixIcon: const Icon(LucideIcons.search),
              isDense: true,
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(sessionsProvider.notifier).reload(),
            child: sessions.when(
              loading: () => const SkeletonListView(),
              error: (e, _) => ListView( // keep the indicator draggable
                children: [
                  const SizedBox(height: 120),
                  ErrorPane(message: l.chatHistoryError),
                ],
              ),
              data: (list) {
                final rows = q.isEmpty
                    ? list
                    : list
                        .where((s) =>
                            s.title.toLowerCase().contains(q) ||
                            s.preview.toLowerCase().contains(q))
                        .toList();
                if (rows.isEmpty) {
                  return ListView( // keep the indicator draggable
                    children: [
                      const SizedBox(height: 120),
                      EmptyState(
                          icon: LucideIcons.search,
                          message: q.isEmpty ? l.chatNoSessions : l.chatNoMatch),
                    ],
                  );
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final s = rows[i];
                    return SessionTile(
                      session: s,
                      slideActions: true,
                      selected:
                          ref.watch(chatStoreProvider.select((st) => st.activeKey)) ==
                              '${widget.agentId}|${s.id}',
                      onTap: () {
                        ref
                            .read(chatStoreProvider.notifier)
                            .openSession(widget.agentId, s.id);
                        context.go('/c/${Uri.encodeComponent(s.id)}');
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
