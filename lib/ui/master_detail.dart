import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../pages/app_drawer.dart';
import 'breakpoints.dart';

import 'load_states.dart';
import 'pane_divider.dart';

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
  /// detail routes — the same wide gate as the chat split (every wide
  /// adaptation flips at one threshold).
  static bool isSplit(BuildContext context) => isChatSplit(context);

  @override
  State<MasterDetailScaffold> createState() => _MasterDetailScaffoldState();
}

/// Shared list-pane width across every master-detail page (one drag
/// habit everywhere). App-lifetime singleton — a double, nothing to
/// reclaim, so no dispose.
final ValueNotifier<double> _mdListWidth = ValueNotifier(400.0);

class _MasterDetailScaffoldState extends State<MasterDetailScaffold> {
  static const _minWidth = 240.0;

  void _onDrag(double dx) {
    // Left-anchored: dragging right (positive dx) grows the list.
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width * 0.6).clamp(_minWidth, 720.0);
    _mdListWidth.value = (_mdListWidth.value + dx).clamp(_minWidth, maxW);
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
                ValueListenableBuilder<double>(
                  valueListenable: _mdListWidth,
                  child: widget.listPane,
                  builder: (context, w, child) =>
                      SizedBox(width: w, child: child),
                ),
                // Left-anchored: positive drag grows the list.
                PaneDivider(onDrag: _onDrag),
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

/// The 48px header of a master-detail pane: truncated title on the
/// left, optional edit pencil on the right (notes/flash panes; pages
/// with richer chrome build their own).
class DetailPaneHeader extends StatelessWidget {
  const DetailPaneHeader({super.key, required this.title, this.onEdit, this.editTooltip});

  final String title;

  /// Pass null to omit the pencil (view-only panes).
  final VoidCallback? onEdit;
  final String? editTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: editTooltip,
                  icon: const Icon(LucideIcons.penLine, size: 20),
                  onPressed: onEdit,
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}
