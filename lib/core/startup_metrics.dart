import 'package:flutter/foundation.dart';

// Lightweight startup instrumentation — tracks time-to-first-frame, local Hive
// hydration, and Firebase sync duration. All timings are relative to app_start.
class StartupMetrics {
  StartupMetrics._();

  static final Stopwatch _clock = Stopwatch()..start();
  static final Stopwatch _syncWatch = Stopwatch();

  static Duration? _firstFrame;
  static Duration? _localHydrate;
  static Duration? _syncDuration;
  static int _firebaseReads = 0;
  static bool _syncStarted = false;
  static bool _syncFinished = false;
  static bool _summaryLogged = false;

  static void markAppStart() {
    if (!_clock.isRunning) {
      _clock.start();
    }
    debugPrint('[startup] app_start');
  }

  static void markFirstFrame() {
    if (_firstFrame != null) return;
    _firstFrame = _clock.elapsed;
    _log('time_to_first_frame_ms=${_firstFrame!.inMilliseconds}');
    _maybeLogSummary();
  }

  static void markLocalHydrateDone(String label) {
    if (_localHydrate != null) return;
    _localHydrate = _clock.elapsed;
    _log('local_hydrate_ms=${_localHydrate!.inMilliseconds} source=$label');
    _maybeLogSummary();
  }

  static void markSyncStart({required bool bootstrap}) {
    if (_syncStarted) return;
    _syncStarted = true;
    if (!_syncWatch.isRunning) {
      _syncWatch.start();
    }
    _log(
      'background_sync_start bootstrap=$bootstrap at_ms=${_clock.elapsed.inMilliseconds}',
    );
  }

  static void markSyncComplete({required int readCount}) {
    _firebaseReads += readCount;
    if (_syncFinished || !_syncStarted) {
      return;
    }
    _syncFinished = true;
    if (_syncWatch.isRunning) {
      _syncWatch.stop();
    }
    _syncDuration = _syncWatch.elapsed;
    _log(
      'background_sync_complete_ms=${_syncDuration?.inMilliseconds ?? 0} firebase_reads=$_firebaseReads',
    );
    _maybeLogSummary();
  }

  static void addFirebaseReads(int count) {
    if (count <= 0) return;
    _firebaseReads += count;
  }

  static void _maybeLogSummary() {
    if (_summaryLogged) return;
    final haveFirstFrame = _firstFrame != null;
    final haveHydrate = _localHydrate != null;
    final syncDoneOrSkipped = _syncFinished || !_syncStarted;
    if (haveFirstFrame && haveHydrate && syncDoneOrSkipped) {
      _summaryLogged = true;
      _log(
        'startup_summary ttff_ms=${_firstFrame!.inMilliseconds} hydrate_ms=${_localHydrate!.inMilliseconds} sync_ms=${_syncDuration?.inMilliseconds ?? -1} firebase_reads=$_firebaseReads',
      );
    }
  }

  static void _log(String message) {
    debugPrint('[startup] $message');
  }
}
