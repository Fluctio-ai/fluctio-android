import 'package:flutter/material.dart';

import '../ui/breakpoints.dart';
import 'app_drawer.dart';

/// Adaptive navigation shell (web app-shell.tsx parity): on wide layouts
/// every authenticated page renders next to the permanent left sidebar —
/// chat, the tools pages, wiki, workflow, settings all keep the same
/// navigation surface, like the web PC layout. On phones the shell is a
/// pass-through and pages keep their modal drawers.
///
/// Mounted ONCE around the route tree (ShellRoute) so the sidebar
/// instance — scroll position, expanded projects — survives navigation.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.path, required this.child});

  /// The matched route location (ShellRoute hands over
  /// `state.matchedLocation`); bare paths render without the sidebar.
  final String path;
  final Widget child;

  /// Pages that never want the sidebar chrome (web BARE_PATHS parity).
  /// /workflow joins them on wide layouts: the embedded web editor needs
  /// ~1220 CSS px (list pane + canvas + properties); 1280 − 300 sidebar =
  /// 980 overflows BOTH edges (the page centers its over-wide content),
  /// so the editor takes the full width and navigation is the back arrow.
  static const _barePaths = ['/setup', '/workflow'];

  @override
  Widget build(BuildContext context) {
    if (!hasPermanentSidebar(context) || _barePaths.contains(path)) {
      return child;
    }
    final theme = Theme.of(context);
    // The Material wraps the sidebar: child pages bring their own
    // Scaffold, the drawer content (ListTile/InkWell) needs one above it.
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          const SizedBox(width: 300, child: AppDrawer(embedded: true)),
          VerticalDivider(
              width: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
          Expanded(child: child),
        ],
      ),
    );
  }
}
