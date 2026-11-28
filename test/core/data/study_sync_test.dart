import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/data/grade_entities.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/core/data/study_sync.dart';
import 'package:numer_app/core/data/sync_service.dart';

// offline at start, so start makes no remote reads and pushDirty still runs
class _FakeConnectivity implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.none,
  ];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

// ignore: subtype_of_sealed_class
class _FakeDocument implements DocumentReference<Map<String, dynamic>> {
  _FakeDocument(this.path);

  @override
  final String path;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollection('$path/$collectionPath');

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  _FakeCollection(this.path);

  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _FakeDocument('$path/$id');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _FakeBatch implements WriteBatch {
  _FakeBatch(this.sets);

  final Map<String, Map<String, dynamic>> sets;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    sets[document.path] = data as Map<String, dynamic>;
  }

  @override
  Future<void> commit() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  final sets = <String, Map<String, dynamic>>{};

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeCollection(collectionPath);

  @override
  WriteBatch batch() => _FakeBatch(sets);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  var userCount = 0;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('study_sync');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => directory.path,
        );
  });

  setUp(() => Storage.configureForUser('user${userCount++}'));

  tearDownAll(() async {
    await Storage.closeForSignOut();
    await directory.delete(recursive: true);
  });

  LocalDatabase db() => LocalDatabase.instance;
  Timestamp at(int ms) => Timestamp.fromMillisecondsSinceEpoch(ms);

  LocalAssignment assignment(String id) => LocalAssignment(
    id: id,
    name: 'quiz $id',
    weight: 0.25,
    maximumScore: 10,
    earnedScore: 7.5,
  );

  LocalCourseGrade grade({
    int updatedAtMs = 1000,
    bool dirty = true,
    bool deleted = false,
  }) => LocalCourseGrade(
    id: 'c1',
    uid: 'u',
    updatedAtMs: updatedAtMs,
    semesterId: 's1',
    gradeLetter: 'A-',
    assignments: [assignment('a1'), assignment('a2')],
    dirty: dirty,
    deleted: deleted,
  );

  LocalSemester semester({int updatedAtMs = 1000, bool dirty = true}) =>
      LocalSemester(
        id: 's1',
        uid: 'u',
        updatedAtMs: updatedAtMs,
        name: 'Fall 2026',
        position: 2,
        dirty: dirty,
      );

  Map<String, dynamic> remoteGrade(int ms, {bool deleted = false}) => {
    'uid': 'u',
    'semesterId': 's2',
    'gradeLetter': 'B+',
    'assignments': [
      {
        'id': 'r1',
        'name': 'final',
        'weight': 1,
        'maximumScore': 100,
        'earnedScore': 88,
      },
    ],
    'deleted': deleted,
    'updatedAt': at(ms),
  };

  Map<String, dynamic> remoteSemester(int ms, {bool deleted = false}) => {
    'uid': 'u',
    'name': 'Spring 2027',
    'position': 3,
    'deleted': deleted,
    'updatedAt': at(ms),
  };

  Future<void> applyGrade(Map<String, dynamic> data) =>
      applyRemoteCourseGrade(db(), uid: 'u', id: 'c1', data: data);

  Future<void> applySemester(Map<String, dynamic> data) =>
      applyRemoteSemester(db(), uid: 'u', id: 's1', data: data);

  test('courseGradeToRemote sends every field', () {
    final remote = courseGradeToRemote(grade());

    expect(remote['uid'], 'u');
    expect(remote['semesterId'], 's1');
    expect(remote['gradeLetter'], 'A-');
    expect(remote['deleted'], isFalse);
    expect(remote['assignments'], [
      for (final id in ['a1', 'a2'])
        {
          'id': id,
          'name': 'quiz $id',
          'weight': 0.25,
          'maximumScore': 10.0,
          'earnedScore': 7.5,
        },
    ]);
    expect(remote['updatedAt'], FieldValue.serverTimestamp());
  });

  test('semesterToRemote sends every field', () {
    final remote = semesterToRemote(semester());

    expect(remote, {
      'uid': 'u',
      'name': 'Fall 2026',
      'position': 2,
      'deleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  Future<_FakeFirestore> push(LocalCourseGrade dirty) async {
    final firestore = _FakeFirestore();
    final service = SyncService(
      firestore: firestore,
      connectivity: _FakeConnectivity(),
      database: db(),
    );
    await service.start(uid: 'u', deviceId: 'd');
    await db().putCourseGrade(dirty);
    await service.pushDirty();
    await service.stop();
    return firestore;
  }

  test('pushDirty writes a dirty grade and leaves it clean', () async {
    final firestore = await push(grade());

    expect(firestore.sets.keys, ['users/u/courseGrades/c1']);
    expect(firestore.sets['users/u/courseGrades/c1']!['gradeLetter'], 'A-');
    expect(db().getCourseGradeById('c1')!.dirty, isFalse);
  });

  test('a locally deleted grade is pushed as deleted', () async {
    final firestore = await push(grade(deleted: true));

    expect(firestore.sets['users/u/courseGrades/c1']!['deleted'], isTrue);
  });

  test('a remote grade creates a clean local record', () async {
    await applyGrade(remoteGrade(2000));

    final local = db().getCourseGradeById('c1')!;
    expect(local.dirty, isFalse);
    expect(local.semesterId, 's2');
    expect(local.updatedAtMs, 2000);
  });

  test('a newer remote grade replaces a clean local one', () async {
    await db().putCourseGrade(grade(dirty: false));

    await applyGrade(remoteGrade(2000));

    final local = db().getCourseGradeById('c1')!;
    expect(local.semesterId, 's2');
    expect(local.gradeLetter, 'B+');
    expect(local.assignments.single.id, 'r1');
    expect(local.assignments.single.earnedScore, 88.0);
    expect(local.updatedAtMs, 2000);
    expect(local.dirty, isFalse);
  });

  test('a dirty local grade newer than the remote is kept', () async {
    await db().putCourseGrade(grade(updatedAtMs: 3000));

    await applyGrade(remoteGrade(2000));

    final local = db().getCourseGradeById('c1')!;
    expect(local.gradeLetter, 'A-');
    expect(local.dirty, isTrue);
    expect(db().getConflicts(), isEmpty);
  });

  test('a dirty local grade older than the remote takes it', () async {
    await db().putCourseGrade(grade(updatedAtMs: 1000));

    await applyGrade(remoteGrade(2000));

    final local = db().getCourseGradeById('c1')!;
    expect(local.gradeLetter, 'B+');
    expect(local.dirty, isFalse);
    final conflict = db().getConflicts().single;
    expect(conflict.collection, 'courseGrades');
    expect(conflict.entityId, 'c1');
  });

  test('a remote deleted grade marks the local one deleted', () async {
    await db().putCourseGrade(grade(dirty: false));

    await applyGrade(remoteGrade(2000, deleted: true));

    expect(db().getCourseGradeById('c1')!.deleted, isTrue);
    expect(db().courseGrades(), isEmpty);
  });

  test('a remote assignment without a name is skipped', () async {
    final data = remoteGrade(2000);
    data['assignments'] = [
      {'id': 'x1', 'weight': 1, 'maximumScore': 10},
      {'id': 'x2', 'name': 'lab', 'weight': 'heavy', 'maximumScore': 10},
      {'id': 'x3', 'name': 'essay', 'weight': 0.5, 'maximumScore': 20},
    ];

    await applyGrade(data);

    final kept = db().getCourseGradeById('c1')!.assignments;
    expect(kept.map((a) => a.id), ['x3']);
    expect(kept.single.earnedScore, isNull);
  });

  test(
    'applyRemoteCourse stores the code and courseToRemote sends it',
    () async {
      await applyRemoteCourse(
        db(),
        uid: 'u',
        id: 'c1',
        data: {
          'name': 'Programming',
          'code': 'CSCI 151',
          'updatedAt': at(2000),
        },
      );

      final course = db().getCourseById('c1')!;
      expect(course.code, 'CSCI 151');
      expect(courseToRemote(course)['code'], 'CSCI 151');

      await applyRemoteCourse(
        db(),
        uid: 'u',
        id: 'c1',
        data: {
          'name': 'Programming',
          'code': 'CSCI 152',
          'updatedAt': at(3000),
        },
      );
      expect(db().getCourseById('c1')!.code, 'CSCI 152');
    },
  );

  test('a newer remote semester replaces a clean local one', () async {
    await db().putSemester(semester(dirty: false));

    await applySemester(remoteSemester(2000));

    final local = db().getSemesterById('s1')!;
    expect(local.name, 'Spring 2027');
    expect(local.position, 3);
    expect(local.dirty, isFalse);
  });

  test('a dirty local semester newer than the remote is kept', () async {
    await db().putSemester(semester(updatedAtMs: 3000));

    await applySemester(remoteSemester(2000));

    expect(db().getSemesterById('s1')!.name, 'Fall 2026');
    expect(db().getConflicts(), isEmpty);
  });

  test('a dirty local semester older than the remote takes it', () async {
    await db().putSemester(semester(updatedAtMs: 1000));

    await applySemester(remoteSemester(2000));

    expect(db().getSemesterById('s1')!.name, 'Spring 2027');
    expect(db().getConflicts().single.collection, 'semesters');
  });

  test('a remote deleted semester marks the local one deleted', () async {
    await db().putSemester(semester(dirty: false));

    await applySemester(remoteSemester(2000, deleted: true));

    expect(db().getSemesterById('s1')!.deleted, isTrue);
    expect(db().semesters(), isEmpty);
  });

  test('a locally deleted semester is pushed as deleted', () {
    final deleted = semester()..deleted = true;

    expect(semesterToRemote(deleted)['deleted'], isTrue);
  });
}
