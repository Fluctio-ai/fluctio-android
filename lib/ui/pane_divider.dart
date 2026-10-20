import 'package:flutter/material.dart';

/// The draggable strip between two panes (web PaneDivider parity): a
/// 9px hit area over a 1px line, column-resize cursor on pointer
/// devices. The host converts [onDrag]'s horizontal delta into a width
/// delta — right-anchored panes pass it negated.
class PaneDivider extends StatelessWidget {
  const PaneDivider({super.key, required this.onDrag});

  /// Horizontal drag delta in px.
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: SizedBox(
          width: 9,
          child: Center(
            child: Container(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}
