import 'package:flutter/material.dart';

/// The shared section rhythm of the KB card surfaces: labelSmall/w600/
/// outline header, 6px gap, body — cards view page and review flip
/// side both lay their content out through it.
class LabeledSection extends StatelessWidget {
  const LabeledSection({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
