import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../kb/kb_models.dart';
import '../../kb/kb_repo.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../../theme/tokens.dart';

/// Spaced-repetition review session: flip-card over the due queue, one
/// grade per card (forgot / fuzzy / remembered), ends with a summary.
class KbCardReviewPage extends ConsumerStatefulWidget {
  const KbCardReviewPage({super.key});

  @override
  ConsumerState<KbCardReviewPage> createState() => _KbCardReviewPageState();
}

class _KbCardReviewPageState extends ConsumerState<KbCardReviewPage> {
  final List<KbCard> _queue = [];
  int _index = 0;
  bool _revealed = false;
  int _forgot = 0;
  int _fuzzy = 0;
  int _remembered = 0;
  String? _error;
  bool _loading = true;
  double _swipeDx = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    try {
      final queue = await ref.read(kbRepoProvider).cardQueue(agentId);
      if (!mounted) return;
      setState(() {
        _queue.addAll(queue);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {_error = '$e'; _loading = false;});
    }
  }

  Future<void> _grade(String grade) async {
    final agentId = ref.read(agentsProvider).selectedId;
    final card = _queue[_index];
    if (agentId != null) {
      try {
        await ref.read(kbRepoProvider).reviewCard(agentId, card.id, grade);
      } catch (_) {
        // The grade is recorded server-side on success; a network blip
        // still advances the local session.
      }
    }
    setState(() {
      switch (grade) {
        case 'forgot':
          _forgot++;
        case 'fuzzy':
          _fuzzy++;
        default:
          _remembered++;
      }
      _revealed = false;
      _index++;
    });
  }

  /// Left = forgot, right = remembered — grades on either a decisive
  /// travel (>60px) or a fling; weak drags spring back ungraded.
  void _onSwipeEnd(DragEndDetails d) {
    final dx = _swipeDx;
    final vx = d.velocity.pixelsPerSecond.dx;
    setState(() => _swipeDx = 0);
    if (dx.abs() <= 60 && vx.abs() <= 600) return;
    final right = vx.abs() > 600 ? vx > 0 : dx > 0;
    _grade(right ? 'remembered' : 'forgot');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.cardReview)),
      body: _loading
          ? const SkeletonProse()
          : _error != null
              ? ErrorPane(message: _error!)
              : _index >= _queue.length
                  ? _summary(context, theme, l)
                  : _cardArea(context, theme, l),
    );
  }

  Widget _cardArea(BuildContext context, ThemeData theme, AppLocalizations l) {
    final card = _queue[_index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('${_index + 1} / ${_queue.length}', style: theme.textTheme.labelMedium),
              const Spacer(),
              Text('${l.cardRemembered} $_remembered',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // Horizontal grade swipes once revealed (ticket 13):
            // left = forgot, right = remembered; the fuzzy grade stays
            // a button. Threshold on travel + velocity keeps taps
            // (flip) and small nudges safe.
            child: GestureDetector(
              onHorizontalDragUpdate:
                  _revealed ? (d) => setState(() => _swipeDx += d.delta.dx) : null,
              onHorizontalDragEnd: _revealed ? _onSwipeEnd : null,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _swipeDx),
                duration: _swipeDx == 0
                    ? const Duration(milliseconds: 180)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                builder: (context, dx, child) =>
                    Transform.translate(offset: Offset(dx, 0), child: child),
                child: InkWell(
                  onTap: () => setState(() => _revealed = !_revealed),
                  borderRadius: AppRadius.cardBorder,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: surfaceCardDecoration(theme.colorScheme),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card.question,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                        ),
                        if (_revealed) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(),
                          ),
                          Text(
                            card.answer,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.6, color: theme.colorScheme.primary),
                          ),
                          // Origin excerpt once revealed — "where did this
                          // card come from" aids recall; manual cards have
                          // none.
                          if (card.sourceExcerpt.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.quote,
                                    size: 12, color: theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Text(
                                  l.cardSource,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              card.sourceExcerpt,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(height: 1.5, color: theme.colorScheme.outline),
                            ),
                          ],
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(l.cardTapToReveal,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: theme.colorScheme.outline)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: _revealed ? () => _grade('forgot') : null,
                  child: Text(l.cardForgot),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
                  ),
                  onPressed: _revealed ? () => _grade('fuzzy') : null,
                  child: Text(l.cardFuzzy),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
                  ),
                  onPressed: _revealed ? () => _grade('remembered') : null,
                  child: Text(l.cardRemembered),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context, ThemeData theme, AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.partyPopper, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(l.cardDone, style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          Text('${l.cardRemembered}: $_remembered    ${l.cardFuzzy}: $_fuzzy    ${l.cardForgot}: $_forgot',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cardBack),
          ),
        ],
      ),
    );
  }
}
