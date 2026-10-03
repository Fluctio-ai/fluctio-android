import 'package:intl/intl.dart';

/// Shared short date/time rendering (one formatting policy instead of a
/// per-page copy). DateFormat construction is comparatively expensive, so
/// instances are cached per locale.
final _hmCache = <String, DateFormat>{};
final _mdCache = <String, DateFormat>{};
final _ymdCache = <String, DateFormat>{};
final _namedCache = <String, Map<String, DateFormat>>{};

DateFormat _hm(String locale) => _hmCache.putIfAbsent(locale, () => DateFormat.Hm(locale));
DateFormat _md(String locale) => _mdCache.putIfAbsent(locale, () => DateFormat.Md(locale));
DateFormat _ymd(String locale) => _ymdCache.putIfAbsent(locale, () => DateFormat.yMd(locale));

DateFormat _named(String locale, String pattern) =>
    (_namedCache[locale] ??= {}).putIfAbsent(pattern, () => DateFormat(pattern, locale));

/// Session-list convention: today → HH:mm; this year → M/d HH:mm;
/// older → yyyy/M/d.
String formatSessionTime(int tsMs, {String locale = 'en_US'}) {
  final local = DateTime.fromMillisecondsSinceEpoch(tsMs).toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (!local.isBefore(today)) return _hm(locale).format(local);
  if (local.year == now.year) {
    return '${_md(locale).format(local)} ${_hm(locale).format(local)}';
  }
  return _ymd(locale).format(local);
}

/// Compact M/d (yyyy/ prefixed for other years), optional HH:mm suffix.
String formatShortDate(DateTime d, {String locale = 'en_US', bool withTime = false}) {
  final local = d.toLocal();
  final now = DateTime.now();
  final date = local.year == now.year
      ? _md(locale).format(local)
      : '${local.year}/${_md(locale).format(local)}';
  return withTime ? '$date ${_hm(locale).format(local)}' : date;
}

/// Chat transcript time-of-day label (HH:mm).
String formatTimeOfDay(DateTime d, {String locale = 'en_US'}) =>
    _hm(locale).format(d.toLocal());

/// Day divider label (MMMEd, e.g. 9月29日周一).
String formatDayLabel(DateTime d, {String locale = 'en_US'}) =>
    _named(locale, 'MMMEd').format(d);

/// Calendar month title (yMMMM, e.g. 2026年10月).
String formatMonthTitle(DateTime d, {String locale = 'en_US'}) =>
    _named(locale, 'yMMMM').format(d);

/// Full calendar date label (yMMMMEEEEd, e.g. 2026年10月2日星期五).
String formatFullDate(DateTime d, {String locale = 'en_US'}) =>
    _named(locale, 'yMMMMEEEEd').format(d);

/// Monday-first short weekday labels (一 二 三…/Mon Tue Wed…) —
/// 2024-01-01 is a Monday, so the week is enumerated from it (the web
/// calendar header does the same trick).
List<String> weekdayShortLabels(String locale) => List.generate(
    7, (i) => _named(locale, 'E').format(DateTime(2024, 1, 1 + i)));
