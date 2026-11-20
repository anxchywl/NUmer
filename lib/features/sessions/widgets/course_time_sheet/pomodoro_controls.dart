import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class PomodoroControls extends StatelessWidget {
  const PomodoroControls({
    super.key,
    required this.course,
    required this.onStart,
    required this.onResume,
    required this.onPause,
    required this.onReset,
    required this.onSkipBreak,
  });

  final Course course;
  final VoidCallback onStart;
  final VoidCallback onResume;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSkipBreak;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final hasSession = state.pomodoroRunning[course.id] ?? false;
    final isPaused = state.pomodoroPaused[course.id] ?? false;
    final onBreak = state.pomodoroIsOnBreak(course.id);
    final elapsed = state.currentPomodoroElapsed(course.id).inSeconds;
    final canReset = hasSession || elapsed > 0;

    IconData primaryIcon;
    String primaryLabel;
    VoidCallback? primaryAction;

    if (!hasSession) {
      primaryIcon = Icons.play_arrow;
      primaryLabel = AppLocalizations.of(context)!.start;
      primaryAction = onStart;
    } else if (isPaused) {
      primaryIcon = Icons.play_arrow;
      primaryLabel = AppLocalizations.of(context)!.resume;
      primaryAction = onResume;
    } else {
      primaryIcon = Icons.pause;
      primaryLabel = AppLocalizations.of(context)!.pause;
      primaryAction = onPause;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: primaryAction,
                icon: Icon(primaryIcon),
                label: Text(primaryLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: canReset ? onReset : null,
                icon: const Icon(Icons.stop),
                label: Text(AppLocalizations.of(context)!.reset),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onBreak ? onSkipBreak : null,
            icon: const Icon(Icons.skip_next),
            label: Text(AppLocalizations.of(context)!.skipBreak),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

String pomodoroPhaseLabel(AppLocalizations l10n, PomodoroPhase phase) {
  switch (phase) {
    case PomodoroPhase.work:
      return l10n.work;
    case PomodoroPhase.shortBreak:
      return l10n.shortBreak;
    case PomodoroPhase.longBreak:
      return l10n.longBreak;
  }
}
