import 'package:fluctio_android/util/dates.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// WeChat-style list timestamp branches (user feedback 2026-11-21):
/// today → HH:mm; yesterday/day-before → words; same Monday-start week
/// → weekday; older this year → M/d; across years → yyyy/M/d.
void main() {
  // Fixed now: Saturday 2026-11-21 15:00 local. The week it sits in
  // runs Mon 11-16 .. Sun 11-22.
  final now = DateTime(2026, 11, 21, 15, 0);
  String fmt(DateTime d, {String locale = 'en_US'}) => formatListTime(
      d.millisecondsSinceEpoch,
      locale: locale,
      yesterday: 'Yesterday',
      now: now);

  test('today shows the time of day', () {
    expect(fmt(DateTime(2026, 11, 21, 9, 5)), '09:05');
    expect(fmt(DateTime(2026, 11, 21, 0, 1)), '00:01');
  });

  test('yesterday reads as a word', () {
    expect(fmt(DateTime(2026, 11, 20, 23, 59)), 'Yesterday');
  });

  test('the day before yesterday is not special-cased (the English word hogged the title) - it uses the weekday/date branches', () {
    // 2026-11-19 is Thursday; same Monday-start week as Sat 11-21.
    expect(fmt(DateTime(2026, 11, 19)), 'Thu');
  });

  test('same Monday-start week reads as the weekday', () {
    expect(fmt(DateTime(2026, 11, 18)), 'Wed');
    expect(fmt(DateTime(2026, 11, 16)), 'Mon'); // week start
    // Sunday is untestable here: in a Monday-start week it is either
    // today, yesterday, or in the future — never a past weekday row.
  });

  test('older dates this year show M/d, last week included', () {
    expect(fmt(DateTime(2026, 11, 15)), '11/15'); // Sunday, previous week
    expect(fmt(DateTime(2026, 10, 9)), '10/9');
  });

  test('across years shows yyyy/M/d', () {
    expect(fmt(DateTime(2025, 12, 31)), '2025/12/31');
  });

  test('zh locale weekday labels carry the 周 prefix', () async {
    await initializeDateFormatting('zh');
    expect(fmt(DateTime(2026, 11, 18), locale: 'zh'), '周三');
  });
}
