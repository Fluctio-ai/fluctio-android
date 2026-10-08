import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';

/// Jump to a card's origin content: diary cards deep-link the diary day
/// (`/kb/diary?date=`, web parity), wiki cards the page detail
/// (`/wiki/page/<type:slug>`). Non-navigable sources (manual, missing
/// ref) render nothing.
class CardSourceLink extends StatelessWidget {
  const CardSourceLink({super.key, required this.sourceType, required this.sourceRef});

  final String sourceType;
  final String sourceRef;

  @override
  Widget build(BuildContext context) {
    if (sourceRef.isEmpty || (sourceType != 'diary' && sourceType != 'wiki')) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final diary = sourceType == 'diary';
    return SizedBox(
      // 44px touch row even though the label is one line.
      height: 44,
      child: InkWell(
        onTap: () => context.push(diary
            ? '/kb/diary?date=${Uri.encodeComponent(sourceRef)}'
            : '/wiki/page/${Uri.encodeComponent(sourceRef)}'),
        borderRadius: AppRadius.controlBorder,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(diary ? LucideIcons.calendarDays : LucideIcons.fileText,
                size: 14, color: scheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                diary ? l.cardFromDiary(sourceRef) : l.cardViewWiki,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
              ),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.externalLink, size: 12, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
