import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import 'pomodoro_controls.dart';

class PomodoroTab extends StatefulWidget {
  const PomodoroTab({super.key, required this.course});

  final Course course;

  @override
  State<PomodoroTab> createState() => _PomodoroTabState();
}

class _PomodoroTabState extends State<PomodoroTab> {
  double? _pendingLongBreak;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final phase = state.pomodoroPhase[widget.course.id] ?? PomodoroPhase.work;
    final remaining = state
        .currentPomodoroRemaining(widget.course.id)
        .inSeconds;
    final elapsed = state.currentPomodoroElapsed(widget.course.id).inSeconds;
    final total = state.pomodoroPhaseDurationFor(widget.course.id).inSeconds;
    final completed = state.pomodoroCompletedWorkFor(widget.course.id);
    final isPaused = state.pomodoroPaused[widget.course.id] ?? false;
    final sliderValue =
        _pendingLongBreak ??
        state.pomodoroLongBreakMinutesFor(widget.course.id).toDouble();
    final minLong = AppState.pomodoroLongBreakMinMinutes.toDouble();
    final maxLong = AppState.pomodoroLongBreakMaxMinutes.toDouble();

    final hasStarted =
        (state.pomodoroRunning[widget.course.id] ?? false) ||
        (state.pomodoroPaused[widget.course.id] ?? false) ||
        elapsed > 0;
    final sliderEnabled = !hasStarted;
    final phaseLabel = hasStarted
        ? pomodoroPhaseLabel(AppLocalizations.of(context)!, phase)
        : AppLocalizations.of(context)!.start;

    return _scrollable([
      const Spacer(),
      ..._status(
        context,
        phaseLabel: phaseLabel,
        isPaused: isPaused,
        remaining: remaining,
        elapsed: elapsed,
        total: total,
        completed: completed,
      ),
      const SizedBox(height: 32),
      const Spacer(),
      ..._longBreak(
        context,
        value: sliderValue,
        min: minLong,
        max: maxLong,
        enabled: sliderEnabled,
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _scrollable(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(children: children),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _status(
    BuildContext context, {
    required String phaseLabel,
    required bool isPaused,
    required int remaining,
    required int elapsed,
    required int total,
    required int completed,
  }) {
    return [
      Chip(
        visualDensity: VisualDensity.compact,
        label: Text(
          '$phaseLabel${isPaused ? ' (${AppLocalizations.of(context)!.paused})' : ''}',
        ),
      ),
      const SizedBox(height: 24),
      Text(
        formatHms(remaining),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      Text(
        '${formatHms(elapsed)} / ${formatHms(total)} ${AppLocalizations.of(context)!.elapsed}',
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
      const SizedBox(height: 20),
      Text(
        AppLocalizations.of(context)!.completedPomodoros(completed),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    ];
  }

  List<Widget> _longBreak(
    BuildContext context, {
    required double value,
    required double min,
    required double max,
    required bool enabled,
  }) {
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          AppLocalizations.of(context)!.longBreakLength(value.round()),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      const SizedBox(height: 8),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: (max - min).round(),
        label:
            '${value.round()} ${AppLocalizations.of(context)!.minutes_plural}',
        onChanged: enabled
            ? (value) => setState(() => _pendingLongBreak = value)
            : null,
        onChangeEnd: enabled
            ? (value) async {
                final appState = context.read<AppState>();
                await appState.setPomodoroLongBreakMinutes(
                  widget.course.id,
                  value.round(),
                );
                if (!mounted) return;
                setState(() => _pendingLongBreak = null);
              }
            : null,
      ),
    ];
  }
}
