import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand waves (DESIGN.md §6, app take on the web logo-wave): three
/// surge-cyan bands phase-shifted by a third of the cycle, drifting on a
/// 3.9s loop — standing water never looks alive. Painted (not an asset),
/// so the drift is a continuous phase advance instead of the SVG's
/// 0→64→0 translate and never clips. Reduced motion freezes the bands.
/// Login/empty-state surfaces only, never a resident bar.
class BrandWave extends StatefulWidget {
  const BrandWave({super.key, this.size = 48});

  final double size;

  @override
  State<BrandWave> createState() => _BrandWaveState();
}

class _BrandWaveState extends State<BrandWave> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3900));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      if (_c.isAnimating) {
        _c.stop();
        _c.value = 0;
      }
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _WavePainter(progress: _c.value, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const cycles = 2;
    for (var band = 0; band < 3; band++) {
      final phase = progress * 2 * math.pi - band * 2 * math.pi / 3;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band == 0 ? 2.6 : band == 1 ? 2.0 : 1.6
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: band == 0 ? 0.95 : band == 1 ? 0.6 : 0.32);
      final path = Path();
      final amp = h / 2 - 2;
      for (var px = 0.0; px <= w; px += 1) {
        final y = h / 2 + amp * math.sin((px / w) * 2 * math.pi * cycles + phase);
        if (px == 0) {
          path.moveTo(px, y);
        } else {
          path.lineTo(px, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.progress != progress || old.color != color;
}
