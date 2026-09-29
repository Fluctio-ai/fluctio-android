import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Destructive-action confirmation — the shared copy/UX for deletes
/// across chat sessions, KB entries and notes.
Future<bool> confirmDelete(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l.chatDeleteConfirm),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatDelete)),
          ],
        ),
      ) ==
      true;
}
