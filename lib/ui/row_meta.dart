import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../util/dates.dart';

/// Right-aligned list-row timestamp — ONE family for every list surface
/// (user sync call 2026-11-21: rows had two positions × two styles ×
/// three granularities). Same styling as the chat bubble stamp
/// (message_list): caption 12 + mono + outline — metadata stays quiet,
/// the subtitle keeps the content preview, and the time can never be
/// ellipsized away by a long preview.
class RowMetaTime extends StatelessWidget {
  /// Milliseconds-since-epoch → formatSessionTime (MM-dd HH:mm; yyyy-
  /// prefixed for other years) — the one granularity everywhere.
  const RowMetaTime({super.key, required this.tsMs})
      : dayStr = null;

  /// ISO string convenience (KB models carry updatedAt as ISO text);
  /// an unparseable/empty string renders nothing (tsMs <= 0).
  RowMetaTime.iso(String iso, {Key? key})
      : this(tsMs: DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? -1, key: key);

  /// Day-granular entities (diary): aggregated per calendar day, no
  /// time-of-day to show — formatShortDate instead.
  const RowMetaTime.day(String this.dayStr, {super.key}) : tsMs = 0;

  final int tsMs;
  final String? dayStr;

  @override
  Widget build(BuildContext context) {
    if (tsMs <= 0 && dayStr == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toString();
    final text = dayStr != null
        ? formatShortDate(DateTime.parse(dayStr!), locale: locale)
        : formatSessionTime(tsMs, locale: locale);
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
          fontSize: AppType.caption, fontFamily: codeMonoFamily, color: Theme.of(context).colorScheme.outline),
    );
  }
}
