import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The one floating-action standard (user call 2026-11-21): the quiet
/// 44dp rounded-square the chat transcript's jump-to-latest pill
/// established — surface fill, hairline border, 6px control radius,
/// 20px glyph. Every list page's add button renders through this so
/// the floating affordance can't drift in size, shape or color.
/// Position stays the host's default slot (bottom-right).
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.onPressed, required this.icon});

  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Quiet on purpose — the ORIGINAL jump-pill colors (user feedback):
    // a filled primary block floating over content was too loud.
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.controlBorder,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        // 12 + 20px icon = 44dp — the app-wide touch-target floor
        // (DESIGN.md).
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
