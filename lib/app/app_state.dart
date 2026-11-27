import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:numer_app/features/sessions/models/alarm_item.dart';
import 'package:numer_app/features/courses/course.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/core/notifications/notifications.dart';
import 'package:numer_app/core/notifications/stored_alarms.dart';
import 'package:numer_app/core/notifications/recording_notification_service.dart';
import 'package:numer_app/core/data/sync_service.dart';
import 'package:numer_app/features/habits/data/habit_service.dart';
import 'package:numer_app/core/startup_metrics.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:numer_app/l10n/app_localizations.dart';

// which day the week starts on for calendars and stats
enum WeekStart { monday, sunday }

// time window shown in the home summary card
enum HomeSummaryRange { off, today, week, month, year, allTime }

// how study progress is displayed on the home screen
enum ProgressView { day, week, off }

// current phase of a running pomodoro session
enum PomodoroPhase { work, shortBreak, longBreak }

// thrown when a new study session would overlap an existing one
class SessionOverlapException implements Exception {
  final String message;
  SessionOverlapException(this.message);
  @override
  String toString() => message;
}

String activeSessionSignature({
  required bool isStudying,
  String? courseId,
  String? kind,
  int? startMs,
  int? expectedEndMs,
}) =>
    '$isStudying|${courseId ?? '-'}|${kind ?? '-'}|${startMs ?? '-'}|${expectedEndMs ?? '-'}';

// central app state, holds profile, courses, sessions, timers and settings and
// notifies the ui on change, backed by hive and synced through syncservice
class AppState extends ChangeNotifier {
  AppState({@visibleForTesting this.loadOverride});

  final Future<void> Function({required bool force})? loadOverride;

  static ThemeMode? _initialThemeMode;
  static void setInitialThemeMode(ThemeMode mode) {
    _initialThemeMode = mode;
  }

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;
  Future<void>? _loadFuture;
  bool _reloadRequested = false;
  Future<void>? _backgroundHydration;
  SyncService? _syncService;
  (String, String)? _sentSessionSignature;
  int _sessionSendCount = 0;
  HabitService? _habitService; // injected
  bool _hydrated = false;
  bool get isHydrated => _hydrated;
  bool _profilePromptCompleted = false;
  bool get profilePromptCompleted => _profilePromptCompleted;
  bool get shouldShowProfilePrompt =>
      requiresProfileSetup && !_profilePromptCompleted;
  bool _courseSheetOpen = false;
  bool get courseSheetOpen => _courseSheetOpen;

  void setCourseSheetOpen(bool value) {
    if (_courseSheetOpen == value) return;
    _courseSheetOpen = value;
    notifyListeners();
  }

  String? major;
  String? profileName;
  String? profileGoal;
  String? profileContact;
  int? profileAvatarIndex;
  int? profileAvatarColorValue;
  bool profileComplete = false;
  bool onboardingCompleted = false;
  int? bootstrapVersion;
  bool get hasCompletedOnboarding => onboardingCompleted || profileComplete;
  Uint8List? profileAvatarImage;
  List<Course> courses = [];
  Map<String, int> courseMinutes = {};
  int _streakCount = 0;
  int get streakCount => _streakCount;
  bool _hasStudyToday = false;
  bool get hasStudyToday => _hasStudyToday;

  bool get requiresProfileSetup {
    if (hasCompletedOnboarding) return false;
    return profileName == null || profileName!.trim().isEmpty;
  }

  Map<String, int> _todayByCourseSeconds = {};
  String _todayKey = _dateKey(DateTime.now());
  Timer? _midnightTimer;

  Map<String, bool> timerRunning = {};
  Map<String, bool> stopwatchRunning = {};
  Map<String, DateTime?> timerStart = {};
  Map<String, DateTime?> stopwatchStart = {};
  Map<String, Duration> timerElapsed = {};
  Map<String, Duration> stopwatchElapsed = {};

  static const int kMaxSecs = 10800;
  static const Duration pomodoroWorkDuration = Duration(minutes: 25);
  static const Duration pomodoroShortBreakDuration = Duration(minutes: 5);
  static const int pomodoroLongBreakMinMinutes = 15;
  static const int pomodoroLongBreakMaxMinutes = 30;
  static const int _defaultPomodoroLongBreakMinutes = 15;
  static const int _pomodoroLongBreakEvery = 4;

  Map<String, bool> pomodoroRunning = {};
  Map<String, bool> pomodoroPaused = {};
  Map<String, PomodoroPhase> pomodoroPhase = {};
  Map<String, DateTime?> pomodoroPhaseStart = {};
  Map<String, Duration> pomodoroPhaseElapsed = {};
  // backwards-compatible alias for older references named pomodoroStart
  Map<String, DateTime?> get pomodoroStart => pomodoroPhaseStart;
  Map<String, int> pomodoroCompletedWork = {};
  final Map<String, int> _pomodoroLongBreakMinutes = {};
  Timer? _pomodoroTicker;

  bool get hasAnyActiveSession =>
      timerRunning.values.any((v) => v == true) ||
      stopwatchRunning.values.any((v) => v == true) ||
      pomodoroRunning.values.any((v) => v == true);

  String? get activeSessionKind {
    if (pomodoroRunning.values.any((v) => v == true)) return 'pomodoro';
    if (timerRunning.values.any((v) => v == true)) return 'timer';
    if (stopwatchRunning.values.any((v) => v == true)) return 'stopwatch';
    return null;
  }

  String? get activeSessionCourseId {
    for (final e in timerRunning.entries) {
      if (e.value == true) return e.key;
    }
    for (final e in pomodoroRunning.entries) {
      if (e.value == true) return e.key;
    }
    for (final e in stopwatchRunning.entries) {
      if (e.value == true) return e.key;
    }
    return null;
  }

  Locale? _locale;
  Locale? get locale => _locale;

  WeekStart _weekStart = WeekStart.monday;
  WeekStart get weekStart => _weekStart;
  ProgressView _progressView = ProgressView.week;
  ProgressView get progressView => _progressView;

  Color _accentColor = const Color(0xFF448AFF);
  Color get accentColor => _accentColor;

  List<({String name, int colorValue})> _userColorPresets = [];
  List<({String name, int colorValue})> get userColorPresets =>
      List.unmodifiable(_userColorPresets);

  Future<void> loadUserColorPresets() async {
    final list = Storage.getUserColorPresets();
    _userColorPresets = list
        .map(
          (m) =>
              (name: m['name'] as String, colorValue: m['colorValue'] as int),
        )
        .toList();
    notifyListeners();
  }

  Future<void> addUserColorPreset(String name, Color color) async {
    if (_userColorPresets.length >= 22) return;
    _userColorPresets.add((name: name, colorValue: color.toARGB32()));
    notifyListeners();
    await _saveUserColorPresets();
  }

  Future<void> removeUserColorPreset(int index) async {
    if (index < 0 || index >= _userColorPresets.length) return;
    _userColorPresets.removeAt(index);
    notifyListeners();
    await _saveUserColorPresets();
  }

  Future<void> _saveUserColorPresets() async {
    final list = _userColorPresets
        .map((p) => {'name': p.name, 'colorValue': p.colorValue})
        .toList();
    await Storage.saveUserColorPresets(list);
  }

  Future<void> loadAccentColor() async {
    final val = await Storage.getAccentColor();
    if (val != null) {
      _accentColor = Color(val);
      notifyListeners();
    }
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    await Storage.setAccentColor(color.toARGB32());
  }

  bool _quickNotesEnabled = true;
  bool get quickNotesEnabled => _quickNotesEnabled;
  bool _allowNudges = true;
  bool get allowNudges => _allowNudges;
  bool _eisenhowerMatrixEnabled = false;
  bool get eisenhowerMatrixEnabled => _eisenhowerMatrixEnabled;
  bool _sessionNotificationsEnabled = true;
  bool get sessionNotificationsEnabled => _sessionNotificationsEnabled;
  Map<String, double> _courseGoalHours = {};
  double? goalHoursForCourse(String id) => _courseGoalHours[id];

  final List<({String sessionId, int duration})> _pendingReflections = [];
  List<({String sessionId, int duration})> get pendingReflections =>
      List.unmodifiable(_pendingReflections);

  void popPendingReflection() {
    if (_pendingReflections.isNotEmpty) {
      _pendingReflections.removeAt(0);
      notifyListeners();
    }
  }

  void _queueReflection(String sessionId, int seconds) {
    if (!_quickNotesEnabled || seconds <= 0) return;
    // avoid queuing the same reflection multiple times
    final exists = _pendingReflections.any((e) => e.sessionId == sessionId);
    if (exists) return;
    _pendingReflections.add((sessionId: sessionId, duration: seconds));
  }

  // stops and persists every running timer, stopwatch and pomodoro, used on sign-out and shutdown
  Future<void> stopAndSaveAllActiveSessions() async {
    final timerIds = timerRunning.keys
        .where((id) => timerRunning[id] == true)
        .toList();
    for (final id in timerIds) {
      await stopTimer(id);
    }

    final stopwatchIds = stopwatchRunning.keys
        .where((id) => stopwatchRunning[id] == true)
        .toList();
    for (final id in stopwatchIds) {
      await stopStopwatch(id);
    }

    final pomodoroIds = pomodoroRunning.keys
        .where(
          (id) => pomodoroRunning[id] == true || pomodoroPaused[id] == true,
        )
        .toList();
    for (final id in pomodoroIds) {
      await resetPomodoroAndSave(id);
    }
  }

