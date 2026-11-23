import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// The app's one swipe-action tile (list rows' endActionPane): neutral
/// tonal fill with icon + label; [destructive] is the only colored
/// variant (error red, kept at the pane's edge). One owner so no pane
/// grows a stray accent again (user call 2026-11-23: UI/VI 一致性;
/// DESIGN.md One Voice Rule — cyan stays on actions/focus, gold stays
/// on warnings, neither belongs on swipe panes).
///
/// Label sits at the caption rung (ladder via labelSmall): swipe chrome
/// is row metadata, not content — the Material button default
/// (labelLarge 15 + 24dp icon) read a step above the 13.5 rows these
/// panes act on.
class SlideActionTile extends StatelessWidget {
  const SlideActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Icon and label take the SAME explicit color — the button's
    // iconColor plumbing doesn't reach the Icon here (it fell back to
    // the dark default on the red block, user report 2026-11-23), and
    // the label would silently inherit a different default. One
    // variable, both widgets.
    final color =
        destructive ? scheme.onError : scheme.onSecondaryContainer;
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: destructive ? scheme.error : scheme.secondaryContainer,
      foregroundColor: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
