import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../data/local/entities.dart';
import '../data/local/local_database.dart';

enum SyncStatus { offline, syncing, upToDate }

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

  SyncStatus _status = SyncStatus.offline;
  SyncStatus get status => _status;

  String? _uid;
  String? _deviceId;
  bool _online = false;
  bool _isRunning = false;
  bool _isSyncing = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _activeSessionSub;
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

    await _db.openForUser(uid);

    _isRunning = true;

    await _checkConnectivity();

    _connectivitySub =
        _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _online = _computeOnlineStatus(results);
      if (_online) {
        unawaited(syncNow());
      } else {
        _setStatus(SyncStatus.offline);
      }
    });

    if (_online) {
      // Fire-and-forget: Heartbeat can happen in background, don't block startup
      unawaited(_claimSession());
    }
    _listenActiveSession();

    if (_online) {
      // Optimization: If we are asked to bootstrap (full sync) but we already have
      // a valid sync state (e.g. we have pulled courses before), then we don't
      // need to do a full pull. We can just do a delta pull.
      // This supports "logout -> login" flows where local data is preserved.
      var shouldBootstrap = bootstrap;
      if (shouldBootstrap) {
        final state = _db.syncStateForKey(_coursesStateKey);
        if (state.lastPullMs > 0) {
          shouldBootstrap = false;
        }
      }
      
      if (shouldBootstrap) {
        // New device / first login: AWAIT to ensure data is loaded before proceeding.
        // Without this, the user would see empty screens or incorrect profile prompts.
        await syncNow(full: true);
      } else {
        // Returning user with local data: Fire-and-forget for instant startup.
        // The app shows local data immediately; sync results merge in background.
        unawaited(syncNow(full: false));
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

  Future<void> syncNow({bool full = false}) async {
    if (!_isRunning || _isSyncing || !_online || _uid == null) {
      return;
    }
    _isSyncing = true;
    _setStatus(SyncStatus.syncing);
    lastError = null;
    try {
      await pushDirty();
      await pullSince(full: full);
      _setStatus(SyncStatus.upToDate);
    } catch (err, stack) {
      if (kDebugMode) {
        
        print('Sync failed: $err\n$stack');
      }
      lastError = err.toString();
      _setStatus(SyncStatus.offline);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> pushDirty() async {
    if (!_isRunning  || !_online || _uid == null) {
      if (_uid == null) return;
    }
    
    // Only set status if not already part of a larger sync
    final rootCall = !_isSyncing;
    if (rootCall) {
      _isSyncing = true;
      _setStatus(SyncStatus.syncing);
    }

    try {
      const maxOperations = 450; 
      final userDoc = _db.userDocOrNull;

      if (userDoc != null && userDoc.dirty) {
        await _pushUser(userDoc);
      }

      Future<void> pushChunk<T extends HiveObject>(
        List<T> items,
        Future<void> Function(
          WriteBatch batch,
          T item,
        )
            writer,
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
        for (final s in dirtySessions)
          s.deleted ? s.delete() : s.save(),
        for (final g in dirtyGoals) g.save(),
        if (userDoc != null && userDoc.dirty == false) userDoc.save(),
      ]);

      // Push dirty habits
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
          batch.set(ref, _habitToRemote(habit), SetOptions(merge: true));
        }
        habit.dirty = false;
        habit.updatedAtMs = _now();
      });

      await Future.wait([
        for (final h in dirtyHabits) h.save(),
      ]);

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

  Future<void> pullSince({bool full = false}) async {
    if (_uid == null) return;
    await _pullUser(full: full);
    await _pullCollection(
      collection: 'courses',
      stateKey: _coursesStateKey,
      mapper: _applyRemoteCourse,
      full: full,
      limit: 250,
    );
    await _pullCollection(
      collection: 'sessions',
      stateKey: _sessionsStateKey,
      mapper: _applyRemoteSession,
      full: full,
      limit: 200,
    );
    await _pullCollection(
      collection: 'goals',
      stateKey: _goalsStateKey,
      mapper: _applyRemoteGoal,
      full: full,
      limit: 200,
    );
    await _pullCollection(
      collection: 'habits',
      stateKey: _habitsStateKey,
      mapper: _applyRemoteHabit,
      full: full,
      limit: 200,
    );
    await _pullHabitHistory(full: full);
    lastPull = DateTime.now();
    await _notifyAfterPullListeners();
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
      // Keep the device claim, but clear study data
      await docRef.set({
        'activeSession': {
          'deviceId': _deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
          // Explicitly clear study fields by setting to null or omitting them if we replaced the map
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
          'expectedEndUtc': expectedEnd != null ? Timestamp.fromDate(expectedEnd.toUtc()) : null,
        },
        'isStudying': true,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _sendHeartbeat() async {
    if (_uid == null || _deviceId == null) return;
    final docRef = _firestore.collection('users').doc(_uid);
    // Just update timestamp and deviceId, preserving other fields if we are syncing?
    // Actually, _sendHeartbeat is called on app start. We typically assume no study session is active on fresh start unless we restore it?
    // But local state restoration happens in AppState.
    // So here we just claim the device.
    
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

  Future<void> _pullUser({bool full = false}) async {
    if (_uid == null) return;
    final ref = _firestore.collection('users').doc(_uid);
    final snapshot = await ref.get(GetOptions(source: Source.server));
    final data = snapshot.data();
    if (data == null) return;
    final updatedAt = _timestampToMs(data['updatedAt']);
    final local = _db.ensureUserDoc();
    final state = _db.syncStateForKey(_userStateKey);
    if (!full && updatedAt <= local.updatedAtMs && !local.dirty) {
      state.lastPullMs = max(state.lastPullMs, updatedAt);
      await _db.putSyncState(state);
      return;
    }
    if (local.dirty && updatedAt <= local.updatedAtMs) {
      
      return;
    }
    if (local.dirty && updatedAt > local.updatedAtMs) {
      await _db.logConflict(
        collection: 'users',
        entityId: local.id,
        localUpdatedAtMs: local.updatedAtMs,
        remoteUpdatedAtMs: updatedAt,
        resolvedWithRemote: true,
      );
    }
    final remoteAvatarIndex =
        (data['avatarIndex'] as num?)?.toInt() ??
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
      ..avatarColorValue = (data['avatarColorValue'] as num?)?.toInt() ?? (data['profileAvatarColorValue'] as num?)?.toInt()
      ..profileComplete = (data['profileComplete'] as bool?) ?? local.profileComplete
      ..dirty = false
      ..updatedAtMs = updatedAt;
    await local.save();
    state.lastPullMs = max(state.lastPullMs, updatedAt);
    await _db.putSyncState(state);
  }

  Future<void> _pullCollection({
    required String collection,
    required String stateKey,
    required Future<void> Function(
      QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
    )
        mapper,
    required bool full,
    int limit = 200,
  }) async {
    if (_uid == null) return;
    final state = _db.syncStateForKey(stateKey);
    var cursor = full ? 0 : state.lastPullMs;

    Query<Map<String, dynamic>> baseQuery = _firestore
        .collection('users')
        .doc(_uid)
        .collection(collection);

    if (cursor > 0) {
      baseQuery = baseQuery.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(cursor),
      );
    }
    baseQuery = baseQuery.orderBy('updatedAt');

    Query<Map<String, dynamic>> pageQuery = baseQuery;
    var maxSeen = cursor;

    while (true) {
      final snapshot = await pageQuery
          .limit(limit)
          .get(GetOptions(source: Source.server));
      if (snapshot.docs.isEmpty) {
        break;
      }
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

    // Parse stats map
    final statsMap = (data['st'] ?? data['stats'] ?? {}) as Map<String, dynamic>;
    final totalCompletions = ((statsMap['tc'] ?? statsMap['totalCompletions']) as num?)?.toInt() ?? 0;
    final currentStreak = ((statsMap['cs'] ?? statsMap['currentStreak']) as num?)?.toInt() ?? 0;
    final longestStreak = ((statsMap['ls'] ?? statsMap['longestStreak']) as num?)?.toInt() ?? 0;

    // Parse last7 to JSON string
    final last7Raw = data['l7'] ?? data['last7'] ?? {};
    final last7Json = last7Raw is Map ? jsonEncode(last7Raw) : '{}';

    // Parse dates
    int startDateMs = DateTime.now().millisecondsSinceEpoch;
    if (data['sd'] is Timestamp) {
      startDateMs = (data['sd'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else if (data['startDate'] is Timestamp) {
      startDateMs = (data['startDate'] as Timestamp).toDate().millisecondsSinceEpoch;
    }

    int? endDateMs;
    if (data['ed'] is Timestamp) {
      endDateMs = (data['ed'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else if (data['endDate'] is Timestamp) {
      endDateMs = (data['endDate'] as Timestamp).toDate().millisecondsSinceEpoch;
    }

    int createdAtMs = DateTime.now().millisecondsSinceEpoch;
    if (data['cr'] is Timestamp) {
      createdAtMs = (data['cr'] as Timestamp).toDate().millisecondsSinceEpoch;
    } else if (data['createdAt'] is Timestamp) {
      createdAtMs = (data['createdAt'] as Timestamp).toDate().millisecondsSinceEpoch;
    }

    // Parse weekDays
    final weekDaysRaw = data['wd'] ?? data['weekDays'] ?? [];
    final weekDays = (weekDaysRaw as List).map((e) => (e as num).toInt()).toList();

    // Parse connectedCourseIds
    final ccRaw = data['cc'] ?? data['connectedCourseIds'] ?? [];
    final connectedCourseIds = (ccRaw as List).map((e) => e.toString()).toList();

    if (habit == null) {
      habit = LocalHabit(
        id: snapshot.id,
        uid: _uid!,
        updatedAtMs: updatedAt,
        name: (data['n'] ?? data['name'] ?? 'Unnamed') as String,
        colorValue: ((data['cl'] ?? data['color']) as num?)?.toInt() ?? 0xFF000000,
        iconCodePoint: ((data['ic'] ?? data['iconCodePoint']) as num?)?.toInt() ?? 0xe156,
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
        dirty: false,
        deleted: data['deleted'] == true,
      );
      await _db.putHabit(habit);
      return;
    }

    // Skip if local is dirty and newer
    if (habit.dirty && updatedAt <= habit.updatedAtMs) {
      return;
    }

    // Log conflict if local is dirty but remote is newer
    if (habit.dirty && updatedAt > habit.updatedAtMs) {
      await _db.logConflict(
        collection: 'habits',
        entityId: habit.id,
        localUpdatedAtMs: habit.updatedAtMs,
        remoteUpdatedAtMs: updatedAt,
        resolvedWithRemote: true,
      );
    }

    habit
      ..name = (data['n'] ?? data['name'] ?? habit.name) as String
      ..colorValue = ((data['cl'] ?? data['color']) as num?)?.toInt() ?? habit.colorValue
      ..iconCodePoint = ((data['ic'] ?? data['iconCodePoint']) as num?)?.toInt() ?? habit.iconCodePoint
      ..iconFamily = data['if'] as String? ?? data['iconFamily'] as String?
      ..iconPackage = data['ip'] as String? ?? data['iconPackage'] as String?
      ..category = (data['ca'] ?? data['category'] ?? habit.category) as String
      ..typeIndex = (data['t'] as num?)?.toInt() ?? habit.typeIndex
      ..targetValue = (data['tv'] as num?)?.toDouble() ?? habit.targetValue
      ..unit = data['u'] as String? ?? data['unit'] as String?
      ..comparatorIndex = (data['co'] as num?)?.toInt() ?? habit.comparatorIndex
      ..frequencyTypeIndex = (data['fq'] as num?)?.toInt() ?? habit.frequencyTypeIndex
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
      ..updatedAtMs = updatedAt
      ..dirty = false;
    await habit.save();
  }

  static const _habitHistoryStateKey = 'habit_history';

  Future<void> _pullHabitHistory({bool full = false}) async {
    if (_uid == null) return;
    final state = _db.syncStateForKey(_habitHistoryStateKey);
    final cursor = full ? 0 : state.lastPullMs;
    var maxSeen = cursor;

    // We pull history for all non-deleted habits. 
    // Optimization: Only pull for habits that were recently synchronized or are active.
    final habits = _db.habits(includeDeleted: false).toList();
    if (habits.isEmpty) return;

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
      for (final doc in snapshot.docs) {
        await _applyRemoteHabitHistory(habit.id, doc);
        maxSeen = max(maxSeen, _timestampToMs(doc.data()['updatedAt']));
      }
    }

    state.lastPullMs = max(state.lastPullMs, maxSeen);
    await _db.putSyncState(state);
  }

  Future<void> _applyRemoteHabitHistory(
    String habitId,
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final data = snapshot.data();
    final updatedAt = _timestampToMs(data['updatedAt']);
    final dateKey = snapshot.id; // Corrected: Firestore history IDs are dateKeys (YYYY-MM-DD)
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

    if (history.dirty && updatedAt <= history.updatedAtMs) {
      return;
    }

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

  Map<String, dynamic> _userToRemote(LocalUserDoc doc) {
    final avatarBase64 = (doc.avatarImage != null && doc.avatarImage!.isNotEmpty)
        ? base64Encode(doc.avatarImage!)
        : null;
    final hasCustomAvatar = avatarBase64 != null;
    final avatarIndex = hasCustomAvatar ? null : doc.avatarIndex;
    return {
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
      'themeMode': doc.themeMode,
      'weekStart': doc.weekStart,
      'progressView': doc.progressView,
      'homeSummaryRange': doc.homeSummaryRange,
      'pendingCoursePrompt': doc.pendingCoursePrompt,
      'avatarColorValue': doc.avatarColorValue,
      'profileAvatarColorValue': doc.avatarColorValue,
      'profileComplete': doc.profileComplete,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
    return {
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
      'ed': habit.endDateMs != null ? Timestamp.fromMillisecondsSinceEpoch(habit.endDateMs!) : null,
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
      'deleted': habit.deleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
    for (final listener in List<Future<void> Function()>.from(_afterPullListeners)) {
      try {
        await listener();
      } catch (_) {
        
      }
    }
  }
}
