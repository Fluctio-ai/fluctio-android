import 'package:fluctio_android/util/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Local timestamps so the year comparison in formatSessionTime matches
  // regardless of the machine's timezone.
  int ts(int year, int month, int day, int hour, int minute) =>
      DateTime(year, month, day, hour, minute).millisecondsSinceEpoch;

  test('this year renders MM-dd HH:mm, other years add yyyy-', () {
    final now = DateTime.now();
    final thisYear =
        formatSessionTime(ts(now.year, 3, 7, 9, 5), locale: 'en_US');
    expect(thisYear, '03-07 09:05');

    final lastYear =
        formatSessionTime(ts(now.year - 1, 12, 30, 23, 59), locale: 'en_US');
    expect(lastYear, '${now.year - 1}-12-30 23:59');
  });
}
