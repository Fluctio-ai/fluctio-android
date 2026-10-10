import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_client.dart';
import '../chat/chat_controller.dart';
import '../kb/kb_repo.dart';
import '../l10n/app_localizations.dart';
import '../share/share_receiver.dart';
import '../theme/tokens.dart';
import '../ui/load_states.dart';
import '../util/app_toast.dart';
import 'chat/panels.dart';

/// Share-target picker: an inbound share lands here before anything is
/// delivered — a content header, then the destination list in the fixed
/// global order (note → chat → article → bookmark; PendingShare.targets
/// filters by payload kind, so the relative order never varies). Chat
/// expands inline into a search + recent-conversation list; the KB
/// destinations settle server-side and close the share.
///
/// Layout follows the app design tokens (AppSpace/AppRadius) and the
/// grouped-list rhythm — 12px cards, 6px controls, 44px touch rows.
class ShareTargetPage extends ConsumerStatefulWidget {
  const ShareTargetPage({super.key});

  @override
  ConsumerState<ShareTargetPage> createState() => _ShareTargetPageState();
}

class _ShareTargetPageState extends ConsumerState<ShareTargetPage> {
  final _search = TextEditingController();
  bool _saving = false;
  bool _chatExpanded = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _cancel() {
    ref.read(pendingShareProvider.notifier).clear();
    Navigator.of(context).pop();
  }

