import 'package:hive/hive.dart';

import 'entities.dart';

@HiveType(typeId: 11)
class LocalCourse extends HiveObject with SyncEntity {
  LocalCourse({
    required this.id,
    required this.uid,
    required this.updatedAtMs,
    required this.name,
    required this.day,
    required this.start,
    required this.end,
    required this.colorValue,
    this.credits,
    this.expLevel,
    this.goalHours,
    this.totalMinutes = 0,
    this.pomodoroLongBreakMinutes,
    this.sortOrder,
    this.hiddenFromLeaderboard = false,
    this.dirty = true,
    this.deleted = false,
  });

  @override
  @HiveField(0)
  String id;

  @override
  @HiveField(1)
  String uid;

  @override
  @HiveField(2)
  int updatedAtMs;

  @override
  @HiveField(3)
  bool dirty;

  @override
  @HiveField(4)
  bool deleted;

  @HiveField(5)
  String name;

  @HiveField(6)
  String day;

  @HiveField(7)
  String start;

  @HiveField(8)
  String end;

  @HiveField(9)
  int colorValue;

  @HiveField(10)
  double? credits;

  @HiveField(11)
  int? expLevel;

  @HiveField(12)
  double? goalHours;

  @HiveField(13)
  int totalMinutes;

  @HiveField(14)
  int? pomodoroLongBreakMinutes;

  @HiveField(15)
  int? sortOrder;

  @HiveField(16)
  bool hiddenFromLeaderboard;
}

class LocalCourseAdapter extends TypeAdapter<LocalCourse> {
  @override
  final int typeId = 11;

  @override
  LocalCourse read(BinaryReader reader) {
    return LocalCourse(
      id: reader.read() as String,
      uid: reader.read() as String,
      updatedAtMs: reader.read() as int,
      name: reader.read() as String,
      day: reader.read() as String,
      start: reader.read() as String,
      end: reader.read() as String,
      colorValue: reader.read() as int,
      credits: reader.read() as double?,
      expLevel: reader.read() as int?,
      goalHours: reader.read() as double?,
      totalMinutes: reader.read() as int,
      pomodoroLongBreakMinutes: reader.read() as int?,
      dirty: reader.read() as bool,
      deleted: reader.read() as bool,
      sortOrder: reader.availableBytes > 0 ? reader.read() as int? : null,
      hiddenFromLeaderboard: reader.availableBytes > 0
          ? reader.read() as bool
          : false,
    );
  }

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
