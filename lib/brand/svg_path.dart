import 'dart:math' as math;
import 'dart:ui';

final _token = RegExp(
    r'[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');
final _isCommand = RegExp(r'^[A-Za-z]$');

/// Parses the SVG path subset used by the generated brand mark
/// (M/L/H/V/C/S/Q/T/A/Z, absolute and relative).
Path parseSvgPath(String d) {
  final tokens = _token.allMatches(d).map((m) => m[0]!).toList();
  final path = Path();
  var i = 0;
  String? cmd;
  var x = 0.0, y = 0.0; // current point
  var sx = 0.0, sy = 0.0; // subpath start
  var lcx = 0.0, lcy = 0.0; // last control point
  var prev = '';

  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (_isCommand.hasMatch(tokens[i])) cmd = tokens[i++];
    final c = cmd!;
    final rel = c == c.toLowerCase();
    final abs = c.toUpperCase();
    switch (abs) {
      case 'M':
        final nx = next() + (rel ? x : 0);
        final ny = next() + (rel ? y : 0);
        path.moveTo(nx, ny);
        x = nx;
        y = ny;
        sx = x;
        sy = y;
        lcx = x;
        lcy = y;
        // Additional coordinate pairs after a moveto are implicit linetos.
        cmd = rel ? 'l' : 'L';
        break;
      case 'L':
        final nx = next() + (rel ? x : 0);
        final ny = next() + (rel ? y : 0);
        path.lineTo(nx, ny);
        x = nx;
        y = ny;
        lcx = x;
        lcy = y;
        break;
      case 'H':
        final nx = next() + (rel ? x : 0);
        path.lineTo(nx, y);
        x = nx;
        lcx = x;
        lcy = y;
        break;
      case 'V':
        final ny = next() + (rel ? y : 0);
        path.lineTo(x, ny);
        y = ny;
        lcx = x;
        lcy = y;
        break;
      case 'C':
        final x1 = next() + (rel ? x : 0), y1 = next() + (rel ? y : 0);
        final x2 = next() + (rel ? x : 0), y2 = next() + (rel ? y : 0);
        final nx = next() + (rel ? x : 0), ny = next() + (rel ? y : 0);
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        lcx = x2;
        lcy = y2;
        x = nx;
        y = ny;
        break;
      case 'S':
        final x1 = (prev == 'C' || prev == 'S') ? 2 * x - lcx : x;
        final y1 = (prev == 'C' || prev == 'S') ? 2 * y - lcy : y;
        final x2 = next() + (rel ? x : 0), y2 = next() + (rel ? y : 0);
        final nx = next() + (rel ? x : 0), ny = next() + (rel ? y : 0);
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        lcx = x2;
        lcy = y2;
        x = nx;
        y = ny;
        break;
      case 'Q':
        final x1 = next() + (rel ? x : 0), y1 = next() + (rel ? y : 0);
        final nx = next() + (rel ? x : 0), ny = next() + (rel ? y : 0);
        path.quadraticBezierTo(x1, y1, nx, ny);
        lcx = x1;
        lcy = y1;
        x = nx;
        y = ny;
        break;
      case 'T':
        final x1 = (prev == 'Q' || prev == 'T') ? 2 * x - lcx : x;
        final y1 = (prev == 'Q' || prev == 'T') ? 2 * y - lcy : y;
        final nx = next() + (rel ? x : 0), ny = next() + (rel ? y : 0);
        path.quadraticBezierTo(x1, y1, nx, ny);
        lcx = x1;
        lcy = y1;
        x = nx;
        y = ny;
        break;
      case 'A':
        final rx = next(), ry = next(), rot = next();
        final large = next() != 0, sweep = next() != 0;
        final nx = next() + (rel ? x : 0), ny = next() + (rel ? y : 0);
        path.arcToPoint(
          Offset(nx, ny),
          radius: Radius.elliptical(rx, ry),
          rotation: rot * math.pi / 180,
          largeArc: large,
          clockwise: sweep,
        );
        x = nx;
        y = ny;
        lcx = x;
        lcy = y;
        break;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        lcx = x;
        lcy = y;
        break;
      default:
        throw FormatException('unsupported path command $c');
    }
    prev = abs;
  }
  return path;
}
