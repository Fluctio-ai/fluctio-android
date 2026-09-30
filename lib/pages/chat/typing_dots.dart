import 'dart:math' as math;

import 'package:flutter/material.dart';

/// DESIGN.md §4/§6: while a turn streams, feedback is the three-dot
/// typing indicator — a 1.4s flow-easing loop, dots phase-shifted by a
/// third of the cycle, transform and opacity only. Reduced motion freezes
/// the dots (state stays legible, motion drops).
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.size = 5, this.color});

  final double size;
  final Color? color;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final dotColor = widget.color ?? Theme.of(context).colorScheme.outline;
    Widget dot(int i) => reduce
        ? _dot(dotColor)
        : AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final t = (_c.value * 3 - i) % 1.0;
              final up = math.sin(t * math.pi);
              return Transform.translate(
                offset: Offset(0, -3 * up),
                child: Opacity(opacity: 0.3 + 0.7 * up, child: child),
              );
            },
            child: _dot(dotColor),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          dot(i),
        ],
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
