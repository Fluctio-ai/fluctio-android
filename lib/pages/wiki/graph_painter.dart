import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../wiki/wiki_models.dart';
import '../../wiki/force_sim.dart';

/// Screen-space painter for the wiki graph: the page owns pan/zoom as a
/// world→screen [view] matrix and everything here draws in viewport
/// pixels, so zooming never inflates the canvas unboundedly —
///   · node radius grows sublinearly (world r · scale^0.6)
///   · labels stay a constant screen size and cull by on-screen node
///     radius (Obsidian-style progressive reveal)
///   · edges stay hairline (1px)
/// Geometry outside the padded viewport is skipped.
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
    required this.labelCache,
    required this.palette,
    required this.view,
    required this.viewVersion,
    required this.selected,
    required this.neighbors,
    required this.labels,
    required this.labelStyle,
  });

  final List<SimNode> nodes;
  final List<(int, int)> edgeIdx;
  final Map<String, String> typeOf;

  /// page id → display label (title, already truncated by the caller).
  final Map<String, String> labelOf;

  /// TextPainter cache owned by the PAGE (a painter dies every rebuild;
  /// owning it here dropped the layout cache of every label per frame).
  final Map<String, TextPainter> labelCache;
  final WikiGraphPalette palette;

  /// world→screen; [viewVersion] bumps on every change so a fresh
  /// painter instance still reports shouldRepaint (Matrix4 has no
  /// value equality).
  final Matrix4 view;
  final int viewVersion;
  final String? selected;
  final Set<String> neighbors;
  final bool labels;
  final TextStyle labelStyle;

  /// Off-viewport slack — keeps half-offscreen labels' anchors alive.
  static const double _pad = 80;

  TextPainter _labelFor(SimNode n) => labelCache[n.id] ??= TextPainter(
        text: TextSpan(text: labelOf[n.id] ?? n.id, style: labelStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final focusing = selected != null;
    final growth = math.pow(view.getMaxScaleOnAxis(), 0.6).toDouble();

    // Transform + radius once; 80px padding keeps half-offscreen
    // labels' anchors alive. Screen radius is clamped so deep zoom can
    // never let a dot (or its label) swallow the canvas.
    final n = nodes.length;
    final pts = List.filled(n, Offset.zero);
    final radii = List.filled(n, 0.0);
    final onscreen = List.filled(n, false);
    for (var i = 0; i < n; i++) {
      final p = MatrixUtils.transformPoint(view, Offset(nodes[i].x, nodes[i].y));
      final r = ((nodes[i].r - 5) * growth).clamp(2.5, 26.0);
      pts[i] = p;
      radii[i] = r;
      onscreen[i] =
          p.dx > -_pad && p.dy > -_pad && p.dx < size.width + _pad && p.dy < size.height + _pad;
    }

    final edgePaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1;
    for (final (s, t) in edgeIdx) {
      if (!onscreen[s] && !onscreen[t]) continue;
      final aId = nodes[s].id;
      final bId = nodes[t].id;
      final lit = !focusing ||
          aId == selected ||
          bId == selected ||
          (neighbors.contains(aId) && neighbors.contains(bId));
      edgePaint.color = palette.edge.withValues(alpha: lit ? 0.6 : 0.08);
      canvas.drawLine(pts[s], pts[t], edgePaint);
    }

    final fill = Paint()..isAntiAlias = true;
    final ring = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (var i = 0; i < n; i++) {
      if (!onscreen[i]) continue;
      final id = nodes[i].id;
      final faded = focusing && id != selected && !neighbors.contains(id);
      fill.color =
          palette.node(typeOf[id] ?? '').withValues(alpha: faded ? 0.08 : 1);
      canvas.drawCircle(pts[i], radii[i], fill);
      if (id == selected) {
        ring.color = palette.selectedBorder;
        canvas.drawCircle(pts[i], radii[i] + 3, ring);
      }
    }

    if (labels) {
      for (var i = 0; i < n; i++) {
        if (!onscreen[i]) continue;
        final id = nodes[i].id;
        final relevant = radii[i] >= 3.2 ||
            (focusing && (id == selected || neighbors.contains(id)));
        if (!relevant) continue;
        if (focusing && id != selected && !neighbors.contains(id)) continue;
        final tp = _labelFor(nodes[i]);
        tp.paint(canvas, Offset(pts[i].dx - tp.width / 2, pts[i].dy + radii[i] + 2));
      }
    }
  }

  @override
  bool shouldRepaint(GraphPainter old) =>
      !identical(old.nodes, nodes) ||
      old.viewVersion != viewVersion ||
      old.selected != selected ||
      old.labels != labels ||
      old.palette != palette;
}
