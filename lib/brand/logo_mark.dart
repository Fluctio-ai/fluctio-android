import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'logo_mark_data.dart';
import 'svg_path.dart';

/// Boot loader: the mark starts settled (matching the static system
/// splash), unwinds layer by layer — the reverse of the web assembly —
/// and fades out once. Vector-drawn from the same generated data as the
/// web component, so there is no image asset.
class LogoMarkLoader extends StatefulWidget {
  const LogoMarkLoader({super.key, this.size = 192});

  final double size;

  @override
  State<LogoMarkLoader> createState() => _LogoMarkLoaderState();
}

class _LogoMarkLoaderState extends State<LogoMarkLoader>
    with SingleTickerProviderStateMixin {
  static const _timeline = Duration(milliseconds: 1500);
  late final AnimationController _controller;
  late final List<List<Path>> _paths;

  @override
  void initState() {
    super.initState();
    _paths = [
      for (final tier in markTiers)
        [for (final d in tier.paths) parseSvgPath(d)],
    ];
    _controller = AnimationController(vsync: this, duration: _timeline, value: 1);
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) => CustomPaint(
          painter: _MarkPainter(_controller.value, _paths),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.value, this.paths);

  final double value; // 1 (settled) -> 0 (gone)
  final List<List<Path>> paths;

  static const _timelineMs = 1500.0;
  static const _baseMs = 350.0;
  static const _layerMs = 600.0;

  @override
  void paint(Canvas canvas, Size size) {
    final t = value * _timelineMs;
    final scale = size.width / 1025;
    final center = Offset(size.width / 2, size.height / 2);

    final baseP = (t / _baseMs).clamp(0.0, 1.0);
    final baseEase = _cubicBezier(0.2, 1, 0.3, 1, baseP);
    _paintTier(canvas, scale, center, 0, baseEase, 0.94 + 0.06 * baseEase, 0);

    for (var i = 1; i < markTiers.length; i++) {
      final p = ((t - markTiers[i].delayMs) / _layerMs).clamp(0.0, 1.0);
      final eased = _cubicBezier(0.2, 1.15, 0.35, 1, p);
      final opacity = _cubicBezier(0.2, 1.15, 0.35, 1, (p / 0.3).clamp(0.0, 1.0))
          .clamp(0.0, 1.0);
      _paintTier(canvas, scale, center, i, opacity, 0.96 + 0.04 * eased,
          35 * (1 - eased));
    }
  }

  void _paintTier(Canvas canvas, double scale, Offset center, int index,
      double opacity, double tierScale, double angleDeg) {
    final paint = Paint()..color = markTiers[index].fill.withValues(alpha: opacity);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.rotate((-16 + angleDeg) * math.pi / 180);
    canvas.scale(-1, 1);
    canvas.scale(tierScale);
    canvas.translate(-512.5, -512);
    if (index == 0) {
      canvas.drawCircle(const Offset(512.5, 512), 511.5, paint);
    }
    // Paint this tier's colour under every later-painted tier as well: the
    // source shapes are pre-cut, so otherwise a notch shows while a lighter
    // tier is still in flight. Later tiers repaint those areas.
    for (var j = index; j < markTiers.length; j++) {
      for (final path in paths[j]) {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.value != value;
}

/// Cubic-bezier easing matching the CSS `cubic-bezier(x1, y1, x2, y2)`.
double _cubicBezier(double x1, double y1, double x2, double y2, double t) {
  if (t <= 0) return 0;
  if (t >= 1) return 1;
  var u = t;
  for (var i = 0; i < 8; i++) {
    final x = _bezier(x1, x2, u) - t;
    if (x.abs() < 1e-5) break;
    final d = _bezierDerivative(x1, x2, u);
    if (d.abs() < 1e-6) break;
    u = (u - x / d).clamp(0.0, 1.0);
  }
  return _bezier(y1, y2, u);
}

double _bezier(double c1, double c2, double u) {
  final v = 1 - u;
  return 3 * v * v * u * c1 + 3 * v * u * u * c2 + u * u * u;
}

double _bezierDerivative(double c1, double c2, double u) {
  final v = 1 - u;
  return 3 * v * v * c1 + 6 * v * u * (c2 - c1) + 3 * u * u * (1 - c2);
}
