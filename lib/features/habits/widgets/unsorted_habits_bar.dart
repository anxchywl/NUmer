import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/features/habits/models/habit.dart';

/// Horizontal scrollable bar for unsorted habits that can be dragged into the Eisenhower matrix
class UnsortedHabitsBar extends StatelessWidget {
  const UnsortedHabitsBar({
    super.key,
    required this.unsortedHabits,
    required this.showHint,
  });

  final List<Habit> unsortedHabits;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: showHint ? 110 : 90,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHint)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.eisenhowerHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: unsortedHabits.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final habit = unsortedHabits[index];
                return _DraggableHabitChip(habit: habit);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableHabitChip extends StatelessWidget {
  const _DraggableHabitChip({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habitColor = habit.color;

    return LongPressDraggable<Habit>(
      data: habit,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: habitColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                habit.name,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildChip(theme, habitColor),
      ),
      child: _buildChip(theme, habitColor),
    );
  }

  Widget _buildChip(ThemeData theme, Color habitColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: habitColor.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: habitColor.withAlpha(150),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'),
            color: habitColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            habit.name,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
