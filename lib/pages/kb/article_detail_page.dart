import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Article detail: full text (chunks joined) with the deep-reading
/// insights section — generate on demand, render compactly.
class KbArticleDetailPage extends ConsumerStatefulWidget {
  const KbArticleDetailPage({super.key, required this.sourceId, this.title = ''});

  final String sourceId;
  final String title;

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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title.isEmpty ? l.kbArticles : widget.title)),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_entries == null)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_entries!.isEmpty)
                  Text(l.kbEmpty, style: theme.textTheme.bodyMedium)
                else
                  SelectableText(
                    _entries!.map((e) => e.content).join('\n\n'),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                const SizedBox(height: 24),
                _insightsSection(context, theme, l),
              ],
            ),
    );
  }

  Widget _insightsSection(BuildContext context, ThemeData theme, AppLocalizations l) {
    if (_generating) {
      return Row(
        children: [
          const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(l.kbGenerating, style: theme.textTheme.bodySmall),
        ],
      );
    }
    if (_insights == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
        ),
        onPressed: _generate,
        icon: const Icon(LucideIcons.sparkles, size: 16),
        label: Text(l.kbGenerateInsights),
      );
    }
    final insights = _insights;
    if (insights == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.sparkles, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(l.kbInsights, style: theme.textTheme.titleSmall),
          ],
        ),
        if (insights.core.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(insights.core, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
          ),
        for (final c in insights.chapters) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(c.title, style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(c.body, style: theme.textTheme.bodySmall?.copyWith(height: 1.6)),
          ),
        ],
        if (insights.quotes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(l.kbQuotes, style: theme.textTheme.titleSmall),
          ),
          for (final q in insights.quotes)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('❝ ', style: TextStyle(color: theme.colorScheme.primary)),
                  Expanded(
                    child: Text('${q.text} — ${q.tag}',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                  ),
                ],
              ),
            ),
        ],
        if (insights.actions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(l.kbActions, style: theme.textTheme.titleSmall),
          ),
          for (final a in insights.actions)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Text('• $a', style: theme.textTheme.bodySmall),
            ),
        ],
      ],
    );
  }
}
