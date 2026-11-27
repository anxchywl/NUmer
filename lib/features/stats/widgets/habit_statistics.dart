import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/stats_models.dart';
import 'habit_report_sheet.dart';
import 'habit_stats_card.dart';

class HabitStatistics extends StatelessWidget {
  final Map<String, HabitStatsResult>? statsByHabit;
  final bool loading;
  final PageController pageController;
  final DateTime reportMonth;
  final ValueChanged<List<Habit>> onLoadStats;
  final ValueChanged<List<Habit>> onHabitsShown;
  final ValueChanged<String> onHabitSelected;

  const HabitStatistics({
    super.key,
    required this.statsByHabit,
    required this.loading,
    required this.pageController,
    required this.reportMonth,
    required this.onLoadStats,
    required this.onHabitsShown,
    required this.onHabitSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Let's get it from FirebaseAuth for now or Provider.
    final uid =
        context.read<firebase_auth.FirebaseAuth?>()?.currentUser?.uid ??
        firebase_auth.FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<Habit>>(
      stream: context.read<HabitService>().habitsStream(uid),
      builder: (context, snapshot) {
        final habits = snapshot.data ?? [];
        if (habits.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.habitStatsEmptyState,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Trigger stats load if needed
        if (statsByHabit == null && !loading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onLoadStats(habits);
          });
        }

        // Initial Page Selection
        onHabitsShown(habits);

        return _layout(context, habits);
      },
    );
  }

  // Refactored inner layout to handle the stream wrapping
  Widget _layout(BuildContext context, List<Habit> habits) {
    final l10n = AppLocalizations.of(context)!;
    // Trigger stats load (idempotent-ish)
    // If we want live updates, we need to know when to force reload.
    // The StreamBuilder above rebuilds this widget on event.
    // So every time this builds, we might want to ensure stats are fresh.
    // But _loadSetState prevents loops.
    // We need to invalidate _allHabitsStatsCache upon stream event.
    // How does the stream builder pass "event" down? It doesn't.

    // Better approach: Listen in initState/didChangeDependencies?
    // But we are in a mixin/state class.
    // Let's just add the listener in initState and dispose in dispose.

    return Column(
      children: [
        // Month Chooser REMOVED (moved to dialog)

        // Swipe Selector (PageView)
        _carousel(context, habits),

        const SizedBox(height: 16),

        // Export Button (Outlined Style)

        // Export Button (Centered)
        _downloadButton(context, l10n, habits),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _carousel(BuildContext context, List<Habit> habits) {
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(180),
      child: PageView.builder(
        controller: pageController,
        itemCount: habits.length,
        onPageChanged: (index) => onHabitSelected(habits[index].id),
        itemBuilder: (context, index) {
          final habit = habits[index];
          final stats = statsByHabit?[habit.id];

          return AnimatedBuilder(
            animation: pageController,
            builder: (context, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ), // Tighter padding
                child: child,
              );
            },
            child: HabitStatsCard(habit: habit, stats: stats),
          );
        },
      ),
    );
  }

  Widget _downloadButton(
    BuildContext context,
    AppLocalizations l10n,
    List<Habit> habits,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () => showHabitReportSheet(
            context,
            habits: habits,
            initialMonth: reportMonth,
          ),
          icon: const Icon(Icons.download, size: 18),
          label: Text(l10n.habitReportDownload),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
