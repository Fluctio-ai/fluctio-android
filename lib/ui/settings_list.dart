import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';

/// Grouped-list kit — the single implementation of "section label +
/// tinted card + icon rows" shared by the profile page, the system
/// settings center, and the app drawer (UI optimization decision 2).
/// One row rhythm: 20px icon at 16px inset, 16px icon-label gap, 14px
/// vertical padding, hairline dividers indented past the icon.

/// Section label above a [SettingsGroup] (or the drawer's lists). The
/// default padding is the page variant — the label sits 4px inside the
/// 16px card margin; the drawer passes its own tighter inset.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.action, this.onAction, this.padding});

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.xl, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (action != null)
            InkWell(
              onTap: onAction,
              borderRadius: AppRadius.controlBorder,
              child: Padding(
                // ≥40px tall touch row around the small "＋ new" text.
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.plus, size: 13),
                    const SizedBox(width: AppSpace.xs),
                    Text(action!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tinted card wrapping [SettingsTile] rows with hairline dividers
/// between them (surfaceCardDecoration — the app's signature grouped
/// surface).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      decoration: surfaceCardDecoration(scheme),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: scheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Standard row inside a [SettingsGroup]: icon in `primary` (the app's
/// "actionable" signal) + label + optional value + optional trailing.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpace.lg),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpace.md),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            if (trailing != null)
              Padding(padding: const EdgeInsets.only(left: AppSpace.xs), child: trailing!),
          ],
        ),
      ),
    );
  }
}
