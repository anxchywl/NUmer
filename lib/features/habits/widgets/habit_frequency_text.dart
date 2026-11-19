import 'package:intl/intl.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../models/habit.dart';

String habitFrequencyText(
  Habit habit,
  AppLocalizations l10n,
  String localeName,
) {
  final numberFormat = NumberFormat.decimalPattern(localeName);
  switch (habit.frequencyType) {
    case HabitFrequencyType.daily:
      return l10n.habitFrequencyEveryDay;
    case HabitFrequencyType.specificDays:
      if (habit.frequencyPeriod == HabitPeriod.month) {
        if (habit.weekDays.isEmpty) {
          return l10n.habitFrequencySpecificMonth;
        }
        final days = habit.weekDays.toList()..sort();
        final dayLabels = days.map((d) => numberFormat.format(d)).join(", ");
        return l10n.habitFrequencyDaysLabel(dayLabels);
      } else if (habit.frequencyPeriod == HabitPeriod.year) {
        return l10n.habitFrequencySpecificDates;
      }
      if (habit.weekDays.length == 7 || habit.weekDays.isEmpty) {
        return l10n.habitFrequencyEveryDay;
      }
      final days = habit.weekDays.toList()..sort();
      final labels = days
          .where((d) => d >= 1 && d <= 7)
          .map((d) => _weekdayLabel(d, localeName))
          .join(", ");
      return l10n.habitFrequencyDaysLabel(labels);
    case HabitFrequencyType.interval:
      final work = habit.intervalDays;
      final rest = habit.frequencyGoal ?? 0;
      return '$work x $rest';
    case HabitFrequencyType.repeatsInPeriod:
      final period = _periodLabel(
        habit.frequencyPeriod ?? HabitPeriod.week,
        l10n,
      ).toLowerCase();
      final count = habit.frequencyGoal ?? 1;
      return l10n.habitFrequencyTimesPerPeriod(count, period);
  }
}

String _periodLabel(HabitPeriod period, AppLocalizations l10n) {
  switch (period) {
    case HabitPeriod.week:
      return l10n.habitPeriodWeek;
    case HabitPeriod.month:
      return l10n.habitPeriodMonth;
    case HabitPeriod.year:
      return l10n.habitPeriodYear;
  }
}

String _weekdayLabel(int weekday, String localeName) {
  final baseMonday = DateTime(2024, 1, 1);
  final date = baseMonday.add(Duration(days: weekday - 1));
  return DateFormat.E(localeName).format(date);
}

String formatWeekRange(List<DateTime> dates) {
  if (dates.isEmpty) return "";
  final start = dates.first;
  final end = dates.last;

  // Format according to prompt: dd.mm.yy – dd.mm.yy
  const startFormat = "dd.MM.yy";
  const endFormat = "dd.MM.yy";

  return "${DateFormat(startFormat).format(start)} – ${DateFormat(endFormat).format(end)}";
}
