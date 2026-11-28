import 'package:hive/hive.dart';

import 'entities.dart';

@HiveType(typeId: 18)
class LocalCourseGrade extends HiveObject with SyncEntity {
  LocalCourseGrade({
    required this.id,
    required this.uid,
    required this.updatedAtMs,
    required this.semesterId,
    this.gradeLetter,
    List<LocalAssignment>? assignments,
    this.dirty = true,
    this.deleted = false,
  }) : assignments = assignments ?? [];

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
  String semesterId;

  @HiveField(6)
  String? gradeLetter;

  @HiveField(7)
  List<LocalAssignment> assignments;
}

@HiveType(typeId: 19)
class LocalAssignment extends HiveObject {
  LocalAssignment({
    required this.id,
    required this.name,
    required this.weight,
    required this.maximumScore,
    this.earnedScore,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double weight;

  @HiveField(3)
  double maximumScore;

  @HiveField(4)
  double? earnedScore;
}

@HiveType(typeId: 20)
class LocalSemester extends HiveObject with SyncEntity {
  LocalSemester({
    required this.id,
    required this.uid,
    required this.updatedAtMs,
    required this.name,
    required this.position,
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
  int position;
}

class LocalCourseGradeAdapter extends TypeAdapter<LocalCourseGrade> {
  @override
  final int typeId = 18;

  @override
  LocalCourseGrade read(BinaryReader reader) {
    return LocalCourseGrade(
      id: reader.read() as String,
      uid: reader.read() as String,
      updatedAtMs: reader.read() as int,
      dirty: reader.read() as bool,
      deleted: reader.read() as bool,
      semesterId: reader.read() as String,
      gradeLetter: reader.read() as String?,
      assignments: (reader.read() as List).cast<LocalAssignment>().toList(),
    );
  }

  @override
  void write(BinaryWriter writer, LocalCourseGrade obj) {
    writer
      ..write(obj.id)
      ..write(obj.uid)
      ..write(obj.updatedAtMs)
      ..write(obj.dirty)
      ..write(obj.deleted)
      ..write(obj.semesterId)
      ..write(obj.gradeLetter)
      ..write(obj.assignments);
  }
}

class LocalAssignmentAdapter extends TypeAdapter<LocalAssignment> {
  @override
  final int typeId = 19;

  @override
  LocalAssignment read(BinaryReader reader) {
    return LocalAssignment(
      id: reader.read() as String,
      name: reader.read() as String,
      weight: reader.read() as double,
      maximumScore: reader.read() as double,
      earnedScore: reader.read() as double?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalAssignment obj) {
    writer
      ..write(obj.id)
      ..write(obj.name)
      ..write(obj.weight)
      ..write(obj.maximumScore)
      ..write(obj.earnedScore);
  }
}

class LocalSemesterAdapter extends TypeAdapter<LocalSemester> {
  @override
  final int typeId = 20;

  @override
  LocalSemester read(BinaryReader reader) {
    return LocalSemester(
      id: reader.read() as String,
      uid: reader.read() as String,
      updatedAtMs: reader.read() as int,
      dirty: reader.read() as bool,
      deleted: reader.read() as bool,
      name: reader.read() as String,
      position: reader.read() as int,
    );
  }

  @override
  void write(BinaryWriter writer, LocalSemester obj) {
    writer
      ..write(obj.id)
      ..write(obj.uid)
      ..write(obj.updatedAtMs)
      ..write(obj.dirty)
      ..write(obj.deleted)
      ..write(obj.name)
      ..write(obj.position);
  }
}
