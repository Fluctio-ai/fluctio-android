import 'package:flutter/material.dart';

import '../../wiki/wiki_models.dart';
import '../../wiki/force_sim.dart';

/// World-space painter for the wiki graph. Pan/zoom live outside (an
/// InteractiveViewer owns the child transform), so this paints raw
/// node/edge coordinates only; [repaint] is the viewer's
/// TransformationController so zoom changes repaint too.
///
/// Labels draw only after the simulation settles — TextPainter layout
/// per frame would cost more than the sim itself; during ticking the
/// moving nodes alone tell the story.
class GraphPainter extends CustomPainter {
  GraphPainter({
    required this.nodes,
    required this.edgeIdx,
    required this.typeOf,
    required this.labelOf,
    required this.palette,
    required this.selected,
    required this.neighbors,
    required this.labels,
    required this.labelStyle,
    required super.repaint,
  });

  final List<SimNode> nodes;
  final List<(int, int)> edgeIdx;
  final Map<String, String> typeOf;

  /// page id → display label (title, already truncated by the caller).
  final Map<String, String> labelOf;
  final WikiGraphPalette palette;
  final String? selected;
  final Set<String> neighbors;
  final bool labels;
  final TextStyle labelStyle;

  final Map<String, TextPainter> _labelCache = {};

  TextPainter _labelFor(SimNode n) => _labelCache[n.id] ??= TextPainter(
        text: TextSpan(text: labelOf[n.id] ?? n.id, style: labelStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final focusing = selected != null;

    final edgePaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1;
    for (final (s, t) in edgeIdx) {
      final a = nodes[s];
      final b = nodes[t];
      final lit = !focusing ||
          a.id == selected ||
          b.id == selected ||
          (neighbors.contains(a.id) && neighbors.contains(b.id));
      edgePaint.color = palette.edge.withValues(alpha: lit ? 0.6 : 0.08);
      canvas.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), edgePaint);
    }

    final fill = Paint()..isAntiAlias = true;
    final ring = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final n in nodes) {
      final r = n.r - 5; // collision radius minus padding
      final faded = focusing && n.id != selected && !neighbors.contains(n.id);
      fill.color =
          palette.node(typeOf[n.id] ?? '').withValues(alpha: faded ? 0.08 : 1);
      canvas.drawCircle(Offset(n.x, n.y), r, fill);
      if (n.id == selected) {
        ring.color = palette.selectedBorder;
        canvas.drawCircle(Offset(n.x, n.y), r + 3, ring);
      }
    }

    if (labels) {
      for (final n in nodes) {
        if (focusing && n.id != selected && !neighbors.contains(n.id)) continue;
        final tp = _labelFor(n);
        tp.paint(canvas, Offset(n.x - tp.width / 2, n.y + n.r - 3));
      }
    }
  }

  @override
  bool shouldRepaint(GraphPainter old) =>
      !identical(old.nodes, nodes) ||
      old.selected != selected ||
      old.labels != labels ||
      old.palette != palette;
}
