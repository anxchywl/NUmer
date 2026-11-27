import 'package:numer_app/app/app_state.dart';

import '../habit_dates.dart';
import '../widgets/habits_due_on.dart';
import 'habit.dart';

({int done, int total}) summarizeHabitsForDay(
  List<Habit> habits,
  DateTime day, {
  required bool mondayFirst,
}) {
  final due = habitsDueOn(
    habits,
    day,
    mondayFirst ? WeekStart.monday : WeekStart.sunday,
  );
  final key = dateKey(day);
  final done = due.where((h) => (h.last7[key] ?? 0) >= h.targetValue).length;
  return (done: done, total: due.length);
}
