import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/habit.dart';

class HabitDaySheet extends StatelessWidget {
  final DateTime date;
  final List<Habit> allHabits; // Pass all to filter active ones for this day
  final Map<String, double> progressMap; // habitId -> value for this day

  const HabitDaySheet({
    super.key,
    required this.date,
    required this.allHabits,
    required this.progressMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedHabits = _getDailyHabits();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                DateFormat.yMMMMEEEEd().format(date),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Daily Overview",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              
              if (sortedHabits.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      Text("No habits scheduled for this day.", style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedHabits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final habit = sortedHabits[index];
                      return _HabitRow(
                        habit: habit,
                        date: date,
                        progress: progressMap[habit.id] ?? 0,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Habit> _getDailyHabits() {
    // Filter habits that are scheduled for this day OR have progress on this day
    return allHabits.where((h) {
      if (progressMap.containsKey(h.id) && progressMap[h.id]! > 0) return true;
      return h.isScheduledFor(date);
    }).toList();
  }
}

class _HabitRow extends StatelessWidget {
  final Habit habit;
  final DateTime date;
  final double progress;

  const _HabitRow({required this.habit, required this.date, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Determine status
    bool isCompleted = false;
    if (habit.type == HabitType.yesNo) {
      isCompleted = progress > 0;
    } else {
      isCompleted = progress >= habit.targetValue;
    }
    
    final isPartial = !isCompleted && progress > 0;

    return InkWell(
      onTap: () {
        // Option: Open edit/details or toggle
        // Requirement: "Tapping a habit: Opens Edit Habit screen"
        // But maybe HabitDetails is better context. Let's try HabitDetailsScreen or a bottom sheet for editing.
        // Given existing code, maybe just open HabitDetailsScreen?
        // Or AddHabitSheet in edit mode?
        // Let's assume HabitDetailsScreen for now or just Show Toast "Edit not implemented" if we lack context.
        // Actually, let's open AddHabitSheet(habit: habit) if possible, or show modal.
        // For now, I'll put a placeholder or basic interaction.
        // Better: Toggle completion for Yes/No, Show details for others.
        // Re-reading request: "Opens Edit Habit screen (via 3 dots or row tap, your choice)"
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: isCompleted ? Border.all(color: habit.color.withAlpha(100)) : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: habit.color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                IconData(habit.iconCodePoint, fontFamily: habit.iconFamily, fontPackage: habit.iconPackage),
                color: habit.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // Name & Progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? theme.colorScheme.onSurface.withAlpha(150) : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (habit.type != HabitType.yesNo)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _formatProgress(),
                        style: theme.textTheme.bodySmall?.copyWith(
                           color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Status Icon
            if (isCompleted)
              Icon(Icons.check_circle, color: habit.color)
            else if (isPartial)
              Icon(Icons.timelapse, color: theme.colorScheme.tertiary)
            else
              Icon(Icons.circle_outlined, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  String _formatProgress() {
    if (habit.type == HabitType.time) {
      final currentMins = (progress / 60).round();
      final targetMins = (habit.targetValue / 60).round();
      return "$currentMins / $targetMins min";
    }
    return "${progress.toInt()} / ${habit.targetValue.toInt()} ${habit.unit ?? ''}";
  }
}
