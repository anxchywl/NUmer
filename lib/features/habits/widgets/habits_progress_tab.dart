import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import 'habits_clearances.dart';
import 'habits_due_on.dart';
import 'habits_matrix_sliver.dart';
import 'today_habits_sliver.dart';

// a list, not one widget: the screen reuses the first stream builder across tabs
List<Widget> habitsProgressSlivers({
  required BuildContext context,
  required Stream<List<Habit>> Function() habitsStream,
  required DateTime selectedDate,
  required Key calendarKey,
  required Widget Function() datePicker,
  required void Function(bool wasLast) onPlaced,
  required void Function(Habit habit) onToggle,
}) {
  return [
    if (isIos(context))
      SliverToBoxAdapter(
        child: SizedBox(height: iosTopContentClearance(context)),
      ),
    // Today View: Check if Eisenhower Matrix is enabled
    StreamBuilder<List<Habit>>(
      stream: habitsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(child: SizedBox());
        }
        final allHabits = snapshot.data!;
        final appState = context.watch<AppState>();

        // If Eisenhower Matrix is enabled, show matrix UI
        if (appState.eisenhowerMatrixEnabled) {
          return HabitsMatrixSliver(
            habits: habitsDueOn(allHabits, selectedDate, appState.weekStart),
            selectedDate: selectedDate,
            calendarKey: calendarKey,
            datePicker: datePicker,
            onPlaced: onPlaced,
            onToggle: onToggle,
          );
        }

        // Regular view - render date picker first
        return const SliverToBoxAdapter(child: SizedBox());
      },
    ),
    // Regular Today View components (only when matrix is disabled)
    Builder(
      builder: (context) {
        final appState = context.watch<AppState>();
        if (appState.eisenhowerMatrixEnabled) {
          return const SliverToBoxAdapter(child: SizedBox());
        }
        return SliverToBoxAdapter(
          child: KeyedSubtree(key: calendarKey, child: datePicker()),
        );
      },
    ),
    // Today View: Habit List (only when matrix is disabled)
    _todayList(habitsStream, selectedDate, onToggle),
  ];
}

Widget _todayList(
  Stream<List<Habit>> Function() habitsStream,
  DateTime selectedDate,
  void Function(Habit habit) onToggle,
) {
  return Builder(
    builder: (context) {
      final appState = context.watch<AppState>();
      if (appState.eisenhowerMatrixEnabled) {
        return const SliverToBoxAdapter(child: SizedBox());
      }
      return StreamBuilder<List<Habit>>(
        stream: habitsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SliverToBoxAdapter(child: SizedBox());
          }
          // Unified Order: Use valid habits stream order directly.
          // This ensures consistency with "My Habits" and Statistics.
          return TodayHabitsSliver(
            habits: habitsDueOn(
              snapshot.data!,
              selectedDate,
              appState.weekStart,
            ),
            selectedDate: selectedDate,
            onToggle: onToggle,
          );
        },
      );
    },
  );
}
