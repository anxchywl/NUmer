import 'package:flutter/material.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../models/habit.dart';
import 'habit_list_item.dart';
import 'habits_clearances.dart';
import 'habits_create_button.dart';

class HabitsListSliver extends StatelessWidget {
  const HabitsListSliver({
    super.key,
    required this.snapshot,
    required this.weekDates,
    required this.optimisticOrder,
    required this.onOrderSynced,
    required this.onReorder,
    required this.onToggle,
    required this.onReturn,
    required this.onCreate,
  });

  final AsyncSnapshot<List<Habit>> snapshot;
  final List<DateTime> weekDates;
  final List<String>? optimisticOrder;
  final VoidCallback onOrderSynced;
  final void Function(List<String> order, int oldIndex, int newIndex) onReorder;
  final Future<void> Function(Habit habit, DateTime date) onToggle;
  final VoidCallback onReturn;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      final l10n = AppLocalizations.of(context)!;
      return SliverFillRemaining(
        child: Center(
          child: Text(l10n.habitsListError(snapshot.error.toString())),
        ),
      );
    }

    // Use existing data even during loading - prevents flicker
    final habits = snapshot.data ?? [];

    if (habits.isEmpty) return _buildEmpty(context);

    return _buildList(context, _applyOptimisticOrder(habits));
  }

  Widget _buildEmpty(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.habitsEmptyListTitle,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onCreate,
              child: const Text(createNewHabitLabel),
            ),
          ],
        ),
      ),
    );
  }

  List<Habit> _applyOptimisticOrder(List<Habit> habits) {
    // Apply optimistic reordering if active
    List<Habit> displayHabits = List.from(habits);
    final order = optimisticOrder;
    if (order == null) return displayHabits;
    final orderMap = order.asMap().map((k, v) => MapEntry(v, k));

    // Check if server data has caught up (same order as optimistic)
    bool synced = true;
    if (displayHabits.length == order.length) {
      for (int i = 0; i < displayHabits.length; i++) {
        if (displayHabits[i].id != order[i]) {
          synced = false;
          break;
        }
      }
    } else {
      synced = false;
    }

    if (synced) {
      // Server caught up, clear optimistic state
      onOrderSynced();
    } else {
      // Apply optimistic sort
      displayHabits.sort((a, b) {
        final idxA = orderMap[a.id] ?? 9999;
        final idxB = orderMap[b.id] ?? 9999;
        return idxA.compareTo(idxB);
      });
    }
    return displayHabits;
  }

  Widget _buildList(BuildContext context, List<Habit> displayHabits) {
    return SliverPadding(
      padding: EdgeInsets.only(
        bottom: isIos(context)
            ? iosBottomNavClearance(context)
            : MediaQuery.of(context).padding.bottom + 80,
      ),
      sliver: SliverReorderableList(
        itemCount: displayHabits.length,
        onReorder: (oldIndex, newIndex) {
          if (oldIndex < newIndex) newIndex -= 1;
          final item = displayHabits.removeAt(oldIndex);
          displayHabits.insert(newIndex, item);

          onReorder(
            displayHabits.map((h) => h.id).toList(),
            oldIndex,
            newIndex,
          );
        },
        itemBuilder: (context, index) {
          final habit = displayHabits[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(habit.id),
            index: index,
            child: HabitListItem(
              habit: habit,
              weekDates: weekDates,
              onToggle: (date) => onToggle(habit, date),
              onReturn: onReturn,
            ),
          );
        },
      ),
    );
  }
}
