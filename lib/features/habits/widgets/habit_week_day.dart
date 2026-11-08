import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../habit_dates.dart';
import '../models/habit.dart';

class HabitWeekDay extends StatelessWidget {
  final Habit habit;
  final DateTime date;
  final bool isSaving;
  final VoidCallback onTap;

  const HabitWeekDay({
    super.key,
    required this.habit,
    required this.date,
    required this.isSaving,
    required this.onTap,
  });

  bool _isBeforeStartDate(DateTime date) {
    final dateMidnight = DateTime(date.year, date.month, date.day);
    final startMidnight = DateTime(
      habit.startDate.year,
      habit.startDate.month,
      habit.startDate.day,
    );
    return dateMidnight.isBefore(startMidnight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeName = AppLocalizations.of(context)!.localeName;
    final key = dateKey(date);
    final currentVal = habit.last7[key] ?? 0.0;
    final isCompleted = currentVal >= habit.targetValue;
    final isPartialProgress =
        habit.type != HabitType.yesNo &&
        currentVal > 0 &&
        currentVal < habit.targetValue;

    final isToday =
        date.day == DateTime.now().day &&
        date.month == DateTime.now().month &&
        date.year == DateTime.now().year;

    // Determine styling state
    final isPreStart = _isBeforeStartDate(date);
    final isFuture = isFutureDate(date);
    final isScheduled = habit.isScheduledFor(date);
    final isGoalMet = habit.isGoalMetForPeriod(
      habit.last7,
      date,
      mondayFirst: context.read<AppState>().weekStart == WeekStart.monday,
    );
    final isLocked = !isCompleted && isGoalMet;

    // Active: Today or past scheduled days
    final isActive = !isPreStart && !isFuture && isScheduled;

    // Interaction only allowed on active days and NOT locked and NOT saving
    final canInteract = isActive && !isLocked && !isSaving;

    // Styling Logic
    Color textColor;
    if (isPreStart || !isScheduled || isLocked) {
      // A, C & Locked: Not required, pre-start or locked -> Muted
      textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
    } else if (isFuture) {
      // B: Future Required -> Regular normal color (same as active)
      textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    } else {
      // Active
      textColor = isToday
          ? habit.color
          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    }

    return GestureDetector(
      onTap: canInteract ? onTap : null,
      child: Column(
        children: [
          Text(
            DateFormat.E(localeName).format(date),
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: (isToday && isScheduled)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 6),
          _buildCircle(
            theme,
            isHidden: isPreStart || !isScheduled,
            isDisabled: isFuture || isLocked,
            isCompleted: isCompleted,
            isPartialProgress: isPartialProgress,
            isToday: isToday,
            isScheduled: isScheduled,
          ),
        ],
      ),
    );
  }

  Widget _buildCircle(
    ThemeData theme, {
    required bool isHidden,
    required bool isDisabled,
    required bool isCompleted,
    required bool isPartialProgress,
    required bool isToday,
    required bool isScheduled,
  }) {
    // Determine Circle Decoration and Child
    BoxDecoration circleDeco;
    Widget? circleChild;

    if (isHidden) {
      // Hidden (transparent)
      circleDeco = const BoxDecoration(color: Colors.transparent);
    } else if (isDisabled) {
      // Visible but disabled (muted background)
      circleDeco = BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      );
    } else {
      // Active / Today / Past
      circleDeco = BoxDecoration(
        color: isCompleted
            ? habit.color
            : (isPartialProgress
                  ? habit.color.withValues(alpha: 0.15)
                  : (isScheduled
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.transparent)),
        shape: BoxShape.circle,
        border: (isToday || isPartialProgress)
            ? Border.all(color: habit.color, width: isPartialProgress ? 2 : 2)
            : null,
      );
      if (isCompleted) {
        circleChild = const Icon(Icons.check, size: 18, color: Colors.white);
      }
    }

    return Container(
      width: 32,
      height: 32,
      decoration: circleDeco,
      alignment: Alignment.center,
      child: circleChild,
    );
  }
}
