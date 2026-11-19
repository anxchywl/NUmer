import 'package:flutter/material.dart';

class MonthDaySelector extends StatelessWidget {
  final Set<int> selectedDays;
  final void Function(int day, bool selected) onDayChanged;

  const MonthDaySelector({
    super.key,
    required this.selectedDays,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Display 1-31 in rows of 6, centered
    final rows = <Widget>[];
    for (int rowStart = 1; rowStart <= 31; rowStart += 6) {
      final rowEnd = (rowStart + 5 > 31) ? 31 : rowStart + 5;
      final rowDays = <Widget>[];
      for (int day = rowStart; day <= rowEnd; day++) {
        rowDays.add(_day(theme, day));
        if (day < rowEnd) rowDays.add(const SizedBox(width: 8));
      }
      rows.add(
        Row(mainAxisAlignment: MainAxisAlignment.center, children: rowDays),
      );
      if (rowEnd < 31) rows.add(const SizedBox(height: 8));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: rows,
    );
  }

  Widget _day(ThemeData theme, int day) {
    final selected = selectedDays.contains(day);
    return GestureDetector(
      onTap: () => onDayChanged(day, !selected),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Text(
          "$day",
          style: TextStyle(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
