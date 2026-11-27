import 'package:flutter/material.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'home_goal.dart';
import 'study_duration.dart';

class TodayBlock extends StatelessWidget {
  const TodayBlock({
    super.key,
    required this.habits,
    required this.onOpenStudy,
    required this.onOpenHabits,
  });

  final Stream<List<Habit>> habits;
  final VoidCallback onOpenStudy;
  final VoidCallback onOpenHabits;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return StreamBuilder<List<Habit>>(
      stream: habits,
      builder: (context, snapshot) {
        final habitsRow = _habitsRow(context, state, snapshot.data);
        return NumerBlock(children: [_studyRow(context, state), ?habitsRow]);
      },
    );
  }

  Widget _studyRow(BuildContext context, AppState state) {
    final l10n = AppLocalizations.of(context)!;
    final studied = formatStudyDuration(l10n, state.todayTotalSeconds());
    final goal = dailyGoalSeconds(state);
    return NumerRow(
      title: l10n.navStudy,
      value: studied,
      subtitle: goal > 0
          ? l10n.homeGoalProgress(studied, formatStudyDuration(l10n, goal))
          : null,
      showChevron: true,
      onTap: onOpenStudy,
    );
  }

  Widget? _habitsRow(BuildContext context, AppState state, List<Habit>? all) {
    if (all == null) return null;
    final summary = summarizeHabitsForDay(
      all,
      DateTime.now(),
      mondayFirst: state.weekStart == WeekStart.monday,
    );
    if (summary.total == 0) return null;
    final l10n = AppLocalizations.of(context)!;
    return NumerRow(
      title: l10n.habitsNavLabel,
      value: l10n.habitsDoneSummary(summary.done, summary.total),
      showChevron: true,
      onTap: onOpenHabits,
    );
  }
}
