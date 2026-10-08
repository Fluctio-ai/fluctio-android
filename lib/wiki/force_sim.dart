import 'dart:math' as math;

/// Minimal d3-force-style simulation for the wiki graph: many-body
/// repulsion + circle collision in one O(n²) pair pass, link springs,
/// centering pull, exponential alpha cooling. Tuning follows the web
/// engine (wiki-graph/engine.ts): link strength 1/deg softens hubs,
/// collision radius exceeds the draw radius so zoomed-in nodes spread.
/// Pure Dart (no Flutter) — a Ticker drives [tick] until [cooled].
class SimNode {
  SimNode(this.id, this.r);

  final String id;

  /// Collision radius; draw radius stays this minus padding.
  final double r;
  double x = 0, y = 0, vx = 0, vy = 0;
}

class ForceSim {
  ForceSim({
    required this.nodes,
    required List<(int, int)> links,
    required this.width,
    required this.height,
  }) {
    _degrees = List.filled(nodes.length, 0);
    _links = [
      for (final (s, t) in links)
        if (s >= 0 && s < nodes.length && t >= 0 && t < nodes.length) (s, t),
    ];
    for (final (s, t) in _links) {
      _degrees[s]++;
      _degrees[t]++;
    }
    // Phyllotaxis seed: even spiral coverage, deterministic jitter so
    // identical graphs lay out identically (tests rely on it).
    final rand = math.Random(7);
    for (var i = 0; i < nodes.length; i++) {
      final angle = i * 2.399963; // golden angle
      final dist = 18 * math.sqrt(i + 0.5);
      nodes[i].x = width / 2 + dist * math.cos(angle) + (rand.nextDouble() - .5) * 4;
      nodes[i].y = height / 2 + dist * math.sin(angle) + (rand.nextDouble() - .5) * 4;
    }
  }

  final List<SimNode> nodes;
  final double width;
  final double height;
  late final List<(int, int)> _links;
  late final List<int> _degrees;
  double _alpha = 1;

  /// Held by an interactive drag: exempt from forces and integration so
  /// the hand wins while neighbours relax around it.
  SimNode? pinned;

  bool get cooled => _alpha < 0.02;

  /// Wake the sim back up (node drag / user nudges) — alpha decay still
  /// cools it back down.
  void reheat([double a = 0.3]) {
    if (_alpha < a) _alpha = a;
  }

  /// One integration step. [charges] scales the repulsion strength so
  /// callers can retune density without touching this file.
  void tick({double repulsion = 4200, double linkDistance = 85}) {
    _alpha *= 0.97;
    final k = _alpha;

    // Repulsion + collision, one pair pass. The 300px cutoff keeps the
    // O(n²) loop cheap once the layout has spread.
    for (var i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      if (a == pinned) continue;
      for (var j = i + 1; j < nodes.length; j++) {
        final b = nodes[j];
        if (b == pinned) continue;
        var dx = b.x - a.x;
        var dy = b.y - a.y;
        var d2 = dx * dx + dy * dy;
        if (d2 < 0.01) {
          dx = ((i * 7 + j * 13) % 11 - 5).toDouble();
          dy = ((i * 5 + j * 3) % 11 - 5).toDouble();
          d2 = dx * dx + dy * dy + 0.5;
        }
        if (d2 > 90000) continue;
        final d = math.sqrt(d2);
        final f = (repulsion / d2) * k;
        var fx = dx / d * f;
        var fy = dy / d * f;
        final minDist = a.r + b.r + 14;
        if (d < minDist) {
          final push = (minDist - d) * 0.5 * k;
          fx += dx / d * push;
          fy += dy / d * push;
        }
        a.vx -= fx;
        a.vy -= fy;
        b.vx += fx;
        b.vy += fy;
      }
    }

    // Link springs: strength 1/deg keeps hub neighbours from clumping.
    for (final (s, t) in _links) {
      final a = nodes[s];
      final b = nodes[t];
      if (a == pinned && b == pinned) continue;
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      final deg = math.max(1, math.min(_degrees[s], _degrees[t]));
      final f = (d - linkDistance) / d * (0.9 / deg) * k;
      final fx = dx * f;
      final fy = dy * f;
      if (a != pinned) {
        a.vx += fx;
        a.vy += fy;
      }
      if (b != pinned) {
        b.vx -= fx;
        b.vy -= fy;
      }
    }

    // Centering pull + damped integration.
    for (final n in nodes) {
      if (n == pinned) continue;
      n.vx += (width / 2 - n.x) * 0.015 * k;
      n.vy += (height / 2 - n.y) * 0.015 * k;
      n.vx *= 0.6;
      n.vy *= 0.6;
      n.x += n.vx;
      n.y += n.vy;
    }
  }
}
