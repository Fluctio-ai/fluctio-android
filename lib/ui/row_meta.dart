import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../util/dates.dart';

/// Right-aligned list-row timestamp — ONE family for every list surface
/// (user sync call 2026-11-21: rows had two positions × two styles ×
/// three granularities). Same styling as the chat bubble stamp
/// (message_list): caption 12 + mono + outline — metadata stays quiet,
/// the subtitle keeps the content preview, and the time can never be
/// ellipsized away by a long preview.
///
/// The text is WeChat-style relative (formatListTime): time of day for
/// today, words for yesterday/day-before, plain date otherwise.
class RowMetaTime extends StatelessWidget {
  /// Milliseconds-since-epoch → formatListTime.
  const RowMetaTime({super.key, required this.tsMs})
      : dayStr = null;

  /// ISO string convenience (KB models carry updatedAt as ISO text);
  /// an unparseable/empty string renders nothing (tsMs <= 0).
  RowMetaTime.iso(String iso, {Key? key})
      : this(tsMs: DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? -1, key: key);

  /// Day-granular entities (diary): aggregated per calendar day, no
  /// time-of-day — the date portion of the same WeChat-style rule.
  const RowMetaTime.day(String this.dayStr, {super.key}) : tsMs = 0;

  final int tsMs;
  final String? dayStr;

  @override
  Widget build(BuildContext context) {
    if (tsMs <= 0 && dayStr == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toString();
    final l = AppLocalizations.of(context)!;
    final text = dayStr != null
        ? formatListTime(DateTime.parse(dayStr!).millisecondsSinceEpoch,
            locale: locale, yesterday: l.timeYesterday)
        : formatListTime(tsMs, locale: locale, yesterday: l.timeYesterday);
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
          fontSize: AppType.caption, fontFamily: codeMonoFamily, color: Theme.of(context).colorScheme.outline),
    );
  }
}
