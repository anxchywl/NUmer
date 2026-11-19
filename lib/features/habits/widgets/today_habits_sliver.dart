import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../models/habit.dart';
import 'habits_clearances.dart';
import 'today_habit_item.dart';

class TodayHabitsSliver extends StatelessWidget {
  const TodayHabitsSliver({
    super.key,
    required this.habits,
    required this.selectedDate,
    required this.onToggle,
  });

  final List<Habit> habits;
  final DateTime selectedDate;
  final void Function(Habit habit) onToggle;

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return _buildEmpty(context);

    return SliverPadding(
      padding: EdgeInsets.only(bottom: progressBottomClearance(context)),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final habit = habits[index];
          return TodayHabitItem(
            habit: habit,
            selectedDate: selectedDate,
            onToggle: () => onToggle(habit),
          );
        }, childCount: habits.length),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: progressBottomClearance(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.done_all, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                l10n.habitsEmptyToday,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
