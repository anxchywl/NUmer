part of 'course_time_sheet.dart';

mixin _CourseTimeActions on _CourseTimeMenuBase {
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    showAppMessage(context, msg, isError: isError);
  }

  bool _shouldConfirmPomodoroSwitch(int newIndex) {
    if (_lastSettledTab != 2 || newIndex == 2) return false;
    final state = context.read<AppState>();
    final running = state.pomodoroRunning[widget.course.id] ?? false;
    final paused = state.pomodoroPaused[widget.course.id] ?? false;
    return running || paused;
  }

  Future<bool> _confirmLeavePomodoro() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.leavePomodoroTitle),
        content: Text(AppLocalizations.of(context)!.leavePomodoroMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.stay),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)!.resetAndLeave),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<bool> _handleWillPop() async {
    final state = context.read<AppState>();
    final running = state.pomodoroRunning[widget.course.id] ?? false;
    final paused = state.pomodoroPaused[widget.course.id] ?? false;
    if (!running && !paused) return true;
    final ok = await _confirmLeavePomodoro();
    if (ok) {
      await state.resetPomodoroAndSave(widget.course.id);
      await state.waitForPendingReflections();
    }
    return ok;
  }

  Future<void> _startTimer() async {
    final state = context.read<AppState>();

    if (hasAnyActiveSessionIn(state)) {
      final info = activeSessionInfo(state);
      final otherId = info?.id;
      final kind = info?.kind ?? 'session';
      if (otherId != null) {
        state.courses.firstWhere(
          (c) => c.id == otherId,
          orElse: () => Course(
            id: otherId,
            name: 'Course',
            day: '',
            start: '',
            end: '',
            colorValue: 0,
          ),
        );
      }
      final l10n = AppLocalizations.of(context)!;
      final kindLabel = switch (kind) {
        'timer' => l10n.timer,
        'stopwatch' => l10n.stopwatch,
        'pomodoro' => l10n.pomodoro,
        _ => l10n.session,
      };
      _snack(l10n.anotherSessionRunningSilly(kindLabel), isError: true);
      Navigator.pop(context);
      return;
    }

    final h = int.tryParse(_hCtrl.text) ?? 0;
    final m = int.tryParse(_mCtrl.text) ?? 0;
    final s = int.tryParse(_sCtrl.text) ?? 0;

    int total = h * 3600 + m * 60 + s;
    if (total <= 0) {
      // Close the input/pop-up (if any) then show an error message
      if (Navigator.canPop(context)) Navigator.pop(context);
      _snack(AppLocalizations.of(context)!.enterTimeFirst, isError: true);
      return;
    }
    if (total > kMaxSessionSeconds) {
      total = kMaxSessionSeconds;
      _snack(AppLocalizations.of(context)!.maxTimeCapped, isError: true);
    }

    final lastCourse = context.read<LastCourseStore>();
    await _savePlannedSecs(total);
    if (state.startTimer(widget.course.id)) {
      unawaited(lastCourse.save(widget.course.id));
    }
    setState(() {});
  }

  Future<void> _doneTimer() async {
    final state = context.read<AppState>();

    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    final planned = await _loadPlannedSecs();
    final seconds = await state.stopTimer(widget.course.id);
    if (planned != null) {
      await _clearPlannedSecs();
    }

    if (!navigator.mounted) return;
    if (seconds <= 0 || !state.courseSheetOpen) {
      navigator.pop();
    }

    showAppMessage(
      navigator.context,
      l10n.timeSavedMessage(courseNameWithoutParentheses(widget.course.name)),
    );
  }

  Future<void> _startStopwatch() async {
    final state = context.read<AppState>();

    if (hasAnyActiveSessionIn(state)) {
      final info = activeSessionInfo(state);
      final otherId = info?.id;
      final kind = info?.kind ?? 'session';
      if (otherId != null) {
        state.courses.firstWhere(
          (c) => c.id == otherId,
          orElse: () => Course(
            id: otherId,
            name: 'Course',
            day: '',
            start: '',
            end: '',
            colorValue: 0,
          ),
        );
      }
      final l10n = AppLocalizations.of(context)!;
      final kindLabel = switch (kind) {
        'timer' => l10n.timer,
        'stopwatch' => l10n.stopwatch,
        'pomodoro' => l10n.pomodoro,
        _ => l10n.session,
      };
      _snack(l10n.anotherSessionRunningSilly(kindLabel), isError: true);
      Navigator.pop(context);
      return;
    }

    if (state.startStopwatch(widget.course.id)) {
      unawaited(context.read<LastCourseStore>().save(widget.course.id));
    }
    setState(() {});
  }

  Future<void> _doneStopwatch() async {
    final state = context.read<AppState>();

    if (!(state.stopwatchRunning[widget.course.id] ?? false) &&
        state.currentElapsedStopwatch(widget.course.id).inSeconds == 0) {
      _snack(AppLocalizations.of(context)!.nothingToSave, isError: true);
      return;
    }

    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;

    final seconds = await state.stopStopwatch(widget.course.id);

    if (!navigator.mounted) return;
    if (seconds <= 0 || !state.courseSheetOpen) {
      navigator.pop();
    }

    showAppMessage(
      navigator.context,
      l10n.timeSavedMessage(courseNameWithoutParentheses(widget.course.name)),
    );
  }

  Future<void> _startPomodoro() async {
    final state = context.read<AppState>();
    final begun = state.startPomodoro(widget.course.id);
    if (!begun) {
      final l10n = AppLocalizations.of(context)!;
      final info = activeSessionInfo(state);
      final kind = info?.kind ?? 'session';
      final kindLabel = switch (kind) {
        'timer' => l10n.timer,
        'stopwatch' => l10n.stopwatch,
        'pomodoro' => l10n.pomodoro,
        _ => l10n.session,
      };
      _snack(l10n.anotherSessionRunningSilly(kindLabel), isError: true);
      Navigator.pop(context);
      return;
    }
    unawaited(context.read<LastCourseStore>().save(widget.course.id));
    setState(() {});
  }

  Future<void> _pausePomodoro() async {
    final state = context.read<AppState>();
    await state.pausePomodoro(widget.course.id);
    if (mounted) setState(() {});
  }

  Future<void> _resumePomodoro() async {
    final state = context.read<AppState>();
    await state.resumePomodoro(widget.course.id);
    if (mounted) setState(() {});
  }

  Future<void> _skipPomodoroBreak() async {
    final state = context.read<AppState>();
    await state.skipPomodoroBreak(widget.course.id);
    if (mounted) setState(() {});
  }

  Future<void> _resetPomodoroCycle() async {
    final state = context.read<AppState>();

    await state.resetPomodoroAndSave(widget.course.id);
    if (mounted) setState(() {});
  }

  Future<void> _editCourse() async {
    await showEditCourseDialog(context, widget.course);
    if (mounted) setState(() {});
  }

  Future<void> _toggleHidden(Course live) async {
    final appState = context.read<AppState>();
    final updated = live.copyWith(
      hiddenFromLeaderboard: !live.hiddenFromLeaderboard,
    );
    await appState.updateCourse(updated);
    setState(() {}); // Toggle icon state immediately

    if (!mounted || !context.mounted) return;

    // Brief delay so the user sees the icon change before the popup closes
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted || !context.mounted) return;

    Navigator.pop(context);

    final msg = updated.hiddenFromLeaderboard
        ? AppLocalizations.of(context)!.courseHiddenFromLeaderboard
        : AppLocalizations.of(context)!.courseVisibleInLeaderboard;
    showAppMessage(context, msg);
  }

  Future<void> _deleteCourse() async {
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);

    final l10n = AppLocalizations.of(context)!;
    final ok = await showNumerConfirm(
      context,
      title: l10n.deleteCourseTitle,
      body: l10n.deleteCourseMessage,
      confirmLabel: l10n.delete,
      destructive: true,
    );

    if (ok) {
      await appState.removeCourse(widget.course.id);

      navigator.pop();
    }
  }

  int _readInputsCapped() {
    final h = int.tryParse(_hCtrl.text) ?? 0;
    final m = int.tryParse(_mCtrl.text) ?? 0;
    final s = int.tryParse(_sCtrl.text) ?? 0;
    int total = h * 3600 + m * 60 + s;
    if (total > kMaxSessionSeconds) total = kMaxSessionSeconds;
    if (total < 0) total = 0;
    return total;
  }

  Future<void> _tick() async {
    if (!mounted) return;
    final state = context.read<AppState>();

    final planned = await _loadPlannedSecs();
    final isThisTimerRunning = (state.timerRunning[widget.course.id] ?? false);
    if (planned != null && isThisTimerRunning) {
      final elapsed = state.currentElapsedTimer(widget.course.id).inSeconds;
      final remaining = planned - elapsed;
      if (remaining <= 0) {
        await state.stopTimer(widget.course.id);
        await _clearPlannedSecs();
        if (!mounted) return;
        showAppMessage(
          context,
          AppLocalizations.of(
            context,
          )!.timeSavedMessage(courseNameWithoutParentheses(widget.course.name)),
        );
      }
    }

    if (state.stopwatchRunning[widget.course.id] ?? false) {
      final e = state.currentElapsedStopwatch(widget.course.id).inSeconds;
      if (e >= kMaxSessionSeconds) {
        await state.stopStopwatch(widget.course.id);
        if (!mounted) return;
        showAppMessage(
          context,
          AppLocalizations.of(
            context,
          )!.timeSavedMessage(courseNameWithoutParentheses(widget.course.name)),
        );
      }
    }

    setState(() {});
  }
}
