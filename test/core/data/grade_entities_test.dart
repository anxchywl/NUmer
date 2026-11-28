import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:numer_app/core/data/grade_entities.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('grade_entities');
    Hive
      ..init(directory.path)
      ..registerAdapter(LocalCourseGradeAdapter())
      ..registerAdapter(LocalAssignmentAdapter())
      ..registerAdapter(LocalSemesterAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<T> roundTrip<T>(String name, T value) async {
    final box = await Hive.openBox<T>(name);
    await box.put('key', value);
    await box.close();
    final reopened = await Hive.openBox<T>(name);
    return reopened.get('key') as T;
  }

  test(
    'a course grade with two assignments and no letter round-trips',
    () async {
      final grade = LocalCourseGrade(
        id: '1700000000000_42',
        uid: 'user',
        updatedAtMs: 1700000000000,
        semesterId: 'fall',
        assignments: [
          LocalAssignment(
            id: 'a1',
            name: 'Midterm',
            weight: 30,
            maximumScore: 100,
            earnedScore: 87.5,
          ),
          LocalAssignment(
            id: 'a2',
            name: 'Final',
            weight: 70,
            maximumScore: 50,
          ),
        ],
      );

      final read = await roundTrip('grades', grade);

      expect(read.id, '1700000000000_42');
      expect(read.uid, 'user');
      expect(read.updatedAtMs, 1700000000000);
      expect(read.dirty, isTrue);
      expect(read.deleted, isFalse);
      expect(read.semesterId, 'fall');
      expect(read.gradeLetter, isNull);
      expect(read.assignments, hasLength(2));
      expect(read.assignments[0].id, 'a1');
      expect(read.assignments[0].name, 'Midterm');
      expect(read.assignments[0].weight, 30);
      expect(read.assignments[0].maximumScore, 100);
      expect(read.assignments[0].earnedScore, 87.5);
      expect(read.assignments[1].id, 'a2');
      expect(read.assignments[1].earnedScore, isNull);
    },
  );

  test('a course grade with a letter keeps its flags', () async {
    final grade = LocalCourseGrade(
      id: 'c',
      uid: 'user',
      updatedAtMs: 5,
      semesterId: 'spring',
      gradeLetter: 'A-',
      dirty: false,
      deleted: true,
    );

    final read = await roundTrip('grades_flags', grade);

    expect(read.gradeLetter, 'A-');
    expect(read.dirty, isFalse);
    expect(read.deleted, isTrue);
    expect(read.assignments, isEmpty);
    read.assignments.add(
      LocalAssignment(id: 'x', name: 'Quiz', weight: 1, maximumScore: 1),
    );
    expect(read.assignments, hasLength(1));
  });

  test('a semester round-trips', () async {
    final semester = LocalSemester(
      id: 's1',
      uid: 'user',
      updatedAtMs: 9,
      name: 'Fall 2026',
      position: 3,
      dirty: false,
    );

    final read = await roundTrip('semesters', semester);

    expect(read.id, 's1');
    expect(read.uid, 'user');
    expect(read.updatedAtMs, 9);
    expect(read.dirty, isFalse);
    expect(read.deleted, isFalse);
    expect(read.name, 'Fall 2026');
    expect(read.position, 3);
  });

  test('a grade created without assignments gets a growable list', () {
    final grade = LocalCourseGrade(
      id: 'c',
      uid: 'user',
      updatedAtMs: 0,
      semesterId: 's',
    );
    grade.assignments.add(
      LocalAssignment(id: 'x', name: 'Quiz', weight: 1, maximumScore: 1),
    );
    expect(grade.assignments, hasLength(1));
  });
}
