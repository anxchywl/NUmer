import 'dart:async';

import 'package:flutter/material.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/history/history.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../data/habit_report_builder.dart';

class HabitReportSession {
  final List<Habit> habits;
  DateTime selectedMonth;
  String selectedFormat = 'excel'; // Default to Excel
  bool isExporting = false;
  bool isSuccess = false;
  String? filePath;
  int countdown = 0;
  Timer? timer;

  HabitReportSession({required this.habits, required this.selectedMonth});

  Future<void> triggerExport(
    BuildContext context,
    AppLocalizations l10n,
    StateSetter setSheetState,
  ) async {
    ExportService.markExportStarted();
    setSheetState(() {
      isExporting = true;
      countdown = 0;
    });
    try {
      final path = await generateHabitReport(
        context,
        habits,
        selectedMonth,
        selectedFormat,
      );
      if (context.mounted) {
        setSheetState(() {
          isSuccess = true;
          filePath = path;
        });
      }
    } catch (e) {
      if (context.mounted) {
        showAppMessage(
          context,
          l10n.habitReportFailed(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (context.mounted) {
        setSheetState(() => isExporting = false);
      }
    }
  }

  void startCountdown(
    BuildContext context,
    AppLocalizations l10n,
    StateSetter setSheetState,
  ) {
    final remaining = ExportService.remainingCooldownSeconds;
    if (remaining == 0) {
      triggerExport(context, l10n, setSheetState);
      return;
    }

    setSheetState(() {
      isExporting = true;
      countdown = remaining;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown > 1) {
        setSheetState(() => countdown--);
      } else {
        t.cancel();
        triggerExport(context, l10n, setSheetState);
      }
    });
  }

  void cancelCountdown(StateSetter setSheetState) {
    timer?.cancel();
    setSheetState(() {
      isExporting = false;
      countdown = 0;
    });
  }
}
