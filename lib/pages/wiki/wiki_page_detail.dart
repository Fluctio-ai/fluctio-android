import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../chat/chat_controller.dart';
import '../../chat/markdown.dart';
import '../../files/file_preview.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../../util/dates.dart';
import '../../wiki/wiki_actions.dart';
import '../../wiki/wiki_links.dart';
import '../../wiki/wiki_models.dart';
import '../../wiki/wiki_repo.dart';
import '../kb/kb_editor_page.dart';

final wikiPageProvider =
    FutureProvider.family<WikiPageInfo, (String, String)>((ref, key) {
  return ref.watch(wikiRepoProvider).page(key.$1, key.$2);
});

/// Wiki page preview (the web's center pane, full-screen): type badge +
/// title header over the shared markdown bundle; `[[wiki links]]`
/// rewrite to internal navigation; edit reuses the KB note editor
/// (MarkdownField + title row); "view in graph" opens the native graph
/// focused on this page.
class WikiPageDetail extends ConsumerStatefulWidget {
  const WikiPageDetail({super.key, required this.pageId});

  final String pageId;

  @override
  ConsumerState<WikiPageDetail> createState() => _WikiPageDetailState();
}

class _WikiPageDetailState extends ConsumerState<WikiPageDetail> {
  Future<void> _edit(WikiPageInfo page) async {
    final l = AppLocalizations.of(context)!;
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KbEditorPage(
          heading: l.wikiEditPage,
          initialText: page.body ?? '',
          titleLabel: l.wikiTitleLabel,
          initialTitle: page.title,
          onSave: (text, title, date, endDate, {status}) async {
            try {
              await ref.read(wikiRepoProvider).save(agentId, widget.pageId,
                  title: title, body: text);
              return true;
            } catch (e) {
              if (mounted) showApiError(context, e);
              return false;
            }
          },
        ),
      ),
    );
    if (ok == true) {
      ref.invalidate(wikiPageProvider((agentId, widget.pageId)));
      ref.invalidate(wikiInventoryProvider(agentId));
    }
  }

  Future<void> _delete(WikiPageInfo page) async {
    final ok = await deleteWikiPageWithConfirm(context, ref, page);
    if (ok && mounted) context.pop();
  }

  void _onLink(String href) {
    final target = wikiLinkTarget(href);
    if (target != null) {
      // Same-page target (self link) still pushes — go_router replaces
      // nothing, and back steps out one hop, which matches the web's
      // in-pane navigation closely enough on touch.
      context.push('/wiki/page/${Uri.encodeComponent(target)}');
    } else {
      openChatLink(context, ref, href);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final page = agentId == null
        ? null
        : ref.watch(wikiPageProvider((agentId, widget.pageId)));
    final loaded = page != null && page.hasValue ? page.value : null;

    return Scaffold(
      appBar: AppBar(
        title: loaded != null
            ? Text(loaded.title, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Text(l.navWiki),
        actions: [
          if (loaded != null) ...[
            IconButton(
              tooltip: l.wikiViewInGraph,
              icon: const Icon(LucideIcons.network, size: 20),
              onPressed: () => context
                  .push('/wiki/graph?focus=${Uri.encodeComponent(widget.pageId)}'),
            ),
            IconButton(
              tooltip: l.wikiEditPage,
              icon: const Icon(LucideIcons.penLine, size: 20),
              onPressed: () => _edit(loaded),
            ),
            IconButton(
              tooltip: l.chatDelete,
              icon: const Icon(LucideIcons.trash2, size: 20),
              onPressed: () => _delete(loaded),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: page == null
          ? const SizedBox.shrink()
          : page.when(
              loading: () => const SkeletonProse(),
              error: (e, _) => ErrorPane(message: l.wikiLoadFailed),
              data: (p) => _body(context, p),
            ),
    );
  }

  Widget _body(BuildContext context, WikiPageInfo p) {
    final theme = Theme.of(context);
    // Resolve [[link]] targets to titles from the inventory when it's
    // loaded (web titleMap); the raw id is the fallback.
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final inv =
        agentId == null ? null : ref.watch(wikiInventoryProvider(agentId));
    final titles = <String, String>{
      for (final q in inv?.value?.pages ?? const <WikiPageInfo>[])
        '${q.pageType}:${q.slug}': q.title,
    };
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Text(p.pageType,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ),
                    if (p.updatedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        formatShortDate(p.updatedAt!, withTime: true),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ],
                ),
                // Title lives in the AppBar and (usually) the body's own
                // `# heading` — a third copy here read as noise (user
                // feedback), so the header row is badge + time only.
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGptMarkdown(
            rewriteWikiLinks(p.body ?? '', (id) => titles[id] ?? id),
            config: markdownConfig(context, onTapLink: _onLink),
            useDollarSignsForLatex: true,
          ),
        ),
      ],
    );
  }
}
