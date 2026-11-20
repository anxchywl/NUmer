import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

import '../models/session_limits.dart';

class AutoFinishWatcher extends StatefulWidget {
  const AutoFinishWatcher({super.key});

  @override
  State<AutoFinishWatcher> createState() => _AutoFinishWatcherState();
}

class _AutoFinishWatcherState extends State<AutoFinishWatcher> {
  Timer? _ticker;
  String? _activeId;
  int? _plannedSecs;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (!mounted) return;
    final state = context.read<AppState>();

    final active = _runningSession(state);

    if (active == null) {
      _activeId = null;
      _plannedSecs = null;
      return;
    }
    final (:kind, :id) = active;

    if (_activeId != id) {
      _activeId = id;
      _plannedSecs = null;
      if (kind == 'timer') {
        final p = await SharedPreferences.getInstance();
        _plannedSecs = p.getInt('timer_planned_$id');
      }
    }

    final courseName = _courseName(state, id);

    if (kind == 'timer') {
      await _finishTimer(state, id, courseName);
    } else if (kind == 'stopwatch') {
      await _finishStopwatch(state, id, courseName);
    } else if (kind == 'pomodoro') {}

    if (mounted) setState(() {});
  }

  ({String kind, String id})? _runningSession(AppState state) {
    final timerEntry = state.timerRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );
    final swEntry = state.stopwatchRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );
    final pomoEntry = state.pomodoroRunning.entries.firstWhere(
      (e) => e.value == true,
      orElse: () => const MapEntry<String, bool>('', false),
    );

    String? kind;
    String? id;
    if (timerEntry.value == true) {
      kind = 'timer';
      id = timerEntry.key;
    } else if (swEntry.value == true) {
      kind = 'stopwatch';
      id = swEntry.key;
    } else if (pomoEntry.value == true) {
      kind = 'pomodoro';
      id = pomoEntry.key;
    }

    if (kind == null || id == null) return null;
    return (kind: kind, id: id);
  }

  String _courseName(AppState state, String id) {
    return state.courses
        .firstWhere(
          (c) => c.id == id,
          orElse: () => Course(
            id: id,
            name: 'Course',
            day: '',
            start: '',
            end: '',
            colorValue: 0xFF94A3B8,
          ),
        )
        .name;
  }

  Future<void> _finishTimer(
    AppState state,
    String id,
    String courseName,
  ) async {
    final elapsed = state.currentElapsedTimer(id).inSeconds;
    if (_plannedSecs != null && _plannedSecs! > 0 && elapsed >= _plannedSecs!) {
      final start = state.timerStart[id];
      DateTime? forcedEnd;
      if (start != null) {
        forcedEnd = start.add(Duration(seconds: _plannedSecs!));
      }

      await state.stopTimer(id, forcedEnd: forcedEnd);
      final p = await SharedPreferences.getInstance();
      await p.remove('timer_planned_$id');

      if (!mounted) return;
      showAppMessage(
        context,
        AppLocalizations.of(
          context,
        )!.timeSavedMessage(courseNameWithoutParentheses(courseName)),
      );
      _activeId = null;
      _plannedSecs = null;
    }
  }

  Future<void> _finishStopwatch(
    AppState state,
    String id,
    String courseName,
  ) async {
    final e = state.currentElapsedStopwatch(id).inSeconds;
    if (e >= kMaxSessionSeconds) {
      await state.stopStopwatch(id);

      if (!mounted) return;
      showAppMessage(
        context,
        AppLocalizations.of(
          context,
        )!.timeSavedMessage(courseNameWithoutParentheses(courseName)),
      );
      _activeId = null;
      _plannedSecs = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
