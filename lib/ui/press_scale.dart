import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// DESIGN.md §4/§6: tactile push feedback — the wrapped control compresses
/// to 0.98 while pressed and springs back in 120ms. A raw-pointer Listener
/// drives it, so the child keeps its own gesture handling (InkWell taps,
/// long-presses) untouched. Disabled controls don't compress.
class TactileScale extends StatefulWidget {
  const TactileScale({super.key, this.enabled = true, this.child});

  final bool enabled;
  final Widget? child;

  @override
  State<TactileScale> createState() => _TactileScaleState();
}

class _TactileScaleState extends State<TactileScale> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final pressed = _down && widget.enabled;
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: pressed ? 0.98 : 1.0,
        duration: AppMotion.press,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
