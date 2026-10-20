import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../pages/app_drawer.dart';
import 'breakpoints.dart';
import 'load_states.dart';

/// Wide-layout list|detail host for the tool pages (web md+ parity:
/// knowledge-views / notes / diary / cards all split list-left,
/// detail-right). Owns the page Scaffold (drawer included) so each page
/// keeps only its app bar + list content; on phones the list stands
/// alone and details keep pushing full routes — callers gate row taps
/// with [MasterDetailScaffold.isSplit].
///
/// The list|detail divider is draggable (web PaneDivider parity); the
/// width is shared by every master-detail page (one drag habit
/// everywhere) and lives only in memory — it resets on app restart.
class MasterDetailScaffold extends StatefulWidget {
  const MasterDetailScaffold({
    super.key,
    this.appBar,
    required this.listPane,
    this.detail,
    this.placeholderIcon = LucideIcons.squareMousePointer,
    this.placeholderText = '',
    this.floatingActionButton,
  });

  /// Page app bar — spans the whole content area above both panes.
  final PreferredSizeWidget? appBar;

  /// The always-visible list column.
  final Widget listPane;

  /// The selected item's detail; null = nothing selected. On phones this
  /// is never rendered (details stay pushed routes there).
  final Widget? detail;

  /// Wide + nothing selected: centered hint in the detail area.
  final IconData placeholderIcon;
  final String placeholderText;

  final Widget? floatingActionButton;

  /// True when this page should split list|detail instead of pushing
  /// detail routes (the wide-layout gate shared with the chat split).
  static bool isSplit(BuildContext context) => hasMasterDetail(context);

  @override
  State<MasterDetailScaffold> createState() => _MasterDetailScaffoldState();
}

class _MasterDetailScaffoldState extends State<MasterDetailScaffold> {
  static double _listWidth = 400;

  static const _minWidth = 240.0;

  void _onDrag(double dx) {
    // Left-anchored: dragging right (positive dx) grows the list.
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width * 0.6).clamp(_minWidth, 720.0);
    setState(() => _listWidth = (_listWidth + dx).clamp(_minWidth, maxW));
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    return Scaffold(
      // Same drawer story as every list surface (adaptive = gone on wide,
      // where the AppShell already mounts the permanent sidebar).
      drawer: AppDrawer.adaptive(context),
      drawerEdgeDragWidth: AppDrawer.edgeDragWidth(context),
      appBar: widget.appBar,
      floatingActionButton: widget.floatingActionButton,
      body: !MasterDetailScaffold.isSplit(context)
          ? widget.listPane
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: _listWidth, child: widget.listPane),
                _PaneDivider(onDrag: _onDrag),
                Expanded(
                  child: detail ??
                      Center(
                        child: EmptyState(
                            icon: widget.placeholderIcon,
                            message: widget.placeholderText),
                      ),
                ),
              ],
            ),
    );
  }
}

/// The draggable strip between the list and detail panes (web
/// PaneDivider parity): a 9px hit area over a 1px line, column-resize
/// cursor on pointer devices.
class _PaneDivider extends StatelessWidget {
  const _PaneDivider({required this.onDrag});

  /// Horizontal drag delta in px; the parent converts it to a width
  /// delta (left-anchored: positive grows).
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: SizedBox(
          width: 9,
          child: Center(
            child: Container(width: 1, color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}
