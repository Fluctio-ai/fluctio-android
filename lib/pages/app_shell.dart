import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../util/app_toast.dart';
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
///
/// Also owns the double-back-to-exit guard: with a ShellRoute, a back
/// press at the inner navigator's bottom routes to the ROOT navigator
/// (go_router's _findCurrentNavigator falls back when the shell can't
/// pop), so a PopScope on any page inside the shell is never consulted —
/// the guard must live HERE, under the root route.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.path, required this.child});

  /// The matched route location (ShellRoute hands over
  /// `state.matchedLocation`); bare paths render without the sidebar.
  final String path;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Pages that never want the shell chrome — web BARE_PATHS parity, plus
  /// /workflow on wide layouts: the embedded web editor needs ~1220 CSS px
  /// (list pane + canvas + properties); 1280 − 300 sidebar = 980 overflows
  /// BOTH edges (the page centers its over-wide content), so the editor
  /// takes the full width and navigation is the back arrow.
  static const _barePaths = ['/setup', '/workflow'];

  DateTime? _lastBackAt;

  @override
  Widget build(BuildContext context) {
    // /setup (pre-login) exits directly — no transcript to protect.
    final guarded = !_barePaths.contains(widget.path);
    Widget body() {
      if (!hasPermanentSidebar(context) ||
          _barePaths.contains(widget.path)) {
        return widget.child;
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
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    if (!guarded) return body();
    // Double-back-to-exit on the shell's bottom route: one stray tap
    // shouldn't kill the transcript mid-session. Drawer/pages open
    // consume back first (navigator local history), so this only sees
    // the bare bottom — from ANY page at its stack root, not just chat.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackAt != null &&
            now.difference(_lastBackAt!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackAt = now;
        AppToast.show(AppLocalizations.of(context)!.exitAgain);
      },
      child: body(),
    );
  }
}
