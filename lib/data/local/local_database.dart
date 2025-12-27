import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import 'entities.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  bool _initialized = false;
  String? _currentUid;

  Box<LocalUserDoc>? _userBox;
  Box<LocalCourse>? _coursesBox;
  Box<LocalSession>? _sessionsBox;
  Box<LocalGoal>? _goalsBox;
  Box<SyncStateEntry>? _syncBox;
  Box<LocalConflict>? _conflictsBox;
  Box<dynamic>? _metaBox;

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
    _userBox = await Hive.openBox<LocalUserDoc>('${uid}_user');
    _coursesBox = await Hive.openBox<LocalCourse>('${uid}_courses');
    _sessionsBox = await Hive.openBox<LocalSession>('${uid}_sessions');
    _goalsBox = await Hive.openBox<LocalGoal>('${uid}_goals');
    _syncBox = await Hive.openBox<SyncStateEntry>('${uid}_sync');
    _conflictsBox = await Hive.openBox<LocalConflict>('${uid}_conflicts');
    _metaBox = await Hive.openBox('${uid}_meta');
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
    ]);
    _userBox = null;
    _coursesBox = null;
    _sessionsBox = null;
    _goalsBox = null;
    _syncBox = null;
    _conflictsBox = null;
    _metaBox = null;
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

  Iterable<LocalSession> sessions({bool includeDeleted = false}) {
    final values = _sessionsBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((s) => !s.deleted);
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

  Future<void> putSession(LocalSession session) async {
    await _sessionsBox?.put(session.id, session);
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
        ..registerAdapter(LocalConflictAdapter());
    }
  }
}
