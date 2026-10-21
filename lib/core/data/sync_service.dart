import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'package:numer_app/core/data/entities.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/sync_schedule.dart';
import 'package:numer_app/core/startup_metrics.dart';

enum SyncStatus { offline, syncing, upToDate }

// keeps hive and firestore in sync, pushes dirty local records and pulls remote changes
class SyncService extends ChangeNotifier {
  SyncService({
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
    LocalDatabase? database,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _connectivity = connectivity ?? Connectivity(),
        _db = database ?? LocalDatabase.instance;

  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;
  final LocalDatabase _db;
  final SyncSchedule _schedule = const SyncSchedule();

  SyncStatus _status = SyncStatus.offline;
  SyncStatus get status => _status;
  bool get hasPulledUser => _hasPulledUser;

  String? _uid;
  String? _deviceId;
  bool _online = false;
  bool _bootstrapping = false;
  bool _hasPulledUser = false;
  bool _isRunning = false;
  bool _isSyncing = false;
  bool _pushPending = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _activeSessionSub;
  Future<void> Function()? _onForcedLogout;
  Future<void> Function()? onBeforeStop;
  final List<Future<void> Function()> _afterPullListeners = [];

  DateTime? lastPush;
  DateTime? lastPull;
  String? lastError;

  static const _userStateKey = 'user';
  static const _coursesStateKey = 'courses';
  static const _sessionsStateKey = 'sessions';
  static const _goalsStateKey = 'goals';
  static const _habitsStateKey = 'habits';
  static const _metaThemeModeKey = 'theme_mode_v2';
  static const _metaWeekStartKey = 'week_start_v2';
  static const _metaHomeSummaryRangeKey = 'home_summary_range_v2';
  static const _metaProgressViewKey = 'progress_view_v2';
  static const _metaQuickNotesKey = 'quick_notes_enabled_v2';
  static const _metaAllowNudgesKey = 'allow_nudges_v2';
  static const _metaEisenhowerKey = 'eisenhower_matrix_enabled_v2';

  Future<void> start({
    required String uid,
    required String deviceId,
    Future<void> Function()? onForcedLogout,
    bool bootstrap = false,
  }) async {
    if (_isRunning && _uid == uid && _deviceId == deviceId) {
      _onForcedLogout = onForcedLogout;
      return;
    }

    await stop();

    _uid = uid;
    _deviceId = deviceId;
    _onForcedLogout = onForcedLogout;
    _bootstrapping = bootstrap;
    _hasPulledUser = false;

    await _db.openForUser(uid);

    _isRunning = true;

    await _checkConnectivity();
    // reflect initial connectivity for the ui, refined again during sync
    if (_online) {
      _setStatus(_isSyncing ? SyncStatus.syncing : SyncStatus.upToDate);
    } else {
      _setStatus(SyncStatus.offline);
    }

    _connectivitySub = _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final nowOnline = _computeOnlineStatus(results);
      final becameOnline = !_online && nowOnline;
      _online = nowOnline;
      if (_online) {
        if (becameOnline &&
            (_bootstrapping || !_hasPulledUser) &&
            !_isSyncing) {
          unawaited(
              syncNow(full: true, startup: _bootstrapping || !_hasPulledUser));
        } else if (_status == SyncStatus.offline && !_isSyncing) {
          _setStatus(SyncStatus.upToDate);
        }
      } else {
        _setStatus(SyncStatus.offline);
      }
    });

    if (_online) {
      // fire-and-forget, the heartbeat runs in the background and must not block startup
      unawaited(_claimSession());
    }
    // start the session-conflict listener unless bootstrapping, then it starts after _pulluser
    if (!bootstrap) {
      _listenActiveSession();
    }

    if (_online) {
      if (bootstrap) {
        // new device or first login, block until the minimal data is fetched
        await syncNow(full: true, startup: true);
      } else {
        // returning user with cache, no auto-sync on launch, we rely on manual or major-event triggers
        // unawaited(syncNow(full: false, startup: true));
      }
    } else {
      _setStatus(SyncStatus.offline);
    }
  }

  Future<void> stop() async {
    if (onBeforeStop != null) {
      await onBeforeStop!();
    }
    _status = SyncStatus.offline;
    _bootstrapping = false;
    _hasPulledUser = false;
    _isRunning = false;
    _isSyncing = false;
    await _connectivitySub?.cancel();
    await _activeSessionSub?.cancel();
    _connectivitySub = null;
    _activeSessionSub = null;
    _uid = null;
    _deviceId = null;
    lastPull = null;
    lastPush = null;
    lastError = null;
    notifyListeners();
  }

  Future<void> syncNow({
    bool full = false,
    bool startup = false,
    bool force = false,
  }) {
    return _runGuarded(
      () async {
        if (startup) {
          StartupMetrics.markSyncStart(bootstrap: full);
        }
        await pushDirty();
        final shouldPull = _schedule.shouldPull(
          nowMs: _now(),
          lastPullMs: lastPull?.millisecondsSinceEpoch,
          force: force || full,
        );
        final readCount = shouldPull ? await pullSince(full: full) : 0;
        if (startup) {
          StartupMetrics.markSyncComplete(readCount: readCount);
        }
      },
      onError: () {
        if (startup) {
          StartupMetrics.markSyncComplete(readCount: 0);
        }
      },
    );
  }

  Future<void> pushNow() async {
    // the running sync may have already collected its dirty records
    if (_isSyncing) {
      _pushPending = true;
      return;
    }
    await _runGuarded(pushDirty);
  }