  // Shared shape for the KB destinations (note / article / bookmark):
  // run server-side, drop the share, toast, leave.
  Future<void> _runSave(Future<void> Function() action, String doneMessage) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      ref.read(pendingShareProvider.notifier).clear();
      if (mounted) {
        // System toast: this page pops back to the sender app right
        // after, and the toast survives that transition.
        AppToast.show(doneMessage);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showApiError(context, e);
      }
    }
  }

  void _saveNote() {
    final share = ref.read(pendingShareProvider);
    final agentId = ref.read(agentsProvider).selectedId;
    final text = share?.text ?? '';
    if (share == null || agentId == null || text.isEmpty) return;
    // Title = first line of the flattened text (24 chars), content keeps
    // the original body.
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final title = flat.length <= 24 ? flat : '${flat.substring(0, 24)}…';
    _runSave(
        () => ref.read(kbRepoProvider).saveNote(agentId, title: title, contentMd: text),
        AppLocalizations.of(context)!.shareNoteDone);
  }

  void _saveLink({required bool asArticle}) {
    final share = ref.read(pendingShareProvider);
    final agentId = ref.read(agentsProvider).selectedId;
    final url = share?.link;
    if (share == null || agentId == null || url == null) return;
    final l = AppLocalizations.of(context)!;
    _runSave(
        () async {
          final repo = ref.read(kbRepoProvider);
          if (asArticle) {
            await repo.ingestUrl(agentId, url);
          } else {
            await repo.saveBookmark(agentId, url);
          }
        },
        asArticle ? l.shareArticleDone : l.shareBookmarkDone);
  }

  void _deliverToSession(String agentId, String sessionId) {
    // Open first, stamp second — ChatPage's absorb listener matches on
    // activeKey == targetKey; stamping before the store settles absorbs
    // into whatever session is still open (stale text in the composer).
    unawaited(ref.read(chatStoreProvider.notifier).openSession(agentId, sessionId));
    ref.read(pendingShareProvider.notifier).target(sessionKeyOf(agentId, sessionId));
    if (mounted) context.go('/c/${Uri.encodeComponent(sessionId)}');
  }

  void _deliverNewChat(String agentId) {
    unawaited(() async {
      final sid = await ref.read(chatStoreProvider.notifier).newChat();
      if (sid.isEmpty || !mounted) return;
      ref.read(pendingShareProvider.notifier).target(sessionKeyOf(agentId, sid));
      if (mounted) context.go('/');
    }());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final share = ref.watch(pendingShareProvider);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));

    if (share == null) {
      return Scaffold(appBar: AppBar(title: Text(l.shareTargetTitle)), body: const SizedBox());
    }
    final targets = share.targets;
    // Chat as the only destination (images / files / short text) — expand
    // straight away rather than presenting a single dead-end row.
    final chatExpanded =
        _chatExpanded || (targets.length == 1 && targets.first == ShareTarget.chat);

    return PopScope(
      // Back gesture = cancel: the payload is dropped, never delivered.
      // onPopInvoked fires synchronously inside the route-change build
      // frame, so the provider clear must be microtask-deferred — an
      // in-frame write trips Riverpod's "modify a provider while
      // building" assertion.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) scheduleMicrotask(() => ref.read(pendingShareProvider.notifier).clear());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.shareTargetTitle),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _cancel,
            icon: const Icon(LucideIcons.x, size: 20),
          ),
        ),
        body: Column(
          children: [
            _ShareHeader(share: share),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
                children: [
                  _DestinationList(
                    targets: targets,
                    saving: _saving,
                    busyTarget: _busyTarget,
                    onPick: _pickTarget,
                  ),
                  if (chatExpanded) ...[
                    const SizedBox(height: AppSpace.sm),
                    _ChatDestination(
                      search: _search,
                      query: _search.text,
                      agentId: agentId,
                      onSearchChanged: () => setState(() {}),
                      onNewChat: () => _deliverNewChat(agentId ?? ''),
                      onPickSession: _deliverToSession,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ShareTarget? _busyTarget;

  void _pickTarget(ShareTarget t) {
    switch (t) {
      case ShareTarget.chat:
        setState(() => _chatExpanded = true);
      case ShareTarget.note:
        _saveNote();
      case ShareTarget.article:
        _saveLink(asArticle: true);
      case ShareTarget.bookmark:
        _saveLink(asArticle: false);
    }
  }
}

/// What is about to be shared — a compact header with a type glyph, the
/// content, and (for images) a thumbnail strip.
class _ShareHeader extends StatelessWidget {
  const _ShareHeader({required this.share});

  final PendingShare share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: surfaceCardDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _typeGlyph(scheme),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(l),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (share.text.isNotEmpty)
                      Text(
                        share.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (share.images.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            _ImageStrip(images: share.images),
          ],
          for (final f in share.files) ...[
            const SizedBox(height: AppSpace.xs),
            _FileRow(name: f.name),
          ],
        ],
      ),
    );
  }

  Widget _typeGlyph(ColorScheme scheme) {
    final IconData icon;
    final Color bg;
    if (share.images.isNotEmpty) {
      icon = LucideIcons.image;
      bg = scheme.primary;
    } else if (share.files.isNotEmpty) {
      icon = LucideIcons.fileText;
      bg = scheme.tertiary;
    } else if (share.link != null) {
      icon = LucideIcons.link;
      bg = scheme.primary;
    } else {
      icon = LucideIcons.type;
      bg = scheme.secondary;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.14),
        borderRadius: AppRadius.controlBorder,
      ),
      child: Icon(icon, size: 20, color: bg),
    );
  }

  String _typeLabel(AppLocalizations l) {
    if (share.images.isNotEmpty) return l.shareImages(share.images.length);
    if (share.files.isNotEmpty) return l.shareFiles(share.files.length);
    if (share.link != null) return l.shareLink;
    return l.shareText;
  }
}

/// Horizontal strip of shared images — up to four thumbnails, each a
/// clipped 40px rounded square (the nested radius).
class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    final shown = images.take(4).toList();
    return Row(
      children: [
        for (final url in shown)
          Padding(
            padding: const EdgeInsets.only(right: AppSpace.xs),
            child: ClipRRect(
              borderRadius: BorderRadius.all(AppRadius.nested),
              child: Image(
                image: NetworkImage(url),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 40,
                  height: 40,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(LucideIcons.image, size: 18),
                ),
              ),
            ),
          ),
        if (images.length > 4)
          Text(
            '+${images.length - 4}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
      ],
    );
  }
}

/// One shared file — a compact icon + name row.
class _FileRow extends StatelessWidget {
  const _FileRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(LucideIcons.fileText, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ],
    );
  }
}

/// The vertical destination list — one tall row per target (44px touch),
/// a tinted icon well, title + subtitle, and a chevron or spinner.
class _DestinationList extends StatelessWidget {
  const _DestinationList({
    required this.targets,
    required this.saving,
    required this.busyTarget,
    required this.onPick,
  });

