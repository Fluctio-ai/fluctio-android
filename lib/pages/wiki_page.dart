import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import '../webview/web_container.dart';

/// Wiki tab: opens the web wiki (pages + graph) inside the fallback
/// WebView container — the graph is WebView territory by design
/// (ticket 10).
class WikiPage extends ConsumerWidget {
  const WikiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId ?? ''));
    return WebContainerPage(title: l.navWiki, path: WebRoutes.wiki(agentId), showDrawer: true);
  }
}
