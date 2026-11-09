import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';

class DaySelector extends StatelessWidget {
  final WeekStart weekStart;
  final Set<int> selectedDays;
  final void Function(int day, bool selected) onDayChanged;

  const DaySelector({
    super.key,
    required this.weekStart,
    required this.selectedDays,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrowWeekdays = MaterialLocalizations.of(context).narrowWeekdays;
    final days = weekStart == WeekStart.monday
        ? [...narrowWeekdays.skip(1), narrowWeekdays.first]
        : narrowWeekdays;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayNum = weekStart == WeekStart.monday
            ? (index + 1)
            : (index == 0 ? 7 : index);
        return _day(theme, dayNum, days[index]);
      }),
    );
  }

  Widget _day(ThemeData theme, int dayNum, String label) {
    final active = selectedDays.contains(dayNum);
    return GestureDetector(
      onTap: () => onDayChanged(dayNum, !active),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: active
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        foregroundColor: active
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
