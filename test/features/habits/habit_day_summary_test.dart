import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/features/habits/habits.dart';

// a wednesday
final _day = DateTime(2026, 3, 4);

Habit _habit({
  HabitFrequencyType frequency = HabitFrequencyType.daily,
  Set<int> weekDays = const {},
  HabitPeriod? period,
  int? goal,
  double target = 1,
  Map<String, double> last7 = const {},
}) => Habit(
  id: 'h',
  name: 'h',
  color: Colors.indigo,
  iconCodePoint: 0,
  category: 'Health',
  type: HabitType.numeric,
  targetValue: target,
  comparator: HabitComparator.atLeast,
  frequencyType: frequency,
  weekDays: weekDays,
  frequencyPeriod: period,
  frequencyGoal: goal,
  startDate: DateTime(2026),
  createdAt: DateTime(2026),
  last7: last7,
);

({int done, int total}) _summary(Habit habit, {bool mondayFirst = true}) =>
    summarizeHabitsForDay([habit], _day, mondayFirst: mondayFirst);

void main() {
  test('a daily habit counts every day', () {
    expect(_summary(_habit()), (done: 0, total: 1));
  });

  test('specific days count only on those days', () {
    Habit on(int weekday) =>
        _habit(frequency: HabitFrequencyType.specificDays, weekDays: {weekday});

    expect(_summary(on(DateTime.wednesday)).total, 1);
    expect(_summary(on(DateTime.thursday)).total, 0);
  });

  test('a met period goal is hidden unless done today', () {
    Habit weekly(Map<String, double> last7) => _habit(
      frequency: HabitFrequencyType.repeatsInPeriod,
      period: HabitPeriod.week,
      goal: 1,
      last7: last7,
    );

    expect(_summary(weekly({'2026-03-02': 1})), (done: 0, total: 0));
    expect(_summary(weekly({'2026-03-04': 1})), (done: 1, total: 1));
  });

  test('the week start decides whether sunday still counts', () {
    final sunday = _habit(
      frequency: HabitFrequencyType.repeatsInPeriod,
      period: HabitPeriod.week,
      goal: 1,
      last7: {'2026-03-01': 1},
    );

    expect(_summary(sunday).total, 1);
    expect(_summary(sunday, mondayFirst: false).total, 0);
  });

  test('done is counted at the target value', () {
    Habit logged(double value) =>
        _habit(target: 5, last7: {'2026-03-04': value});

    expect(_summary(logged(4)).done, 0);
    expect(_summary(logged(5)).done, 1);
  });
}
