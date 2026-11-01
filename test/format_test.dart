import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/data/format.dart';

void main() {
  test('formatPlayCount', () {
    expect(formatPlayCount(9876), '9876');
    expect(formatPlayCount(18000), '1.8万');
    expect(formatPlayCount(600123), '60.0万');
    expect(formatPlayCount(230000000), '2.3亿');
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 56)), '03:56');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatDuration(const Duration(seconds: -5)), '00:00');
  });

  test('greetingFor', () {
    expect(greetingFor(DateTime(2026, 1, 1, 9)), '上午好');
    expect(greetingFor(DateTime(2026, 1, 1, 21)), '晚上好');
  });
}
