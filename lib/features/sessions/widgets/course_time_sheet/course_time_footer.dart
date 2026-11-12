import 'package:flutter/material.dart';

import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'pomodoro_controls.dart';

class CourseTimeFooter extends StatelessWidget {
  const CourseTimeFooter({
    super.key,
    required this.course,
    required this.tabIndex,
    required this.fadeAway,
    required this.isTimerRunning,
    required this.isStopwatchRunning,
    required this.isPomodoroActive,
    required this.onStartTimer,
    required this.onDoneTimer,
    required this.onStartStopwatch,
    required this.onDoneStopwatch,
    required this.onStartPomodoro,
    required this.onResumePomodoro,
    required this.onPausePomodoro,
    required this.onResetPomodoro,
    required this.onSkipBreak,
  });

  final Course course;
  final int tabIndex;
  final Animation<double> fadeAway;
  final bool isTimerRunning;
  final bool isStopwatchRunning;
  final bool isPomodoroActive;
  final VoidCallback onStartTimer;
  final VoidCallback onDoneTimer;
  final VoidCallback onStartStopwatch;
  final VoidCallback onDoneStopwatch;
  final VoidCallback onStartPomodoro;
  final VoidCallback onResumePomodoro;
  final VoidCallback onPausePomodoro;
  final VoidCallback onResetPomodoro;
  final VoidCallback onSkipBreak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: tabIndex == 2
          ? PomodoroControls(
              course: course,
              onStart: onStartPomodoro,
              onResume: onResumePomodoro,
              onPause: onPausePomodoro,
              onReset: onResetPomodoro,
              onSkipBreak: onSkipBreak,
            )
          : FadeTransition(
              opacity: ReverseAnimation(fadeAway),
              child: _startDoneRow(context),
            ),
    );
  }

  Widget _startDoneRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: tabIndex == 0
                ? (isTimerRunning || isPomodoroActive ? null : onStartTimer)
                : (isStopwatchRunning || isPomodoroActive
                      ? null
                      : onStartStopwatch),
            icon: const Icon(Icons.play_arrow),
            label: Text(AppLocalizations.of(context)!.start),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: tabIndex == 0
                ? (isTimerRunning ? onDoneTimer : null)
                : (isStopwatchRunning ? onDoneStopwatch : null),
            icon: const Icon(Icons.check),
            label: Text(AppLocalizations.of(context)!.done),
          ),
        ),
      ],
    );
  }
}
