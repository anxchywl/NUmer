import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/core/identity/id_token_provider.dart';
import 'package:numer_app/core/identity/module_session.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/habits/habits.dart';

Course course(String id, String name, {double? credits}) => Course(
  id: id,
  name: name,
  day: 'Mon',
  start: '09:00',
  end: '10:00',
  colorValue: 0xFF3B82F6,
  credits: credits,
);

Habit habit(String id, {double done = 0, double target = 1}) {
  final now = DateTime.now();
  return Habit(
    id: id,
    name: id,
    color: Colors.indigo,
    iconCodePoint: 0,
    category: 'Health',
    type: HabitType.numeric,
    targetValue: target,
    comparator: HabitComparator.atLeast,
    frequencyType: HabitFrequencyType.daily,
    startDate: DateTime(2020),
    createdAt: DateTime(2020),
    last7: {dayKey(now): done},
  );
}

String dayKey(DateTime d) =>
    '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';

class FakeState extends ChangeNotifier implements AppState {
  FakeState({this.courses = const [], this.goals = ProgressView.off});

  @override
  List<Course> courses;
  ProgressView goals;
  int studiedSeconds = 0;
  bool startAccepted = true;

  @override
  Map<String, bool> timerRunning = {};
  @override
  Map<String, bool> stopwatchRunning = {};
  @override
  Map<String, bool> pomodoroRunning = {};
  @override
  Map<String, bool> pomodoroPaused = {};
  @override
  Map<String, PomodoroPhase> pomodoroPhase = {};

  @override
  bool get hasAnyActiveSession => [
    timerRunning,
    stopwatchRunning,
    pomodoroRunning,
  ].any((running) => running.containsValue(true));

  @override
  ProgressView get progressView => goals;
  @override
  WeekStart get weekStart => WeekStart.monday;
  @override
  double? goalHoursForCourse(String id) => null;
  @override
  int todayTotalSeconds() => studiedSeconds;

  @override
  String? get profileName => null;
  @override
  int? get profileAvatarIndex => null;
  @override
  int? get profileAvatarColorValue => null;
  @override
  bool get requiresProfileSetup => true;
  @override
  int get streakCount => 0;
  @override
  bool get hasStudyToday => false;

  bool _sheetOpen = false;
  @override
  bool get courseSheetOpen => _sheetOpen;
  @override
  void setCourseSheetOpen(bool open) => _sheetOpen = open;

  @override
  bool startTimer(String id) => startAccepted;
  @override
  bool startStopwatch(String id) => startAccepted;
  @override
  bool startPomodoro(String id) => startAccepted;

  @override
  Duration currentElapsedTimer(String id) => Duration.zero;
  @override
  Duration currentElapsedStopwatch(String id) => Duration.zero;
  @override
  Duration currentPomodoroElapsed(String id) => Duration.zero;
  @override
  Duration currentPomodoroRemaining(String id) => const Duration(minutes: 25);
  @override
  Duration pomodoroPhaseDurationFor(String id) => const Duration(minutes: 25);
  @override
  int pomodoroCompletedWorkFor(String id) => 0;
  @override
  int pomodoroLongBreakMinutesFor(String id) => 15;
  @override
  bool pomodoroIsOnBreak(String id) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSync extends ChangeNotifier implements SyncService {
  FakeSync({this.status = SyncStatus.upToDate, this.lastError});

  @override
  SyncStatus status;
  @override
  String? lastError;
  int syncCalls = 0;
  final listeners = <Future<void> Function()>[];

  @override
  Future<void> syncNow({
    bool full = false,
    bool startup = false,
    bool force = false,
  }) async {
    syncCalls++;
  }

  @override
  void addAfterPullListener(Future<void> Function() listener) =>
      listeners.add(listener);
  @override
  void removeAfterPullListener(Future<void> Function() listener) =>
      listeners.remove(listener);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHabits implements HabitService {
  final controllers = <StreamController<List<Habit>>>[];

  void emit(List<Habit> habits) => controllers.last.add(habits);

  @override
  Stream<List<Habit>> habitsStream(String userId) {
    controllers.add(StreamController<List<Habit>>());
    return controllers.last.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth extends ChangeNotifier implements AuthController {
  @override
  User? get currentUser => _FakeUser();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CountingSession implements ModuleSession {
  int tokenReads = 0;

  @override
  IdTokenProvider get idToken {
    tokenReads++;
    return ({bool forceRefresh = false}) async => 'token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
