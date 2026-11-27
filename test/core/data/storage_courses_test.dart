import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/courses/courses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  var userCount = 0;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('storage_courses');
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

  Course course(String id) => Course(
    id: id,
    name: 'name $id',
    day: 'monday',
    start: '09:00',
    end: '10:00',
    colorValue: 0,
  );

  // stands in for a pull, which leaves the records clean
  Future<void> storePulled(List<String> ids) async {
    await Storage.saveCourses([for (final id in ids) course(id)]);
    for (final entry in LocalDatabase.instance.coursesBox.values) {
      entry.dirty = false;
      await entry.save();
    }
  }

  LocalDatabase db() => LocalDatabase.instance;

  test('saving a list keeps the courses missing from it', () async {
    await storePulled(['local', 'remote']);

    await Storage.saveCourses([course('local')]);

    expect(db().getCourseById('remote')!.deleted, isFalse);
    expect(db().dirtyCourses(), isEmpty);
  });

  test('saving an empty list deletes nothing', () async {
    await storePulled(['first', 'second']);

    await Storage.saveCourses([]);

    expect(await Storage.getCourses(), hasLength(2));
  });

  test('deleting a course marks only that course', () async {
    await storePulled(['removed', 'kept']);

    await Storage.deleteCourse('removed');

    expect(db().getCourseById('removed')!.deleted, isTrue);
    expect(db().dirtyCourses().map((c) => c.id), ['removed']);
    expect((await Storage.getCourses()).map((c) => c.id), ['kept']);
  });
}
