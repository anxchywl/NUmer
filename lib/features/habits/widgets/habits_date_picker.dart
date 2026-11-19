import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class HabitsDatePicker extends StatelessWidget {
  const HabitsDatePicker({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.scrollController,
    required this.onSelect,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ScrollController scrollController;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 24) / 7; // Show 7 items

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) =>
            _buildDay(context, dates[index], itemWidth),
      ),
    );
  }

  Widget _buildDay(BuildContext context, DateTime date, double itemWidth) {
    final theme = Theme.of(context);
    final localeName = AppLocalizations.of(context)!.localeName;
    final now = DateTime.now();
    final isSelected =
        date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day;
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return GestureDetector(
      onTap: () => onSelect(date),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: itemWidth - 8, // Subtract margin
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isToday
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          border: isToday && !isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 1)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat.E(localeName).format(date),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
