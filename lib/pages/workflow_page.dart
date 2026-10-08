import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_client.dart';
import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import '../webview/web_container.dart';

/// Workflows: native list of the agent's workflows; the editor itself is
/// the web app inside the fallback WebView (ticket 10).
class WorkflowPage extends ConsumerStatefulWidget {
  const WorkflowPage({super.key});

  @override
  ConsumerState<WorkflowPage> createState() => _WorkflowPageState();
}

class _WorkflowPageState extends ConsumerState<WorkflowPage> {
  /// Bumped after a create — a fresh key rebuilds the WebView so the new
  /// workflow shows up. Web parity: the web list pane ends in an "+ add
  /// workflow" row (a JS prompt there); the WebView can't host prompts,
  /// so the affordance lives on the app bar here.
  int _reload = 0;

  Future<void> _create() async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.workflowNew),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l.workflowNewHint),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(l.workflowNew)),
        ],
      ),
    );
    controller.dispose();
    if (id == null || id.isEmpty) return;
    final agentId = ref.read(agentsProvider).selectedId;
    if (agentId == null) return;
    try {
      // Minimal legal seed: the backend's Validate() requires exactly
      // one entry node, so the web onCreateWorkflow's empty-nodes
      // skeleton is rejected these days — a single reply node passes
      // (validate.go exactlyOneEntry / handlers_workflow.go PUT).
      const seed = "version: 1\nnodes:\n  - name: reply\n    kind: reply\n    prompt: 'ok'\n";
      await ref.read(apiClientProvider).put(
            '/api/agents/$agentId/workflows/${Uri.encodeComponent(id)}',
            data: {'yaml': seed},
          );
      if (mounted) setState(() => _reload++);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final agentId = ref.watch(agentsProvider.select((a) => a.selectedId ?? ''));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navWorkflow),
        actions: [
          IconButton(
            tooltip: l.workflowNew,
            icon: const Icon(LucideIcons.plus),
            onPressed: _create,
          ),
        ],
      ),
      body: WebContainerPage(
        key: ValueKey(_reload),
        title: l.navWorkflow,
        path: WebRoutes.workflows(agentId),
        // The workflows page ships its own title + back header.
        showTitle: false,
      ),
    );
  }
}
