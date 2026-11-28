import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:numer_app/core/data/entities.dart';

// the adapter as it was before the code field, to write records of an older install
class _LegacyCourseAdapter extends TypeAdapter<LocalCourse> {
  @override
  final int typeId = 11;

  @override
  LocalCourse read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, LocalCourse obj) {
    writer
      ..write(obj.id)
      ..write(obj.uid)
      ..write(obj.updatedAtMs)
      ..write(obj.name)
      ..write(obj.day)
      ..write(obj.start)
      ..write(obj.end)
      ..write(obj.colorValue)
      ..write(obj.credits)
      ..write(obj.expLevel)
      ..write(obj.goalHours)
      ..write(obj.totalMinutes)
      ..write(obj.pomodoroLongBreakMinutes)
      ..write(obj.dirty)
      ..write(obj.deleted)
      ..write(obj.sortOrder)
      ..write(obj.hiddenFromLeaderboard);
  }
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('course_entity');
    Hive.init(directory.path);
  });

  tearDown(() async {
    await Hive.close();
    Hive.resetAdapters();
    await directory.delete(recursive: true);
  });

  LocalCourse course({String? code}) => LocalCourse(
    id: '1700000000000_7',
    uid: 'user',
    updatedAtMs: 1700000000000,
    name: 'Programming',
    day: 'monday',
    start: '09:00',
    end: '10:15',
    colorValue: 0xFF3B82F6,
    credits: 6,
    expLevel: 2,
    goalHours: 4.5,
    totalMinutes: 90,
    pomodoroLongBreakMinutes: 20,
    sortOrder: 3,
    hiddenFromLeaderboard: true,
    dirty: false,
    deleted: false,
    code: code,
  );

  test('a course written before the code field reads with no code', () async {
    Hive.resetAdapters();
    Hive.registerAdapter(_LegacyCourseAdapter());
    final legacy = await Hive.openBox<LocalCourse>('courses');
    await legacy.put('c', course());
    await legacy.close();

    Hive.resetAdapters();
    Hive.registerAdapter(LocalCourseAdapter());
    final box = await Hive.openBox<LocalCourse>('courses');
    final read = box.get('c')!;

    expect(read.code, isNull);
    expect(read.id, '1700000000000_7');
    expect(read.uid, 'user');
    expect(read.updatedAtMs, 1700000000000);
    expect(read.name, 'Programming');
    expect(read.day, 'monday');
    expect(read.start, '09:00');
    expect(read.end, '10:15');
    expect(read.colorValue, 0xFF3B82F6);
    expect(read.credits, 6);
    expect(read.expLevel, 2);
    expect(read.goalHours, 4.5);
    expect(read.totalMinutes, 90);
    expect(read.pomodoroLongBreakMinutes, 20);
    expect(read.sortOrder, 3);
    expect(read.hiddenFromLeaderboard, isTrue);
    expect(read.dirty, isFalse);
    expect(read.deleted, isFalse);
  });

  test('a course code round-trips', () async {
    Hive.resetAdapters();
    Hive.registerAdapter(LocalCourseAdapter());
    final box = await Hive.openBox<LocalCourse>('courses');
    await box.put('c', course(code: 'CSCI 151'));
    await box.close();

    final reopened = await Hive.openBox<LocalCourse>('courses');
    final read = reopened.get('c')!;

    expect(read.code, 'CSCI 151');
    expect(read.hiddenFromLeaderboard, isTrue);
    expect(read.sortOrder, 3);
  });
}
