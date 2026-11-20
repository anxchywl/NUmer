import 'package:flutter/material.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/history/history.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../stats_format.dart';

Future<String> generateHabitReport(
  BuildContext context,
  List<Habit> habits,
  DateTime monthDate,
  String format,
) async {
  // Removed "Generating CSV..." snackbar message
  final l10n = AppLocalizations.of(context)!;
  // Calculate month name early to avoid async gap usage of context
  final localizedMonth = monthName(context, monthDate.month);

  final start = DateTime(monthDate.year, monthDate.month, 1);
  final daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
  final end = DateTime(monthDate.year, monthDate.month, daysInMonth);

  // 1. Fetch History
  final activeHabits = habits.where((h) => !h.archived).toList();
  final habitHistoryMap = _historyByHabit(activeHabits, start, end);

  // 2. Prepare Rows (Pivoted)
  // Header - use English for CSV, localized for Excel
  final dayLabel = format == 'csv' ? 'Day' : l10n.csvDay;
  final header = <dynamic>[dayLabel];
  for (final h in activeHabits) {
    header.add(h.name);
  }
  final rows = <List<dynamic>>[header];

  // Days Rows
  final habitCompletions = <String, int>{}; // Track total completions for Rate
  final habitTargets = <String, int>{}; // Track total targets

  for (int day = 1; day <= daysInMonth; day++) {
    final d = DateTime(monthDate.year, monthDate.month, day);
    rows.add(
      _dayRow(d, activeHabits, habitHistoryMap, habitCompletions, habitTargets),
    );
  }

  rows.addAll(
    _summaryRows(format, l10n, activeHabits, habitCompletions, habitTargets),
  );

  // 4. Generate File
  // Localized filename: habits_MonthName_YYYY.{format}
  final fileExtension = format == 'excel' ? 'xlsx' : 'csv';
  final fileName =
      "${l10n.habitReportFileName(localizedMonth, monthDate.year)}.$fileExtension";

  return _writeReportFile(format, fileName, rows);
}

Future<String> _writeReportFile(
  String format,
  String fileName,
  List<List<dynamic>> rows,
) async {
  final String path;
  if (format == 'excel') {
    path = await ExportService.generateExcelFile(
      fileName: fileName,
      rows: rows,
    );
  } else {
    path = await ExportService.generateCsvFile(fileName: fileName, rows: rows);
  }

  return path;
}

Map<String, Map<String, double>> _historyByHabit(
  List<Habit> activeHabits,
  DateTime start,
  DateTime end,
) {
  final habitHistoryMap = <String, Map<String, double>>{};
  for (final habit in activeHabits) {
    final localHabit = Storage.getHabitById(habit.id);
    final resetAtMs = localHabit?.resetAtMs ?? 0;
    final historyList = Storage.getHabitHistoryForDateRange(
      habit.id,
      start,
      end,
    );
    final map = <String, double>{};
    for (final entry in historyList) {
      if (resetAtMs > 0 && entry.updatedAtMs < resetAtMs) {
        continue;
      }
      if (entry.deleted) continue;
      map[entry.dateKey] = entry.value ?? 0.0;
    }
    habitHistoryMap[habit.id] = map;
  }
  return habitHistoryMap;
}

List<dynamic> _dayRow(
  DateTime d,
  List<Habit> activeHabits,
  Map<String, Map<String, double>> habitHistoryMap,
  Map<String, int> habitCompletions,
  Map<String, int> habitTargets,
) {
  final dateKey =
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);

  final row = <dynamic>[d.day];

  // Check if this is a future date
  final isFuture = d.isAfter(todayDate);

  for (final h in activeHabits) {
    // For future dates, leave cell empty
    if (isFuture) {
      row.add('');
      continue;
    }

    // Calc Target (only for dates up to today)
    bool isScheduled = h.isScheduledFor(d);
    if (isScheduled) {
      habitTargets[h.id] = (habitTargets[h.id] ?? 0) + 1;
    }

    final map = habitHistoryMap[h.id];
    final val = map?[dateKey];

    if (val != null && val >= h.targetValue) {
      row.add('X');
      // If scheduled, it counts to completion rate
      if (isScheduled) {
        habitCompletions[h.id] = (habitCompletions[h.id] ?? 0) + 1;
      }
    } else if (isScheduled) {
      // Undone required/scheduled day
      row.add('-');
    } else {
      // Non-required day
      row.add('');
    }
  }
  return row;
}

List<List<dynamic>> _summaryRows(
  String format,
  AppLocalizations l10n,
  List<Habit> activeHabits,
  Map<String, int> habitCompletions,
  Map<String, int> habitTargets,
) {
  // 3. Add Summary Rows (Total, Target, Rate) - use English for CSV, localized for Excel
  final totalLabel = format == 'csv'
      ? 'Total completed'
      : l10n.csvTotalCompleted;
  final targetLabel = format == 'csv' ? 'Target' : l10n.csvTarget;
  final rateLabel = format == 'csv' ? 'Rate' : l10n.csvRate;

  final totalRow = <dynamic>[totalLabel];
  final targetRow = <dynamic>[targetLabel];
  final rateRow = <dynamic>[rateLabel];

  for (final h in activeHabits) {
    final comp = habitCompletions[h.id] ?? 0;
    final targ = habitTargets[h.id] ?? 0;
    final rate = targ > 0 ? (comp / targ * 100) : 0.0;

    totalRow.add(comp);
    targetRow.add(targ);
    rateRow.add("${rate.toStringAsFixed(1)}%");
  }

  return [
    [], // Spacer
    totalRow,
    targetRow,
    rateRow,
  ];
}
