import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/app_toast.dart';

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs;

  final _hCtrl = TextEditingController();
  final _mCtrl = TextEditingController();
  final _sCtrl = TextEditingController();

  final _hNode = FocusNode();
  final _mNode = FocusNode();
  final _sNode = FocusNode();

  Timer? _ticker;

  bool _kbOpen = false;

  late final AnimationController _kbCtrl;
  late final Animation<Offset> _inputSlide;
  late final Animation<double> _fadeAway;
  late final Animation<Offset> _timerSlide;

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

    _kbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _inputSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.20),
    ).animate(CurvedAnimation(parent: _kbCtrl, curve: Curves.easeOutCubic));
    _fadeAway = CurvedAnimation(
      parent: _kbCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _timerSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.20),
    ).animate(CurvedAnimation(parent: _kbCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addObserver(this);

    _hNode.addListener(_handleFocusChange);
    _mNode.addListener(_handleFocusChange);
    _sNode.addListener(_handleFocusChange);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _kbCtrl.dispose();
    _hCtrl.dispose();
    _mCtrl.dispose();
    _sCtrl.dispose();
    _hNode.removeListener(_handleFocusChange);
    _mNode.removeListener(_handleFocusChange);
    _sNode.removeListener(_handleFocusChange);
    _hNode.dispose();
    _mNode.dispose();
    _sNode.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    _updateCondensedMode();
  }

  void _updateCondensedMode() {
    final bool timerFocused =
        _hNode.hasFocus || _mNode.hasFocus || _sNode.hasFocus;
    final bool shouldBeCondensed = _kbOpen && timerFocused;

    if (shouldBeCondensed) {
      _kbCtrl.forward();
      // Only force-switch to Timer tab if not already there
      if (_tabs.index != 0) {
        _tabs.animateTo(0);
      }
    } else {
      _kbCtrl.reverse();
    }
    setState(() {});
  }

  @override
  void didChangeMetrics() {
    if (ModalRoute.of(context)?.isCurrent != true) return;

    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isNotEmpty ? views.first : null;
    final bottomPx = view?.viewInsets.bottom ?? 0.0;
    final dpr =
        view?.devicePixelRatio ??
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final bottom = bottomPx / dpr;

    final nowOpen = bottom > 0;
    if (nowOpen == _kbOpen) return;
    _kbOpen = nowOpen;
    _updateCondensedMode();
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

    final timerFocused = _hNode.hasFocus || _mNode.hasFocus || _sNode.hasFocus;
    final bool isCondensed = _kbOpen && timerFocused;

    final shouldGuardPop = isPomodoroActiveForThis;

    return PopScope(
      canPop: !shouldGuardPop,
      onPopInvokedWithResult: _handlePopInvoked,
      child: _sheet(
        live: live,
        isCondensed: isCondensed,
        isTimerRunning: isTimerRunningForThis,
        isStopwatchRunning: isStopwatchRunningForThis,
        isPomodoroActive: isPomodoroActiveForThis,
        isAnyRunning: isAnyRunningCombined,
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

  Widget _sheet({
    required Course live,
    required bool isCondensed,
    required bool isTimerRunning,
    required bool isStopwatchRunning,
    required bool isPomodoroActive,
    required bool isAnyRunning,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            _header(live, isAnyRunning),
            const SizedBox(height: 8),
            CourseTimeTabBar(controller: _tabs, isCondensed: isCondensed),
            const SizedBox(height: 8),
            Expanded(child: _tabViews(isCondensed)),
            _footer(
              isTimerRunning: isTimerRunning,
              isStopwatchRunning: isStopwatchRunning,
              isPomodoroActive: isPomodoroActive,
            ),
          ],
        ),
      ),
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

  Widget _tabViews(bool isCondensed) {
    return IgnorePointer(
      // Keep timer inputs interactive while keyboard is open so
      // users can switch H/M/S focus directly.
      ignoring: _kbOpen && _tabs.index != 0,
      child: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _timerTab(isCondensed),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isCondensed
                ? const SizedBox.shrink()
                : StopwatchTab(course: widget.course),
          ),
          PomodoroTab(course: widget.course),
        ],
      ),
    );
  }

  Widget _timerTab(bool isCondensed) {
    return TimerTab(
      course: widget.course,
      hCtrl: _hCtrl,
      mCtrl: _mCtrl,
      sCtrl: _sCtrl,
      hNode: _hNode,
      mNode: _mNode,
      sNode: _sNode,
      inputSlide: _kbOpen
          ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
          : _inputSlide,
      fadeAway: _fadeAway,
      timerSlide: _timerSlide,
      isCondensed: isCondensed,
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
      fadeAway: _fadeAway,
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
