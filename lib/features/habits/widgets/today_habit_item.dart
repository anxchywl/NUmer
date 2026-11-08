import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../habit_dates.dart';
import '../models/habit.dart';
import 'habit_completion_indicator.dart';

class TodayHabitItem extends StatelessWidget {
  const TodayHabitItem({
    super.key,
    required this.habit,
    required this.selectedDate,
    required this.onToggle,
  });

  final Habit habit;
  final DateTime selectedDate;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentValue = habit.last7[dateKey(selectedDate)] ?? 0.0;
    final isFuture = isFutureDate(selectedDate);
    final isDark = theme.brightness == Brightness.dark;

    final row = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 16),
          Expanded(child: _buildText(context, currentValue)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: isFuture ? null : onToggle,
            child: HabitCompletionIndicator(
              habit: habit,
              currentValue: currentValue,
              size: 36,
            ),
          ),
        ],
      ),
    );
    if (!isFuture) return row;
    return Opacity(opacity: 0.5, child: row);
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: habit.color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        IconData(
          habit.iconCodePoint,
          fontFamily: habit.iconFamily,
          fontPackage: habit.iconPackage,
        ),
        color: habit.color,
        size: 24,
      ),
    );
  }

  Widget _buildText(BuildContext context, double currentValue) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    final useLightTitle =
        appState.homeSummaryRange == HomeSummaryRange.off &&
        habit.connectedCourseIds.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          habit.name,
          style: TextStyle(
            fontWeight: useLightTitle ? FontWeight.w500 : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _requirementText(l10n, currentValue),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _requirementText(AppLocalizations l10n, double currentValue) {
    final numberFormat = NumberFormat.decimalPattern(l10n.localeName);
    if (habit.type == HabitType.numeric) {
      final unit = (habit.unit ?? "").trim();
      final currentStr = numberFormat.format(currentValue.toInt());
      final targetStr = numberFormat.format(habit.targetValue.toInt());
      return unit.isNotEmpty
          ? l10n.habitRequirementToday(currentStr, targetStr, unit)
          : l10n.habitRequirementTodayNoUnit(currentStr, targetStr);
    } else if (habit.type == HabitType.time) {
      final curStr = _formatDurationHms(currentValue);
      final tarStr = _formatDurationHms(habit.targetValue);
      return l10n.habitRequirementTodayNoUnit(curStr, tarStr);
    }
    return l10n.habitRequirementMarkDone;
  }

  String _formatDurationHms(double seconds) {
    final totalSeconds = seconds.round().clamp(0, 359999).toInt();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = secs.toString().padLeft(2, '0');
    return "$hStr:$mStr:$sStr";
  }
}
