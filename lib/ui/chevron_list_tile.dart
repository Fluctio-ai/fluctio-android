import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// KB list row (articles / notes / flash / diary / cards / wiki):
/// the same WeChat geometry as SessionTile — timestamp on the title
/// line's right (user feedback 2026-11-21: it used to hang off the
/// ListTile trailing, vertically centered BETWEEN the two lines), the
/// type/preview line below, tight 12px gutters. Titles render at
/// titleMedium (17): the bare Texts used to fall through to ListTile's
/// bodyLarge default, so the KB lists ran a visible size below the
/// session rows — every list surface now shares one title size and one
/// row rhythm, with the paddings scaled to it.
///
/// [padding] overrides the shared rhythm where the host list already
/// pads its children (cards_page).
class ChevronListTile extends StatelessWidget {
  const ChevronListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.selected = false,
    this.onTap,
    this.onLongPress,
  });

  final Widget title;
  final Widget? subtitle;

  /// Timestamp (RowMetaTime family) — rides the title line's right,
  /// aligned to the first title line even when the title wraps.
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  /// Master-detail split: marks the row whose detail is showing.
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
        padding: padding ?? const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            // Tight chevron gutters (user feedback 2026-11-21: the
            // pointer is an affordance, not content) — 12px edges like
            // the session rows, 4px to the title.
            Icon(LucideIcons.chevronRight, size: 16, color: scheme.outline),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title line: title + timestamp at the right, like
                  // WeChat's time-on-the-title-line; start-aligned so a
                  // wrapping title (flash/cards) keeps the time on the
                  // first line.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DefaultTextStyle(
                          style: Theme.of(context).textTheme.titleMedium!,
                          child: title,
                        ),
                      ),
                      if (trailing != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: trailing,
                        ),
                    ],
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: DefaultTextStyle(
                        style: AppTheme.listSubtitleStyle(scheme),
                        child: subtitle!,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
