import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';

int dailyGoalSeconds(AppState state) {
  if (state.progressView == ProgressView.off) return 0;
  return state.courses.fold(0, (total, course) {
    final weeklyHours = _weeklyGoalHours(state, course);
    return total + (weeklyHours * 3600 / 7).round();
  });
}

double _weeklyGoalHours(AppState state, Course course) {
  final custom = state.goalHoursForCourse(course.id) ?? 0;
  if (custom > 0) return custom;
  final credits = course.credits ?? 0;
  if (credits <= 0) return 0;
  return credits * hoursPerCreditForLevel(course.expLevel ?? 3);
}
