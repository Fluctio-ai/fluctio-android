import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Raw-pointer horizontal fling detector that bypasses the gesture arena.
///
/// List surfaces want fling-right for drawer/navigation, but inner
/// recognizers claim every horizontal drag — Slidable rows, gpt_markdown
/// selection panes — and an arena-based recognizer can never win against
/// them (innermost wins). This tracks pointers directly and fires only
/// on a fling-shaped travel: fast, long, horizontal-dominant. Deliberate
/// slow drags (text selection) never fire, and a fling that an inner
/// horizontal scroller actually consumed (code blocks, TabBarView
/// pages) is suppressed via the scroll notifications it bubbles.
class HorizontalFlingDetector extends StatefulWidget {
  const HorizontalFlingDetector({
    super.key,
    required this.child,
    this.onFlingRight,
    this.onFlingLeft,
  });

  final Widget child;
  final VoidCallback? onFlingRight;
  final VoidCallback? onFlingLeft;

  @override
  State<HorizontalFlingDetector> createState() =>
      _HorizontalFlingDetectorState();
}

class _HorizontalFlingDetectorState extends State<HorizontalFlingDetector> {
  // Gesture bookkeeping lives HERE, not in build closures — the parents
  // (chat page, diary day pane) rebuild at streaming/typing frequency,
  // and any rebuild landing inside a gesture window would drop the
  // bookkeeping and silently eat the fling.
  int? _tracked;
  Offset? _start;
  Stopwatch? _watch;
  bool _consumed = false;

  bool _onNotification(ScrollNotification n) {
    // Only FINGER-driven scroll counts as "an inner scroller took it":
    // ballistic/inertia frames carry dragDetails == null, so a leftover
    // momentum tail (or a second finger's drift) can't poison the next
    // gesture's fresh flag.
    final dragDetails = switch (n) {
      ScrollStartNotification(:final dragDetails) => dragDetails,
      ScrollUpdateNotification(:final dragDetails) => dragDetails,
      ScrollEndNotification(:final dragDetails) => dragDetails,
      _ => null,
    };
    if (n.metrics.axis == Axis.horizontal && dragDetails != null) {
      _consumed = true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          if (_tracked != null) return;
          _tracked = e.pointer;
          _start = e.position;
          _consumed = false;
          _watch = Stopwatch()..start();
        },
        onPointerUp: (e) {
          if (e.pointer != _tracked) return;
          _tracked = null;
          final s = _start;
          final w = _watch;
          w?.stop();
          if (s == null || w == null || _consumed) return;
          final dx = e.position.dx - s.dx;
          final dy = e.position.dy - s.dy;
          // Fling shape: a quarter of the screen across, clearly
          // horizontal, within 400ms (≈250px/s at phone widths).
          final minDx = MediaQuery.sizeOf(context).width * 0.25;
          if (dx.abs() < minDx || dy.abs() > dx.abs() * 0.5 ||
              w.elapsedMilliseconds > 400) {
            return;
          }
          if (dx > 0) {
            widget.onFlingRight?.call();
          } else {
            widget.onFlingLeft?.call();
          }
        },
        onPointerCancel: (_) => _tracked = null,
        child: widget.child,
      ),
    );
  }
}

/// [HorizontalFlingDetector] wired to open the modal drawer — the
/// fling fallback for list rows (Slidable) that eat the Scaffold's
/// arena-based drawer drag. A no-op where no modal drawer is mounted
/// (wide layouts run the permanent sidebar instead).
///
/// [active] toggles the callbacks WITHOUT remounting the subtree:
/// flipping between `DrawerFling(child)` and bare `child` swaps the
/// body slot's runtimeType and rebuilds everything under it (scroll
/// positions lost, drags cancelled) — diary's reading-mode flip needs
/// the detector to stay put and just go inert.
class DrawerFling extends StatelessWidget {
  const DrawerFling({super.key, required this.child, this.active = true});

  final Widget child;

  /// When false the detector stays mounted but never fires — the page
  /// owns horizontal flings in that state (diary's day view).
  final bool active;

  @override
  Widget build(BuildContext context) {
    if (!active || hasPermanentSidebar(context)) return child;
    return Builder(builder: (context) {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold == null || !scaffold.hasDrawer) return child;
      return HorizontalFlingDetector(
        onFlingRight: scaffold.openDrawer,
        child: child,
      );
    });
  }
}
