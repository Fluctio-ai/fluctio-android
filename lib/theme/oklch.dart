import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// OkLCH → sRGB [Color], mirroring what CSS `oklch()` does in the browser.
///
/// The web theme (fastclaw `web/src/app/globals.css`) stores every palette
/// entry as an oklch literal; converting at runtime — instead of pasting
/// hand-converted hex — keeps the token table byte-for-byte comparable with
/// the CSS source of truth.
///
/// Math per Björn Ottosson's OKLab spec: polar → cartesian OKLab, the
/// non-linear LMS' cube, the linear-sRGB matrix, then the standard sRGB
/// transfer function with clamping.
Color oklch(double l, double c, double h) {
  final rad = h * math.pi / 180.0;
  final a = c * math.cos(rad);
  final b = c * math.sin(rad);

  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

  final lC = l_ * l_ * l_;
  final mC = m_ * m_ * m_;
  final sC = s_ * s_ * s_;

  double linear = 4.0767416621 * lC - 3.3077115913 * mC + 0.2309699292 * sC;
  double r = _encode(linear);
  linear = -1.2684380046 * lC + 2.6097574011 * mC - 0.3413193965 * sC;
  double g = _encode(linear);
  linear = -0.0041960863 * lC - 0.7034186147 * mC + 1.7076147010 * sC;
  double bl = _encode(linear);

  return Color.fromARGB(255, (r * 255).round(), (g * 255).round(), (bl * 255).round());
}

double _encode(double x) {
  if (x <= 0.0031308) return _clamp(x * 12.92);
  return _clamp(1.055 * math.pow(x, 1 / 2.4).toDouble() - 0.055);
}

double _clamp(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
