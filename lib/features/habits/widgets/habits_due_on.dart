import 'package:numer_app/app/app_state.dart';

import '../habit_dates.dart';
import '../models/habit.dart';

List<Habit> habitsDueOn(
  List<Habit> habits,
  DateTime date,
  WeekStart weekStart,
) {
  return habits.where((h) {
    if (!h.isScheduledFor(date)) return false;

    // Check completion status for the selected date
    final key = dateKey(date);
    final currentValue = h.last7[key] ?? 0.0;
    final isCompletedOnDate = currentValue >= h.targetValue;

    // RULE: Show if completed on this date OR period goal NOT met.
    // This allows users to see/edit their progress today even if the goal was just met,
    // and ensures the habit reappears if progress drops below the threshold.
    if (isCompletedOnDate) return true;
    return !h.isGoalMetForPeriod(
      h.last7,
      date,
      mondayFirst: weekStart == WeekStart.monday,
    );
  }).toList();
}
