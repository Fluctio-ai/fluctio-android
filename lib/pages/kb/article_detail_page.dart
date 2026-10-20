import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/adaptive_tab_bar.dart';
import '../../ui/load_states.dart';
import '../../chat/markdown.dart';

/// Article detail, tabbed like the web (knowledge-views.tsx DetailTab):
/// the original text plus the five deep-reading sections — 概要 / 章节 /
/// 金句 / 行动 / 新芽. Section tabs render only after insights exist, so
/// an article with no reading yet is just 原文 + the generate action in
/// the app bar.
class KbArticleDetailPage extends ConsumerStatefulWidget {
  const KbArticleDetailPage({super.key, required this.sourceId, this.title = '', this.embedded = false});

  final String sourceId;
  final String title;

  /// Master-detail pane mode: no back leading (the pane has no route to
  /// pop — popping would dismiss the whole list page).
  final bool embedded;

  @override
  ConsumerState<KbArticleDetailPage> createState() => _KbArticleDetailPageState();
}

class _KbArticleDetailPageState extends ConsumerState<KbArticleDetailPage> {
  List<KbEntry>? _entries;
  KbInsights? _insights;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    // Entries and insights are independent — run them concurrently
    // (insights failure just means the generate button offers itself).
    final (entries, insights) = await (
      ref.read(kbRepoProvider).entries(agentId, widget.sourceId),
      ref.read(kbRepoProvider).insights(agentId, widget.sourceId).catchError((_) => null),
    ).wait;
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _insights = insights;
    });
  }

  Future<void> _generate() async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null || _generating) return;
    setState(() => _generating = true);
    try {
      final insights =
          await ref.read(kbRepoProvider).generateInsights(agentId, widget.sourceId);
      if (mounted) {
        setState(() => _insights = insights);
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasInsights = _insights != null;
    final tabCount = hasInsights ? 6 : 1;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(widget.title.isEmpty ? l.kbArticles : widget.title),
        actions: [
          if (_generating)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (!hasInsights)
            IconButton(
              tooltip: l.kbGenerateInsights,
              icon: Icon(LucideIcons.sparkles, size: 20, color: theme.colorScheme.primary),
              onPressed: _generate,
            ),
        ],
      ),
      // ValueKey: TabController.length is immutable, so the controller
      // must rebuild when the reading arrives and the tabs go 1 → 6.
      body: _error != null
          ? ErrorPane(message: _error!)
          : DefaultTabController(
              key: ValueKey(tabCount),
              length: tabCount,
              child: Column(
                children: [
                  AdaptiveTabBar(
                    // Even spread like the wiki tabs (user feedback) —
                    // labels are 2-4 CJK chars, so six still fit a phone;
                    // longer/localized sets scroll horizontally instead
                    // of clipping (AdaptiveTabBar).
                    tabs: [
                      Tab(text: l.kbOriginal),
                      if (hasInsights) ...[
                        Tab(text: l.kbCoreSummary),
                        Tab(text: l.kbChapters),
                        Tab(text: l.kbQuotes),
                        Tab(text: l.kbActions),
                        Tab(text: l.kbSprouts),
                      ],
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _originalTab(context, l),
                        if (hasInsights) ...[
                          _proseTab(context, _insights!.core),
                          _chaptersTab(context),
                          _quotesTab(context),
                          _actionsTab(context),
                          _sproutsTab(context),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _originalTab(BuildContext context, AppLocalizations l) {
    final entries = _entries;
    if (entries == null) return const SkeletonProse();
    if (entries.isEmpty) return EmptyState(icon: LucideIcons.newspaper, message: l.kbEmpty);
    return _proseTab(context, entries.map((e) => e.content).join('\n\n'));
  }

  /// Markdown content in the transcript's look — zh 1.7 leading, tinted
  /// code/blockquote blocks.
  Widget _proseTab(BuildContext context, String text) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: transcriptMarkdown(context, text),
      );

  Widget _chaptersTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in _insights!.chapters) ...[
            Text(c.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            transcriptMarkdown(context, c.body),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _quotesTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final q in _insights!.quotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuoteRow(
                  text: '${q.text} — ${q.tag}',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            ),
        ],
      ),
    );
  }

  Widget _actionsTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in _insights!.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: theme.colorScheme.primary, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(a,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Sprouts: intro, each seed (title / seed line / body / Aha), and the
  /// optional cross-domain echo validating one seed quote.
  Widget _sproutsTab(BuildContext context) {
    final theme = Theme.of(context);
    final ins = _insights!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ins.sproutsIntro.isNotEmpty)
            Text(ins.sproutsIntro,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
          for (final s in ins.sprouts) ...[
            const SizedBox(height: 16),
            Text(s.title, style: theme.textTheme.titleSmall),
            if (s.seed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(s.seed,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline, height: 1.5)),
              ),
            if (s.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(s.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
              ),
            if (s.aha.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Aha: ${s.aha}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.primary, height: 1.5)),
              ),
          ],
          if (ins.echoSeed.isNotEmpty) ...[
            const SizedBox(height: 24),
            _QuoteRow(
                text: ins.echoSeed,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
            if (ins.echoSeedComment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(ins.echoSeedComment,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline, height: 1.5)),
              ),
            for (final e in ins.echoItems) ...[
              const SizedBox(height: 12),
              Text('${e.perspective} · ${e.label}', style: theme.textTheme.titleSmall),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${e.quote} — ${e.source}',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Quote-marked line — lucide quote glyph + text, shared by the quotes
/// tab's entries and the sprouts' echo-seed callout.
class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(LucideIcons.quote,
              size: 14, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
