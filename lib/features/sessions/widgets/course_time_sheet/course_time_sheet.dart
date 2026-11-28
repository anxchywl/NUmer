import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';
import 'package:numer_app/shared/widgets/sheet_focus.dart';
import 'package:numer_ui/numer_ui.dart';

import '../../data/last_course_store.dart';
import '../../models/active_session_info.dart';
import '../../models/session_limits.dart';
import 'course_time_footer.dart';
import 'course_time_header.dart';
import 'course_time_tab_bar.dart';
import 'pomodoro_tab.dart';
import 'stopwatch_tab.dart';
import 'timer_tab.dart';

part 'course_time_actions.dart';

Future<void> showCourseTimeSheet(BuildContext context, Course course) {
  final appState = context.read<AppState>();
  appState.setCourseSheetOpen(true);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final isIos = Theme.of(context).platform == TargetPlatform.iOS;
      return FractionallySizedBox(
        heightFactor: isIos ? 0.85 : 0.8,
        child: _CourseTimeMenu(course: course),
      );
    },
  ).whenComplete(() => appState.setCourseSheetOpen(false));
}

class _CourseTimeMenu extends StatefulWidget {
  final Course course;
  const _CourseTimeMenu({required this.course});

  @override
  State<_CourseTimeMenu> createState() => _CourseTimeMenuState();
}

abstract class _CourseTimeMenuBase extends State<_CourseTimeMenu>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _hCtrl = TextEditingController();
  final _mCtrl = TextEditingController();
  final _sCtrl = TextEditingController();

  final _focus = NumerSheetFocusMode();

  Timer? _ticker;

  int _lastSettledTab = 0;
  bool _restoringTab = false;

  String get _plannedKey => 'timer_planned_${widget.course.id}';
  Future<void> _savePlannedSecs(int secs) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_plannedKey, secs);
  }

  Future<int?> _loadPlannedSecs() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_plannedKey);
  }

  Future<void> _clearPlannedSecs() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_plannedKey);
  }
}

class _CourseTimeMenuState extends _CourseTimeMenuBase with _CourseTimeActions {
  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    int initialIndex = 0;
    if (state.pomodoroRunning[widget.course.id] == true ||
        state.pomodoroPaused[widget.course.id] == true) {
      initialIndex = 2;
    } else if (state.stopwatchRunning[widget.course.id] == true) {
      initialIndex = 1;
    } else if (state.timerRunning[widget.course.id] == true) {
      initialIndex = 0;
    }

    _tabs = TabController(length: 3, vsync: this, initialIndex: initialIndex)
      ..addListener(_handleTabChange);
    _lastSettledTab = initialIndex;

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    _focus.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted || _restoringTab) {
      setState(() {});
      return;
    }
    if (!_tabs.indexIsChanging) {
      final newIndex = _tabs.index;
      if (_shouldConfirmPomodoroSwitch(newIndex)) {
        _restoringTab = true;
        Future.microtask(() async {
          final ok = await _confirmLeavePomodoro();
          if (!mounted) return;
          if (ok) {
            final state = context.read<AppState>();
            await state.resetPomodoroAndSave(widget.course.id);
            await state.waitForPendingReflections();
            if (!mounted) return;
            _lastSettledTab = newIndex;
          } else {
            _tabs.animateTo(2);
            _lastSettledTab = 2;
          }
          _restoringTab = false;
          if (mounted) setState(() {});
        });
        return;
      }
      _lastSettledTab = newIndex;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final live = state.courses.firstWhere(
      (c) => c.id == widget.course.id,
      orElse: () => widget.course,
    );

    final isTimerRunningForThis = state.timerRunning[widget.course.id] ?? false;
    final isStopwatchRunningForThis =
        state.stopwatchRunning[widget.course.id] ?? false;
    final isPomodoroActiveForThis =
        (state.pomodoroRunning[widget.course.id] ?? false) ||
        (state.pomodoroPaused[widget.course.id] ?? false);

    final isAnyRunningCombined =
        isTimerRunningForThis ||
        isStopwatchRunningForThis ||
        isPomodoroActiveForThis;

    final shouldGuardPop = isPomodoroActiveForThis;

    return PopScope(
      canPop: !shouldGuardPop,
      onPopInvokedWithResult: _handlePopInvoked,
      child: SheetFocusBuilder(
        focus: _focus,
        builder: (context) => _sheet(
          context,
          live: live,
          isTimerRunning: isTimerRunningForThis,
          isStopwatchRunning: isStopwatchRunningForThis,
          isPomodoroActive: isPomodoroActiveForThis,
          isAnyRunning: isAnyRunningCombined,
        ),
      ),
    );
  }

  Future<void> _handlePopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    final allow = await _handleWillPop();
    if (allow && mounted) {
      navigator.pop(result);
    }
  }

  Widget _sheet(
    BuildContext context, {
    required Course live,
    required bool isTimerRunning,
    required bool isStopwatchRunning,
    required bool isPomodoroActive,
    required bool isAnyRunning,
  }) {
    final chrome = _focus.hidesChrome;
    final keyboard = chrome ? MediaQuery.viewInsetsOf(context).bottom : 0.0;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Column(
            children: [
              NumerFocusFold(
                hidden: chrome,
                child: _chrome(live, isAnyRunning),
              ),
              Expanded(child: _tabViews()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SheetDoneActions(
                  focus: _focus,
                  actions: _footer(
                    isTimerRunning: isTimerRunning,
                    isStopwatchRunning: isStopwatchRunning,
                    isPomodoroActive: isPomodoroActive,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chrome(Course live, bool isAnyRunning) {
    return Column(
      children: [
        _header(live, isAnyRunning),
        const SizedBox(height: 8),
        CourseTimeTabBar(controller: _tabs),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _header(Course live, bool isAnyRunning) {
    return CourseTimeHeader(
      course: live,
      isAnyRunning: isAnyRunning,
      onToggleHidden: () => _toggleHidden(live),
      onEdit: _editCourse,
      onDelete: _deleteCourse,
    );
  }

  Widget _tabViews() {
    return TabBarView(
      controller: _tabs,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _timerTab(),
        StopwatchTab(course: widget.course),
        PomodoroTab(course: widget.course),
      ],
    );
  }

  Widget _timerTab() {
    return TimerTab(
      course: widget.course,
      hCtrl: _hCtrl,
      mCtrl: _mCtrl,
      sCtrl: _sCtrl,
      hNode: _focus.nodeFor('hours'),
      mNode: _focus.nodeFor('minutes'),
      sNode: _focus.nodeFor('seconds'),
      typing: _focus.hidesChrome,
      loadPlanned: _loadPlannedSecs,
      readInputs: _readInputsCapped,
      onChanged: () => setState(() {}),
    );
  }

  Widget _footer({
    required bool isTimerRunning,
    required bool isStopwatchRunning,
    required bool isPomodoroActive,
  }) {
    return CourseTimeFooter(
      course: widget.course,
      tabIndex: _tabs.index,
      isTimerRunning: isTimerRunning,
      isStopwatchRunning: isStopwatchRunning,
      isPomodoroActive: isPomodoroActive,
      onStartTimer: _startTimer,
      onDoneTimer: _doneTimer,
      onStartStopwatch: _startStopwatch,
      onDoneStopwatch: _doneStopwatch,
      onStartPomodoro: _startPomodoro,
      onResumePomodoro: _resumePomodoro,
      onPausePomodoro: _pausePomodoro,
      onResetPomodoro: _resetPomodoroCycle,
      onSkipBreak: _skipPomodoroBreak,
    );
  }
}