  final List<ShareTarget> targets;
  final bool saving;
  final ShareTarget? busyTarget;
  final ValueChanged<ShareTarget> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: surfaceCardDecoration(scheme),
      child: Column(
        children: [
          for (var i = 0; i < targets.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 68, color: scheme.outlineVariant),
            _DestinationRow(
              target: targets[i],
              saving: saving,
              busy: busyTarget == targets[i],
              onTap: () => onPick(targets[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.target,
    required this.saving,
    required this.busy,
    required this.onTap,
  });

  final ShareTarget target;
  final bool saving;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = AppLocalizations.of(context)!;

    final (icon, label, subtitle, color) = switch (target) {
      ShareTarget.note => (LucideIcons.stickyNote, l.shareToNote, l.shareToNoteHint, scheme.primary),
      ShareTarget.chat => (LucideIcons.messageSquare, l.shareToChat, l.shareToChatHint, scheme.primary),
      ShareTarget.article => (LucideIcons.newspaper, l.shareToArticle, l.shareToArticleHint, scheme.tertiary),
      ShareTarget.bookmark => (LucideIcons.bookmark, l.shareToBookmark, l.shareToBookmarkHint, scheme.onPrimaryContainer),
    };

    return InkWell(
      onTap: saving ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                // Container always primary-tinted so the well reads in
                // both themes; the glyph picks a contrasting color so
                // each target still differs (bookmark got lost against
                // the dark card when its well used `secondary`).
                color: scheme.primary.withValues(alpha: 0.14),
                borderRadius: AppRadius.controlBorder,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(LucideIcons.chevronRight, size: 18, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

/// Inline chat destination — search field, "new chat" row, then recent
/// conversations. Sits directly beneath the destination list when the
/// chat target is chosen, so the whole sheet reads as one surface.
class _ChatDestination extends ConsumerWidget {
  const _ChatDestination({
    required this.search,
    required this.query,
    required this.agentId,
    required this.onSearchChanged,
    required this.onNewChat,
    required this.onPickSession,
  });

  final TextEditingController search;
  final String query;
  final String? agentId;
  final VoidCallback onSearchChanged;
  final VoidCallback onNewChat;
  final void Function(String agentId, String sessionId) onPickSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: surfaceCardDecoration(scheme),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.xs),
            child: TextField(
              controller: search,
              onChanged: (_) => onSearchChanged(),
              decoration: InputDecoration(
                hintText: l.chatSearchHint,
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.controlBorder,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () {
                          search.clear();
                          onSearchChanged();
                        },
                      ),
              ),
            ),
          ),
          ListTile(
            dense: true,
            leading: Icon(LucideIcons.messageSquarePlus, size: 20, color: scheme.primary),
            title: Text(l.chatNew, style: theme.textTheme.bodyMedium),
            onTap: onNewChat,
          ),
          const Divider(height: 1),
          _RecentSessions(agentId: agentId, query: query, onPick: onPickSession),
        ],
      ),
    );
  }
}

class _RecentSessions extends ConsumerWidget {
  const _RecentSessions({required this.agentId, required this.query, required this.onPick});

  final String? agentId;
  final String query;
  final void Function(String agentId, String sessionId) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    if (agentId == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final sessions = ref.watch(sessionsProvider);
    return sessions.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpace.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => ErrorPane(message: l.chatHistoryError),
      data: (list) {
        final q = query.trim().toLowerCase();
        // Cap the inline list — the picker is a quick-destination surface,
        // not the full history. Search matches across everything; with no
        // query only the 10 most recent show.
        final matched = q.isEmpty
            ? list
            : list
                .where((s) =>
                    s.title.toLowerCase().contains(q) || s.preview.toLowerCase().contains(q))
                .toList();
        final rows = q.isEmpty ? matched.take(10).toList() : matched;
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Text(
              q.isEmpty ? l.chatNoSessions : l.chatNoMatch,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          );
        }
        return Column(
          children: [
            for (final s in rows)
              SessionTile(
                session: s,
                selected: false,
                onTap: () => onPick(agentId!, s.id),
              ),
          ],
        );
      },
    );
  }
}
