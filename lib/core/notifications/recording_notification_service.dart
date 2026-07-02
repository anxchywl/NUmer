import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

// shows a live-updating persistent notification while a study session is active,
// android uses an ongoing notification, ios refreshes periodically in the foreground
// and falls back to a static subtitle when backgrounded

enum _SessionKind { timer, stopwatch, pomodoro }

// callback types so the service can read live state from appstate without a hard cycle
typedef ElapsedCallback = Duration Function();
typedef PomodoroInfoCallback = ({String phase, Duration remaining});
typedef PomodoroQueryCallback = PomodoroInfoCallback Function();

// singleton that manages the live study-session notification and ios live activity
class RecordingNotifService {
  RecordingNotifService._();
  static final RecordingNotifService instance = RecordingNotifService._();

  // plugin ───────────────────────────────────────────────────────────────
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pluginInited = false;

  // constants ────────────────────────────────────────────────────────────
  static const int _notifId = 888;
  static const String _channelId = 'recording_channel';
  static const String _channelName = 'Study Session';
  static const String _channelDesc = 'Live status for active study sessions.';
  static const MethodChannel _liveActivityChannel =
      MethodChannel('numer/live_activity_session');
  static const Duration _maxSessionDuration = Duration(hours: 3);

  // state ────────────────────────────────────────────────────────────────
  _SessionKind? _kind;
  String? _courseId;
  String? _courseName;
  bool _paused = false;
  DateTime? _startedAt;
  DateTime? _expectedEndAt;
  bool _countsDown = false;

  // live-state readers injected by appstate
  ElapsedCallback? _elapsedReader;
  PomodoroQueryCallback? _pomodoroReader;

  Timer? _ticker;
  bool _refreshInFlight = false;
  bool _refreshQueued = false;
  bool _liveActivityStarted = false;

  // initialisation ───────────────────────────────────────────────────────

