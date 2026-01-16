import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/habit.dart';
import '../../../services/habit_service.dart';
import '../../../app_state.dart';
import 'habit_logging_sheet.dart';
import '../../../l10n/app_localizations.dart';

class HabitDaySheet extends StatelessWidget {
  final DateTime date;
  final List<Habit> allHabits;
  final Map<String, double> progressMap;
  final String userId;
  final bool isReadOnly;

  const HabitDaySheet({
    super.key,
    required this.date,
    required this.allHabits,
    required this.progressMap,
    required this.userId,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
                DateFormat.yMMMMEEEEd(l10n.localeName).format(date),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.habitDailyOverview,
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
                      Text(l10n.habitNoHabitsThisDay, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
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
                        userId: userId,
                        isReadOnly: isReadOnly,
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
    // Show habits that were COMPLETED OR are SCHEDULED for this day
    return allHabits.where((h) {
      final isScheduled = h.isScheduledFor(date);
      final hasProgress = progressMap.containsKey(h.id) && progressMap[h.id]! > 0;
      return isScheduled || hasProgress;
    }).toList();
  }
}

class _HabitRow extends StatelessWidget {
  final Habit habit;
  final DateTime date;
  final double progress;
  final String userId;
  final bool isReadOnly;

  const _HabitRow({
    required this.habit,
    required this.date,
    required this.progress,
    required this.userId,
    required this.isReadOnly,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    // Determine status
    bool isCompleted = false;
    if (habit.type == HabitType.yesNo) {
      isCompleted = progress > 0;
    } else {
      isCompleted = progress >= habit.targetValue;
    }
    
    final isPartial = !isCompleted && progress > 0;

    return InkWell(
      onTap: isReadOnly ? null : () {
        _logProgress(context);
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
                        _formatProgress(l10n),
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

  String _formatProgress(AppLocalizations l10n) {
    final numberFormat = NumberFormat.decimalPattern(l10n.localeName);
    if (habit.type == HabitType.time) {
      final currentMins = (progress / 60).round();
      final targetMins = (habit.targetValue / 60).round();
      return "${numberFormat.format(currentMins)} / ${numberFormat.format(targetMins)} ${l10n.habitMinutesShort}";
    }
    final current = numberFormat.format(progress.toInt());
    final target = numberFormat.format(habit.targetValue.toInt());
    final unit = habit.unit ?? '';
    return "$current / $target ${unit.isNotEmpty ? unit : ''}".trim();
  }

  void _logProgress(BuildContext context) async {
    if (habit.type == HabitType.yesNo) {
      HapticFeedback.lightImpact();
      final isCompleted = progress >= habit.targetValue;
      try {
        await context.read<HabitService>().toggleCompletion(
              userId: userId,
              habit: habit,
              date: date,
              completed: !isCompleted,
            );
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Error: $e"), backgroundColor: Theme.of(context).colorScheme.error),
           );
        }
      }
      if (context.mounted) context.read<AppState>().triggerSync();
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => HabitLoggingSheet(
          habit: habit,
          date: date,
          userId: userId,
          initialValue: progress,
        ),
      );
    }
  }
}
