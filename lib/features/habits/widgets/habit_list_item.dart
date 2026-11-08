import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../screens/habit_details_screen.dart';
import 'habit_frequency_text.dart';
import 'habit_week_strip.dart';

class HabitListItem extends StatelessWidget {
  final Habit habit;
  final List<DateTime> weekDates; // Base week dates from parent (current week)
  final Function(DateTime) onToggle;
  final VoidCallback? onReturn;

  const HabitListItem({
    super.key,
    required this.habit,
    required this.weekDates,
    required this.onToggle,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Divider(
                  height: 32,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                HabitWeekStrip(
                  habit: habit,
                  weekDates: weekDates,
                  onToggle: onToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: habit.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            IconData(
              habit.iconCodePoint,
              fontFamily: habit.iconFamily,
              fontPackage: habit.iconPackage,
            ),
            color: habit.color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildTitle(context)),
        IconButton(
          icon: Icon(
            Icons.more_vert,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HabitDetailsScreen(habit: habit),
              ),
            );
            // Re-center on return if today is selected
            onReturn?.call();
          },
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final frequencyText = habitFrequencyText(habit, l10n, l10n.localeName);
    final appState = context.read<AppState>();
    final useLightTitle =
        appState.homeSummaryRange == HomeSummaryRange.off &&
        habit.connectedCourseIds.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                habit.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: useLightTitle ? FontWeight.w500 : FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (habit.liveCurrentStreak > 0) ...[
              const SizedBox(width: 8),
              _buildStreakBadge(theme),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          frequencyText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStreakBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 12,
            color: Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            "${habit.liveCurrentStreak}",
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}
