import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../chat/chat_routes.dart';
import '../l10n/app_localizations.dart';
import 'diary_models.dart';
import 'diary_repo.dart';

/// Shared shelved-ledger entry actions (ticket #16): tapping an open row
/// IS the confirm — viewing counts, no real conversation required — and
/// long-press offers "stop reminding". Both are manual settlements
/// (resolution="manual"); the server-side retire sweep handles silence.

/// Tap-through confirm: fire-and-forget PATCH resolved, refresh the
/// ledger, toast — navigation (if any) proceeds immediately, never
/// waiting on the request. Rows without an id (legacy snapshots) are
/// inert; the caller gates on [DiaryShelved.settleable].
void confirmShelved(
    BuildContext context, WidgetRef ref, String agentId, DiaryShelved item) {
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  ref.read(diaryRepoProvider).settle(agentId, item.id, resolved: true).then((_) {
    messenger.showSnackBar(SnackBar(content: Text(l.shelvedConfirmed)));
  }).catchError((_) {});
  ref.invalidate(diaryShelvedProvider(agentId));
}

/// Long-press "stop reminding": confirm dialog, then PATCH dropped and
/// refresh the ledger. Dropped rows leave immediately and stay retired
/// (silence past the window does the same automatically).
Future<void> stopRemindingShelved(
    BuildContext context, WidgetRef ref, String agentId, DiaryShelved item) async {
  final l = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.shelvedStopRemind),
      content: Text(l.shelvedStopRemindBody(item.topic)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.shelvedStopRemind)),
      ],
    ),
  );
  if (ok != true) return;
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(diaryRepoProvider).settle(agentId, item.id, resolved: false);
    messenger.showSnackBar(SnackBar(content: Text(l.shelvedStopRemind)));
  } catch (_) {}
  ref.invalidate(diaryShelvedProvider(agentId));
}

/// The tap semantics shared by the dashboard row and the diary card:
/// settle (when settleable) and deep-link into the deferred conversation.
void openShelvedEntry(
    BuildContext context, WidgetRef ref, String agentId, DiaryShelved item) {
  if (item.settleable) confirmShelved(context, ref, agentId, item);
  if (item.session.isNotEmpty) {
    context.push(chatSessionRoute(item.session, seq: item.seq));
  }
}
