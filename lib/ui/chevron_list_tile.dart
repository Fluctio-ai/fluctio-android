import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// KB list row: wiki-style leading chevron over the web row rhythm
/// (web knowledge-views: ChevronRight h-3, muted; px-3 padding, gap-2
/// to the title) — the single home for the look shared by the KB
/// pages, instead of bare-text rows or default ListTile gutters.
///
/// [padding] overrides the shared rhythm where the host list already
/// pads its children (cards_page); [dense]/[trailing] pass through.
class ChevronListTile extends StatelessWidget {
  const ChevronListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.dense = false,
    this.padding,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool dense;
  final EdgeInsetsGeometry? padding;

  /// Master-detail split: marks the row whose detail is showing.
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      // Tight chevron gutters (user feedback 2026-11-21: the pointer is
      // an affordance, not content) — 12px edges like the session rows,
      // 4px to the title.
      contentPadding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
      horizontalTitleGap: 4,
      dense: dense,
      selected: selected,
      leading: Icon(LucideIcons.chevronRight, size: 16, color: scheme.outline),
      title: title,
      subtitle: subtitle,
      subtitleTextStyle: AppTheme.listSubtitleStyle(scheme),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
