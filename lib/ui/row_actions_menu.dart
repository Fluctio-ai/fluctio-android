import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';

/// One entry of the long-press row-actions menu — mirrors a swipe
/// action (same icon / label / behavior); [destructive] tints deletes
/// red.
class RowAction {
  const RowAction({
    required this.icon,
    required this.label,
    required this.onRun,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRun;
  final bool destructive;
}

/// Latest pointer-down position, written by the root [Listener] in
/// main.dart. Rows use plain [ListTile.onLongPress] (the callback
/// carries no position), so the menu anchors on the recorded touch
/// point instead.
Offset? lastPointerDown;

/// Long-press channel for row actions: a small menu floating at the
/// touch point (swipe stays the fast path, long-press the discoverable
/// one — both run the same actions). Runs the action after the menu
/// dismisses, so pushed routes (editors, confirm dialogs) land on the
/// page, not on top of the menu.
Future<void> showRowActionsMenu(BuildContext context, List<RowAction> actions) {
  HapticFeedback.mediumImpact();
  final size = (Overlay.of(context).context.findRenderObject() as RenderBox).size;
  // Anchor on the finger press (screen-center fallback for keyboard
  // triggers), clamped so the estimated menu box stays on screen:
  // right-edge rows (right-thumb use) flip the menu left, rows near
  // the bottom lift it up.
  const menuWidth = 232.0;
  const itemHeight = 48.0;
  final anchor = lastPointerDown ?? size.center(Offset.zero);
  final left = (anchor.dx + menuWidth > size.width ? size.width - menuWidth : anchor.dx)
      .clamp(0.0, size.width);
  final top = (anchor.dy + actions.length * itemHeight > size.height
          ? size.height - actions.length * itemHeight
          : anchor.dy)
      .clamp(0.0, size.height);
  final scheme = Theme.of(context).colorScheme;
  return showMenu<String>(
    context: context,
    position:
        RelativeRect.fromLTRB(left, top, size.width - left, size.height - top),
    // Card-family surface and radius — the default M3 menu container
    // tint doesn't match the theme's cool-cyan dark surfaces.
    color: scheme.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 6,
    shape:
        const RoundedRectangleBorder(borderRadius: BorderRadius.all(AppRadius.card)),
    popUpAnimationStyle: AnimationStyle(duration: AppMotion.entrance),
    items: [
      for (var i = 0; i < actions.length; i++)
        PopupMenuItem(
          value: '$i',
          height: itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(actions[i].icon,
                  size: 20,
                  color: actions[i].destructive
                      ? scheme.error
                      : scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(actions[i].label,
                  style: actions[i].destructive
                      ? TextStyle(color: scheme.error)
                      : null),
            ],
          ),
        ),
    ],
  ).then((selected) {
    if (selected != null) actions[int.parse(selected)].onRun();
  });
}

/// The trailing ⋯ row-menu affordance: a ~44px-tall hit box hugging the
/// row's right edge. The PopupMenuButton icon variant centers the 18px
/// glyph in a 48dp box with wide gutters on both sides — this plain
/// child hugs the glyph while the padding grows the tap target. Shared
/// by the session rows (chat list, drawer) and drawer project rows so
/// the spacing can't drift between them.
class RowMenuButton extends StatelessWidget {
  const RowMenuButton({super.key, required this.itemBuilder, this.onSelected});

  final PopupMenuItemBuilder<String> itemBuilder;
  final PopupMenuItemSelected<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      padding: EdgeInsets.zero,
      itemBuilder: itemBuilder,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Icon(LucideIcons.ellipsisVertical,
            size: 18, color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
