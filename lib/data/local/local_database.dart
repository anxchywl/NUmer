import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import 'entities.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  static const bootstrapMetaKey = 'bootstrap_version_v1';
  static const streakMetaKey = 'streak_snapshot_v1';

  bool _initialized = false;
  String? _currentUid;

  Box<LocalUserDoc>? _userBox;
  Box<LocalCourse>? _coursesBox;
  Box<LocalSession>? _sessionsBox;
  Box<LocalGoal>? _goalsBox;
  Box<SyncStateEntry>? _syncBox;
  Box<LocalConflict>? _conflictsBox;
  Box<dynamic>? _metaBox;

  Box<LocalSession>? _peerSessionsBox;
  Box<LocalCourse>? _peerCoursesBox;
  Box<LocalHabit>? _habitsBox;
  Box<LocalHabitHistory>? _habitHistoryBox;

  Future<void> initCore() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _registerAdapters();
    _initialized = true;
  }

  Future<void> openForUser(String uid) async {
    await initCore();
    if (_currentUid == uid) return;
    await close();
    _currentUid = uid;
    
    // Open all boxes in parallel for faster startup
    final results = await Future.wait([
      Hive.openBox<LocalUserDoc>('${uid}_user'),
      Hive.openBox<LocalCourse>('${uid}_courses'),
      Hive.openBox<LocalSession>('${uid}_sessions'),
      Hive.openBox<LocalGoal>('${uid}_goals'),
      Hive.openBox<SyncStateEntry>('${uid}_sync'),
      Hive.openBox<LocalConflict>('${uid}_conflicts'),
      Hive.openBox('${uid}_meta'),
      Hive.openBox<LocalSession>('${uid}_peer_sessions'),
      Hive.openBox<LocalCourse>('${uid}_peer_courses'),
      Hive.openBox<LocalHabit>('${uid}_habits'),
      Hive.openBox<LocalHabitHistory>('${uid}_habit_history'),
    ]);
    
    _userBox = results[0] as Box<LocalUserDoc>;
    _coursesBox = results[1] as Box<LocalCourse>;
    _sessionsBox = results[2] as Box<LocalSession>;
    _goalsBox = results[3] as Box<LocalGoal>;
    _syncBox = results[4] as Box<SyncStateEntry>;
    _conflictsBox = results[5] as Box<LocalConflict>;
    _metaBox = results[6];
    _peerSessionsBox = results[7] as Box<LocalSession>;
    _peerCoursesBox = results[8] as Box<LocalCourse>;
    _habitsBox = results[9] as Box<LocalHabit>;
    _habitHistoryBox = results[10] as Box<LocalHabitHistory>;
  }

  Future<void> close() async {
    await Future.wait([
      _userBox?.close() ?? Future.value(),
      _coursesBox?.close() ?? Future.value(),
      _sessionsBox?.close() ?? Future.value(),
      _goalsBox?.close() ?? Future.value(),
      _syncBox?.close() ?? Future.value(),
      _conflictsBox?.close() ?? Future.value(),
      _metaBox?.close() ?? Future.value(),
      _peerSessionsBox?.close() ?? Future.value(),
      _peerCoursesBox?.close() ?? Future.value(),
      _habitsBox?.close() ?? Future.value(),
      _habitHistoryBox?.close() ?? Future.value(),
    ]);
    _userBox = null;
    _coursesBox = null;
    _sessionsBox = null;
    _goalsBox = null;
    _syncBox = null;
    _conflictsBox = null;
    _metaBox = null;
    _peerSessionsBox = null;
    _peerCoursesBox = null;
    _habitsBox = null;
    _habitHistoryBox = null;
    _currentUid = null;
  }

  String? get currentUid => _currentUid;

  LocalUserDoc ensureUserDoc() {
    final uid = _requireUid();
    final box = _userBox!;
    final existing = box.get(uid);
    if (existing != null) {
      return existing;
    }
    final now = _now();
    final created = LocalUserDoc(
      id: uid,
      uid: uid,
      updatedAtMs: now,
    );
    box.put(uid, created);
    return created;
  }

  Iterable<LocalCourse> courses({bool includeDeleted = false}) {
    final values = _coursesBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((c) => !c.deleted);
  }

  Iterable<LocalCourse> peerCourses(String targetUid) {
     final values = _peerCoursesBox?.values ?? const Iterable.empty();
     return values.where((c) => c.uid == targetUid && !c.deleted);
  }

  Iterable<LocalSession> sessions({bool includeDeleted = false}) {
    final values = _sessionsBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((s) => !s.deleted);
  }
  
  Iterable<LocalSession> peerSessions(String targetUid) {
     final values = _peerSessionsBox?.values ?? const Iterable.empty();
     return values.where((s) => s.uid == targetUid && !s.deleted);
  }

  Iterable<LocalGoal> goals({bool includeDeleted = false}) {
    final values = _goalsBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((g) => !g.deleted);
  }

  List<LocalCourse> dirtyCourses() =>
      (_coursesBox?.values ?? const Iterable<LocalCourse>.empty())
          .where((c) => c.dirty)
          .toList(growable: false);

  List<LocalSession> dirtySessions() =>
      (_sessionsBox?.values ?? const Iterable<LocalSession>.empty())
          .where((s) => s.dirty)
          .toList(growable: false);

  List<LocalGoal> dirtyGoals() =>
      (_goalsBox?.values ?? const Iterable<LocalGoal>.empty())
          .where((g) => g.dirty)
          .toList(growable: false);

  LocalUserDoc? get userDocOrNull => _userBox?.get(_currentUid);

  SyncStateEntry syncStateForKey(String key) {
    final box = _syncBox!;
    final existing = box.get(key);
    if (existing != null) return existing;
    final entry = SyncStateEntry(collection: key);
    box.put(key, entry);
    return entry;
  }

  List<LocalConflict> getConflicts() =>
      _conflictsBox?.values.toList(growable: false) ?? const [];

  Future<void> logConflict({
    required String collection,
    required String entityId,
    required int localUpdatedAtMs,
    required int remoteUpdatedAtMs,
    required bool resolvedWithRemote,
  }) async {
    final entry = LocalConflict(
      collection: collection,
      entityId: entityId,
      localUpdatedAtMs: localUpdatedAtMs,
      remoteUpdatedAtMs: remoteUpdatedAtMs,
      resolvedWithRemote: resolvedWithRemote,
      timestampMs: _now(),
    );
    await _conflictsBox?.put('${entry.timestampMs}_$entityId', entry);
  }

  Future<void> putCourse(LocalCourse course) async {
    await _coursesBox?.put(course.id, course);
  }

  LocalCourse? getCourseById(String id) => _coursesBox?.get(id);

  LocalSession? getSessionById(String id) => _sessionsBox?.get(id);

  LocalGoal? getGoalById(String id) => _goalsBox?.get(id);

  Future<void> putPeerCourse(LocalCourse course, String compositeKey) async {
     await _peerCoursesBox?.put(compositeKey, course);
  }

  Future<void> putSession(LocalSession session) async {
    await _sessionsBox?.put(session.id, session);
  }
  
  Future<void> putPeerSession(LocalSession session, String compositeKey) async {
     // Store using composite key like ${userId}_${sessionId} to avoid collision if IDs clash (unlikely but safe)
     // or just sessionId if we trust UUIDs. 
     // Requirement says: groupId + memberId, wait.
     // Storage Schema for Peer Data: "keyed by groupId + memberId" - wait, that's just cache access.
     // Hive box is peer_sessions. We should store by sessionId, but we need to query by userId.
     // Hive iteration is fast enough for small sets.
     await _peerSessionsBox?.put(compositeKey, session);
  }

  Future<void> putGoal(LocalGoal goal) async {
    await _goalsBox?.put(goal.id, goal);
  }

  Future<void> putUser(LocalUserDoc doc) async {
    await _userBox?.put(doc.id, doc);
  }

  Box<LocalCourse> get coursesBox =>
      _coursesBox ?? (throw StateError('User courses box not opened'));

  Box<LocalSession> get sessionsBox =>
      _sessionsBox ?? (throw StateError('User sessions box not opened'));

  Box<LocalGoal> get goalsBox =>
      _goalsBox ?? (throw StateError('User goals box not opened'));

  Box<LocalUserDoc> get userBox =>
      _userBox ?? (throw StateError('User box not opened'));

  Box<dynamic> get metaBox =>
      _metaBox ?? (throw StateError('Meta box not opened'));

  Box<SyncStateEntry> get syncBox =>
      _syncBox ?? (throw StateError('Sync box not opened'));

  Box<LocalConflict> get conflictsBox =>
      _conflictsBox ?? (throw StateError('Conflicts box not opened'));
      
  Box<LocalSession> get peerSessionsBox =>
      _peerSessionsBox ?? (throw StateError('Peer sessions box not opened'));

  Box<LocalCourse> get peerCoursesBox =>
      _peerCoursesBox ?? (throw StateError('Peer courses box not opened'));

  Future<void> putSyncState(SyncStateEntry entry) async {
    await _syncBox?.put(entry.collection, entry);
  }

  Future<void> clearAll() async {
    await Future.wait([
      _userBox?.clear() ?? Future.value(),
      _coursesBox?.clear() ?? Future.value(),
      _sessionsBox?.clear() ?? Future.value(),
      _goalsBox?.clear() ?? Future.value(),
      _syncBox?.clear() ?? Future.value(),
      _conflictsBox?.clear() ?? Future.value(),
      _metaBox?.clear() ?? Future.value(),
      _peerSessionsBox?.clear() ?? Future.value(),
      _peerCoursesBox?.clear() ?? Future.value(),
    ]);
  }

  Future<void> deleteBoxesForUser(String uid) async {
    await Hive.deleteBoxFromDisk('${uid}_user');
    await Hive.deleteBoxFromDisk('${uid}_courses');
    await Hive.deleteBoxFromDisk('${uid}_sessions');
    await Hive.deleteBoxFromDisk('${uid}_goals');
    await Hive.deleteBoxFromDisk('${uid}_sync');
    await Hive.deleteBoxFromDisk('${uid}_conflicts');
    await Hive.deleteBoxFromDisk('${uid}_meta');
    await Hive.deleteBoxFromDisk('${uid}_peer_sessions');
    await Hive.deleteBoxFromDisk('${uid}_peer_courses');
  }

  dynamic getMeta(String key) => _metaBox?.get(key);

  Future<void> putMeta(String key, dynamic value) async {
    if (value == null) {
      await _metaBox?.delete(key);
    } else {
      await _metaBox?.put(key, value);
    }
  }

  Future<void> clearMetaKey(String key) async {
    await _metaBox?.delete(key);
  }

  List<String> allIds(String collection) {
    switch (collection) {
      case 'sessions':
        return _sessionsBox?.keys.cast<String>().toList() ?? [];
      case 'courses':
        return _coursesBox?.keys.cast<String>().toList() ?? [];
      case 'goals':
        return _goalsBox?.keys.cast<String>().toList() ?? [];
      default:
        return [];
    }
  }

  int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  String _requireUid() {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      throw StateError('LocalDatabase user not opened');
    }
    return uid;
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(10)) {
      Hive
        ..registerAdapter(LocalUserDocAdapter())
        ..registerAdapter(LocalCourseAdapter())
        ..registerAdapter(LocalSessionAdapter())
        ..registerAdapter(LocalGoalAdapter())
        ..registerAdapter(SyncStateEntryAdapter())
        ..registerAdapter(LocalConflictAdapter())
        ..registerAdapter(LocalHabitAdapter())
        ..registerAdapter(LocalHabitHistoryAdapter());
    }
  }

  // Habit CRUD
  Iterable<LocalHabit> habits({bool includeDeleted = false}) {
    final values = _habitsBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((h) => !h.deleted);
  }

  List<LocalHabit> dirtyHabits() =>
      (_habitsBox?.values ?? const Iterable<LocalHabit>.empty())
          .where((h) => h.dirty)
          .toList(growable: false);

  LocalHabit? getHabitById(String id) => _habitsBox?.get(id);

  Future<void> putHabit(LocalHabit habit) async {
    await _habitsBox?.put(habit.id, habit);
  }

  Box<LocalHabit> get habitsBox =>
      _habitsBox ?? (throw StateError('Habits box not opened'));

  // Habit History CRUD
  Iterable<LocalHabitHistory> habitHistory({bool includeDeleted = false}) {
    final values = _habitHistoryBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((h) => !h.deleted);
  }

  Iterable<LocalHabitHistory> habitHistoryForHabit(String habitId, {bool includeDeleted = false}) {
    return habitHistory(includeDeleted: includeDeleted).where((h) => h.habitId == habitId);
  }

  List<LocalHabitHistory> dirtyHabitHistory() =>
      (_habitHistoryBox?.values ?? const Iterable<LocalHabitHistory>.empty())
          .where((h) => h.dirty)
          .toList(growable: false);

  LocalHabitHistory? getHabitHistoryById(String id) => _habitHistoryBox?.get(id);

  Future<void> putHabitHistory(LocalHabitHistory entry) async {
    await _habitHistoryBox?.put(entry.id, entry);
  }

  Box<LocalHabitHistory> get habitHistoryBox =>
      _habitHistoryBox ?? (throw StateError('Habit History box not opened'));

  bool hasBootstrapCache() {
    final hasCoreBoxes = (_userBox?.isNotEmpty ?? false) ||
        (_coursesBox?.isNotEmpty ?? false) ||
        (_sessionsBox?.isNotEmpty ?? false) ||
        (_habitsBox?.isNotEmpty ?? false);
    final hasMeta = _metaBox?.isNotEmpty ?? false;
    final hasSyncState =
        _syncBox?.values.any((entry) => entry.lastPullMs > 0) ?? false;
    return hasCoreBoxes || hasMeta || hasSyncState;
  }
}
