import 'package:flutter/material.dart';
import 'package:numer_app/core/data/storage.dart';

import '../models/habit.dart';
import 'eisenhower_matrix_widget.dart';
import 'habit_sorter_card.dart';
import 'habits_clearances.dart';

class HabitsMatrixSliver extends StatelessWidget {
  const HabitsMatrixSliver({
    super.key,
    required this.habits,
    required this.selectedDate,
    required this.calendarKey,
    required this.datePicker,
    required this.onPlaced,
    required this.onToggle,
  });

  final List<Habit> habits;
  final DateTime selectedDate;
  final Key calendarKey;
  final Widget Function() datePicker;
  final void Function(bool wasLast) onPlaced;
  final void Function(Habit habit) onToggle;

  @override
  Widget build(BuildContext context) {
    final placements = Storage.getHabitQuadrantPlacements();
    final unsortedHabits = habits
        .where((h) => !placements.containsKey(h.id))
        .toList();

    // Full-screen matrix layout
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final availableHeight =
        screenHeight - topPadding - kToolbarHeight - bottomPadding - 20;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: availableHeight - progressBottomClearance(context),
        child: Column(
          children: [
            // Top Area: Sorter OR Calendar Strip
            unsortedHabits.isNotEmpty
                ? HabitSorterCard(
                    key: ValueKey(unsortedHabits.first.id),
                    habit: unsortedHabits.first,
                    onPlaced: () => onPlaced(unsortedHabits.length == 1),
                  )
                : KeyedSubtree(key: calendarKey, child: datePicker()),

            // Matrix grid
            Expanded(
              child: EisenhowerMatrixWidget(
                habits: habits
                    .where((h) => placements.containsKey(h.id))
                    .toList(),
                selectedDate: selectedDate,
                onHabitTap: onToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
