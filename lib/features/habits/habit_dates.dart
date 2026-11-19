import 'package:numer_app/app/app_state.dart';

String dateKey(DateTime d) {
  return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}

int weekStartOffset(DateTime date, WeekStart weekStart) {
  if (weekStart == WeekStart.monday) {
    return (date.weekday - DateTime.monday).clamp(0, 6);
  }
  return date.weekday % 7;
}

bool isFutureDate(DateTime date) {
  final today = DateTime.now();
  final todayMidnight = DateTime(today.year, today.month, today.day);
  final dateMidnight = DateTime(date.year, date.month, date.day);
  return dateMidnight.isAfter(todayMidnight);
}
