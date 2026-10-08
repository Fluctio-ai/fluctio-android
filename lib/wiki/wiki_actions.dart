import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../chat/chat_controller.dart';
import '../l10n/app_localizations.dart';
import 'wiki_models.dart';
import 'wiki_repo.dart';

/// Delete a wiki page behind the shared confirm dialog (the web's
/// deletePageConfirm copy) — one flow for the list rows and the detail
/// view. Errors surface via [showApiError]. Returns true when the page
/// was actually deleted.
Future<bool> deleteWikiPageWithConfirm(
    BuildContext context, WidgetRef ref, WikiPageInfo page) async {
  final l = AppLocalizations.of(context)!;
  final agentId = ref.read(agentsProvider).selectedId;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.wikiDeleteTitle),
      content: Text(l.wikiDeleteConfirm(page.title)),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l.cancel)),
        FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l.chatDelete)),
      ],
    ),
  );
  if (ok != true || agentId == null) return false;
  try {
    await ref.read(wikiRepoProvider).delete(agentId, page.id);
    ref.invalidate(wikiInventoryProvider(agentId));
    return true;
  } catch (e) {
    if (context.mounted) showApiError(context, e);
    return false;
  }
}
