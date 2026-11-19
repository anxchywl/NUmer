import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/habits/habit_dates.dart';

void main() {
  test('dateKey pads month and day and ignores the time', () {
    expect(dateKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    expect(dateKey(DateTime(2026, 11, 27)), '2026-11-27');
  });

  group('weekStartOffset', () {
    // 2026-11-23 is a monday
    final week = List.generate(7, (i) => DateTime(2026, 11, 23 + i));

    test('counts days since monday', () {
      final offsets = week.map((d) => weekStartOffset(d, WeekStart.monday));
      expect(offsets, [0, 1, 2, 3, 4, 5, 6]);
    });

    test('counts days since sunday', () {
      final offsets = week.map((d) => weekStartOffset(d, WeekStart.sunday));
      expect(offsets, [1, 2, 3, 4, 5, 6, 0]);
    });
  });

  group('isFutureDate', () {
    final now = DateTime.now();

    test('is false for any time today and for the past', () {
      expect(isFutureDate(DateTime(now.year, now.month, now.day)), isFalse);
      expect(
        isFutureDate(DateTime(now.year, now.month, now.day, 23, 59, 59)),
        isFalse,
      );
      expect(isFutureDate(DateTime(now.year, now.month, now.day - 1)), isFalse);
    });

    test('is true from the next midnight', () {
      expect(isFutureDate(DateTime(now.year, now.month, now.day + 1)), isTrue);
    });
  });
}