  Future<void> _runGuarded(
    Future<void> Function() body, {
    VoidCallback? onError,
  }) async {
    if (!_isRunning || _isSyncing || !_online || _uid == null) {
      return;
    }
    _isSyncing = true;
    _setStatus(SyncStatus.syncing);
    lastError = null;
    try {
      await body();
      _setStatus(SyncStatus.upToDate);
    } catch (err, stack) {
      onError?.call();
      if (kDebugMode) {
        print('Sync failed: $err\n$stack');
      }
      lastError = err.toString();
      _setStatus(SyncStatus.offline);
    } finally {
      _isSyncing = false;
      if (_pushPending) {
        _pushPending = false;
        await pushNow();
      }
    }
  }

  Future<void> pushDirty() async {
    if (!_isRunning || !_online || _uid == null) {
      if (_uid == null) return;
    }

    // only set status when not already inside a larger sync
    final rootCall = !_isSyncing;
    if (rootCall) {
      _isSyncing = true;
      _setStatus(SyncStatus.syncing);
    }

    try {
      const maxOperations = 450;
      final userDoc = _db.userDocOrNull;

      if (userDoc != null && userDoc.dirty) {
        // on a fresh device with no cached profile, dont overwrite remote fields with local defaults until the remote user is pulled
        if (!(_bootstrapping && !_hasPulledUser)) {
          await _pushUser(userDoc);
        }
      }

      Future<void> pushChunk<T extends HiveObject>(
        List<T> items,
        Future<void> Function(
          WriteBatch batch,
          T item,
        ) writer,
      ) async {
        if (items.isEmpty) return;
        var offset = 0;
        while (offset < items.length) {
          final slice = items.sublist(
            offset,
            min(offset + maxOperations, items.length),
          );
          final batch = _firestore.batch();
          for (final item in slice) {
            await writer(batch, item);
          }
          await batch.commit();
          offset += slice.length;
        }
      }

      final dirtyCourses = _db.dirtyCourses();
      await pushChunk<LocalCourse>(dirtyCourses, (batch, course) async {
        final ref = _firestore
            .collection('users')
            .doc(_uid)
            .collection('courses')
            .doc(course.id);
        batch.set(ref, _courseToRemote(course), SetOptions(merge: true));
        course.dirty = false;
        course.updatedAtMs = _now();
      });

      final dirtySessions = _db.dirtySessions();
      await pushChunk<LocalSession>(dirtySessions, (batch, session) async {
        final ref = _firestore
            .collection('users')
            .doc(_uid)
            .collection('sessions')
            .doc(session.id);
        batch.set(ref, _sessionToRemote(session), SetOptions(merge: true));
        session.dirty = false;
        session.updatedAtMs = _now();
      });

      final dirtyGoals = _db.dirtyGoals();
      await pushChunk<LocalGoal>(dirtyGoals, (batch, goal) async {
        final ref = _firestore
            .collection('users')
            .doc(_uid)
            .collection('goals')
            .doc(goal.id);
        if (goal.deleted) {
          batch.delete(ref);
        } else {
          batch.set(ref, _goalToRemote(goal), SetOptions(merge: true));
        }
        goal.dirty = false;
        goal.updatedAtMs = _now();
      });

      await Future.wait([
        for (final c in dirtyCourses) c.save(),
        for (final s in dirtySessions) s.deleted ? s.delete() : s.save(),
        for (final g in dirtyGoals) g.save(),
        if (userDoc != null && userDoc.dirty == false) userDoc.save(),
      ]);

      // push dirty habits
      final dirtyHabits = _db.dirtyHabits();
      await pushChunk<LocalHabit>(dirtyHabits, (batch, habit) async {
        final ref = _firestore
            .collection('users')
            .doc(_uid)
            .collection('habits')
            .doc(habit.id);
        if (habit.deleted) {
          batch.delete(ref);
        } else {
          if (habit.resetPending) {
            await _deleteRemoteHabitHistory(habit.id);
            habit.resetPending = false;
          }
          batch.set(ref, _habitToRemote(habit), SetOptions(merge: true));
        }
        habit.dirty = false;
        habit.updatedAtMs = _now();
      });

      await Future.wait([
        for (final h in dirtyHabits) _db.putHabit(h),
      ]);

      // push dirty habit history entries
      final dirtyHistory = _db.dirtyHabitHistory();
      await pushChunk<LocalHabitHistory>(dirtyHistory, (batch, history) async {
        final ref = _firestore
            .collection('users')
            .doc(_uid)
            .collection('habits')
            .doc(history.habitId)
            .collection('history')
            .doc(history.dateKey);

        final payload = {
          'ts': Timestamp.fromMillisecondsSinceEpoch(history.completedAtMs),
          'updatedAt': FieldValue.serverTimestamp(),
          'v': history.value,
          'm': history.manualValue,
          'ver': history.version, // version for optimistic locking
          'deleted': history.deleted,
        };

        batch.set(ref, payload, SetOptions(merge: true));
        history.dirty = false;
        history.updatedAtMs = _now();
      });

      await Future.wait([
        for (final h in dirtyHistory) _db.putHabitHistory(h),
      ]);

      final historyState = _db.syncStateForKey(_habitHistoryStateKey);
      historyState.lastPushMs = _now();
      await _db.putSyncState(historyState);

      final state = _db.syncStateForKey(_coursesStateKey);
      state.lastPushMs = _now();
      await _db.putSyncState(state);
      lastPush = DateTime.now();

      if (rootCall) {
        _setStatus(SyncStatus.upToDate);
      }
    } catch (err) {
      if (rootCall) {
        lastError = err.toString();
        _setStatus(SyncStatus.offline);
      }
      rethrow;
    } finally {
      if (rootCall) {
        _isSyncing = false;
      }
    }
  }