  /// must be called once before any show(), from notifs.init or main
  static Future<void> init() async {
    if (_pluginInited) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: ios),
    );

    // dedicated low-importance channel, no sound or vibration on updates
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
    }

    _pluginInited = true;
  }

  // public api ───────────────────────────────────────────────────────────

  /// show or replace the persistent notification for a timer session
  void showTimer({
    required String courseId,
    required String courseName,
    required ElapsedCallback elapsedReader,
    DateTime? startedAt,
    DateTime? expectedEndAt,
    bool countsDown = false,
  }) {
    _kind = _SessionKind.timer;
    _courseId = courseId;
    _courseName = courseName;
    _elapsedReader = elapsedReader;
    _pomodoroReader = null;
    _paused = false;
    _startedAt = startedAt;
    _expectedEndAt = expectedEndAt;
    _countsDown = countsDown;
    _startTicker();
    _requestRefresh();
  }

  /// show or replace the persistent notification for a stopwatch session
  void showStopwatch({
    required String courseId,
    required String courseName,
    required ElapsedCallback elapsedReader,
    DateTime? startedAt,
    DateTime? expectedEndAt,
  }) {
    _kind = _SessionKind.stopwatch;
    _courseId = courseId;
    _courseName = courseName;
    _elapsedReader = elapsedReader;
    _pomodoroReader = null;
    _paused = false;
    _startedAt = startedAt;
    _expectedEndAt = expectedEndAt;
    _countsDown = false;
    _startTicker();
    _requestRefresh();
  }

  /// show or replace the persistent notification for a pomodoro session
  void showPomodoro({
    required String courseId,
    required String courseName,
    required PomodoroQueryCallback pomodoroReader,
    DateTime? phaseEndsAt,
    bool paused = false,
  }) {
    _kind = _SessionKind.pomodoro;
    _courseId = courseId;
    _courseName = courseName;
    _elapsedReader = null;
    _pomodoroReader = pomodoroReader;
    _paused = paused;
    _startedAt = DateTime.now();
    _expectedEndAt = phaseEndsAt;
    _countsDown = true;
    _startTicker();
    _requestRefresh();
  }

  /// mark the session paused, updates buttons and stops the ticker to save cpu
  void pause() {
    _paused = true;
    _ticker?.cancel();
    _ticker = null;
    _requestRefresh();
  }

  /// mark the session resumed and restart the ticker
  void resume() {
    _paused = false;
    _startTicker();
    _requestRefresh();
  }

  /// remove the notification and stop all updates
  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    _kind = null;
    _courseId = null;
    _courseName = null;
    _elapsedReader = null;
    _pomodoroReader = null;
    _paused = false;
    _startedAt = null;
    _expectedEndAt = null;
    _countsDown = false;
    _liveActivityStarted = false;
    unawaited(_plugin.cancel(id: _notifId));
    if (Platform.isIOS) {
      unawaited(_liveActivityChannel.invokeMethod<bool>('end'));
    }
  }

  // internal helpers ─────────────────────────────────────────────────────

  void _startTicker() {
    final needsTicker = _kind == _SessionKind.pomodoro && !_paused;
    if (!needsTicker) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker?.cancel();
    _ticker =
        Timer.periodic(const Duration(seconds: 1), (_) => _requestRefresh());
  }

  void _requestRefresh() {
    if (_kind == null) return;
    if (_refreshInFlight) {
      _refreshQueued = true;
      return;
    }
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_kind == null) return;
    _refreshInFlight = true;
    try {
      do {
        _refreshQueued = false;
        if (_kind == null) break;
        _recomputeTimeAnchors();

        final title = _buildTitle();
        final body = _buildBody();
        final details = _buildDetails();
        final payload = _courseId;

        if (Platform.isIOS) {
          await _refreshLiveActivity(title: title, body: body);
          continue;
        }

        await _plugin.show(
          id: _notifId,
          title: title,
          body: body,
          notificationDetails: details,
          payload: payload,
        );
      } while (_refreshQueued);
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _refreshLiveActivity({
    required String title,
    required String body,
  }) async {
    final kind = _kind;
    if (kind == null) return;
    final data =
        _buildLiveActivityPayload(title: title, body: body, kind: kind);
    try {
      if (!_liveActivityStarted) {
        final started = await _liveActivityChannel.invokeMethod<bool>(
              'start',
              data,
            ) ??
            false;
        _liveActivityStarted = started;
        if (!started && kDebugMode) {
          debugPrint(
              'RecordingNotifService: Live Activity start was rejected.');
        }
      } else {
        final updated = await _liveActivityChannel.invokeMethod<bool>(
              'update',
              data,
            ) ??
            false;
        if (!updated) {
          if (kDebugMode) {
            debugPrint(
                'RecordingNotifService: Live Activity update failed, retrying start.');
          }
          final restarted = await _liveActivityChannel.invokeMethod<bool>(
                'start',
                data,
              ) ??
              false;
          _liveActivityStarted = restarted;
          if (!restarted && kDebugMode) {
            debugPrint(
                'RecordingNotifService: Live Activity restart was rejected.');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RecordingNotifService: Live Activity error: $e');
      }
      _liveActivityStarted = false;
    }
  }

  Map<String, Object?> _buildLiveActivityPayload({
    required String title,
    required String body,
    required _SessionKind kind,
  }) {
    String kindName;
    String? phase;
    int elapsedSeconds = 0;
    int remainingSeconds = 0;

    switch (kind) {
      case _SessionKind.timer:
        kindName = 'timer';
        elapsedSeconds = (_elapsedReader?.call() ?? Duration.zero).inSeconds;
        break;
      case _SessionKind.stopwatch:
        kindName = 'stopwatch';
        elapsedSeconds = (_elapsedReader?.call() ?? Duration.zero).inSeconds;
        break;
      case _SessionKind.pomodoro:
        kindName = 'pomodoro';
        final info = _pomodoroReader?.call();
        phase = info?.phase;
        remainingSeconds = (info?.remaining ?? Duration.zero).inSeconds;
        break;
    }

    final showChronometer = _shouldUseSystemChronometer();

    return <String, Object?>{
      'sessionId': _courseId ?? 'active-session',
      'kind': kindName,
      'courseName': _courseName ?? 'Session',
      'title': title,
      'body': body,
      'phase': phase,
      'paused': _paused,
      'elapsedSeconds': elapsedSeconds,
      'remainingSeconds': remainingSeconds,
      'showChronometer': showChronometer,
      'countsDown': _countsDown,
      'startedAtMs': _startedAt?.millisecondsSinceEpoch,
      'endsAtMs': _expectedEndAt?.millisecondsSinceEpoch,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    };
  }

  String _buildTitle() {
    switch (_kind!) {
      case _SessionKind.timer:
        return 'Timer - ${_courseName ?? ''}';
      case _SessionKind.stopwatch:
        return 'Stopwatch - ${_courseName ?? ''}';
      case _SessionKind.pomodoro:
        return 'Pomodoro - ${_courseName ?? ''}';
    }
  }

  String _buildBody() {
    if (_paused) {
      return 'Session paused';
    }
    switch (_kind!) {
      case _SessionKind.timer:
        if (_shouldUseSystemChronometer()) {
          return _countsDown ? 'Timer running' : 'Session running';
        }
        final elapsed = _elapsedReader?.call() ?? Duration.zero;
        return 'Elapsed: ${_fmt(elapsed)}';
      case _SessionKind.stopwatch:
        if (_shouldUseSystemChronometer()) {
          return 'Session running';
        }
        final elapsed = _elapsedReader?.call() ?? Duration.zero;
        return 'Elapsed: ${_fmt(elapsed)}';
      case _SessionKind.pomodoro:
        final info = _pomodoroReader?.call();
        if (info == null) return 'Starting…';
        if (_shouldUseSystemChronometer()) {
          return '${info.phase} running';
        }
        return '${info.phase} - ${_fmt(info.remaining)} remaining';
    }
  }

  static String _fmt(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${_p(h)}:${_p(m)}:${_p(s)}';
    }
    return '${_p(m)}:${_p(s)}';
  }

  static String _p(int n) => n.toString().padLeft(2, '0');

  NotificationDetails _buildDetails() {
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBanner: false,
      presentList: false,
      presentBadge: false,
      presentSound: false,
      threadIdentifier: 'active_session_recording',
    );

    final chrono = _androidChronometerSpec();

    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        showWhen: chrono.showWhen,
        when: chrono.whenMs,
        onlyAlertOnce: true,
        usesChronometer: chrono.usesChronometer,
        chronometerCountDown: chrono.countsDown,
        timeoutAfter: chrono.timeoutAfterMs,
        color: const Color(0xFF448AFF),
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.service,
      ),
      iOS: iosDetails,
    );
  }

  void _recomputeTimeAnchors() {
    final now = DateTime.now();
    switch (_kind) {
      case _SessionKind.timer:
      case _SessionKind.stopwatch:
        final elapsed = _elapsedReader?.call() ?? Duration.zero;
        final safeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
        _startedAt ??= now.subtract(safeElapsed);
        if (_kind == _SessionKind.stopwatch && _startedAt != null) {
          _expectedEndAt ??= _startedAt!.add(_maxSessionDuration);
        }
        return;
      case _SessionKind.pomodoro:
        if (_paused) return;
        final info = _pomodoroReader?.call();
        if (info == null) return;
        final remaining =
            info.remaining.isNegative ? Duration.zero : info.remaining;
        _startedAt = now;
        _expectedEndAt = now.add(remaining);
        _countsDown = true;
        return;
      case null:
        return;
    }
  }

  bool _shouldUseSystemChronometer() {
    if (_paused) return false;
    switch (_kind) {
      case _SessionKind.timer:
      case _SessionKind.stopwatch:
        return _startedAt != null;
      case _SessionKind.pomodoro:
        return _expectedEndAt != null;
      case null:
        return false;
    }
  }

  ({
    bool showWhen,
    int? whenMs,
    bool usesChronometer,
    bool countsDown,
    int? timeoutAfterMs
  }) _androidChronometerSpec() {
    if (!_shouldUseSystemChronometer()) {
      return (
        showWhen: false,
        whenMs: null,
        usesChronometer: false,
        countsDown: false,
        timeoutAfterMs: null,
      );
    }

    final now = DateTime.now();
    switch (_kind) {
      case _SessionKind.timer:
        if (_countsDown && _expectedEndAt != null) {
          final timeout = _expectedEndAt!.difference(now).inMilliseconds;
          return (
            showWhen: true,
            whenMs: _expectedEndAt!.millisecondsSinceEpoch,
            usesChronometer: true,
            countsDown: true,
            timeoutAfterMs: timeout > 0 ? timeout : null,
          );
        }
        final timeout = _expectedEndAt?.difference(now).inMilliseconds;
        return (
          showWhen: true,
          whenMs: _startedAt?.millisecondsSinceEpoch,
          usesChronometer: true,
          countsDown: false,
          timeoutAfterMs: timeout != null && timeout > 0 ? timeout : null,
        );
      case _SessionKind.stopwatch:
        final timeout = _expectedEndAt?.difference(now).inMilliseconds;
        return (
          showWhen: true,
          whenMs: _startedAt?.millisecondsSinceEpoch,
          usesChronometer: true,
          countsDown: false,
          timeoutAfterMs: timeout != null && timeout > 0 ? timeout : null,
        );
      case _SessionKind.pomodoro:
        return (
          showWhen: true,
          whenMs: _expectedEndAt?.millisecondsSinceEpoch,
          usesChronometer: true,
          countsDown: true,
          timeoutAfterMs: null,
        );
      case null:
        return (
          showWhen: false,
          whenMs: null,
          usesChronometer: false,
          countsDown: false,
          timeoutAfterMs: null,
        );
    }
  }
}
