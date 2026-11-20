import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../stats_format.dart';

class HabitReportSelectionView extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final DateTime selectedMonth;
  final String selectedFormat;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<String> onFormatChanged;

  const HabitReportSelectionView({
    super.key,
    required this.l10n,
    required this.theme,
    required this.selectedMonth,
    required this.selectedFormat,
    required this.onMonthChanged,
    required this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month Selector
        Row(
          children: [
            _previousMonthButton(),
            Expanded(child: _monthLabel(context)),
            _nextMonthButton(),
          ],
        ),

        const SizedBox(height: 24),

        // Format Selector
        Text(
          l10n.exportFormat,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _formatChips(),
      ],
    );
  }

  Widget _previousMonthButton() {
    return IconButton(
      onPressed: () {
        final minDate = DateTime(2025, 1, 1);
        final prevMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);

        if (prevMonth.isBefore(minDate)) {
          return;
        }

        onMonthChanged(prevMonth);
      },
      icon: Icon(
        Icons.chevron_left,
        color: () {
          final minDate = DateTime(2025, 1, 1);
          final prevMonth = DateTime(
            selectedMonth.year,
            selectedMonth.month - 1,
          );

          if (prevMonth.isBefore(minDate)) {
            return theme.disabledColor;
          }
          return null;
        }(),
      ),
    );
  }

  Widget _monthLabel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          "${monthName(context, selectedMonth.month)} ${selectedMonth.year}",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _nextMonthButton() {
    return IconButton(
      onPressed: () {
        final now = DateTime.now();
        final currentMonth = DateTime(now.year, now.month);
        final nextMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);

        if (nextMonth.isAfter(currentMonth)) {
          return;
        }

        onMonthChanged(nextMonth);
      },
      icon: Icon(
        Icons.chevron_right,
        color: () {
          final now = DateTime.now();
          final currentMonth = DateTime(now.year, now.month);
          final nextMonth = DateTime(
            selectedMonth.year,
            selectedMonth.month + 1,
          );

          if (nextMonth.isAfter(currentMonth)) {
            return theme.disabledColor;
          }
          return null;
        }(),
      ),
    );
  }

  Widget _formatChips() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: Text(l10n.exportFormatCSV),
            selected: selectedFormat == 'csv',
            onSelected: (selected) {
              if (selected) {
                onFormatChanged('csv');
              }
            },
            selectedColor: theme.colorScheme.secondaryContainer,
            labelStyle: TextStyle(
              color: selectedFormat == 'csv'
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ChoiceChip(
            label: Text(l10n.exportFormatExcel),
            selected: selectedFormat == 'excel',
            onSelected: (selected) {
              if (selected) {
                onFormatChanged('excel');
              }
            },
            selectedColor: theme.colorScheme.secondaryContainer,
            labelStyle: TextStyle(
              color: selectedFormat == 'excel'
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
