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
/// the web's WebGL engine): [ForceSim] computes positions, [GraphPainter]
/// draws, InteractiveViewer owns pan/zoom/pinch. Touch parity with the
/// web's mobile overlay — taps select (tapping the selected node
/// clears), no node dragging; a selection fades non-neighbours and the
/// bottom bar jumps into the preview.
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

  final _tf = TransformationController();
  late final Ticker _ticker;
  Size _viewport = Size.zero;
  ForceSim? _sim;
  List<SimNode> _nodes = const [];
  List<(int, int)> _edges = const [];
  Map<String, String> _typeOf = const {};
  Map<String, String> _titleOf = const {};
  Map<String, List<String>> _adj = {};
  String? _selected;
  Set<String> _neighbors = {};
  bool _labels = false;
  String? _builtFor;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tf.dispose();
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

  void _fit() {
    if (_viewport == Size.zero) return;
    final s = math.min(_viewport.width / _world.width,
            _viewport.height / _world.height) *
        0.95;
    _tf.value = Matrix4.identity()
      ..translateByDouble((_viewport.width - _world.width * s) / 2,
          (_viewport.height - _world.height * s) / 2, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void _centerOn(SimNode n) {
    if (_viewport == Size.zero) return;
    final s = _tf.value.getMaxScaleOnAxis();
    _tf.value = Matrix4.identity()
      ..translateByDouble(_viewport.width / 2 - n.x * s, _viewport.height / 2 - n.y * s, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
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

  /// Tap coordinates arrive in the transformed (world) space — the
  /// GestureDetector sits inside the viewer's child.
  void _tap(TapUpDetails d) {
    final scale = _tf.value.getMaxScaleOnAxis();
    SimNode? best;
    var bestD2 = double.infinity;
    for (final n in _nodes) {
      final dx = n.x - d.localPosition.dx;
      final dy = n.y - d.localPosition.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = n;
      }
    }
    if (best == null) return;
    final threshold = best.r - 5 + 14 / scale;
    if (bestD2 <= threshold * threshold) _select(best.id);
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
          InteractiveViewer(
            transformationController: _tf,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(4000),
            minScale: 0.08,
            maxScale: 4,
            child: SizedBox(
              width: _world.width,
              height: _world.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _tap,
                child: CustomPaint(
                  painter: GraphPainter(
                    nodes: _nodes,
                    edgeIdx: _edges,
                    typeOf: _typeOf,
                    labelOf: {
                      for (final e in _titleOf.entries)
                        e.key:
                            e.value.length > 12 ? '${e.value.substring(0, 12)}…' : e.value,
                    },
                    palette: palette,
                    selected: _selected,
                    neighbors: _neighbors,
                    labels: _labels,
                    labelStyle: TextStyle(fontSize: 12, color: palette.label),
                    repaint: _tf,
                  ),
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