  Future<void> waitForPendingReflections() async {
    while (_pendingReflections.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> loadLocale() async {
    final v = await Storage.getLocale();
    if (v != null) {
      _locale = Locale(v);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale? l) async {
    _locale = l;
    notifyListeners();
    await Storage.setLocale(l?.languageCode);
  }

  Future<void> loadWeekStart() async {
    final v = await Storage.getWeekStart();
    _weekStart = (v == 'sunday') ? WeekStart.sunday : WeekStart.monday;
    notifyListeners();
  }

  Future<void> setWeekStart(WeekStart ws) async {
    _weekStart = ws;
    notifyListeners();
    await Storage.setWeekStart(ws == WeekStart.sunday ? 'sunday' : 'monday');
  }

  void bindSyncService(SyncService service) {
    if (_syncService == service) return;
    _syncService?.removeAfterPullListener(_handleRemoteRefresh);
    _syncService = service;
    _syncService?.addAfterPullListener(_handleRemoteRefresh);
    _syncService?.onBeforeStop = () async {
      await stopAndSaveAllActiveSessions();
      await _syncService?.syncNow();
    };
    if (_syncService == null) {
      _hydrated = true;
    }
  }

  void bindHabitService(HabitService service) {
    if (_habitService == service) return;
    _habitService = service;
  }

  // reloads all state when the sync layer signals fresh remote data
  Future<void> _handleRemoteRefresh() async {
    try {
      await load(force: true);
      if (!_hydrated) {
        _hydrated = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  // loads all persisted state once, reusing the in-flight future for concurrent calls
  Future<void> load({bool force = false}) {
    final running = _loadFuture;
    if (running != null) {
      // the running load may have read storage before the caller changed it
      _reloadRequested |= force;
      return running;
    }
    if (_isLoaded && !force) {
      return Future.value();
    }
    return _loadFuture = _loadUntilCurrent(
      force: force,
    ).whenComplete(() => _loadFuture = null);
  }

  Future<void> _loadUntilCurrent({required bool force}) async {
    final performLoad = loadOverride ?? _performLoad;
    var forceNext = force;
    do {
      _reloadRequested = false;
      await performLoad(force: forceNext);
      forceNext = true;
    } while (_reloadRequested);
  }

  // asks the sync service to push and pull now, no-op if sync is not wired
  Future<void> triggerSync({bool full = false}) async {
    final sync = _syncService;
    if (sync == null) return;
    await sync.syncNow(full: full);
  }

  void _triggerSync() {
    unawaited(_syncService?.pushNow());
  }

  // does the real load work, reads storage, hydrates the shell then finishes in the background
  Future<void> _performLoad({required bool force}) async {
    if (force || !_isLoaded) {
      _resetFields();
    }

    // parallelise independent storage reads used for shell hydration
    final results = await Future.wait([
      Storage.getMajor(), // 0
      Storage.getProfileName(), // 1
      Storage.getProfileGoal(), // 2
      Storage.getProfileContact(), // 3
      Storage.getProfileAvatarIndex(), // 4
      Storage.getProfileAvatarColor(), // 5
      Storage.getProfileAvatarImageBytes(), // 6
      Storage.getProfilePromptShown(), // 7
      Storage.getCourses(), // 8
      Storage.getAlarms(), // 9
      Storage.getCourseMinutes(), // 10
      Storage.getCourseGoalHours(), // 11
      loadLocale(), // 12
      loadWeekStart(), // 13
      loadHomeSummaryRange(), // 14
      loadProgressView(), // 15
      loadQuickNotesEnabled(), // 16
      loadAllowNudges(), // 17
      loadEisenhowerMatrixEnabled(), // 18
      loadSessionNotificationsEnabled(), // 19
      Storage.getPomodoroLongBreakMinutes(), // 20
      Storage.getOnboardingCompleted(), // 21
      Storage.getBootstrapVersionFlag(), // 22
      Storage.getAccentColor(), // 23
      loadUserColorPresets(), // 24
      loadThemeMode(), // 25
    ]);

    major = results[0] as String?;
    profileName = results[1] as String?;
    profileGoal = results[2] as String?;
    profileContact = results[3] as String?;
    profileAvatarIndex = results[4] as int?;
    profileAvatarColorValue = results[5] as int?;
    profileAvatarImage = results[6] as Uint8List?;
    _profilePromptCompleted = results[7] as bool;
    courses = results[8] as List<Course>;
    await cancelStoredAlarms(
      (results[9] as List<AlarmItem>).map((a) => a.id),
      cancel: Notifs.cancel,
      clear: () => Storage.saveAlarms(const []),
    );
    courseMinutes = results[10] as Map<String, int>;
    _courseGoalHours = results[11] as Map<String, double>;
    onboardingCompleted = (results[21] as bool?) ?? false;
    bootstrapVersion = results[22] as int?;

    final accentVal = results[23] as int?;
    if (accentVal != null) {
      _accentColor = Color(accentVal);
    }

    profileComplete = Storage.getProfileComplete();

    _courseGoalHours.removeWhere(
      (id, _) => courses.every((Course c) => c.id != id),
    );

    final storedLongBreaks = results[20] as Map<String, int>;

    for (final c in courses) {
      courseMinutes.putIfAbsent(c.id, () => 0);
      timerRunning.putIfAbsent(c.id, () => false);
      stopwatchRunning.putIfAbsent(c.id, () => false);
      timerElapsed.putIfAbsent(c.id, () => Duration.zero);
      stopwatchElapsed.putIfAbsent(c.id, () => Duration.zero);
      pomodoroRunning.putIfAbsent(c.id, () => false);
      pomodoroPaused.putIfAbsent(c.id, () => false);
      pomodoroPhase.putIfAbsent(c.id, () => PomodoroPhase.work);
      pomodoroPhaseStart.putIfAbsent(c.id, () => null);
      pomodoroPhaseElapsed.putIfAbsent(c.id, () => Duration.zero);
      pomodoroCompletedWork.putIfAbsent(c.id, () => 0);
      _pomodoroLongBreakMinutes[c.id] = _clampLongBreakMinutes(
        storedLongBreaks[c.id] ??
            _pomodoroLongBreakMinutes[c.id] ??
            _defaultPomodoroLongBreakMinutes,
      );
    }

    await Storage.saveCourseMinutes(courseMinutes);
    await _hydrateDailyStateFromCache();
    _ensureTodayKeyUpToDate();
    _scheduleMidnightReset();
    _hydrateStreakFromCache();

    final session = await Storage.getActiveSession();
    if (session != null) {
      try {
        final timers =
            (session['timers'] as Map?)?.cast<String, dynamic>() ?? {};
        final stops =
            (session['stopwatches'] as Map?)?.cast<String, dynamic>() ?? {};
        final pomos =
            (session['pomodoros'] as Map?)?.cast<String, dynamic>() ?? {};

        for (final id in timers.keys) {
          final m = timers[id] as Map;
          timerRunning[id] = (m['running'] ?? false) as bool;
          timerElapsed[id] = Duration(seconds: (m['elapsed'] ?? 0) as int);
          if (m['start'] != null) {
            timerStart[id] = DateTime.tryParse(m['start'] as String);
            if (timerRunning[id] == true && timerStart[id] != null) {
              if (timerElapsed[id]!.inSeconds > kMaxSecs) {
                timerElapsed[id] = const Duration(seconds: kMaxSecs);
              }
            }
          }
        }

        for (final id in stops.keys) {
          final m = stops[id] as Map;
          stopwatchRunning[id] = (m['running'] ?? false) as bool;
          stopwatchElapsed[id] = Duration(seconds: (m['elapsed'] ?? 0) as int);
          if (m['start'] != null) {
            stopwatchStart[id] = DateTime.tryParse(m['start'] as String);
            if (stopwatchRunning[id] == true && stopwatchStart[id] != null) {
              if (stopwatchElapsed[id]!.inSeconds > kMaxSecs) {
                stopwatchElapsed[id] = const Duration(seconds: kMaxSecs);
              }
            }
          }
        }

        for (final id in pomos.keys) {
          final m = pomos[id] as Map;
          pomodoroRunning[id] = (m['running'] ?? false) as bool;
          pomodoroPaused[id] = (m['paused'] ?? false) as bool;
          final phaseStr = m['phase'] as String?;
          if (phaseStr != null) {
            pomodoroPhase[id] = PomodoroPhase.values.firstWhere(
              (p) => p.name == phaseStr,
              orElse: () => PomodoroPhase.work,
            );
          }
          final startStr = m['phaseStart'] as String?;
          pomodoroPhaseStart[id] = startStr != null
              ? DateTime.tryParse(startStr)
              : null;
          pomodoroPhaseElapsed[id] = Duration(
            seconds: (m['phaseElapsed'] ?? 0) as int,
          );
          pomodoroCompletedWork[id] = (m['completedWork'] ?? 0) as int;
        }

        _sanitizeSingleActiveSession();
        await _saveActiveSession();
      } catch (_) {}
    }

    _hydrated = true;
    _isLoaded = true;
    StartupMetrics.markLocalHydrateDone('app_state');
    notifyListeners();

    _backgroundHydration ??= _finishBackgroundHydration();
    try {
      await _backgroundHydration;
    } finally {
      _backgroundHydration = null;
    }
  }

  Future<void> _hydrateDailyStateFromCache() async {
    final cached = await Storage.getDailyState();
    final todayKey = _dateKey(DateTime.now());
    _todayKey = todayKey;
    if (cached != null && cached['dateKey'] == todayKey) {
      final map = cached['map'] as Map<String, int>?;
      if (map != null) {
        _todayByCourseSeconds = Map<String, int>.from(map);
      }
    }
    for (final c in courses) {
      _todayByCourseSeconds.putIfAbsent(c.id, () => 0);
    }
  }

  void _hydrateStreakFromCache() {
    final snapshot = Storage.getStreakSnapshot();
    if (snapshot == null) return;
    _streakCount = (snapshot['count'] as int?) ?? 0;
    _hasStudyToday = snapshot['hasToday'] == true;
  }

  Future<void> _finishBackgroundHydration() async {
    try {
      await Storage.migrateDailyStateToSessionsIfNeeded();
    } catch (_) {}
    try {
      await _recomputeTodayFromSessions();
      await enforceActiveSessionBounds(duringLoad: true);
      await _catchUpPomodoros();
      if (pomodoroRunning.values.any((v) => v == true)) {
        _ensurePomodoroTicker();
      }
      _updateStreak();
      await _syncRecordingNotificationForCurrentSession();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _recomputeTodayFromSessions() async {
    try {
      _todayKey = _dateKey(DateTime.now());
      final calculated = await secondsByCourseForDay(DateTime.now());
      _todayByCourseSeconds = Map<String, int>.from(calculated);
      for (final c in courses) {
        _todayByCourseSeconds.putIfAbsent(c.id, () => 0);
      }
      await _saveDailyState();
    } catch (_) {}
  }

  Future<void> loadProgressView() async {
    final s = await Storage.getProgressView();
    _progressView = (s == 'week')
        ? ProgressView.week
        : (s == 'off' ? ProgressView.off : ProgressView.day);
    notifyListeners();
  }

  Future<void> setProgressView(ProgressView v) async {
    _progressView = v;
    notifyListeners();
    await Storage.setProgressView(
      v == ProgressView.week ? 'week' : (v == ProgressView.off ? 'off' : 'day'),
    );
  }

  Future<void> loadQuickNotesEnabled() async {
    _quickNotesEnabled = await Storage.getQuickNotesEnabled();
    notifyListeners();
  }

  Future<void> setQuickNotesEnabled(bool value) async {
    _quickNotesEnabled = value;
    notifyListeners();
    await Storage.setQuickNotesEnabled(value);
  }

  Future<void> loadAllowNudges() async {
    _allowNudges = await Storage.getAllowNudges();
    notifyListeners();
  }

  Future<void> setAllowNudges(bool value) async {
    _allowNudges = value;
    notifyListeners();
    await Storage.setAllowNudges(value);
    final sync = _syncService;
    if (sync != null) {
      // push immediately so group visibility updates without delay
      await sync.pushNow();
    } else {
      _triggerSync();
    }
  }

  Future<void> loadEisenhowerMatrixEnabled() async {
    _eisenhowerMatrixEnabled = await Storage.getEisenhowerMatrixEnabled();
    notifyListeners();
  }

  Future<void> setEisenhowerMatrixEnabled(bool value) async {
    _eisenhowerMatrixEnabled = value;
    notifyListeners();
    await Storage.setEisenhowerMatrixEnabled(value);
  }

  Future<void> loadSessionNotificationsEnabled() async {
    _sessionNotificationsEnabled =
        await Storage.getSessionNotificationsEnabled();
    notifyListeners();
  }

  Future<void> setSessionNotificationsEnabled(bool enabled) async {
    _sessionNotificationsEnabled = enabled;
    notifyListeners();
    await Storage.setSessionNotificationsEnabled(enabled);
    await _syncRecordingNotificationForCurrentSession();
  }

  Future<void> _syncRecordingNotificationForCurrentSession() async {
    if (!_sessionNotificationsEnabled) {
      RecordingNotifService.instance.cancel();
      return;
    }

    for (final entry in timerRunning.entries) {
      if (entry.value == true) {
        await _showTimerRecordingNotification(entry.key);
        return;
      }
    }

    for (final entry in stopwatchRunning.entries) {
      if (entry.value == true) {
        _showStopwatchRecordingNotification(entry.key);
        return;
      }
    }

    for (final entry in pomodoroRunning.entries) {
      if (entry.value == true || pomodoroPaused[entry.key] == true) {
        _showPomodoroRecordingNotification(entry.key);
        return;
      }
    }

    RecordingNotifService.instance.cancel();
  }

  Future<void> _showTimerRecordingNotification(String id) async {
    if (!_sessionNotificationsEnabled || timerRunning[id] != true) {
      return;
    }

    final start = timerStart[id];
    DateTime? expectedEnd;
    var countsDown = false;

    if (start != null) {
      final prefs = await SharedPreferences.getInstance();
      final plannedSecsRaw = prefs.getInt('timer_planned_$id');
      final plannedSecs = plannedSecsRaw != null && plannedSecsRaw > 0
          ? plannedSecsRaw.clamp(1, kMaxSecs)
          : null;
      final maxEnd = start.add(const Duration(seconds: kMaxSecs));
      if (plannedSecs != null) {
        final plannedEnd = start.add(Duration(seconds: plannedSecs));
        expectedEnd = plannedEnd.isBefore(maxEnd) ? plannedEnd : maxEnd;
        countsDown = true;
      } else {
        expectedEnd = maxEnd;
      }
    }

    RecordingNotifService.instance.showTimer(
      courseId: id,
      courseName: _courseName(id),
      elapsedReader: () => currentElapsedTimer(id),
      startedAt: start,
      expectedEndAt: expectedEnd,
      countsDown: countsDown,
    );
  }

  void _showStopwatchRecordingNotification(String id) {
    if (!_sessionNotificationsEnabled || stopwatchRunning[id] != true) {
      return;
    }

    final start = stopwatchStart[id];
    RecordingNotifService.instance.showStopwatch(
      courseId: id,
      courseName: _courseName(id),
      elapsedReader: () => currentElapsedStopwatch(id),
      startedAt: start,
      expectedEndAt: start?.add(const Duration(seconds: kMaxSecs)),
    );
  }

  void _showPomodoroRecordingNotification(String id) {
    final running = pomodoroRunning[id] == true || pomodoroPaused[id] == true;
    if (!_sessionNotificationsEnabled || !running) {
      return;
    }

    final paused = pomodoroPaused[id] == true;
    final now = DateTime.now();
    final phaseEndsAt = paused ? null : now.add(currentPomodoroRemaining(id));
    RecordingNotifService.instance.showPomodoro(
      courseId: id,
      courseName: _courseName(id),
      pomodoroReader: () {
        final phase = pomodoroPhase[id] ?? PomodoroPhase.work;
        final remaining = currentPomodoroRemaining(id);
        final phaseLabel = switch (phase) {
          PomodoroPhase.work => 'Focus',
          PomodoroPhase.shortBreak => 'Short Break',
          PomodoroPhase.longBreak => 'Long Break',
        };
        return (phase: phaseLabel, remaining: remaining);
      },
      phaseEndsAt: phaseEndsAt,
      paused: paused,
    );
  }

  Future<void> setCourseGoalHours(
    String id,
    double? hours, {
    bool notify = true,
  }) async {
    if (hours == null || hours <= 0) {
      _courseGoalHours.remove(id);
    } else {
      _courseGoalHours[id] = hours;
    }
    await Storage.setCourseGoalHours(id, hours);
    _triggerSync();
    if (notify) notifyListeners();
  }

  void _sanitizeSingleActiveSession() {
    String? keptCourse;
    String? keptKind;

    for (final e in timerRunning.entries) {
      if (e.value == true) {
        keptCourse ??= e.key;
        keptKind ??= 'timer';
        if (e.key != keptCourse) timerRunning[e.key] = false;
      }
    }

    for (final e in stopwatchRunning.entries) {
      if (keptKind == 'timer') {
        if (e.value == true) stopwatchRunning[e.key] = false;
      } else {
        if (e.value == true) {
          if (keptCourse == null) {
            keptCourse = e.key;
            keptKind = 'stopwatch';
          } else if (e.key != keptCourse) {
            stopwatchRunning[e.key] = false;
          }
        }
      }
    }

    for (final e in pomodoroRunning.entries) {
      if (e.value == true) {
        if (keptKind == null) {
          keptCourse = e.key;
          keptKind = 'pomodoro';
        } else if (keptKind != 'pomodoro' || e.key != keptCourse) {
          _clearPomodoroState(e.key);
        }
      }
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _ensureTodayKeyUpToDate() {
    final nowKey = _dateKey(DateTime.now());
    if (_todayKey != nowKey) {
      _todayKey = nowKey;
      _todayByCourseSeconds.clear();
      for (final c in courses) {
        _todayByCourseSeconds.putIfAbsent(c.id, () => 0);
      }
      _saveDailyState();
      notifyListeners();
    }
  }

  Future<void> _saveDailyState() async =>
      Storage.saveDailyState(_todayKey, _todayByCourseSeconds);

  DateTime _todayStartDateTime() {
    final parts = _todayKey.split('-');
    if (parts.length != 3) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final day = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(year, month, day);
  }

  int _secondsOverlapToday(DateTime start, DateTime end) {
    final dayStart = _todayStartDateTime();
    final dayEnd = dayStart.add(const Duration(days: 1));
    final from = start.isAfter(dayStart) ? start : dayStart;
    final to = end.isBefore(dayEnd) ? end : dayEnd;
    final secs = to.difference(from).inSeconds;
    return secs > 0 ? secs : 0;
  }

  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () {
      _ensureTodayKeyUpToDate();
      _scheduleMidnightReset();
    });
  }

  int todaySecondsFor(String courseId) => _todayByCourseSeconds[courseId] ?? 0;

  int todayTotalSeconds() =>
      _todayByCourseSeconds.values.fold(0, (a, b) => a + b);

  // records study time for a course today, updates the streak and feeds linked habits
  Future<void> addStudySeconds(String courseId, int seconds) async {
    if (seconds <= 0) return;
    _todayByCourseSeconds[courseId] =
        (_todayByCourseSeconds[courseId] ?? 0) + seconds;
    await _saveDailyState();
    _updateStreak();
    notifyListeners();
    await _saveDailyState();
    _updateStreak();
    notifyListeners();
    unawaited(_maybeCelebrateProgress(courseId));

    // sync to habits
    if (_habitService != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(
          _habitService!.updateHabitProgressFromCourse(
            userId: user.uid,
            courseId: courseId,
            date: DateTime.now(),
            deltaSeconds: seconds,
          ),
        );
      }
    }
  }

  bool get hasProfile => profileName != null && profileName!.trim().isNotEmpty;

  // saves the user profile locally and, when a uid is given, pushes it to the remote doc
  Future<void> saveProfile({
    required String name,
    String? goal,
    String? majorText,
    String? contact,
    int? avatarIndex,
    int? avatarColorValue,
    String? uid, // optional uid for a direct remote update
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) return;

    profileName = normalizedName;
    major = _cleanOptional(majorText);
    profileGoal = _cleanOptional(goal);
    profileContact = _cleanOptional(contact);

    profileAvatarIndex = avatarIndex;
    profileAvatarImage = null; // enforce no custom image

    profileAvatarColorValue = avatarColorValue;
    profileComplete = true;
    onboardingCompleted = true;

    await Future.wait([
      Storage.setProfileName(profileName),
      Storage.setProfileGoal(profileGoal),
      Storage.setProfileContact(profileContact),
      Storage.setProfileAvatarIndex(profileAvatarIndex),
      Storage.setProfileAvatarColor(profileAvatarColorValue),
      Storage.setProfileAvatarImageBytes(profileAvatarImage),
      Storage.setMajor(major),
      Storage.setProfileComplete(profileComplete),
      Storage.setOnboardingCompleted(onboardingCompleted),
    ]);
    await Storage.setProfilePromptShown(true);
    _profilePromptCompleted = true;

    // direct cloud update when a uid is provided, avoids waiting for periodic sync
    if (uid != null) {
      final cloudData = {
        'displayName': profileName,
        'profileName': profileName,
        'major': major,
        'profileGoal': profileGoal,
        'profileContact': profileContact,
        'profileComplete': true,
        'avatarColorValue': avatarColorValue,
        'profileAvatarColorValue': avatarColorValue,
        'onboardingCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (profileAvatarImage != null) {
        final b64 = base64Encode(profileAvatarImage!);
        cloudData['avatarImageBase64'] = b64;
        cloudData['profileAvatarImageBase64'] = b64;
        cloudData['avatarIndex'] = FieldValue.delete();
        cloudData['profileAvatarIndex'] = FieldValue.delete();
      } else if (profileAvatarIndex != null) {
        cloudData['avatarIndex'] = profileAvatarIndex;
        cloudData['profileAvatarIndex'] = profileAvatarIndex;
        cloudData['avatarImageBase64'] = FieldValue.delete();
        cloudData['profileAvatarImageBase64'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(cloudData, SetOptions(merge: true));
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != profileName) {
      await user.updateDisplayName(profileName);
    }

    _triggerSync();
    notifyListeners();
  }

  Future<void> setMajor(String? m) async {
    major = _cleanOptional(m);
    await Storage.setMajor(major);
    _triggerSync();
    notifyListeners();
  }

  Future<void> addCourse(Course c) async {
    final sortOrder = c.sortOrder ?? courses.length;
    courses = [...courses, c.copyWith(sortOrder: sortOrder)];
    await Storage.saveCourses(courses);

    courseMinutes.putIfAbsent(c.id, () => 0);
    timerRunning[c.id] = false;
    stopwatchRunning[c.id] = false;
    timerElapsed[c.id] = Duration.zero;
    stopwatchElapsed[c.id] = Duration.zero;
    pomodoroRunning[c.id] = false;
    pomodoroPaused[c.id] = false;
    pomodoroPhase[c.id] = PomodoroPhase.work;
    pomodoroPhaseStart[c.id] = null;
    pomodoroPhaseElapsed[c.id] = Duration.zero;
    pomodoroCompletedWork[c.id] = 0;
    _pomodoroLongBreakMinutes[c.id] = _clampLongBreakMinutes(
      _pomodoroLongBreakMinutes[c.id],
    );

    _todayByCourseSeconds.putIfAbsent(c.id, () => 0);
    await Storage.saveCourseMinutes(courseMinutes);
    await _saveDailyState();

    _updateStreak();
    _triggerSync();
    notifyListeners();
  }

  Future<void> reorderCourses(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= courses.length) return;
    if (newIndex < 0 || newIndex > courses.length) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final updated = List<Course>.from(courses);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    for (var i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(sortOrder: i);
    }
    courses = updated;
    await Storage.saveCourses(courses);
    _triggerSync();
    notifyListeners();
  }

  Future<void> removeCourse(String id) async {
    if (timerRunning[id] == true) {
      await stopTimer(id);
    }
    if (stopwatchRunning[id] == true) {
      await stopStopwatch(id);
    }
    if (pomodoroRunning[id] == true || pomodoroPaused[id] == true) {
      await resetPomodoro(id);
    }

    courses = courses.where((Course c) => c.id != id).toList();
    await Storage.deleteCourse(id);

    courseMinutes.remove(id);
    timerRunning.remove(id);
    stopwatchRunning.remove(id);
    timerStart.remove(id);
    stopwatchStart.remove(id);
    timerElapsed.remove(id);
    stopwatchElapsed.remove(id);
    pomodoroRunning.remove(id);
    pomodoroPaused.remove(id);
    pomodoroPhase.remove(id);
    pomodoroPhaseStart.remove(id);
    pomodoroPhaseElapsed.remove(id);
    pomodoroCompletedWork.remove(id);
    _pomodoroLongBreakMinutes.remove(id);
    await setCourseGoalHours(id, null, notify: false);

    _todayByCourseSeconds.remove(id);

    await Storage.saveCourseMinutes(courseMinutes);
    await _saveDailyState();

    await Storage.deleteSessionsForCourse(id);
    await Storage.removeCourseFromDailyState(id);
    await Storage.removeCourseFromActiveSession(id);
    await Storage.removeCourseFromCourseMinutes(id);
    await Storage.removePomodoroLongBreakMinutes(id);

    await _saveActiveSession();

    _updateStreak();
    _triggerSync();
    notifyListeners();
  }

  int minutesFor(String id) => courseMinutes[id] ?? 0;
  int totalMinutesAll() => courseMinutes.values.fold(0, (a, b) => a + b);

  Future<void> addMinutesToCourse(String id, int m) async {
    if (m <= 0) return;
    courseMinutes[id] = (courseMinutes[id] ?? 0) + m;
    await Storage.saveCourseMinutes(courseMinutes);
    notifyListeners();
  }

  void _updateStreak() {
    final sessions = LocalDatabase.instance.sessions().toList();
    if (sessions.isEmpty) {
      _streakCount = 0;
      _hasStudyToday = false;
      unawaited(Storage.saveStreakSnapshot(_streakCount, _hasStudyToday));
      return;
    }

    final dates = sessions
        .map((s) {
          final dt = DateTime.fromMillisecondsSinceEpoch(s.startUtcMs);
          return DateTime(dt.year, dt.month, dt.day);
        })
        .toSet()
        .toList();

    dates.sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    _hasStudyToday = dates.contains(today);

    int count = 0;
    DateTime currentCheck = _hasStudyToday ? today : yesterday;

    if (!dates.contains(currentCheck)) {
      _streakCount = 0;
      return;
    }

    while (dates.contains(currentCheck)) {
      count++;
      currentCheck = currentCheck.subtract(const Duration(days: 1));
    }

    _streakCount = count;
    unawaited(Storage.saveStreakSnapshot(_streakCount, _hasStudyToday));
  }

  Future<String?> _addSessionSplitAcrossMidnight({
    required String courseId,
    required DateTime startLocal,
    required DateTime endLocal,
    required String kind,
  }) async {
    if (!endLocal.isAfter(startLocal)) return null;

    final cut = DateTime(endLocal.year, endLocal.month, endLocal.day);

    final crossesMidnight = startLocal.isBefore(cut) && endLocal.isAfter(cut);

    if (crossesMidnight) {
      await Storage.addSession(
        courseId: courseId,
        startLocal: startLocal,
        endLocal: cut,
        kind: kind,
      );

      final res = await Storage.addSession(
        courseId: courseId,
        startLocal: cut,
        endLocal: endLocal,
        kind: kind,
      );
      _updateStreak();
      return res;
    } else {
      final res = await Storage.addSession(
        courseId: courseId,
        startLocal: startLocal,
        endLocal: endLocal,
        kind: kind,
      );
      _updateStreak();
      return res;
    }
  }

  bool startTimer(String id) {
    if (hasAnyActiveSession) return false;

    timerRunning[id] = true;
    timerStart[id] = DateTime.now();
    timerElapsed[id] ??= Duration.zero;
    unawaited(_scheduleTimerNotification(id));
    _saveActiveSession();
    notifyListeners();

    // live recording notification
    if (_sessionNotificationsEnabled) {
      unawaited(_showTimerRecordingNotification(id));
    }
    return true;
  }

  Future<int> stopTimer(
    String id, {
    DateTime? forcedEnd,
    bool suppressReflection = false,
  }) async {
    if (timerRunning[id] != true || timerStart[id] == null) return 0;

    final start = timerStart[id]!;
    var now = forcedEnd ?? DateTime.now();
    if (now.isBefore(start)) {
      now = start;
    }

    var totalSecs = now.difference(start).inSeconds;
    if (totalSecs < 0) totalSecs = 0;
    if (totalSecs > kMaxSecs) totalSecs = kMaxSecs;

    final cut = DateTime(now.year, now.month, now.day);
    int secsPrevDay = 0;
    int secsToday = 0;

    if (start.isBefore(cut) && now.isAfter(cut)) {
      final realPrev = cut.difference(start).inSeconds;
      final realToday = now.difference(cut).inSeconds;

      var sum = realPrev + realToday;
      if (sum <= 0) {
        secsPrevDay = 0;
        secsToday = 0;
      } else if (sum <= totalSecs) {
        secsPrevDay = realPrev;
        secsToday = realToday;
      } else {
        final diff = sum - totalSecs;
        final todayAdj = realToday - diff;
        secsToday = todayAdj < 0 ? 0 : todayAdj;
        secsPrevDay = totalSecs - secsToday;
        if (secsPrevDay < 0) secsPrevDay = 0;
      }
    } else {
      secsPrevDay = 0;
      secsToday = totalSecs;
    }

    timerRunning[id] = false;
    timerElapsed[id] = Duration.zero;
    timerStart[id] = null;

    RecordingNotifService.instance.cancel();
    notifyListeners();
    _triggerSync();

    final sessionId = await _addSessionSplitAcrossMidnight(
      courseId: id,
      startLocal: start,
      endLocal: now,
      kind: 'timer',
    );

    if (secsToday > 0) {
      await addStudySeconds(id, secsToday);
    }

    if (totalSecs > 0) {
      await addMinutesToCourse(id, totalSecs ~/ 60);
    }

    unawaited(_cancelTimerNotification(id));
    if (forcedEnd == null && totalSecs > 0 && !_isAppInForeground) {}

    if (sessionId != null && !suppressReflection) {
      _queueReflection(sessionId, totalSecs);
    }

    await _saveActiveSession();

    // sync time habits, mirrors the stopwatch logic
    if (_habitService != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(
          _habitService!.syncTimeHabitsForCourse(
            user.uid,
            id,
            start,
            knownDelta: totalSecs.toDouble(),
          ),
        );
        unawaited(
          _habitService!.updateHabitProgressFromCourse(
            userId: user.uid,
            courseId: id,
            date: start,
            deltaSeconds: totalSecs,
          ),
        );
      }
    }

    return totalSecs;
  }

  Duration currentElapsedTimer(String id) {
    if (timerRunning[id] == true && timerStart[id] != null) {
      return (timerElapsed[id] ?? Duration.zero) +
          DateTime.now().difference(timerStart[id]!);
    }
    return timerElapsed[id] ?? Duration.zero;
  }

  bool startStopwatch(String id) {
    if (hasAnyActiveSession) return false;

    stopwatchRunning[id] = true;
    stopwatchStart[id] = DateTime.now();
    stopwatchElapsed[id] ??= Duration.zero;
    unawaited(_scheduleStopwatchNotification(id));
    _saveActiveSession();
    notifyListeners();

    // live recording notification
    if (_sessionNotificationsEnabled) {
      _showStopwatchRecordingNotification(id);
    }
    return true;
  }

  Future<int> stopStopwatch(
    String id, {
    DateTime? forcedEnd,
    bool suppressReflection = false,
  }) async {
    if (stopwatchRunning[id] != true || stopwatchStart[id] == null) return 0;
    final start = stopwatchStart[id]!;
    var now = forcedEnd ?? DateTime.now();
    if (now.isBefore(start)) {
      now = start;
    }

    var totalSecs = now.difference(start).inSeconds;
    if (totalSecs < 0) totalSecs = 0;
    if (totalSecs > kMaxSecs) totalSecs = kMaxSecs;

    final cut = DateTime(now.year, now.month, now.day);
    int secsPrevDay = 0;
    int secsToday = 0;

    if (start.isBefore(cut) && now.isAfter(cut)) {
      final realPrev = cut.difference(start).inSeconds;
      final realToday = now.difference(cut).inSeconds;

      var sum = realPrev + realToday;
      if (sum <= 0) {
        secsPrevDay = 0;
        secsToday = 0;
      } else if (sum <= totalSecs) {
        secsPrevDay = realPrev;
        secsToday = realToday;
      } else {
        final diff = sum - totalSecs;
        final todayAdj = realToday - diff;
        secsToday = todayAdj < 0 ? 0 : todayAdj;
        secsPrevDay = totalSecs - secsToday;
        if (secsPrevDay < 0) secsPrevDay = 0;
      }
    } else {
      secsPrevDay = 0;
      secsToday = totalSecs;
    }

    stopwatchRunning[id] = false;
    stopwatchElapsed[id] = Duration.zero;
    stopwatchStart[id] = null;

    RecordingNotifService.instance.cancel();
    notifyListeners();
    _triggerSync();

    final sessionId = await _addSessionSplitAcrossMidnight(
      courseId: id,
      startLocal: start,
      endLocal: now,
      kind: 'stopwatch',
    );

    if (secsToday > 0) {
      await addStudySeconds(id, secsToday);
    }

    if (totalSecs > 0) {
      await addMinutesToCourse(id, totalSecs ~/ 60);
    }

    unawaited(_cancelStopwatchNotification(id));
    if (forcedEnd == null && totalSecs > 0 && !_isAppInForeground) {}

    if (sessionId != null && !suppressReflection) {
      _queueReflection(sessionId, totalSecs);
    }

    await _saveActiveSession();

    // sync time habits
    if (_habitService != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(
          _habitService!.syncTimeHabitsForCourse(
            user.uid,
            id,
            start,
            knownDelta: totalSecs.toDouble(),
          ),
        );
        // also push a yes/no habit completion update
        unawaited(
          _habitService!.updateHabitProgressFromCourse(
            userId: user.uid,
            courseId: id,
            date: start,
            deltaSeconds: totalSecs,
          ),
        );
      }
    }

    return totalSecs;
  }

  Future<void> enforceActiveSessionBounds({bool duringLoad = false}) async {
    final runningTimerIds = timerRunning.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();
    final runningStopwatchIds = stopwatchRunning.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();
    final runningPomodoroIds = pomodoroRunning.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList();

    if (runningTimerIds.isEmpty &&
        runningStopwatchIds.isEmpty &&
        runningPomodoroIds.isEmpty) {
      return;
    }

    SharedPreferences? prefs;
    if (runningTimerIds.isNotEmpty) {
      prefs = await SharedPreferences.getInstance();
    }
    final now = DateTime.now();

    for (final id in runningTimerIds) {
      final start = timerStart[id];
      if (start == null) {
        continue;
      }

      final plannedSecs = prefs?.getInt('timer_planned_$id');
      if (plannedSecs != null && plannedSecs > 0) {
        final plannedEnd = start.add(Duration(seconds: plannedSecs));
        if (!now.isBefore(plannedEnd)) {
          await stopTimer(
            id,
            forcedEnd: plannedEnd,
            suppressReflection: duringLoad,
          );
          await prefs?.remove('timer_planned_$id');
          continue;
        }
      }

      final hardCapEnd = start.add(const Duration(seconds: kMaxSecs));
      if (!now.isBefore(hardCapEnd)) {
        await stopTimer(
          id,
          forcedEnd: hardCapEnd,
          suppressReflection: duringLoad,
        );
      }
    }

    for (final id in runningStopwatchIds) {
      final start = stopwatchStart[id];
      if (start == null) {
        continue;
      }
      final hardCapEnd = start.add(const Duration(seconds: kMaxSecs));
      if (!now.isBefore(hardCapEnd)) {
        await stopStopwatch(
          id,
          forcedEnd: hardCapEnd,
          suppressReflection: duringLoad,
        );
      }
    }

    for (final id in runningPomodoroIds) {
      final elapsed = currentPomodoroElapsed(id);
      final duration = _pomodoroPhaseDuration(id);
      if (elapsed >= duration) {
        final start = pomodoroPhaseStart[id];
        DateTime? end;
        if (start != null) {
          end = start.add(duration);
        }
        await _advancePomodoroPhase(id, phaseEnd: end);
      }
    }
  }

  Duration currentElapsedStopwatch(String id) {
    if (stopwatchRunning[id] == true && stopwatchStart[id] != null) {
      final now = DateTime.now();
      final base = stopwatchElapsed[id] ?? Duration.zero;
      final sinceStart = now.isAfter(stopwatchStart[id]!)
          ? now.difference(stopwatchStart[id]!)
          : Duration.zero;
      return base + sinceStart;
    }
    return stopwatchElapsed[id] ?? Duration.zero;
  }

  Duration currentPomodoroElapsed(String id) =>
      _currentPomodoroElapsedInternal(id, now: DateTime.now());

  Duration currentPomodoroRemaining(String id) {
    final total = _pomodoroPhaseDuration(id);
    final elapsed = currentPomodoroElapsed(id);
    final remaining = total - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration pomodoroPhaseDurationFor(String id) => _pomodoroPhaseDuration(id);

  bool pomodoroIsOnBreak(String id) =>
      (pomodoroPhase[id] ?? PomodoroPhase.work) != PomodoroPhase.work;

  bool pomodoroIsPaused(String id) => pomodoroPaused[id] == true;

  int pomodoroCompletedWorkFor(String id) => pomodoroCompletedWork[id] ?? 0;

  int pomodoroLongBreakMinutesFor(String id) =>
      _clampLongBreakMinutes(_pomodoroLongBreakMinutes[id]);

  Future<void> setPomodoroLongBreakMinutes(String id, int minutes) async {
    final clamped = _clampLongBreakMinutes(minutes);
    if ((_pomodoroLongBreakMinutes[id] ?? _defaultPomodoroLongBreakMinutes) ==
        clamped) {
      return;
    }
    _pomodoroLongBreakMinutes[id] = clamped;
    await Storage.setPomodoroLongBreakMinutes(id, clamped);
    notifyListeners();
  }

  bool startPomodoro(String id) {
    if (hasAnyActiveSession) return false;
    _clearPomodoroState(id);
    pomodoroRunning[id] = true;
    pomodoroPhase[id] = PomodoroPhase.work;
    pomodoroPhaseElapsed[id] = Duration.zero;
    pomodoroPhaseStart[id] = DateTime.now();
    pomodoroPaused[id] = false;
    _ensurePomodoroTicker();
    _saveActiveSession();
    notifyListeners();

    // live recording notification
    if (_sessionNotificationsEnabled) {
      _showPomodoroRecordingNotification(id);
    }
    return true;
  }

  Future<void> pausePomodoro(String id) async {
    if (pomodoroRunning[id] != true || pomodoroPaused[id] == true) return;
    pomodoroPhaseElapsed[id] = _currentPomodoroElapsedInternal(id);
    pomodoroPhaseStart[id] = null;
    pomodoroPaused[id] = true;
    RecordingNotifService.instance.pause();
    notifyListeners();
    await _saveActiveSession();
    _triggerSync();
  }

  Future<void> resumePomodoro(String id) async {
    if (pomodoroRunning[id] != true || pomodoroPaused[id] != true) return;
    pomodoroPaused[id] = false;
    pomodoroPhaseStart[id] = DateTime.now();
    _ensurePomodoroTicker();
    RecordingNotifService.instance.resume();
    notifyListeners();
    await _saveActiveSession();
    _triggerSync();
  }

  Future<void> skipPomodoroBreak(String id) async {
    if (pomodoroRunning[id] != true) return;
    if ((pomodoroPhase[id] ?? PomodoroPhase.work) == PomodoroPhase.work) return;
    _beginPomodoroPhase(id, PomodoroPhase.work);
    await _saveActiveSession();
    _showPomodoroRecordingNotification(id);
    notifyListeners();
  }

  Future<void> skipPomodoroWork(String id) async {
    if (pomodoroRunning[id] != true && pomodoroPaused[id] != true) return;
    if ((pomodoroPhase[id] ?? PomodoroPhase.work) != PomodoroPhase.work) return;
    _beginPomodoroPhase(id, PomodoroPhase.shortBreak);
    await _saveActiveSession();
    _showPomodoroRecordingNotification(id);
    notifyListeners();
  }

  Future<void> resetPomodoro(String id) async {
    _clearPomodoroState(id);
    _stopPomodoroTickerIfIdle();
    RecordingNotifService.instance.cancel();
    notifyListeners();
    _triggerSync();
    await _saveActiveSession();
  }

  Future<bool> saveWorkAndQuitPomodoro(String id) async {
    final running = pomodoroRunning[id] == true || pomodoroPaused[id] == true;
    if (!running) return false;
    final phase = pomodoroPhase[id] ?? PomodoroPhase.work;
    bool saved = false;
    if (phase == PomodoroPhase.work) {
      final elapsed = _currentPomodoroElapsedInternal(id);
      if (elapsed.inSeconds > 0) {
        await _persistPomodoroWork(id, elapsed, DateTime.now());
        saved = true;
      }
    }
    _clearPomodoroState(id);
    _stopPomodoroTickerIfIdle();
    RecordingNotifService.instance.cancel();
    await _saveActiveSession();
    if (saved) {
      _triggerSync();
    }
    notifyListeners();
    return saved;
  }

  Future<void> resetPomodoroAndSave(String id) async {
    final phase = pomodoroPhase[id] ?? PomodoroPhase.work;
    var savedWork = false;
    if (phase == PomodoroPhase.work) {
      final elapsed = _currentPomodoroElapsedInternal(id);
      if (elapsed.inSeconds > 0) {
        await _persistPomodoroWork(id, elapsed, DateTime.now());
        savedWork = true;
      }
    }
    _clearPomodoroState(id);
    _stopPomodoroTickerIfIdle();
    RecordingNotifService.instance.cancel();
    await _saveActiveSession();
    if (savedWork) {
      _triggerSync();
    }
    notifyListeners();
  }

  Duration _pomodoroPhaseDuration(String id) {
    final phase = pomodoroPhase[id] ?? PomodoroPhase.work;
    switch (phase) {
      case PomodoroPhase.work:
        return pomodoroWorkDuration;
      case PomodoroPhase.shortBreak:
        return pomodoroShortBreakDuration;
      case PomodoroPhase.longBreak:
        return Duration(minutes: pomodoroLongBreakMinutesFor(id));
    }
  }

  Duration _currentPomodoroElapsedInternal(String id, {DateTime? now}) {
    final base = pomodoroPhaseElapsed[id] ?? Duration.zero;
    final running = pomodoroRunning[id] ?? false;
    final paused = pomodoroPaused[id] ?? false;
    final start = pomodoroPhaseStart[id];
    if (running && !paused && start != null) {
      final delta = (now ?? DateTime.now()).difference(start);
      if (delta.isNegative) return base;
      return base + delta;
    }
    return base;
  }

  Future<void> _advancePomodoroPhase(String id, {DateTime? phaseEnd}) async {
    if (pomodoroRunning[id] != true) return;
    final end = phaseEnd ?? DateTime.now();
    final phase = pomodoroPhase[id] ?? PomodoroPhase.work;
    final elapsed = _currentPomodoroElapsedInternal(id, now: end);
    var persisted = false;

    if (phase == PomodoroPhase.work) {
      if (elapsed.inSeconds > 0) {
        await _persistPomodoroWork(id, elapsed, end);
        persisted = true;
      }
      final completed = (pomodoroCompletedWork[id] ?? 0) + 1;
      final needsLongBreak = completed >= _pomodoroLongBreakEvery;
      pomodoroCompletedWork[id] = needsLongBreak ? 0 : completed;
      final nextPhase = needsLongBreak
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak;
      _beginPomodoroPhase(id, nextPhase, startAt: end);
    } else {
      _beginPomodoroPhase(id, PomodoroPhase.work, startAt: end);
    }

    await _saveActiveSession();
    if (persisted) {
      _triggerSync();
    }
    _showPomodoroRecordingNotification(id);
    notifyListeners();
  }

  void _beginPomodoroPhase(
    String id,
    PomodoroPhase phase, {
    DateTime? startAt,
  }) {
    pomodoroPhase[id] = phase;
    pomodoroPhaseElapsed[id] = Duration.zero;
    pomodoroPhaseStart[id] = startAt ?? DateTime.now();
    pomodoroPaused[id] = false;
    pomodoroRunning[id] = true;
    _ensurePomodoroTicker();
  }

  Future<void> _persistPomodoroWork(
    String id,
    Duration elapsed,
    DateTime end,
  ) async {
    var secs = elapsed.inSeconds;
    if (secs <= 0) return;
    if (secs > kMaxSecs) secs = kMaxSecs;
    final start = end.subtract(Duration(seconds: secs));
    final sessionId = await _addSessionSplitAcrossMidnight(
      courseId: id,
      startLocal: start,
      endLocal: end,
      kind: 'pomodoro',
    );
    await addStudySeconds(id, secs);
    await addMinutesToCourse(id, secs ~/ 60);
    if (sessionId != null) {
      _queueReflection(sessionId, secs);
    }

    // sync time habits
    if (_habitService != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        unawaited(
          _habitService!.syncTimeHabitsForCourse(
            user.uid,
            id,
            start,
            knownDelta: secs.toDouble(),
          ),
        );
        unawaited(
          _habitService!.updateHabitProgressFromCourse(
            userId: user.uid,
            courseId: id,
            date: start,
            deltaSeconds: secs,
          ),
        );
      }
    }
  }

  DateTime _pomodoroPhaseFinishAt(String id) {
    final start = pomodoroPhaseStart[id];
    if (start == null) return DateTime.now();
    final elapsed = pomodoroPhaseElapsed[id] ?? Duration.zero;
    final total = _pomodoroPhaseDuration(id);
    final remaining = total - elapsed;
    if (remaining.isNegative) return start;
    return start.add(remaining);
  }

  void _ensurePomodoroTicker() {
    if (_pomodoroTicker != null) return;
    _pomodoroTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_tickPomodoros()),
    );
  }

  void _stopPomodoroTickerIfIdle() {
    if (pomodoroRunning.values.any((v) => v == true)) return;
    _pomodoroTicker?.cancel();
    _pomodoroTicker = null;
  }

  Future<void> _tickPomodoros() async {
    final now = DateTime.now();
    final ids = pomodoroRunning.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toList(growable: false);
    if (ids.isEmpty) {
      _stopPomodoroTickerIfIdle();
      return;
    }

    for (final id in ids) {
      if (pomodoroPaused[id] == true) continue;
      final finishAt = _pomodoroPhaseFinishAt(id);
      if (!now.isBefore(finishAt)) {
        await _advancePomodoroPhase(id, phaseEnd: finishAt);
      }
    }

    if (!pomodoroRunning.values.any((v) => v == true)) {
      _stopPomodoroTickerIfIdle();
    }
  }

  Future<void> _catchUpPomodoros() async {
    final now = DateTime.now();
    for (final entry in pomodoroRunning.entries) {
      final id = entry.key;
      if (entry.value != true) continue;
      if (pomodoroPaused[id] == true) continue;
      var guard = 0;
      while (guard++ < 64) {
        final finishAt = _pomodoroPhaseFinishAt(id);
        if (now.isBefore(finishAt)) break;
        await _advancePomodoroPhase(id, phaseEnd: finishAt);
        if (pomodoroPaused[id] == true || pomodoroRunning[id] != true) break;
      }
    }
  }

  void _clearPomodoroState(String id) {
    pomodoroRunning[id] = false;
    pomodoroPaused[id] = false;
    pomodoroPhase[id] = PomodoroPhase.work;
    pomodoroPhaseStart[id] = null;
    pomodoroPhaseElapsed[id] = Duration.zero;
    pomodoroCompletedWork[id] = 0;
  }

  int _clampLongBreakMinutes(int? minutes) {
    final value = minutes ?? _defaultPomodoroLongBreakMinutes;
    final num clamped = value.clamp(
      pomodoroLongBreakMinMinutes,
      pomodoroLongBreakMaxMinutes,
    );
    return clamped.toInt();
  }

  Future<void> stopActiveSessionIfAny() async {
    final cid = activeSessionCourseId;
    final kind = activeSessionKind;
    if (cid == null || kind == null) return;
    if (kind == 'timer') {
      await stopTimer(cid);
    } else if (kind == 'stopwatch') {
      await stopStopwatch(cid);
    } else if (kind == 'pomodoro') {
      await resetPomodoro(cid);
    }
  }

  int _notificationId(String kind, String courseId) {
    final s = '${kind}_$courseId';
    int hash = 0;
    for (int i = 0; i < s.length; i++) {
      hash = (31 * hash + s.codeUnitAt(i)) & 0x7fffffff;
    }
    return hash;
  }

  String _courseName(String id) {
    return courses
        .firstWhere(
          (Course c) => c.id == id,
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

  String _courseNameForMessages(String id) {
    return _courseName(id)
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool get _isAppInForeground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  Future<void> _scheduleTimerNotification(String id) async {
    final start = timerStart[id];
    if (start == null) return;
    final prefs = await SharedPreferences.getInstance();
    final planned = prefs.getInt('timer_planned_$id');
    final secs = (planned != null && planned > 0) ? planned : kMaxSecs;
    if (secs <= 0) return;
    final fireAt = start.add(Duration(seconds: secs));
    if (!fireAt.isAfter(DateTime.now())) return;
    final name = _courseNameForMessages(id);
    await Notifs.scheduleOnce(
      id: _notificationId('timer', id),
      title: 'Timer finished',
      body: 'Time for $name is saved',
      whenLocal: fireAt,
    );
  }

  Future<void> _cancelTimerNotification(String id) async {
    await Notifs.cancel(_notificationId('timer', id));
  }

  Future<void> _scheduleStopwatchNotification(String id) async {
    final start = stopwatchStart[id];
    if (start == null) return;
    final fireAt = start.add(const Duration(seconds: kMaxSecs));
    if (!fireAt.isAfter(DateTime.now())) return;
    final name = _courseNameForMessages(id);
    await Notifs.scheduleOnce(
      id: _notificationId('stopwatch', id),
      title: 'Stopwatch auto-stopped',
      body: '"$name" reached the 3 hour limit.',
      whenLocal: fireAt,
    );
  }

  Future<void> _cancelStopwatchNotification(String id) async {
    await Notifs.cancel(_notificationId('stopwatch', id));
  }

  Future<void> _maybeCelebrateProgress(String courseId) async {
    final course = courses.firstWhere(
      (Course c) => c.id == courseId,
      orElse: () => Course(
        id: courseId,
        name: 'Course',
        day: '',
        start: '',
        end: '',
        colorValue: 0,
      ),
    );
    final customGoal = goalHoursForCourse(courseId);
    double? weeklyHours;
    if (customGoal != null && customGoal > 0) {
      weeklyHours = customGoal;
    } else {
      final credits = course.credits;
      if (credits == null || credits <= 0) return;
      final perCredit = _hoursPerCredit(course.expLevel ?? 3);
      weeklyHours = credits * perCredit;
    }
    final weeklyGoalSecs = (weeklyHours * 3600).clamp(1, 1 << 31).toInt();

    if (_progressView == ProgressView.day) {
      final dailyGoal = (weeklyGoalSecs / 7).round().clamp(1, 1 << 31);
      final elapsed = todaySecondsFor(courseId);
      if (elapsed < dailyGoal) return;
      final token = _dateKey(DateTime.now());
      if (!await _markProgressCelebrated('day', courseId, token)) return;
      await Notifs.showImmediate(
        id: _notificationId('progress_day', courseId),
        title: 'Daily goal crushed!',
        body: '"${course.name}" reached today\'s target. Nice work!',
      );
    } else {
      final (start, end) = _currentWeekBounds();
      final elapsedMap = await secondsByCourseBetween(start, end);
      final elapsed = elapsedMap[courseId] ?? 0;
      if (elapsed < weeklyGoalSecs) return;
      final token = _weekKey(start);
      if (!await _markProgressCelebrated('week', courseId, token)) return;
      await Notifs.showImmediate(
        id: _notificationId('progress_week', courseId),
        title: 'Weekly goal complete!',
        body: '"${course.name}" met this week\'s target. Keep it up!',
      );
    }
  }

  Future<bool> _markProgressCelebrated(
    String scope,
    String courseId,
    String token,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'progress_${scope}_$courseId';
    if (prefs.getString(key) == token) return false;
    await prefs.setString(key, token);
    return true;
  }

  (DateTime, DateTime) _currentWeekBounds() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final offset = (_progressWeekOffset(midnight));
    final start = midnight.subtract(Duration(days: offset));
    final end = start.add(const Duration(days: 7));
    return (start, end);
  }

  int _progressWeekOffset(DateTime midnight) {
    if (_weekStart == WeekStart.monday) {
      return (midnight.weekday - DateTime.monday).clamp(0, 6);
    }
    return midnight.weekday % 7;
  }

  String _weekKey(DateTime start) =>
      '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';

  double _hoursPerCredit(int level) {
    switch (level) {
      case 1:
        return 3.0;
      case 2:
        return 2.5;
      case 3:
        return 2.0;
      case 4:
        return 1.5;
      case 5:
        return 1.0;
      default:
        return 2.0;
    }
  }

  Future<void> _saveActiveSession() async {
    final timers = <String, Map<String, dynamic>>{};
    final stops = <String, Map<String, dynamic>>{};
    final pomos = <String, Map<String, dynamic>>{};

    String? activeCourseId;
    String? activeKind;
    DateTime? activeStart;
    DateTime? activeExpectedEnd;

    for (final c in courses) {
      timers[c.id] = {
        'running': timerRunning[c.id] ?? false,
        'start': timerStart[c.id]?.toIso8601String(),
        'elapsed': timerElapsed[c.id]?.inSeconds ?? 0,
      };
      if (timerRunning[c.id] == true) {
        activeCourseId = c.id;
        activeKind = 'timer';
        activeStart = timerStart[c.id];
        // timers have no fixed end here, the planned duration is resolved below
      }

      stops[c.id] = {
        'running': stopwatchRunning[c.id] ?? false,
        'start': stopwatchStart[c.id]?.toIso8601String(),
        'elapsed': stopwatchElapsed[c.id]?.inSeconds ?? 0,
      };
      if (stopwatchRunning[c.id] == true) {
        activeCourseId = c.id;
        activeKind = 'stopwatch';
        activeStart = stopwatchStart[c.id];
        if (activeStart != null) {
          activeExpectedEnd = activeStart.add(const Duration(hours: 3));
        }
      }

      pomos[c.id] = {
        'running': pomodoroRunning[c.id] ?? false,
        'paused': pomodoroPaused[c.id] ?? false,
        'phase': (pomodoroPhase[c.id] ?? PomodoroPhase.work).name,
        'phaseStart': pomodoroPhaseStart[c.id]?.toIso8601String(),
        'phaseElapsed': pomodoroPhaseElapsed[c.id]?.inSeconds ?? 0,
        'completedWork': pomodoroCompletedWork[c.id] ?? 0,
      };
      if (pomodoroRunning[c.id] == true && !(pomodoroPaused[c.id] ?? false)) {
        activeCourseId = c.id;
        activeKind = 'pomodoro';
        activeStart = pomodoroPhaseStart[c.id];
        // pomodoro end is fixed by the current phase duration
        final duration = _pomodoroPhaseDuration(c.id);
        if (activeStart != null) {
          activeExpectedEnd = activeStart.add(duration);
        }
      }
    }

    // for a running timer, use the planned duration from prefs, falling back to start + 3h
    if (activeKind == 'timer' &&
        activeStart != null &&
        activeCourseId != null) {
      final prefs = await SharedPreferences.getInstance();
      final plannedSeconds = prefs.getInt('timer_planned_$activeCourseId') ?? 0;
      if (plannedSeconds > 0) {
        activeExpectedEnd = activeStart.add(Duration(seconds: plannedSeconds));
      } else {
        activeExpectedEnd = activeStart.add(const Duration(hours: 3));
      }
    }

    await Storage.saveActiveSession({
      'timers': timers,
      'stopwatches': stops,
      'pomodoros': pomos,
    });

    // broadcast to remote
    final sync = _syncService;
    if (sync != null) {
      await _sendActiveSessionIfChanged(
        sync,
        isStudying: activeCourseId != null,
        courseId: activeCourseId,
        kind: activeKind,
        start: activeStart,
        expectedEnd: activeExpectedEnd,
      );
    }
  }

  Future<void> _sendActiveSessionIfChanged(
    SyncService sync, {
    required bool isStudying,
    String? courseId,
    String? kind,
    DateTime? start,
    DateTime? expectedEnd,
  }) async {
    Future<bool> send() => sync.updateActiveSession(
      isStudying: isStudying,
      courseId: courseId,
      kind: kind,
      start: start,
      expectedEnd: expectedEnd,
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      await send();
      return;
    }

    final signature = activeSessionSignature(
      isStudying: isStudying,
      courseId: courseId,
      kind: kind,
      startMs: start?.millisecondsSinceEpoch,
      expectedEndMs: expectedEnd?.millisecondsSinceEpoch,
    );
    if (_sentSessionSignature == (uid, signature)) return;

    // writes are acknowledged late when offline, so the old signature is stale once sent
    final attempt = ++_sessionSendCount;
    _sentSessionSignature = null;
    final sent = await send();
    if (!sent || attempt != _sessionSendCount) return;
    _sentSessionSignature = (uid, signature);
  }

  void _forgetSentSession() {
    _sessionSendCount++;
    _sentSessionSignature = null;
  }

  Future<Map<String, int>> secondsByCourseBetween(
    DateTime startLocal,
    DateTime endLocal,
  ) {
    return Storage.secondsByCourseBetween(startLocal, endLocal);
  }

  Future<Map<String, int>> secondsByCourseForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return Storage.secondsByCourseBetween(start, end);
  }

  Future<List<Map<String, int>>> dailySeries(DateTime startLocal, int days) {
    return Storage.dailySeries(startLocal, days);
  }

  Future<void> applyRemoteProfile(Map<String, dynamic>? data) async {
    if (data == null) return;
    bool changed = false;
    final remoteOnboardingCompleted =
        data['onboardingCompleted'] == true || data['profileComplete'] == true;

    Future<void> setString(
      String? value,
      String? current,
      Future<void> Function(String?) setter,
      void Function(String?) assign,
    ) async {
      final normalized = value?.trim();
      if (normalized != null &&
          normalized.isNotEmpty &&
          normalized != (current?.trim())) {
        assign(normalized);
        await setter(normalized);
        changed = true;
      }
    }

    await setString(
      data['profileName'] as String?,
      profileName,
      Storage.setProfileName,
      (v) => profileName = v,
    );

    final syncedProfileName = profileName?.trim() ?? '';
    if (syncedProfileName.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.displayName != syncedProfileName) {
        try {
          await user.updateDisplayName(syncedProfileName);
        } catch (_) {}
      }

      final remoteDisplayName = (data['displayName'] as String?)?.trim();
      if (user != null && remoteDisplayName != syncedProfileName) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'displayName': syncedProfileName,
                'profileName': syncedProfileName,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        } catch (_) {}
      }
    }

    await setString(
      data['profileGoal'] as String?,
      profileGoal,
      Storage.setProfileGoal,
      (v) => profileGoal = v,
    );

    await setString(
      data['major'] as String?,
      major,
      Storage.setMajor,
      (v) => major = v,
    );

    await setString(
      data['profileContact'] as String?,
      profileContact,
      Storage.setProfileContact,
      (v) => profileContact = v,
    );

    final localDirty = LocalDatabase.instance.userDocOrNull?.dirty == true;
    final remoteAvatarIndex =
        (data['profileAvatarIndex'] as num?)?.toInt() ??
        (data['avatarIndex'] as num?)?.toInt();
    final remoteAvatarBase64 =
        data['profileAvatarImageBase64'] as String? ??
        data['avatarImageBase64'] as String?;
    Uint8List? remoteAvatarBytes;
    if (remoteAvatarBase64 != null && remoteAvatarBase64.isNotEmpty) {
      try {
        remoteAvatarBytes = base64Decode(remoteAvatarBase64);
      } catch (_) {
        remoteAvatarBytes = null;
      }
    }
    final localHasAvatar =
        (profileAvatarImage != null && profileAvatarImage!.isNotEmpty) ||
        profileAvatarIndex != null;
    final canApplyAvatar = !localDirty || !localHasAvatar;
    if (canApplyAvatar &&
        remoteAvatarBytes != null &&
        remoteAvatarBytes.isNotEmpty &&
        (profileAvatarImage == null ||
            profileAvatarImage!.isEmpty ||
            profileAvatarImage!.lengthInBytes !=
                remoteAvatarBytes.lengthInBytes)) {
      profileAvatarImage = remoteAvatarBytes;
      profileAvatarIndex = null;
      await Storage.setProfileAvatarImageBytes(remoteAvatarBytes);
      await Storage.setProfileAvatarIndex(null);
      changed = true;
    } else if (canApplyAvatar &&
        remoteAvatarIndex != null &&
        remoteAvatarIndex >= 0 &&
        (remoteAvatarIndex != profileAvatarIndex ||
            (profileAvatarImage != null && profileAvatarImage!.isNotEmpty))) {
      profileAvatarIndex = remoteAvatarIndex;
      profileAvatarImage = null;
      await Storage.setProfileAvatarIndex(remoteAvatarIndex);
      await Storage.setProfileAvatarImageBytes(null);
      changed = true;
    }

    if (onboardingCompleted != remoteOnboardingCompleted) {
      onboardingCompleted = remoteOnboardingCompleted;
      await Storage.setOnboardingCompleted(onboardingCompleted);
      changed = true;
    }

    final profileCompleteFlag = remoteOnboardingCompleted;
    if (profileCompleteFlag && !_profilePromptCompleted) {
      _profilePromptCompleted = true;
      await Storage.setProfilePromptShown(true);
      changed = true;
    }

    if (profileCompleteFlag != profileComplete) {
      profileComplete = profileCompleteFlag;
      await Storage.setProfileComplete(profileCompleteFlag);
      changed = true;
    }

    final remoteAvatarColorValue =
        (data['avatarColorValue'] as num?)?.toInt() ??
        (data['profileAvatarColorValue'] as num?)?.toInt();
    if ((!localDirty || profileAvatarColorValue == null) &&
        remoteAvatarColorValue != null &&
        remoteAvatarColorValue != profileAvatarColorValue) {
      profileAvatarColorValue = remoteAvatarColorValue;
      await Storage.setProfileAvatarColor(remoteAvatarColorValue);
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    await Storage.clearAll();
    _resetFields();
    await _saveActiveSession();
    _isLoaded = true;
    _hydrated = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _pomodoroTicker?.cancel();
    _pomodoroTicker = null;
    _syncService?.removeAfterPullListener(_handleRemoteRefresh);
    super.dispose();
  }

  Future<void> reset() async {
    await clearAll();
    _forgetSentSession();
    _reloadRequested = false;
    _isLoaded = false;
  }

  void unload() {
    _forgetSentSession();
    _reloadRequested = false;
    _resetFields();
    _isLoaded = false;
    _hydrated = false;
    notifyListeners();
  }

  void _resetFields({bool cancelTimers = true}) {
    major = null;
    profileName = null;
    profileGoal = null;
    profileContact = null;
    profileAvatarIndex = null;
    profileAvatarImage = null;
    profileAvatarColorValue = null;
    profileComplete = false;
    onboardingCompleted = false;
    bootstrapVersion = null;
    _profilePromptCompleted = false;
    _courseGoalHours = {};
    courses = [];
    courseMinutes = {};
    _todayByCourseSeconds = {};
    _todayKey = _dateKey(DateTime.now());
    _streakCount = 0;
    _hasStudyToday = false;
    timerRunning.clear();
    stopwatchRunning.clear();
    timerStart.clear();
    stopwatchStart.clear();
    timerElapsed.clear();
    stopwatchElapsed.clear();
    pomodoroRunning.clear();
    pomodoroPaused.clear();
    pomodoroPhase.clear();
    pomodoroPhaseStart.clear();
    pomodoroPhaseElapsed.clear();
    pomodoroCompletedWork.clear();
    _pomodoroLongBreakMinutes.clear();
    if (cancelTimers) {
      _pomodoroTicker?.cancel();
      _pomodoroTicker = null;
      _midnightTimer?.cancel();
      _midnightTimer = null;
    }
  }

  Future<void> updateCourse(Course updated) async {
    final i = courses.indexWhere((Course c) => c.id == updated.id);
    if (i == -1) return;
    final existing = courses[i];
    courses[i] = updated.copyWith(
      sortOrder: updated.sortOrder ?? existing.sortOrder,
    );
    await Storage.saveCourses(courses);
    _triggerSync();
    notifyListeners();
  }

  static const _kThemeKey = 'themeMode';
  ThemeMode _themeMode = _initialThemeMode ?? ThemeMode.system;
  bool _themeLoaded = false;
  ThemeMode get themeMode => _themeMode;
  ThemeMode get effectiveThemeMode =>
      _themeLoaded ? _themeMode : (_initialThemeMode ?? ThemeMode.system);
  static String get kThemePrefsKey => _kThemeKey;

  Future<void> loadThemeMode() async {
    var stored = await Storage.getThemeMode();

    if (stored == null) {
      // fallback migration, prefs -> hive
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getString(_kThemeKey);
      if (stored != null) {
        await Storage.setThemeMode(stored);
      }
    } else {
      // self-healing, keep the lightweight boot prefs in sync with hive
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kThemeKey) != stored) {
        await prefs.setString(_kThemeKey, stored);
      }
    }

    final parsed = _parseMode(stored ?? _initialThemeMode?.name ?? 'system');
    final shouldNotify = !_themeLoaded || _themeMode != parsed;
    _themeMode = parsed;
    _themeLoaded = true;
    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _themeLoaded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, mode.name);
    await Storage.setThemeMode(mode.name);
  }

