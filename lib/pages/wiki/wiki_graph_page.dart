import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../ui/load_states.dart';
import '../../wiki/force_sim.dart';
import '../../wiki/wiki_models.dart';
import '../../wiki/wiki_repo.dart';
import 'graph_painter.dart';

final wikiGraphProvider = FutureProvider.family<WikiGraphInfo, String>((ref, agentId) {
  return ref.watch(wikiRepoProvider).graph(agentId);
});

/// Native force-directed wiki graph (this surface's replacement for
/// the web's WebGL engine): [ForceSim] computes positions, the page
/// owns the world→screen view matrix (pan / pinch via onScale*,
/// node drag pins the node and reheats the sim), [GraphPainter] draws
/// in screen space. Taps select (tapping the selected node clears);
/// a selection fades non-neighbours and the bottom bar jumps into the
/// preview.
class WikiGraphPage extends ConsumerStatefulWidget {
  const WikiGraphPage({super.key, this.focusId});

  /// Preselect + center this page (the detail view's "view in graph").
  final String? focusId;

  @override
  ConsumerState<WikiGraphPage> createState() => _WikiGraphPageState();
}

class _WikiGraphPageState extends ConsumerState<WikiGraphPage>
    with SingleTickerProviderStateMixin {
  static const Size _world = Size(2200, 1400);
  static const double _minScale = 0.12, _maxScale = 3.5;

  late final Ticker _ticker;
  Size _viewport = Size.zero;
  ForceSim? _sim;
  List<SimNode> _nodes = const [];
  List<(int, int)> _edges = const [];
  Map<String, String> _typeOf = const {};

  /// id → truncated label, built once per graph (every paint frame reads
  /// it — per-build truncation cost a string pass per setState).
  Map<String, String> _labelOf = const {};

  /// TextPainter cache owned by the page: a painter instance dies with
  /// every rebuild (pinch/zoom runs at frame rate), which used to drop
  /// the layout cache of every label each frame.
  final Map<String, TextPainter> _labelCache = {};
  Map<String, String> _titleOf = const {};
  Map<String, List<String>> _adj = {};
  String? _selected;
  Set<String> _neighbors = {};
  bool _labels = false;
  String? _builtFor;

  // View (world→screen) + a version stamp — Matrix4 has no value
  // equality, so the painter needs an int to detect change.
  final Matrix4 _view = Matrix4.identity();
  int _viewVersion = 0;

  // Gesture state: node drag vs canvas pan/pinch, rebuilt each gesture
  // from the snapshot taken at onScaleStart. The drag candidate is
  // recorded on touch-down but only ACTIVATED once the pointer moves —
  // pinning/reheating on touch-down would jiggle the node away before
  // the tap's hit test ran (nodes became untappable after zoom).
  SimNode? _dragged;
  SimNode? _dragCandidate;
  Matrix4? _viewAtGestureStart;
  Offset? _gestureFocal;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    final sim = _sim;
    if (sim == null) return;
    for (var i = 0; i < 3; i++) {
      sim.tick();
    }
    if (sim.cooled && !_labels) {
      _labels = true;
      _ticker.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fit();
        final focus = widget.focusId;
        if (focus != null && _titleOf.containsKey(focus)) _select(focus);
      });
    }
    setState(() {});
  }

  /// Idempotent build keyed by a cheap signature — the provider may
  /// re-emit unchanged data on ref watches.
  void _buildGraph(WikiGraphInfo g) {
    final sig = '${g.nodes.length}:${g.edges.length}:'
        '${g.nodes.isEmpty ? '' : g.nodes.first.id}';
    if (sig == _builtFor) return;
    _builtFor = sig;

    final deg = <String, int>{};
    for (final e in g.edges) {
      deg[e.src] = (deg[e.src] ?? 0) + 1;
      deg[e.dst] = (deg[e.dst] ?? 0) + 1;
    }
    final idx = <String, int>{};
    for (var i = 0; i < g.nodes.length; i++) {
      idx[g.nodes[i].id] = i;
    }
    _nodes = [
      for (final p in g.nodes)
        // Draw radius grows with degree (hub), +5 collision padding.
        SimNode(p.id, (4 + math.sqrt((deg[p.id] ?? 0) * 1.8)).clamp(9.0, 17.0) + 5),
    ];
    _edges = [
      for (final e in g.edges)
        if (idx.containsKey(e.src) && idx.containsKey(e.dst))
          (idx[e.src]!, idx[e.dst]!),
    ];
    _typeOf = {for (final p in g.nodes) p.id: p.pageType};
    _titleOf = {for (final p in g.nodes) p.id: p.title};
    // 12 CJK chars + ellipsis — the web engine's label cap.
    _labelOf = {
      for (final p in g.nodes)
        p.id: p.title.length > 12 ? '${p.title.substring(0, 12)}…' : p.title,
    };
    _adj = {};
    for (final e in g.edges) {
      _adj.putIfAbsent(e.src, () => []).add(e.dst);
      _adj.putIfAbsent(e.dst, () => []).add(e.src);
    }
    _selected = null;
    _neighbors = {};
    _labels = false;
    _sim = ForceSim(
        nodes: _nodes, links: _edges, width: _world.width, height: _world.height);
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  // ---- view helpers ----

  double get _scale => _view.getMaxScaleOnAxis();

  void _setView(Matrix4 m) {
    _view.setFrom(m);
    setState(() => _viewVersion++);
  }

  Offset _screenToWorld(Offset p) => MatrixUtils.transformPoint(
      Matrix4.inverted(_view), p);

  void _fit() {
    if (_viewport == Size.zero) return;
    final s = math.max(
        _minScale,
        math.min(_viewport.width / _world.width, _viewport.height / _world.height) *
            0.95);
    final m = Matrix4.identity()
      ..scaleByDouble(s, s, 1, 1);
    m.storage[12] = (_viewport.width - _world.width * s) / 2;
    m.storage[13] = (_viewport.height - _world.height * s) / 2;
    _setView(m);
  }

  void _centerOn(SimNode node) {
    if (_viewport == Size.zero) return;
    final s = _scale;
    final m = Matrix4.identity()..scaleByDouble(s, s, 1, 1);
    m.storage[12] = _viewport.width / 2 - node.x * s;
    m.storage[13] = _viewport.height / 2 - node.y * s;
    _setView(m);
  }

  /// Zoom around a screen-space anchor: view' = T(f) · S(k) · T(-f) · view.
  Matrix4 _zoomed(Matrix4 base, Offset f, double k) {
    final t = Matrix4.identity()
      ..translateByDouble(f.dx, f.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-f.dx, -f.dy, 0, 1);
    t.multiply(base); // t = t·base — base maps world→screen, then the zoom
    return t;
  }

  // ---- gestures ----

  SimNode? _nodeAt(Offset screen) {
    final w = _screenToWorld(screen);
    final hitPad = 14 / _scale;
    SimNode? best;
    var bestD2 = double.infinity;
    for (final n in _nodes) {
      final dx = n.x - w.dx;
      final dy = n.y - w.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = n;
      }
    }
    if (best == null) return null;
    final threshold = best.r - 5 + hitPad;
    return bestD2 <= threshold * threshold ? best : null;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _viewAtGestureStart = _view.clone();
    _gestureFocal = d.localFocalPoint;
    _dragCandidate = _nodeAt(d.localFocalPoint);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final base = _viewAtGestureStart;
    final focal0 = _gestureFocal;
    if (base == null || focal0 == null) return;
    final moved = (d.localFocalPoint - focal0).distance > 8;

    // A second finger landing cancels a drag — pinch takes over.
    if (d.pointerCount > 1 && _dragged != null) {
      _endDrag();
      _viewAtGestureStart = _view.clone();
    }

    if (_dragged == null && moved && d.pointerCount == 1 && _dragCandidate != null) {
      // The gesture became a drag — pin + wake the sim only now.
      _dragged = _dragCandidate;
      _sim?.pinned = _dragged;
      _sim?.reheat(0.25);
      if (!_ticker.isActive) _ticker.start();
    }

    if (_dragged != null) {
      final w = MatrixUtils.transformPoint(Matrix4.inverted(base), d.localFocalPoint);
      _dragged!.x = w.dx;
      _dragged!.y = w.dy;
      _dragged!.vx = _dragged!.vy = 0;
      if (!_ticker.isActive) _ticker.start();
      setState(() {});
      return;
    }

    // Pan + pinch, rebuilt from the gesture-start snapshot.
    final s0 = base.getMaxScaleOnAxis();
    final k = ((s0 * d.scale).clamp(_minScale, _maxScale)) / s0;
    final m = _zoomed(base, focal0, k);
    final pan = d.localFocalPoint - focal0;
    m.storage[12] += pan.dx;
    m.storage[13] += pan.dy;
    _setView(m);
  }

  void _endDrag() {
    _sim?.pinned = null;
    _dragged = null;
    _dragCandidate = null;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _endDrag();
    _viewAtGestureStart = null;
    _gestureFocal = null;
  }

  void _tap(TapUpDetails d) {
    // A tap only fires when the gesture arena resolved it as such (a
    // node drag goes to the scale recognizer instead) — no extra
    // movement guard needed, and the node is exactly where it looks:
    // nothing reheated the sim during the touch.
    final hit = _nodeAt(d.localPosition);
    if (hit == null) return;
    _select(hit.id);
  }

  void _select(String id) {
    setState(() {
      if (_selected == id) {
        _selected = null;
        _neighbors = {};
      } else {
        _selected = id;
        _neighbors = _adj[id]?.toSet() ?? {};
      }
    });
    final n = _nodes.where((n) => n.id == id).firstOrNull;
    if (n != null) _centerOn(n);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId));
    final graph = agentId == null ? null : ref.watch(wikiGraphProvider(agentId));
    // Build directly (first frame / cached provider value) — the
    // signature guard makes repeated calls free.
    graph?.whenOrNull(data: _buildGraph);
    final palette = WikiGraphPalette.of(theme.brightness);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.wikiKnowledgeGraph),
        actions: [
          IconButton(
            tooltip: l.wikiFit,
            icon: const Icon(LucideIcons.maximize2, size: 20),
            onPressed: _fit,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: graph == null
          ? const SizedBox.shrink()
          : graph.when(
              loading: () => const Center(
                  child: SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => ErrorPane(message: l.wikiLoadFailed),
              data: (g) => g.nodes.isEmpty
                  ? EmptyState(icon: LucideIcons.network, message: l.wikiNoPages)
                  : _canvas(context, palette),
            ),
    );
  }

  Widget _canvas(BuildContext context, WikiGraphPalette palette) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      _viewport = constraints.biggest;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onTapUp: _tap,
              child: CustomPaint(
                painter: GraphPainter(
                  nodes: _nodes,
                  edgeIdx: _edges,
                  typeOf: _typeOf,
                  labelOf: _labelOf,
                  labelCache: _labelCache,
                  palette: palette,
                  view: _view,
                  viewVersion: _viewVersion,
                  selected: _selected,
                  neighbors: _neighbors,
                  labels: _labels,
                  labelStyle: TextStyle(fontSize: AppType.caption, color: palette.label),
                ),
              ),
            ),
          ),
          // Compact type legend — the colors mean nothing without it.
          Positioned(
            left: 12,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.9),
                borderRadius: AppRadius.controlBorder,
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (type, label) in [
                    ('entity', l.wikiEntity),
                    ('concept', l.wikiConcept),
                    ('source', l.wikiSource),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(color: palette.node(type), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(label, style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                color: scheme.surface,
                borderRadius: AppRadius.cardBorder,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _titleOf[_selected] ?? _selected!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: l.wikiOpen,
                        icon: const Icon(LucideIcons.arrowUpRight, size: 20),
                        onPressed: () =>
                            context.push('/wiki/page/${Uri.encodeComponent(_selected!)}'),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: () => _select(_selected!),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
