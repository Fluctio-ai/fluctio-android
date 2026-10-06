import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/chat_controller.dart';
import 'package:fluctio_android/l10n/app_localizations.dart';
import 'package:fluctio_android/pages/wiki/graph_painter.dart';
import 'package:fluctio_android/pages/wiki/wiki_graph_page.dart';
import 'package:fluctio_android/wiki/wiki_models.dart';

/// Agents pre-resolved with a selection so the graph page skips the
/// null-agent guard (same trick as widget_test's _LoadedAgents).
class _WikiAgents extends AgentsController {
  @override
  AgentsState build() => const AgentsState(loaded: true, selectedId: 'agt_test');
}

WikiGraphInfo _fixture() {
  const types = [
    'overview',
    'entity', 'entity', 'entity', 'entity',
    'concept', 'concept', 'concept', 'concept',
    'source', 'source', 'source',
  ];
  return WikiGraphInfo.fromJson({
    'nodes': [
      for (var i = 0; i < types.length; i++)
        {'id': 'node$i', 'page_type': types[i], 'slug': 'slug$i', 'title': '节点$i node$i'},
    ],
    'edges': [
      for (var i = 0; i + 1 < types.length; i++)
        {'src_page_id': 'node$i', 'dst_page_id': 'node${i + 1}'},
      {'src_page_id': 'node0', 'dst_page_id': 'node6'},
      {'src_page_id': 'node2', 'dst_page_id': 'node11'},
    ],
  });
}

void main() {
  testWidgets('graph page renders fixture, sim settles, pump settles',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentsProvider.overrideWith(_WikiAgents.new),
          wikiGraphProvider.overrideWith((ref, agentId) async => _fixture()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const WikiGraphPage(),
        ),
      ),
    );

    await tester.pump(); // provider future resolves
    await tester.pump(); // first graph build starts the ticker

    // The ticker must cool and stop — pumpAndSettle only returns once
    // nothing keeps scheduling frames.
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is GraphPainter),
      findsOneWidget,
    );
    // Legend rendered (en locale).
    expect(find.text('Entities'), findsOneWidget);
    // No selection yet — the bottom open bar is absent.
    expect(find.text('Open'), findsNothing);
  });
}
