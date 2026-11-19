import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../../models/habit.dart';
import 'day_selector.dart';
import 'month_day_selector.dart';
import 'period_selector.dart';
import 'year_selector.dart';

class SpecificDaysContent extends StatelessWidget {
  final HabitPeriod period;
  final WeekStart weekStart;
  final Set<int> selectedDays;
  final ValueChanged<HabitPeriod> onPeriodSelected;
  final void Function(int day, bool selected) onDayChanged;
  final ValueChanged<int> onDateRemoved;
  final VoidCallback onAddDate;

  const SpecificDaysContent({
    super.key,
    required this.period,
    required this.weekStart,
    required this.selectedDays,
    required this.onPeriodSelected,
    required this.onDayChanged,
    required this.onDateRemoved,
    required this.onAddDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.habitFrequencySpecificDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        // Sub-selector
        _periodTabs(theme, l10n),
        const SizedBox(height: 16),
        if (period == HabitPeriod.week)
          DaySelector(
            weekStart: weekStart,
            selectedDays: selectedDays,
            onDayChanged: onDayChanged,
          )
        else if (period == HabitPeriod.month)
          MonthDaySelector(
            selectedDays: selectedDays,
            onDayChanged: onDayChanged,
          ) // New method
        else if (period == HabitPeriod.year)
          YearSelector(
            selectedDates: selectedDays,
            onRemove: onDateRemoved,
            onAdd: onAddDate,
          ), // New method
      ],
    );
  }

  Widget _periodTabs(ThemeData theme, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tab(l10n.habitFrequencyPeriodWeekLabel, HabitPeriod.week),
          _tab(l10n.habitFrequencyPeriodMonthLabel, HabitPeriod.month),
          _tab(l10n.habitFrequencyPeriodYearLabel, HabitPeriod.year),
        ],
      ),
    );
  }

  Widget _tab(String label, HabitPeriod value) {
    return PeriodTab(
      label: label,
      selected: period == value,
      onTap: () => onPeriodSelected(value),
    );
  }
}
