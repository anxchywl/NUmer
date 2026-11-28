import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/data/grade_entities.dart';
import 'package:numer_app/core/data/grade_storage.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/courses/courses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  var userCount = 0;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('grade_storage');
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

  List<LocalAssignment> assignments({double earned = 80}) => [
    LocalAssignment(
      id: 'a1',
      name: 'Midterm',
      weight: 40,
      maximumScore: 100,
      earnedScore: earned,
    ),
    LocalAssignment(id: 'a2', name: 'Final', weight: 60, maximumScore: 100),
  ];

  Future<void> putGrade(String courseId, {double earned = 80}) =>
      GradeStorage.putCourseGrade(
        courseId: courseId,
        semesterId: 'fall',
        gradeLetter: 'B+',
        assignments: assignments(earned: earned),
      );

  Future<LocalCourseGrade> cleanGrade(String courseId) async {
    final grade = db().getCourseGradeById(courseId)!;
    grade.dirty = false;
    await grade.save();
    return grade;
  }

  Course course(String id, {String? name}) => Course(
    id: id,
    name: name ?? 'name $id',
    day: '',
    start: '',
    end: '',
    colorValue: 0,
  );

  test('a put grade reads back dirty', () async {
    await putGrade('c1');

    final grades = GradeStorage.courseGrades();
    expect(grades, hasLength(1));
    final grade = grades.single;
    expect(grade.id, 'c1');
    expect(grade.uid, db().currentUid);
    expect(grade.semesterId, 'fall');
    expect(grade.gradeLetter, 'B+');
    expect(grade.assignments.map((a) => a.id), ['a1', 'a2']);
    expect(grade.dirty, isTrue);
    expect(db().dirtyCourseGrades(), hasLength(1));
  });

  test('putting equal values leaves a clean grade untouched', () async {
    await putGrade('c1');
    final before = (await cleanGrade('c1')).updatedAtMs;

    await putGrade('c1');

    final grade = db().getCourseGradeById('c1')!;
    expect(grade.dirty, isFalse);
    expect(grade.updatedAtMs, before);
  });

  test('a changed assignment marks the grade dirty', () async {
    await putGrade('c1');
    await cleanGrade('c1');

    await putGrade('c1', earned: 95);

    final grade = db().getCourseGradeById('c1')!;
    expect(grade.dirty, isTrue);
    expect(grade.assignments.first.earnedScore, 95);
  });

  test('an assignment edited in place on a read grade is saved', () async {
    await putGrade('c1');
    await cleanGrade('c1');
    final read = GradeStorage.courseGrades().single;

    read.assignments.first.earnedScore = 90;
    await GradeStorage.putCourseGrade(
      courseId: 'c1',
      semesterId: read.semesterId,
      gradeLetter: read.gradeLetter,
      assignments: read.assignments,
    );
    read.assignments.first.earnedScore = 10;

    final stored = db().getCourseGradeById('c1')!;
    expect(stored.dirty, isTrue);
    expect(stored.assignments.first.earnedScore, 90);
  });

  test('deleting a grade is a soft delete', () async {
    await putGrade('c1');
    await cleanGrade('c1');

    await GradeStorage.deleteCourseGrade('c1');
    await GradeStorage.deleteCourseGrade('missing');

    expect(GradeStorage.courseGrades(), isEmpty);
    final grade = db().getCourseGradeById('c1')!;
    expect(grade.deleted, isTrue);
    expect(grade.dirty, isTrue);
  });

  test('deleting a course soft-deletes only its grade', () async {
    await Storage.saveCourses([course('c1'), course('c2')]);
    await putGrade('c1');
    await putGrade('c2');

    await Storage.deleteCourse('c1');

    expect(db().getCourseGradeById('c1')!.deleted, isTrue);
    expect(db().getCourseGradeById('c2')!.deleted, isFalse);
    expect(GradeStorage.courseGrades().map((g) => g.id), ['c2']);
  });

  test('semesters put, skip equal values and soft delete', () async {
    await GradeStorage.putSemester(id: 's1', name: 'Fall', position: 0);
    final semester = db().getSemesterById('s1')!;
    expect(semester.dirty, isTrue);
    semester.dirty = false;
    await semester.save();
    final before = semester.updatedAtMs;

    await GradeStorage.putSemester(id: 's1', name: 'Fall', position: 0);
    expect(db().getSemesterById('s1')!.dirty, isFalse);
    expect(db().getSemesterById('s1')!.updatedAtMs, before);

    await GradeStorage.putSemester(id: 's1', name: 'Fall 2026', position: 0);
    expect(db().getSemesterById('s1')!.dirty, isTrue);

    await GradeStorage.deleteSemester('s1');
    expect(GradeStorage.semesters(), isEmpty);
    expect(db().getSemesterById('s1')!.deleted, isTrue);
  });

  test(
    'a course code marks the course dirty and survives saveCourses',
    () async {
      await Storage.saveCourses([course('c1')]);
      final local = db().getCourseById('c1')!;
      local.dirty = false;
      await local.save();

      await GradeStorage.setCourseCode('c1', 'CSCI 151');

      expect(GradeStorage.courseCode('c1'), 'CSCI 151');
      expect(db().getCourseById('c1')!.dirty, isTrue);

      await Storage.saveCourses([course('c1', name: 'Renamed')]);

      expect(GradeStorage.courseCode('c1'), 'CSCI 151');
    },
  );

  test('storage throws without an open user', () async {
    await Storage.closeForSignOut();

    expect(GradeStorage.courseGrades, throwsStateError);
    expect(() => GradeStorage.courseCode('c1'), throwsStateError);
  });
}
