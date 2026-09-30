import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';

// Shared loading/empty/error surfaces (DESIGN.md §4): skeletons match the
// target layout's rhythm, empties are composed compositions (glyph +
// copy + optional entry), errors report inline with an optional retry.
// Never a generic centered spinner or a bare "No data" row.

/// List-shaped skeleton: leading glyph square + title/subtitle bars at
/// ListTile rhythm, staggered widths, nested 4px radii. Static on purpose
/// — transient placeholders don't spend the per-screen looping-motion
/// budget (DESIGN.md §6).
class SkeletonListView extends StatelessWidget {
  const SkeletonListView({super.key, this.itemCount = 6, this.leading = true});

  final int itemCount;
  final bool leading;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [SkeletonList(itemCount: itemCount, leading: leading)],
      );
}

/// [SkeletonListView]'s rows as a plain column — for embedding inside
/// sheets and panels whose parent already owns the scroll
/// (app drawer sections, agent-settings tab bodies).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6, this.leading = true});

  final int itemCount;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final bar = Theme.of(context).colorScheme.secondaryContainer;
    Widget line(double widthFactor, double height) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.all(AppRadius.nested)),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < itemCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (leading) ...[
                  Container(
                    width: 20,
                    height: 20,
                    decoration:
                        BoxDecoration(color: bar, borderRadius: BorderRadius.all(AppRadius.nested)),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(switch (i % 3) { 0 => 1.0, 1 => 0.9, _ => 0.8 }, 12),
                      const SizedBox(height: 8),
                      line(switch (i % 3) { 0 => 0.7, 1 => 0.55, _ => 0.85 }, 9),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Prose-shaped skeleton for reading surfaces (article detail): a heavy
/// headline bar, then paragraph groups of staggered body lines.
class SkeletonProse extends StatelessWidget {
  const SkeletonProse({super.key, this.paragraphs = 4});

  final int paragraphs;

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [SkeletonProseLines(paragraphs: paragraphs)],
      );
}

/// [SkeletonProse]'s bars as a plain column — for embedding inside
/// another scrollable's children (article detail's body list).
class SkeletonProseLines extends StatelessWidget {
  const SkeletonProseLines({super.key, this.paragraphs = 4});

  final int paragraphs;

  @override
  Widget build(BuildContext context) {
    final bar = Theme.of(context).colorScheme.secondaryContainer;
    Widget line(double widthFactor, {double height = 10}) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.all(AppRadius.nested)),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: line(0.75, height: 18),
        ),
        for (var p = 0; p < paragraphs; p++) ...[
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: line(i == 2 ? 0.6 : 1.0),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Composed empty state: 40px line glyph + one line of copy + optional
/// entry action. Not a bare "No data" text row.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Inline error surface: alert glyph + message (+ retry when the caller
/// can refresh its provider).
class ErrorPane extends StatelessWidget {
  const ErrorPane({super.key, required this.message, this.onRetry, this.retryLabel});

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
            if (onRetry != null && retryLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
