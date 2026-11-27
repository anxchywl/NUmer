import 'package:flutter/material.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';

import 'habit_report_selection_view.dart';
import 'habit_report_session.dart';
import 'habit_report_success_view.dart';

Future<void> showHabitReportSheet(
  BuildContext context, {
  required List<Habit> habits,
  required DateTime initialMonth,
}) async {
  final session = HabitReportSession(
    habits: habits,
    selectedMonth: initialMonth,
  );

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSheetState) =>
          _sheetBody(context, session, setSheetState),
    ),
  ).then((_) => session.timer?.cancel());
}

Widget _sheetBody(
  BuildContext context,
  HabitReportSession session,
  StateSetter setSheetState,
) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);

  // Update the periodic timer to call triggerExport
  if (session.timer != null &&
      !session.timer!.isActive &&
      session.countdown == 1) {
    // This is a bit tricky inside build.
    // Better to handle it in the timer callback itself.
  }

  return Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      left: 24,
      right: 24,
      top: 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.habitReportTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Animated content switcher
        _switcher(l10n, theme, session, setSheetState),

        const SizedBox(height: 32),
        _actionButton(context, l10n, session, setSheetState),
        if (session.isExporting && session.countdown > 0)
          _countdownNote(l10n, theme, session.countdown),
        const SizedBox(height: 16),
      ],
    ),
  );
}

Widget _switcher(
  AppLocalizations l10n,
  ThemeData theme,
  HabitReportSession session,
  StateSetter setSheetState,
) {
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 500),
    layoutBuilder: (currentChild, previousChildren) {
      return Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[...previousChildren, ?currentChild],
      );
    },
    transitionBuilder: (child, animation) =>
        _slideAndFade(child, animation, session.isSuccess),
    child: session.isSuccess
        ? HabitReportSuccessView(
            key: const ValueKey(true),
            l10n: l10n,
            theme: theme,
            filePath: session.filePath,
          )
        : HabitReportSelectionView(
            key: const ValueKey(false),
            l10n: l10n,
            theme: theme,
            selectedMonth: session.selectedMonth,
            selectedFormat: session.selectedFormat,
            onMonthChanged: (newMonth) =>
                setSheetState(() => session.selectedMonth = newMonth),
            onFormatChanged: (newFormat) =>
                setSheetState(() => session.selectedFormat = newFormat),
          ),
  );
}

Widget _slideAndFade(
  Widget child,
  Animation<double> animation,
  bool isSuccess,
) {
  final isIncoming = child.key == ValueKey(isSuccess);

  final offset = isIncoming
      ? Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        )
      : Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeInCubic),
        );

  return FadeTransition(
    opacity: animation,
    child: SlideTransition(position: offset, child: child),
  );
}

Widget _actionButton(
  BuildContext context,
  AppLocalizations l10n,
  HabitReportSession session,
  StateSetter setSheetState,
) {
  return FilledButton(
    onPressed: session.isSuccess
        ? () => Navigator.pop(context)
        : (session.isExporting
              ? (session.countdown > 0
                    ? () => session.cancelCountdown(setSheetState)
                    : null)
              : () => session.startCountdown(context, l10n, setSheetState)),
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: NumerButtonChild(
      label: session.isExporting
          ? (session.countdown > 0 ? l10n.cancel : l10n.exporting)
          : (session.isSuccess ? l10n.done : l10n.habitReportDownloadAction),
      icon: session.isExporting && session.countdown > 0
          ? const Icon(Icons.close)
          : (session.isSuccess ? null : const Icon(Icons.download)),
      loading: session.isExporting && session.countdown == 0,
      loadingHint: l10n.loadingHint,
    ),
  );
}

Widget _countdownNote(AppLocalizations l10n, ThemeData theme, int countdown) {
  final scheme = theme.colorScheme;
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      l10n.habitReportDownloadCountdown(countdown),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
    ),
  );
}
