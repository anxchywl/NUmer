part of 'local_database.dart';

extension LocalDatabaseHabits on LocalDatabase {
  // habit crud
  Iterable<LocalHabit> habits({bool includeDeleted = false}) {
    final values = _habitsBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((h) => !h.deleted);
  }

  List<LocalHabit> dirtyHabits() =>
      (_habitsBox?.values ?? const Iterable<LocalHabit>.empty())
          .where((h) => h.dirty)
          .toList(growable: false);

  LocalHabit? getHabitById(String id) => _habitsBox?.get(id);

  Future<void> putHabit(LocalHabit habit) async {
    await _habitsBox?.put(habit.id, habit);
  }

  Box<LocalHabit> get habitsBox =>
      _habitsBox ?? (throw StateError('Habits box not opened'));

  // habit history crud
  Iterable<LocalHabitHistory> habitHistory({bool includeDeleted = false}) {
    final values = _habitHistoryBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((h) => !h.deleted);
  }

  Iterable<LocalHabitHistory> habitHistoryForHabit(
    String habitId, {
    bool includeDeleted = false,
  }) {
    return habitHistory(
      includeDeleted: includeDeleted,
    ).where((h) => h.habitId == habitId);
  }

  List<LocalHabitHistory> dirtyHabitHistory() =>
      (_habitHistoryBox?.values ?? const Iterable<LocalHabitHistory>.empty())
          .where((h) => h.dirty)
          .toList(growable: false);

  LocalHabitHistory? getHabitHistoryById(String id) =>
      _habitHistoryBox?.get(id);

  Future<void> putHabitHistory(LocalHabitHistory entry) async {
    await _habitHistoryBox?.put(entry.id, entry);
  }

  Box<LocalHabitHistory> get habitHistoryBox =>
      _habitHistoryBox ?? (throw StateError('Habit History box not opened'));
}