  ThemeMode _parseMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String? _cleanOptional(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  HomeSummaryRange _homeSummaryRange = HomeSummaryRange.today;
  HomeSummaryRange get homeSummaryRange => _homeSummaryRange;

  Future<void> loadHomeSummaryRange() async {
    final s = await Storage.getHomeSummaryRange();
    switch (s) {
      case 'week':
        _homeSummaryRange = HomeSummaryRange.week;
        break;
      case 'month':
        _homeSummaryRange = HomeSummaryRange.month;
        break;
      case 'year':
        _homeSummaryRange = HomeSummaryRange.year;
        break;
      case 'allTime':
        _homeSummaryRange = HomeSummaryRange.allTime;
        break;
      case 'off':
        _homeSummaryRange = HomeSummaryRange.off;
        break;
      default:
        _homeSummaryRange = HomeSummaryRange.today;
    }
    notifyListeners();
  }

  Future<void> setHomeSummaryRange(HomeSummaryRange r) async {
    _homeSummaryRange = r;
    notifyListeners();
    final s = switch (r) {
      HomeSummaryRange.off => 'off',
      HomeSummaryRange.today => 'today',
      HomeSummaryRange.week => 'week',
      HomeSummaryRange.month => 'month',
      HomeSummaryRange.year => 'year',
      HomeSummaryRange.allTime => 'allTime',
    };
    await Storage.setHomeSummaryRange(s);
  }

  (DateTime start, DateTime end) homeSummaryBoundsNow() {
    final now = DateTime.now();
    switch (_homeSummaryRange) {
      case HomeSummaryRange.off:
        return (now, now);
      case HomeSummaryRange.today:
        final s = DateTime(now.year, now.month, now.day);
        return (s, now);
      case HomeSummaryRange.week:
        final midnight = DateTime(now.year, now.month, now.day);
        final wd = midnight.weekday;
        final offset = (weekStart == WeekStart.monday)
            ? (wd - DateTime.monday)
            : (wd % 7);
        final s = midnight.subtract(Duration(days: offset));
        return (s, now);
      case HomeSummaryRange.month:
        final s = DateTime(now.year, now.month, 1);
        return (s, now);
      case HomeSummaryRange.year:
        final s = DateTime(now.year, 1, 1);
        return (s, now);
      case HomeSummaryRange.allTime:
        final s = DateTime(1970, 1, 1);
        return (s, now);
    }
  }

  String homeSummaryLabel(BuildContext context) => switch (_homeSummaryRange) {
    HomeSummaryRange.off => AppLocalizations.of(context)!.off,
    HomeSummaryRange.today => AppLocalizations.of(context)!.studiedToday,
    HomeSummaryRange.week => AppLocalizations.of(context)!.studiedThisWeek,
    HomeSummaryRange.month => AppLocalizations.of(context)!.studiedThisMonth,
    HomeSummaryRange.year => AppLocalizations.of(context)!.studiedThisYear,
    HomeSummaryRange.allTime => AppLocalizations.of(context)!.studiedOverall,
  };

  String localizeSessionType(BuildContext context, String? sessionType) {
    if (sessionType == null) return AppLocalizations.of(context)!.session;
    switch (sessionType.toLowerCase()) {
      case 'timer':
        return AppLocalizations.of(context)!.timer;
      case 'stopwatch':
        return AppLocalizations.of(context)!.stopwatch;
      case 'pomodoro':
        return AppLocalizations.of(context)!.pomodoro;
      default:
        return AppLocalizations.of(context)!.session;
    }
  }

  Future<void> addManualSession({
    required String courseId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (await Storage.hasSessionOverlap(start, end)) {
      throw SessionOverlapException(
        'You already studied during this time period.',
      );
    }
    if (!end.isAfter(start)) return;
    await _addSessionSplitAcrossMidnight(
      courseId: courseId,
      startLocal: start,
      endLocal: end,
      kind: 'manual recording',
    );

    final totalSecs = end.difference(start).inSeconds;
    if (totalSecs > 0) {
      final minutes = totalSecs ~/ 60;
      if (minutes > 0) {
        courseMinutes[courseId] = (courseMinutes[courseId] ?? 0) + minutes;
        await Storage.saveCourseMinutes(courseMinutes);
      }

      _ensureTodayKeyUpToDate();
      final todayOverlap = _secondsOverlapToday(start, end);
      if (todayOverlap > 0) {
        _todayByCourseSeconds[courseId] =
            (_todayByCourseSeconds[courseId] ?? 0) + todayOverlap;
        await _saveDailyState();
      }
    }

    _triggerSync();
    notifyListeners();
    unawaited(_maybeCelebrateProgress(courseId));

    // sync to habits
    if (_habitService != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // recalculate time habits
        unawaited(
          _habitService!.syncTimeHabitsForCourse(
            user.uid,
            courseId,
            start,
            knownDelta: totalSecs.toDouble(),
          ),
        );

        // legacy update for yes/no completion
        unawaited(
          _habitService!.updateHabitProgressFromCourse(
            userId: user.uid,
            courseId: courseId,
            date: start,
            deltaSeconds: totalSecs,
          ),
        );
      }
    }
  }

  Future<void> deleteSession({
    required String id,
    required String courseId,
    required DateTime startLocal,
    required DateTime endLocal,
  }) async {
    await Storage.deleteSession(
      id,
      courseId: courseId,
      startUtc: startLocal.toUtc(),
      endUtc: endLocal.toUtc(),
    );

    final duration = endLocal.difference(startLocal).inSeconds;
    if (duration > 0) {
      final minutes = duration ~/ 60;
      if (minutes > 0 && courseMinutes.containsKey(courseId)) {
        final updated = (courseMinutes[courseId] ?? 0) - minutes;
        courseMinutes[courseId] = updated <= 0 ? 0 : updated;
        await Storage.saveCourseMinutes(courseMinutes);
      }

      final todayOverlap = _secondsOverlapToday(startLocal, endLocal);
      if (todayOverlap > 0) {
        final updated = (_todayByCourseSeconds[courseId] ?? 0) - todayOverlap;
        _todayByCourseSeconds[courseId] = updated <= 0 ? 0 : updated;
        await _saveDailyState();
      }
    }

    // sync habits for this course and date
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _habitService != null) {
      // time habits, recalculate from remaining sessions
      unawaited(
        _habitService!.syncTimeHabitsForCourse(
          user.uid,
          courseId,
          startLocal,
          knownDelta: -duration.toDouble(),
        ),
      );
      // yes/no habits, revert auto-completion if needed
      unawaited(
        _habitService!.checkAndRevertHabitCompletion(
          user.uid,
          courseId,
          startLocal,
        ),
      );
    }

    _updateStreak();
    // push the deletion immediately, delta sync only
    if (_syncService != null) {
      unawaited(_syncService!.pushDirty());
    }
    notifyListeners();
  }

  Future<void> saveSessionNotes({
    required String id,
    required String? notes,
  }) async {
    await Storage.setSessionNotes(id, notes);
    _triggerSync();
    notifyListeners();
  }
}
