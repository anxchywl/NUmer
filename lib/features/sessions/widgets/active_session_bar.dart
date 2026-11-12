import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../models/active_session_info.dart';
import '../models/session_limits.dart';

class ActiveSessionBar extends StatefulWidget {
  const ActiveSessionBar({super.key});

  @override
  State<ActiveSessionBar> createState() => _ActiveSessionBarState();
}

class _ActiveSessionBarState extends State<ActiveSessionBar> {
  Timer? _ticker;
  String? _cachedCourseId;
  int? _plannedSecs;

  @override
  void initState() {
    super.initState();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadPlannedIfNeeded(String courseId) async {
    if (_cachedCourseId == courseId) return;
    _cachedCourseId = courseId;
    final prefs = await SharedPreferences.getInstance();
    _plannedSecs = prefs.getInt('timer_planned_$courseId');
    if (mounted) setState(() {});
  }

  String _fmtHMSLocal(int s) {
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!hasAnyActiveSessionIn(state)) {
      return const SizedBox.shrink();
    }

    final info = activeSessionInfo(state)!;
    final courseId = info.id;
    final kind = info.kind;
    final course = state.courses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => Course(
        id: courseId,
        name: 'Unknown',
        day: '',
        start: '',
        end: '',
        colorValue: 0xFF94A3B8,
      ),
    );

    if (kind == 'timer') {
      _loadPlannedIfNeeded(courseId);
    } else {
      _plannedSecs = null;
      _cachedCourseId = null;
    }

    final (timeText, subtitleKind) = _sessionTexts(state, courseId, kind);

    final theme = Theme.of(context);
    final bg = theme.colorScheme.primaryContainer;
    final fg = theme.colorScheme.onPrimaryContainer;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Material(
        key: ValueKey('$courseId-$kind'),
        color: bg,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: course.color),
              const SizedBox(width: 10),
              _labels(theme, fg, course.name, '$subtitleKind • $timeText'),
              const SizedBox(width: 12),
              _stopButton(state, course, courseId, kind),
            ],
          ),
        ),
      ),
    );
  }

  (String, String) _sessionTexts(AppState state, String courseId, String kind) {
    String timeText;
    String subtitleKind;
    if (kind == 'timer') {
      final elapsed = state.currentElapsedTimer(courseId).inSeconds;
      if (_plannedSecs != null && _plannedSecs! > 0) {
        final remaining = (_plannedSecs! - elapsed).clamp(
          0,
          kMaxSessionSeconds,
        );
        timeText = '${_fmtHMSLocal(remaining)} remaining';
      } else {
        timeText = '${_fmtHMSLocal(elapsed)} elapsed';
      }
      subtitleKind = 'Timer';
    } else if (kind == 'stopwatch') {
      final elapsed = state.currentElapsedStopwatch(courseId).inSeconds;
      timeText = _fmtHMSLocal(elapsed);
      subtitleKind = 'Stopwatch';
    } else {
      final remaining = state.currentPomodoroRemaining(courseId).inSeconds;
      final phase = state.pomodoroPhase[courseId] ?? PomodoroPhase.work;
      final paused = state.pomodoroPaused[courseId] ?? false;
      timeText =
          '${_pomodoroPhaseLabel(phase)} • ${_fmtHMSLocal(remaining)} remaining${paused ? ' (paused)' : ''}';
      subtitleKind = 'Pomodoro';
    }

    return (timeText, subtitleKind);
  }

  Widget _labels(ThemeData theme, Color fg, String title, String subtitle) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }

  Widget _stopButton(
    AppState state,
    Course course,
    String courseId,
    String kind,
  ) {
    return FilledButton.tonalIcon(
      onPressed: () => _stop(state, course, courseId, kind),
      icon: const Icon(Icons.stop_circle_outlined),
      label: Text(
        kind == 'timer' ? 'Done' : (kind == 'stopwatch' ? 'Stop' : 'Reset'),
      ),
    );
  }

  Future<void> _stop(
    AppState state,
    Course course,
    String courseId,
    String kind,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    int seconds = 0;
    String? snackMessage;

    if (kind == 'timer') {
      snackMessage = AppLocalizations.of(
        context,
      )!.timeSavedMessage(courseNameWithoutParentheses(course.name));
      seconds = await state.stopTimer(courseId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('timer_planned_$courseId');
    } else if (kind == 'stopwatch') {
      snackMessage = AppLocalizations.of(
        context,
      )!.timeSavedMessage(courseNameWithoutParentheses(course.name));
      seconds = await state.stopStopwatch(courseId);
    } else {
      await state.resetPomodoro(courseId);
      snackMessage =
          'Pomodoro for "${courseNameWithoutParentheses(course.name)}" reset.';
    }

    if (kind != 'pomodoro' && seconds > 0) {
      // Global listener handles reflection now
    }

    if (messenger.mounted) {
      showAppMessage(navigator.context, snackMessage);
    }
  }

  String _pomodoroPhaseLabel(PomodoroPhase phase) {
    final l10n = AppLocalizations.of(context)!;
    switch (phase) {
      case PomodoroPhase.work:
        return l10n.work;
      case PomodoroPhase.shortBreak:
        return l10n.shortBreak;
      case PomodoroPhase.longBreak:
        return l10n.longBreak;
    }
  }
}
