import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/habits/habits.dart';

import '../models/stats_models.dart';

Future<HabitStatsResult> computeHabitStats(Habit habit) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Start from habit start date
  final start = DateTime(
    habit.startDate.year,
    habit.startDate.month,
    habit.startDate.day,
  );

  // If future start date, no stats
  if (start.isAfter(today)) {
    return const HabitStatsResult(0, 0, 0, 0.0);
  }

  // End date: habit.endDate or Today
  DateTime end = today;
  if (habit.endDate != null) {
    final e = DateTime(
      habit.endDate!.year,
      habit.endDate!.month,
      habit.endDate!.day,
    );
    if (e.isBefore(today)) end = e;
  }

  // LOCAL-FIRST: Use local cache for history
  final historyMap = _cachedHistory(habit.id);

  final (
    required,
    completed,
  ) = habit.frequencyType == HabitFrequencyType.repeatsInPeriod
      ? _countByPeriod(habit, historyMap, start, end)
      : _countByDay(habit, historyMap, start, end);

  final notCompleted = required - completed;
  final rate = required > 0 ? (completed / required * 100) : 0.0;

  return HabitStatsResult(required, completed, notCompleted, rate);
}

Map<String, double> _cachedHistory(String habitId) {
  final localHistory = Storage.getHabitHistoryFromCache(habitId);
  final historyMap = <String, double>{};
  for (final h in localHistory) {
    if (h.deleted) continue;
    historyMap[h.dateKey] = h.value ?? 0.0;
  }
  return historyMap;
}

// Period-based logic (Matches HabitService.recalculateStreak)
(int, int) _countByPeriod(
  Habit habit,
  Map<String, double> historyMap,
  DateTime start,
  DateTime end,
) {
  int required = 0;
  int completed = 0;

  DateTime pStart = _periodStart(habit.frequencyPeriod!, start);

  while (!pStart.isAfter(end)) {
    final pNext = _nextPeriodStart(habit.frequencyPeriod!, pStart);
    final pEnd = pNext.subtract(const Duration(days: 1));

    final iStart = pStart.isBefore(start) ? start : pStart;
    final iEnd = pEnd.isAfter(end) ? end : pEnd;

    if (!iStart.isAfter(iEnd)) {
      required += (habit.frequencyGoal ?? 1);

      final periodCompletions = _completedDays(habit, historyMap, iStart, iEnd);

      final goal = habit.frequencyGoal ?? 1;
      final capped = periodCompletions > goal ? goal : periodCompletions;
      completed += capped;
    }
    pStart = pNext;
  }
  return (required, completed);
}

DateTime _periodStart(HabitPeriod period, DateTime d) {
  switch (period) {
    case HabitPeriod.week:
      // Align with Monday
      return d.subtract(Duration(days: d.weekday - 1));
    case HabitPeriod.month:
      return DateTime(d.year, d.month, 1);
    case HabitPeriod.year:
      return DateTime(d.year, 1, 1);
  }
}

DateTime _nextPeriodStart(HabitPeriod period, DateTime pStart) {
  switch (period) {
    case HabitPeriod.week:
      return pStart.add(const Duration(days: 7));
    case HabitPeriod.month:
      return DateTime(pStart.year, pStart.month + 1, 1);
    case HabitPeriod.year:
      return DateTime(pStart.year + 1, 1, 1);
  }
}

int _completedDays(
  Habit habit,
  Map<String, double> historyMap,
  DateTime iStart,
  DateTime iEnd,
) {
  int periodCompletions = 0;
  DateTime d = iStart;
  while (!d.isAfter(iEnd)) {
    final k =
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    if ((historyMap[k] ?? 0) >= habit.targetValue) {
      periodCompletions++;
    }
    d = d.add(const Duration(days: 1));
  }
  return periodCompletions;
}

// Day-based logic
(int, int) _countByDay(
  Habit habit,
  Map<String, double> historyMap,
  DateTime start,
  DateTime end,
) {
  int required = 0;
  int completed = 0;

  int totalDays = end.difference(start).inDays + 1;
  for (var i = 0; i < totalDays; i++) {
    final d = start.add(Duration(days: i));
    if (habit.isScheduledFor(d)) {
      required++;
      final k =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      if ((historyMap[k] ?? 0) >= habit.targetValue) {
        completed++;
      }
    }
  }
  return (required, completed);
}
