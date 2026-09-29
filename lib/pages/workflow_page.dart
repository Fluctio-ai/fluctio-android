import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import '../webview/web_container.dart';

/// Workflows: native list of the agent's workflows; the editor itself is
/// the web app inside the fallback WebView (ticket 10).
class WorkflowPage extends ConsumerWidget {
  const WorkflowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId ?? ''));
    return Scaffold(
      appBar: AppBar(title: Text(l.navWorkflow)),
      body: WebContainerPage(title: l.navWorkflow, path: WebRoutes.workflows(agentId)),
    );
  }
}
