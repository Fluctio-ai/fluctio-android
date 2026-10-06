import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluctio_android/wiki/force_sim.dart';

void main() {
  ForceSim build(int n, List<(int, int)> links) {
    final nodes = [for (var i = 0; i < n; i++) SimNode('n$i', 12)];
    return ForceSim(nodes: nodes, links: links, width: 2200, height: 1400);
  }

  test('cools within a bounded number of ticks, positions stay finite', () {
    final sim = build(40, [for (var i = 0; i < 39; i++) (i, i + 1)]);
    var ticks = 0;
    while (!sim.cooled && ticks < 1000) {
      sim.tick();
      ticks++;
    }
    expect(sim.cooled, isTrue,
        reason: 'alpha decay 0.97/tick must cool within ~130 ticks');
    for (final n in sim.nodes) {
      expect(n.x.isFinite && n.y.isFinite, isTrue);
      // World bounds plus slack — nothing escapes to the moon.
      expect(n.x, inInclusiveRange(-500, 2700));
      expect(n.y, inInclusiveRange(-500, 1900));
    }
  });

  test('linked nodes sit closer than unlinked ones on average', () {
    final sim = build(30, [for (var i = 0; i < 29; i++) (i, i + 1)]);
    while (!sim.cooled) {
      sim.tick();
    }
    final nodes = sim.nodes;
    double dist(int a, int b) {
      final dx = nodes[a].x - nodes[b].x;
      final dy = nodes[a].y - nodes[b].y;
      return math.sqrt(dx * dx + dy * dy);
    }

    var linked = 0.0;
    for (var i = 0; i + 1 < nodes.length; i++) {
      linked += dist(i, i + 1);
    }
    linked /= nodes.length - 1;

    var unlinked = 0.0;
    var count = 0;
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 2; j < nodes.length; j++) {
        unlinked += dist(i, j);
        count++;
      }
    }
    unlinked /= count;

    expect(linked, lessThan(unlinked),
        reason: 'springs must hold chain neighbours closer than strangers');
  });

  test('deterministic: identical input lays out identically', () {
    ForceSim run() {
      final sim = build(12, const [(0, 1), (1, 2), (2, 0), (3, 4)]);
      while (!sim.cooled) {
        sim.tick();
      }
      return sim;
    }

    final a = run();
    final b = run();
    for (var i = 0; i < a.nodes.length; i++) {
      expect(b.nodes[i].x, closeTo(a.nodes[i].x, 0.0001));
      expect(b.nodes[i].y, closeTo(a.nodes[i].y, 0.0001));
    }
  });
}