  Future<int> pullSince({bool full = false}) async {
    if (_uid == null) return 0;
    var readCount = 0;
    readCount += await _pullUser(full: full);
    readCount += await _pullCollection(
      collection: 'courses',
      stateKey: _coursesStateKey,
      mapper: _applyRemoteCourse,
      full: full,
      limit: 250,
    );
    readCount += await _pullCollection(
      collection: 'sessions',
      stateKey: _sessionsStateKey,
      mapper: _applyRemoteSession,
      full: full,
      limit: 200,
    );
    readCount += await _pullCollection(
      collection: 'goals',
      stateKey: _goalsStateKey,
      mapper: _applyRemoteGoal,
      full: full,
      limit: 200,
    );
    readCount += await _pullCollection(
      collection: 'habits',
      stateKey: _habitsStateKey,
      mapper: _applyRemoteHabit,
      full: full,
      limit: 200,
    );
    readCount += await _pullHabitHistory(full: full);
    lastPull = DateTime.now();
    await _notifyAfterPullListeners();
    return readCount;
  }

  Future<void> _checkConnectivity() async {
    final value = await _connectivity.checkConnectivity();
    _online = _computeOnlineStatus(value);
  }

  void _setStatus(SyncStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  Future<void> updateActiveSession({
    required bool isStudying,
    String? courseId,
    String? kind,
    DateTime? start,
    DateTime? expectedEnd,
  }) async {
    if (_uid == null || _deviceId == null) return;
    final docRef = _firestore.collection('users').doc(_uid);

    if (!isStudying) {
      // keep the device claim but clear study data
      await docRef.set({
        'activeSession': {
          'deviceId': _deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
          // explicitly clear study fields since we replaced the map
          'courseId': null,
          'kind': null,
          'startUtc': null,
          'expectedEndUtc': null,
        },
        'isStudying': false,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await docRef.set({
        'activeSession': {
          'deviceId': _deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
          'courseId': courseId,
          'kind': kind,
          'startUtc': start != null ? Timestamp.fromDate(start.toUtc()) : null,
          'expectedEndUtc': expectedEnd != null
              ? Timestamp.fromDate(expectedEnd.toUtc())
              : null,
        },
        'isStudying': true,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_uid == null || _deviceId == null) return;
    final docRef = _firestore.collection('users').doc(_uid);
    // called on app start, just claims the device, active-session restore happens in appstate
    await docRef.set({
      'activeSession': {
        'deviceId': _deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> _claimSession() async {
    if (_uid == null || _deviceId == null) return;
    await _sendHeartbeat();
  }

  void _listenActiveSession() {
    if (_uid == null || _deviceId == null) return;
    _activeSessionSub = _firestore
        .collection('users')
        .doc(_uid)
        .snapshots()
        .listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;
      final active = data['activeSession'];
      if (active is Map && active['deviceId'] is String) {
        final currentDevice = active['deviceId'] as String;
        if (currentDevice.isNotEmpty && currentDevice != _deviceId) {
          if (_onForcedLogout != null) {
            await _onForcedLogout!.call();
          }
        }
      }
    });
  }

  Future<void> _pushUser(LocalUserDoc doc) async {
    if (_uid == null) return;
    final ref = _firestore.collection('users').doc(_uid);
    await ref.set(_userToRemote(doc), SetOptions(merge: true));
    doc.dirty = false;
    doc.updatedAtMs = _now();
    await doc.save();
    final state = _db.syncStateForKey(_userStateKey);
    state.lastPushMs = doc.updatedAtMs;
    await _db.putSyncState(state);
  }

  Future<int> _pullUser({bool full = false}) async {
    if (_uid == null) return 0;
    var reads = 0;
    final ref = _firestore.collection('users').doc(_uid);
    final snapshot = await ref.get(GetOptions(source: Source.server));
    _hasPulledUser = true;
    if (snapshot.exists) reads++;
    final data = snapshot.data();
    if (data == null) return reads;
    final updatedAt = _timestampToMs(data['updatedAt']);
    final local = _db.ensureUserDoc();
    final state = _db.syncStateForKey(_userStateKey);
    final preferRemote = _bootstrapping || !_db.hasBootstrapCache();
    final resolvedUpdatedAt = updatedAt > 0 ? updatedAt : _now();

    if (!preferRemote) {
      if (!full && updatedAt <= local.updatedAtMs && !local.dirty) {
        state.lastPullMs = max(state.lastPullMs, updatedAt);
        await _db.putSyncState(state);
        return reads;
      }
      if (local.dirty && updatedAt <= local.updatedAtMs) {
        return reads;
      }
      if (local.dirty && updatedAt > local.updatedAtMs) {
        // local has unpushed changes, keep them, they go out on the next sync cycle
        await _db.logConflict(
          collection: 'users',
          entityId: local.id,
          localUpdatedAtMs: local.updatedAtMs,
          remoteUpdatedAtMs: updatedAt,
          resolvedWithRemote: false, // local wins to preserve settings
        );
        return reads;
      }
    }

    Future<void> seedMeta(String key, dynamic value) async {
      if (value == null) return;
      if (!_bootstrapping && _db.getMeta(key) != null) return;
      await _db.putMeta(key, value);
    }

    String? normalizeThemeMode(String? value) {
      switch (value) {
        case 'light':
        case 'dark':
        case 'system':
          return value;
        default:
          return null;
      }
    }

    String? normalizeWeekStart(String? value) {
      if (value == 'sunday') return 'sunday';
      if (value == 'monday') return 'monday';
      return null;
    }

    String? normalizeProgressView(String? value) {
      if (value == 'week' || value == 'day' || value == 'off') return value;
      return null;
    }

    String? normalizeHomeSummaryRange(String? value) {
      const allowed = {'today', 'week', 'month', 'year', 'allTime', 'off'};
      if (value != null && allowed.contains(value)) {
        return value;
      }
      return null;
    }

    await seedMeta(
      _metaThemeModeKey,
      normalizeThemeMode(data['themeMode'] as String?),
    );
    await seedMeta(
      _metaWeekStartKey,
      normalizeWeekStart(data['weekStart'] as String?),
    );
    await seedMeta(
      _metaProgressViewKey,
      normalizeProgressView(data['progressView'] as String?),
    );
    await seedMeta(
      _metaHomeSummaryRangeKey,
      normalizeHomeSummaryRange(data['homeSummaryRange'] as String?),
    );
    await seedMeta(_metaQuickNotesKey, data['quickNotesEnabled'] as bool?);
    await seedMeta(_metaAllowNudgesKey, data['allowNudges'] as bool?);
    await seedMeta(
      _metaEisenhowerKey,
      data['eisenhowerMatrixEnabled'] as bool?,
    );

    final remoteAvatarIndex = (data['avatarIndex'] as num?)?.toInt() ??
        (data['profileAvatarIndex'] as num?)?.toInt();
    final remoteAvatarBase64 = data['avatarImageBase64'] as String? ??
        data['profileAvatarImageBase64'] as String?;
    local
      ..profileName = data['profileName'] as String?
      ..profileGoal = data['profileGoal'] as String?
      ..major = data['major'] as String?
      ..profileContact = data['profileContact'] as String?
      ..avatarIndex = remoteAvatarIndex
      ..avatarImage = _decodeAvatar(remoteAvatarBase64)
      ..themeMode = data['themeMode'] as String?
      ..weekStart = (data['weekStart'] as String?) ?? local.weekStart
      ..progressView = (data['progressView'] as String?) ?? local.progressView
      ..homeSummaryRange =
          (data['homeSummaryRange'] as String?) ?? local.homeSummaryRange
      ..pendingCoursePrompt =
          (data['pendingCoursePrompt'] as bool?) ?? local.pendingCoursePrompt
      ..avatarColorValue = (data['avatarColorValue'] as num?)?.toInt() ??
          (data['profileAvatarColorValue'] as num?)?.toInt()
      ..profileComplete =
          (data['profileComplete'] as bool?) ?? local.profileComplete
      ..onboardingCompleted = data['onboardingCompleted'] == true ||
          data['profileComplete'] == true ||
          local.onboardingCompleted
      ..allowNudges = (data['allowNudges'] as bool?) ?? local.allowNudges
      ..quickNotesEnabled =
          (data['quickNotesEnabled'] as bool?) ?? local.quickNotesEnabled
      ..eisenhowerMatrixEnabled = (data['eisenhowerMatrixEnabled'] as bool?) ??
          local.eisenhowerMatrixEnabled
      ..dirty = false
      ..updatedAtMs = resolvedUpdatedAt;
    final remoteBootstrapVersion = (data['bootstrapVersion'] as num?)?.toInt();
    if (remoteBootstrapVersion != null) {
      local.bootstrapVersion = remoteBootstrapVersion;
    }
    await local.save();
    state.lastPullMs = max(state.lastPullMs, resolvedUpdatedAt);
    await _db.putSyncState(state);
    if (_bootstrapping) {
      _bootstrapping = false;
      // start listening for session conflicts now that bootstrap is done
      _listenActiveSession();
    }
    return reads;
  }

  Future<int> _pullCollection({
    required String collection,
    required String stateKey,
    required Future<void> Function(
      QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
    ) mapper,
    required bool full,
    int limit = 200,
  }) async {
    if (_uid == null) return 0;
    final state = _db.syncStateForKey(stateKey);
    var cursor = full ? 0 : state.lastPullMs;

    Query<Map<String, dynamic>> baseQuery =
        _firestore.collection('users').doc(_uid).collection(collection);

    if (cursor > 0) {
      baseQuery = baseQuery.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(cursor),
      );
    }
    baseQuery = baseQuery.orderBy('updatedAt');

    Query<Map<String, dynamic>> pageQuery = baseQuery;
    var maxSeen = cursor;
    var readCount = 0;

    while (true) {
      final snapshot =
          await pageQuery.limit(limit).get(GetOptions(source: Source.server));
      if (snapshot.docs.isEmpty) {
        break;
      }
      readCount += snapshot.docs.length;
      for (final doc in snapshot.docs) {
        await mapper(doc);
        maxSeen = max(maxSeen, _timestampToMs(doc.data()['updatedAt']));
      }
      if (snapshot.docs.length < limit) {
        break;
      }
      final lastDoc = snapshot.docs.last;
      pageQuery = baseQuery.startAfterDocument(lastDoc);
    }

    state.lastPullMs = max(state.lastPullMs, maxSeen);
    await _db.putSyncState(state);
    return readCount;
  }

  Future<void> _applyRemoteCourse(
      QueryDocumentSnapshot<Map<String, dynamic>> snapshot) async {
    final data = snapshot.data();
    final updatedAt = _timestampToMs(data['updatedAt']);
    var course = _db.getCourseById(snapshot.id);
    if (course == null) {
      course = LocalCourse(
        id: snapshot.id,
        uid: _uid!,
        name: data['name'] as String? ?? '',
        day: data['day'] as String? ?? '',
        start: data['start'] as String? ?? '',
        end: data['end'] as String? ?? '',
        colorValue: (data['colorValue'] as num?)?.toInt() ?? 0,
        credits: (data['credits'] as num?)?.toDouble(),
        expLevel: (data['expLevel'] as num?)?.toInt(),
        goalHours: (data['goalHours'] as num?)?.toDouble(),
        totalMinutes: (data['totalMinutes'] as num?)?.toInt() ?? 0,
        pomodoroLongBreakMinutes:
            (data['pomodoroLongBreakMinutes'] as num?)?.toInt(),
        sortOrder: (data['sortOrder'] as num?)?.toInt(),
        hiddenFromLeaderboard: data['hiddenFromLeaderboard'] == true,
        updatedAtMs: updatedAt,
        dirty: false,
        deleted: data['deleted'] == true,
      );
      await _db.putCourse(course);
      return;
    }

    if (course.dirty && updatedAt <= course.updatedAtMs) {
      return;
    }

    if (course.dirty && updatedAt > course.updatedAtMs) {
      await _db.logConflict(
        collection: 'courses',
        entityId: course.id,
        localUpdatedAtMs: course.updatedAtMs,
        remoteUpdatedAtMs: updatedAt,
        resolvedWithRemote: true,
      );
    }

    course
      ..name = data['name'] as String? ?? course.name
      ..day = data['day'] as String? ?? course.day
      ..start = data['start'] as String? ?? course.start
      ..end = data['end'] as String? ?? course.end
      ..colorValue = (data['colorValue'] as num?)?.toInt() ?? course.colorValue
      ..credits = (data['credits'] as num?)?.toDouble()
      ..expLevel = (data['expLevel'] as num?)?.toInt()
      ..goalHours = (data['goalHours'] as num?)?.toDouble()
      ..goalHours = (data['goalHours'] as num?)?.toDouble()
      ..sortOrder = (data['sortOrder'] as num?)?.toInt() ?? course.sortOrder
      ..hiddenFromLeaderboard = data['hiddenFromLeaderboard'] == true
      ..deleted = data['deleted'] == true
      ..updatedAtMs = updatedAt
      ..dirty = false;
    await course.save();
  }

  Future<void> _applyRemoteSession(
      QueryDocumentSnapshot<Map<String, dynamic>> snapshot) async {
    final data = snapshot.data();
    final updatedAt = _timestampToMs(data['updatedAt']);
    var session = _db.getSessionById(snapshot.id);

    if (!snapshot.exists) {
      if (session != null && !session.deleted) {
        session.deleted = true;
        session.dirty = false;
        session.updatedAtMs = updatedAt;
        await session.save();
      }
      return;
    }

    final startUtc = _timestampToMs(data['startUtc']);
    final endUtc = _timestampToMs(data['endUtc']);
    if (session == null) {
      session = LocalSession(
        id: snapshot.id,
        uid: _uid!,
        courseId: data['courseId'] as String? ?? '',
        startUtcMs: startUtc,
        endUtcMs: endUtc,
        seconds: (data['seconds'] as num?)?.toInt() ?? 0,
        kind: data['kind'] as String?,
        notes: data['notes'] as String?,
        createdAtMs: _timestampToMs(data['createdAt']),
        updatedAtMs: updatedAt,
        dirty: false,
        deleted: data['deleted'] == true,
      );
      await _db.putSession(session);
      return;
    }

    if (session.dirty && updatedAt <= session.updatedAtMs) {
      return;
    }

    if (session.dirty && updatedAt > session.updatedAtMs) {
      await _db.logConflict(
        collection: 'sessions',
        entityId: session.id,
        localUpdatedAtMs: session.updatedAtMs,
        remoteUpdatedAtMs: updatedAt,
        resolvedWithRemote: true,
      );
    }

    session
      ..courseId = data['courseId'] as String? ?? session.courseId
      ..startUtcMs = startUtc
      ..endUtcMs = endUtc
      ..seconds = (data['seconds'] as num?)?.toInt() ?? session.seconds
      ..kind = data['kind'] as String?
      ..notes = data['notes'] as String?
      ..deleted = data['deleted'] == true
      ..updatedAtMs = updatedAt
      ..dirty = false;
    await session.save();
  }

  Future<void> _applyRemoteGoal(
      QueryDocumentSnapshot<Map<String, dynamic>> snapshot) async {
    final data = snapshot.data();
    final updatedAt = _timestampToMs(data['updatedAt']);
    var goal = _db.getGoalById(snapshot.id);
    if (goal == null) {
      goal = LocalGoal(
        id: snapshot.id,
        uid: _uid!,
        hours: (data['hours'] as num?)?.toDouble(),
        updatedAtMs: updatedAt,
        dirty: false,
        deleted: data['deleted'] == true,
      );
      await _db.putGoal(goal);
    } else {
      if (goal.dirty && updatedAt <= goal.updatedAtMs) {
        return;
      }
      if (goal.dirty && updatedAt > goal.updatedAtMs) {
        await _db.logConflict(
          collection: 'goals',
          entityId: goal.id,
          localUpdatedAtMs: goal.updatedAtMs,
          remoteUpdatedAtMs: updatedAt,
          resolvedWithRemote: true,
        );
      }
      goal
        ..hours = (data['hours'] as num?)?.toDouble()
        ..deleted = data['deleted'] == true
        ..updatedAtMs = updatedAt
        ..dirty = false;
      await goal.save();
    }

    final course = _db.getCourseById(snapshot.id);
    if (course != null) {
      course.goalHours = goal.hours;
      await course.save();
    }
  }

  Future<void> _applyRemoteHabit(
      QueryDocumentSnapshot<Map<String, dynamic>> snapshot) async {
    final data = snapshot.data();
    final updatedAt = _timestampToMs(data['updatedAt']);
    var habit = _db.getHabitById(snapshot.id);
    final resetAtMs = _timestampToMs(data['rs'] ?? data['latestResetAt']);
    final localResetAtMs = habit?.resetAtMs ?? 0;

    // parse stats map
    final statsMap =
        (data['st'] ?? data['stats'] ?? {}) as Map<String, dynamic>;
    final totalCompletions =
        ((statsMap['tc'] ?? statsMap['totalCompletions']) as num?)?.toInt() ??
            0;
    final currentStreak =
        ((statsMap['cs'] ?? statsMap['currentStreak']) as num?)?.toInt() ?? 0;
    final longestStreak =
        ((statsMap['ls'] ?? statsMap['longestStreak']) as num?)?.toInt() ?? 0;

    // parse last7 into a json string
    final last7Raw = data['l7'] ?? data['last7'] ?? {};
    final last7Json = last7Raw is Map ? jsonEncode(last7Raw) : '{}';

    // parse dates
    int startDateMs = DateTime.now().millisecondsSinceEpoch;
    if (data['sd'] is Timestamp) {
      startDateMs = (data['sd'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else if (data['startDate'] is Timestamp) {
      startDateMs =
          (data['startDate'] as Timestamp).toDate().millisecondsSinceEpoch;
    }

    int? endDateMs;
    if (data['ed'] is Timestamp) {
      endDateMs = (data['ed'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else if (data['endDate'] is Timestamp) {
      endDateMs =
          (data['endDate'] as Timestamp).toDate().millisecondsSinceEpoch;
    }

    int createdAtMs = DateTime.now().millisecondsSinceEpoch;
    if (data['cr'] is Timestamp) {
      createdAtMs = (data['cr'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else if (data['createdAt'] is Timestamp) {
      createdAtMs =
          (data['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch;
    }

    // parse week days
    final weekDaysRaw = data['wd'] ?? data['weekDays'] ?? [];
    final weekDays =
        (weekDaysRaw as List).map((e) => (e as num).toInt()).toList();

    // parse connected course ids
    final ccRaw = data['cc'] ?? data['connectedCourseIds'] ?? [];
    final connectedCourseIds =
        (ccRaw as List).map((e) => e.toString()).toList();

    if (habit == null) {
      habit = LocalHabit(
        id: snapshot.id,
        uid: _uid!,
        updatedAtMs: updatedAt,
        name: (data['n'] ?? data['name'] ?? 'Unnamed') as String,
        colorValue:
            ((data['cl'] ?? data['color']) as num?)?.toInt() ?? 0xFF000000,
        iconCodePoint:
            ((data['ic'] ?? data['iconCodePoint']) as num?)?.toInt() ?? 0xe156,
        iconFamily: data['if'] as String? ?? data['iconFamily'] as String?,
        iconPackage: data['ip'] as String? ?? data['iconPackage'] as String?,
        category: (data['ca'] ?? data['category'] ?? 'Other') as String,
        typeIndex: (data['t'] as num?)?.toInt() ?? 0,
        targetValue: (data['tv'] as num?)?.toDouble() ?? 1.0,
        unit: data['u'] as String? ?? data['unit'] as String?,
        comparatorIndex: (data['co'] as num?)?.toInt() ?? 0,
        frequencyTypeIndex: (data['fq'] as num?)?.toInt() ?? 1,
        weekDays: weekDays,
        intervalDays: (data['iv'] as num?)?.toInt() ?? 1,
        frequencyPeriodIndex: (data['fp'] as num?)?.toInt(),
        frequencyGoal: (data['fg'] as num?)?.toInt(),
        startDateMs: startDateMs,
        endDateMs: endDateMs,
        totalCompletions: totalCompletions,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        sortOrder: (data['so'] as num?)?.toInt() ?? 0,
        last7Json: last7Json,
        archived: data['ar'] == true || data['archived'] == true,
        createdAtMs: createdAtMs,
        connectedCourseIds: connectedCourseIds,
        resetAtMs: resetAtMs > 0 ? resetAtMs : null,
        dirty: false,
        deleted: data['deleted'] == true,
      );
      await _db.putHabit(habit);
      return;
    }

    if (resetAtMs > 0 && resetAtMs > localResetAtMs) {
      await _clearLocalHabitProgressForReset(habit, resetAtMs);
    }

    // skip when local is dirty or newer than the incoming remote
    if (habit.dirty || habit.updatedAtMs > updatedAt) {
      return;
    }

    habit
      ..name = (data['n'] ?? data['name'] ?? habit.name) as String
      ..colorValue =
          ((data['cl'] ?? data['color']) as num?)?.toInt() ?? habit.colorValue
      ..iconCodePoint =
          ((data['ic'] ?? data['iconCodePoint']) as num?)?.toInt() ??
              habit.iconCodePoint
      ..iconFamily = data['if'] as String? ?? data['iconFamily'] as String?
      ..iconPackage = data['ip'] as String? ?? data['iconPackage'] as String?
      ..category = (data['ca'] ?? data['category'] ?? habit.category) as String
      ..typeIndex = (data['t'] as num?)?.toInt() ?? habit.typeIndex
      ..targetValue = (data['tv'] as num?)?.toDouble() ?? habit.targetValue
      ..unit = data['u'] as String? ?? data['unit'] as String?
      ..comparatorIndex = (data['co'] as num?)?.toInt() ?? habit.comparatorIndex
      ..frequencyTypeIndex =
          (data['fq'] as num?)?.toInt() ?? habit.frequencyTypeIndex
      ..weekDays = weekDays
      ..intervalDays = (data['iv'] as num?)?.toInt() ?? habit.intervalDays
      ..frequencyPeriodIndex = (data['fp'] as num?)?.toInt()
      ..frequencyGoal = (data['fg'] as num?)?.toInt()
      ..startDateMs = startDateMs
      ..endDateMs = endDateMs
      ..totalCompletions = totalCompletions
      ..currentStreak = currentStreak
      ..longestStreak = longestStreak
      ..sortOrder = (data['so'] as num?)?.toInt() ?? habit.sortOrder
      ..last7Json = last7Json
      ..archived = data['ar'] == true || data['archived'] == true
      ..createdAtMs = createdAtMs
      ..connectedCourseIds = connectedCourseIds
      ..deleted = data['deleted'] == true
      ..resetAtMs = resetAtMs > 0 ? resetAtMs : habit.resetAtMs
      ..updatedAtMs = updatedAt
      ..dirty = false;
    await habit.save();
  }

  static const _habitHistoryStateKey = 'habit_history';

  Future<int> _pullHabitHistory({bool full = false}) async {
    if (_uid == null) return 0;
    final state = _db.syncStateForKey(_habitHistoryStateKey);
    final cursor = full ? 0 : state.lastPullMs;
    var maxSeen = cursor;
    var readCount = 0;

    // pull history for all non-deleted habits
    final habits = _db.habits(includeDeleted: false).toList();
    if (habits.isEmpty) return 0;

    for (final habit in habits) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .doc(_uid)
          .collection('habits')
          .doc(habit.id)
          .collection('history');

      if (cursor > 0) {
        query = query.where(
          'updatedAt',
          isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(cursor),
        );
      }

      final snapshot = await query.get(GetOptions(source: Source.server));
      readCount += snapshot.docs.length;
      for (final doc in snapshot.docs) {
        await _applyRemoteHabitHistory(habit.id, doc);
        maxSeen = max(maxSeen, _timestampToMs(doc.data()['updatedAt']));
      }
    }

    state.lastPullMs = max(state.lastPullMs, maxSeen);
    await _db.putSyncState(state);
    return readCount;
  }

  Future<void> _applyRemoteHabitHistory(
    String habitId,
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final data = snapshot.data();
    final updatedAt = _timestampToMs(data['updatedAt']);
    final habit = _db.getHabitById(habitId);
    final resetAtMs = habit?.resetAtMs ?? 0;
    if (resetAtMs > 0 && updatedAt < resetAtMs) {
      return;
    }
    final dateKey =
        snapshot.id; // firestore history ids are datekeys (yyyy-mm-dd)
    final id = '${habitId}_$dateKey';

    var history = _db.getHabitHistoryById(id);
    if (history == null) {
      history = LocalHabitHistory(
        id: id,
        uid: _uid!,
        habitId: habitId,
        dateKey: dateKey,
        completedAtMs: _timestampToMs(data['ts'] ?? data['timestamp']),
        updatedAtMs: updatedAt,
        value: (data['v'] ?? data['value'] as num?)?.toDouble() ?? 1.0,
        manualValue: (data['m'] as num?)?.toDouble(),
        note: data['note'] as String?,
        dirty: false,
        deleted: data['deleted'] == true,
      );
      await _db.putHabitHistory(history);
      return;
    }

    // skip when local is dirty or newer/equal
    if (history.dirty || history.updatedAtMs >= updatedAt) return;

    history
      ..completedAtMs = _timestampToMs(data['ts'] ?? data['timestamp'])
      ..value = (data['v'] ?? data['value'] as num?)?.toDouble() ?? 1.0
      ..manualValue = (data['m'] as num?)?.toDouble()
      ..note = (data['note'] as String?)
      ..deleted = data['deleted'] == true
      ..updatedAtMs = updatedAt
      ..dirty = false;
    await history.save();
  }

  Future<void> _clearLocalHabitProgressForReset(
    LocalHabit habit,
    int resetAtMs,
  ) async {
    final entries =
        _db.habitHistoryForHabit(habit.id, includeDeleted: true).toList();
    for (final entry in entries) {
      await _db.habitHistoryBox.delete(entry.id);
    }
    habit
      ..totalCompletions = 0
      ..currentStreak = 0
      ..longestStreak = 0
      ..last7Json = '{}'
      ..resetAtMs = resetAtMs
      ..resetPending = false
      ..updatedAtMs = max(habit.updatedAtMs, resetAtMs)
      ..dirty = false;
    await habit.save();
  }

  Future<void> _deleteRemoteHabitHistory(String habitId) async {
    if (_uid == null) return;
    final historyRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('habits')
        .doc(habitId)
        .collection('history');

    const batchSize = 400;
    while (true) {
      final snapshot = await historyRef.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < batchSize) break;
    }
  }

  Map<String, dynamic> _userToRemote(LocalUserDoc doc) {
    final avatarBase64 =
        (doc.avatarImage != null && doc.avatarImage!.isNotEmpty)
            ? base64Encode(doc.avatarImage!)
            : null;
    final hasCustomAvatar = avatarBase64 != null;
    final avatarIndex = hasCustomAvatar ? null : doc.avatarIndex;
    final payload = <String, dynamic>{
      'uid': doc.uid,
      'displayName': doc.profileName,
      'profileName': doc.profileName,
      'profileGoal': doc.profileGoal,
      'major': doc.major,
      'profileContact': doc.profileContact,
      'avatarIndex': avatarIndex,
      'profileAvatarIndex': avatarIndex,
      'avatarImageBase64': hasCustomAvatar ? avatarBase64 : null,
      'profileAvatarImageBase64': hasCustomAvatar ? avatarBase64 : null,
      'pendingCoursePrompt': doc.pendingCoursePrompt,
      'avatarColorValue': doc.avatarColorValue,
      'profileAvatarColorValue': doc.avatarColorValue,
      'profileComplete': doc.profileComplete,
      'onboardingCompleted': doc.onboardingCompleted,
      'bootstrapVersion': doc.bootstrapVersion,
      'allowNudges': doc.allowNudges,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // dont overwrite remote fields with nulls when the local cache is empty
    payload.removeWhere((_, value) => value == null);
    return payload;
  }

  Map<String, dynamic> _courseToRemote(LocalCourse course) {
    return {
      'uid': course.uid,
      'name': course.name,
      'day': course.day,
      'start': course.start,
      'end': course.end,
      'colorValue': course.colorValue,
      'credits': course.credits,
      'expLevel': course.expLevel,
      'goalHours': course.goalHours,
      'totalMinutes': course.totalMinutes,
      'pomodoroLongBreakMinutes': course.pomodoroLongBreakMinutes,
      'sortOrder': course.sortOrder,
      'hiddenFromLeaderboard': course.hiddenFromLeaderboard,
      'deleted': course.deleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _sessionToRemote(LocalSession session) {
    return {
      'uid': session.uid,
      'courseId': session.courseId,
      'startUtc': Timestamp.fromMillisecondsSinceEpoch(session.startUtcMs),
      'endUtc': Timestamp.fromMillisecondsSinceEpoch(session.endUtcMs),
      'seconds': session.seconds,
      'kind': session.kind,
      'notes': session.notes,
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(session.createdAtMs),
      'deleted': session.deleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _goalToRemote(LocalGoal goal) {
    return {
      'uid': goal.uid,
      'hours': goal.hours,
      'deleted': goal.deleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _habitToRemote(LocalHabit habit) {
    final resetAtMs = habit.resetAtMs;
    final payload = {
      'n': habit.name,
      'cl': habit.colorValue,
      'ic': habit.iconCodePoint,
      'if': habit.iconFamily,
      'ip': habit.iconPackage,
      'ca': habit.category,
      't': habit.typeIndex,
      'tv': habit.targetValue,
      'u': habit.unit,
      'co': habit.comparatorIndex,
      'fq': habit.frequencyTypeIndex,
      'wd': habit.weekDays,
      'iv': habit.intervalDays,
      'fp': habit.frequencyPeriodIndex,
      'fg': habit.frequencyGoal,
      'sd': Timestamp.fromMillisecondsSinceEpoch(habit.startDateMs),
      'ed': habit.endDateMs != null
          ? Timestamp.fromMillisecondsSinceEpoch(habit.endDateMs!)
          : null,
      'st': {
        'tc': habit.totalCompletions,
        'cs': habit.currentStreak,
        'ls': habit.longestStreak,
      },
      'so': habit.sortOrder,
      'l7': habit.last7Json.isNotEmpty ? _decodeJsonMap(habit.last7Json) : {},
      'ar': habit.archived,
      'cr': Timestamp.fromMillisecondsSinceEpoch(habit.createdAtMs),
      'cc': habit.connectedCourseIds,
      'rs': resetAtMs != null
          ? Timestamp.fromMillisecondsSinceEpoch(resetAtMs)
          : null,
      'deleted': habit.deleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    payload.removeWhere((_, value) => value == null);
    return payload;
  }

  Map<String, dynamic>? _decodeJsonMap(String json) {
    if (json.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return null;
    }
  }

  int _timestampToMs(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().millisecondsSinceEpoch;
    }
    if (value is DateTime) {
      return value.toUtc().millisecondsSinceEpoch;
    }
    if (value is int) {
      return value;
    }
    return 0;
  }

  Uint8List? _decodeAvatar(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(base64Str));
    } catch (_) {
      return null;
    }
  }

  int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  bool _computeOnlineStatus(dynamic payload) {
    if (payload is ConnectivityResult) {
      return payload != ConnectivityResult.none;
    }
    if (payload is List<ConnectivityResult>) {
      return payload.any((result) => result != ConnectivityResult.none);
    }
    return false;
  }

  void addAfterPullListener(Future<void> Function() listener) {
    _afterPullListeners.add(listener);
  }

  void removeAfterPullListener(Future<void> Function() listener) {
    _afterPullListeners.remove(listener);
  }

  Future<void> _notifyAfterPullListeners() async {
    for (final listener
        in List<Future<void> Function()>.from(_afterPullListeners)) {
      try {
        await listener();
      } catch (_) {}
    }
  }
}
