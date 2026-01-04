import 'dart:typed_data';

import 'package:hive/hive.dart';


mixin SyncEntity {
  String get id;
  set id(String value);

  String get uid;
  set uid(String value);

  int get updatedAtMs;
  set updatedAtMs(int value);

  bool get dirty;
  set dirty(bool value);

  bool get deleted;
  set deleted(bool value);
}

@HiveType(typeId: 10)
class LocalUserDoc extends HiveObject with SyncEntity {
  LocalUserDoc({
    required this.id,
    required this.uid,
    required this.updatedAtMs,
    this.dirty = true,
    this.deleted = false,
    this.profileName,
    this.profileGoal,
    this.major,
    this.avatarIndex,
    this.avatarImage,
    this.themeMode,
    this.weekStart = 'monday',
    this.progressView = 'week',
    this.homeSummaryRange = 'today',
    this.activeSessionDeviceId,
    this.activeSessionUpdatedAtMs,
    this.pendingCoursePrompt = false,
    this.quickNotesEnabled = true,
    this.avatarColorValue,
    this.profileComplete = false,
    this.profileContact,
    this.allowNudges = true,
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
  String? profileName;

  @HiveField(6)
  String? profileGoal;

  @HiveField(7)
  String? major;

  @HiveField(8)
  int? avatarIndex;

  @HiveField(9)
  Uint8List? avatarImage;

  @HiveField(10)
  String? themeMode;

  @HiveField(11)
  String weekStart;

  @HiveField(12)
  String progressView;

  @HiveField(13)
  String homeSummaryRange;

  @HiveField(14)
  String? activeSessionDeviceId;

  @HiveField(15)
  int? activeSessionUpdatedAtMs;

  @HiveField(16)
  bool pendingCoursePrompt;

  @HiveField(17)
  bool quickNotesEnabled;

  @HiveField(18)
  int? avatarColorValue;

  @HiveField(19)
  bool profileComplete = false;

  @HiveField(20)
  String? profileContact;

  @HiveField(21)
  bool allowNudges;
}

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
}

@HiveType(typeId: 12)
class LocalSession extends HiveObject with SyncEntity {
  LocalSession({
    required this.id,
    required this.uid,
    required this.courseId,
    required this.startUtcMs,
    required this.endUtcMs,
    required this.seconds,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.kind,
    this.notes,
    this.dirty = true,
    this.deleted = false,
  });

  @override
  @HiveField(0)
  String id;

  @override
  @HiveField(1)
  String uid;

  @HiveField(2)
  String courseId;

  @HiveField(3)
  int startUtcMs;

  @HiveField(4)
  int endUtcMs;

  @HiveField(5)
  int seconds;

  @HiveField(6)
  String? kind;

  @HiveField(7)
  int createdAtMs;

  @override
  @HiveField(8)
  int updatedAtMs;

  @override
  @HiveField(9)
  bool dirty;

  @override
  @HiveField(10)
  bool deleted;

  @HiveField(11)
  String? notes;
}

@HiveType(typeId: 13)
class LocalGoal extends HiveObject with SyncEntity {
  LocalGoal({
    required this.id,
    required this.uid,
    required this.updatedAtMs,
    this.hours,
    this.dirty = true,
    this.deleted = false,
  });

  @override
  @HiveField(0)
  String id;

  @override
  @HiveField(1)
  String uid;

  @HiveField(2)
  double? hours;

  @override
  @HiveField(3)
  int updatedAtMs;

  @override
  @HiveField(4)
  bool dirty;

  @override
  @HiveField(5)
  bool deleted;
}

@HiveType(typeId: 14)
class SyncStateEntry extends HiveObject {
  SyncStateEntry({
    required this.collection,
    this.lastPullMs = 0,
    this.lastPushMs = 0,
  });

  @HiveField(0)
  String collection;

  @HiveField(1)
  int lastPullMs;

  @HiveField(2)
  int lastPushMs;
}

@HiveType(typeId: 15)
class LocalConflict extends HiveObject {
  LocalConflict({
    required this.collection,
    required this.entityId,
    required this.localUpdatedAtMs,
    required this.remoteUpdatedAtMs,
    required this.resolvedWithRemote,
    required this.timestampMs,
  });

  @HiveField(0)
  String collection;

  @HiveField(1)
  String entityId;

  @HiveField(2)
  int localUpdatedAtMs;

  @HiveField(3)
  int remoteUpdatedAtMs;

  @HiveField(4)
  bool resolvedWithRemote;

  @HiveField(5)
  int timestampMs;
}

class LocalUserDocAdapter extends TypeAdapter<LocalUserDoc> {
  @override
  final int typeId = 10;

  @override
  LocalUserDoc read(BinaryReader reader) {
    return LocalUserDoc(
      id: reader.read() as String,
      uid: reader.read() as String,
      updatedAtMs: reader.read() as int,
      dirty: reader.read() as bool,
      deleted: reader.read() as bool,
      profileName: reader.read() as String?,
      profileGoal: reader.read() as String?,
      major: reader.read() as String?,
      avatarIndex: reader.read() as int?,
      avatarImage: reader.read() as Uint8List?,
      themeMode: reader.read() as String?,
      weekStart: reader.read() as String,
      progressView: reader.read() as String,
      homeSummaryRange: reader.read() as String,
      activeSessionDeviceId: reader.read() as String?,
      activeSessionUpdatedAtMs: reader.read() as int?,
      pendingCoursePrompt: reader.read() as bool,
      quickNotesEnabled: (reader.availableBytes > 0 ? reader.read() : true) as bool,
      avatarColorValue: (reader.availableBytes > 0 ? reader.read() : null) as int?,
      profileComplete: (reader.availableBytes > 0 ? reader.read() : false) as bool,
      profileContact: (reader.availableBytes > 0 ? reader.read() : null) as String?,
      allowNudges: (reader.availableBytes > 0 ? reader.read() : true) as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalUserDoc obj) {
    writer
      ..write(obj.id)
      ..write(obj.uid)
      ..write(obj.updatedAtMs)
      ..write(obj.dirty)
      ..write(obj.deleted)
      ..write(obj.profileName)
      ..write(obj.profileGoal)
      ..write(obj.major)
      ..write(obj.avatarIndex)
      ..write(obj.avatarImage)
      ..write(obj.themeMode)
      ..write(obj.weekStart)
      ..write(obj.progressView)
      ..write(obj.homeSummaryRange)
      ..write(obj.activeSessionDeviceId)
      ..write(obj.activeSessionUpdatedAtMs)
      ..write(obj.pendingCoursePrompt)
      ..write(obj.quickNotesEnabled)
      ..write(obj.avatarColorValue)
      ..write(obj.profileComplete)
      ..write(obj.profileContact)
      ..write(obj.allowNudges);
  }
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
      ..write(obj.sortOrder);
  }
}

class LocalSessionAdapter extends TypeAdapter<LocalSession> {
  @override
  final int typeId = 12;

  @override
  LocalSession read(BinaryReader reader) {
    return LocalSession(
      id: reader.read() as String,
      uid: reader.read() as String,
      courseId: reader.read() as String,
      startUtcMs: reader.read() as int,
      endUtcMs: reader.read() as int,
      seconds: reader.read() as int,
      createdAtMs: reader.read() as int,
      updatedAtMs: reader.read() as int,
      kind: reader.read() as String?,
      dirty: reader.read() as bool,
      deleted: reader.read() as bool,
      notes: reader.availableBytes > 0 ? reader.read() as String? : null,
    );
  }

  @override
  void write(BinaryWriter writer, LocalSession obj) {
    writer
      ..write(obj.id)
      ..write(obj.uid)
      ..write(obj.courseId)
      ..write(obj.startUtcMs)
      ..write(obj.endUtcMs)
      ..write(obj.seconds)
      ..write(obj.createdAtMs)
      ..write(obj.updatedAtMs)
      ..write(obj.kind)
      ..write(obj.dirty)
      ..write(obj.deleted)
      ..write(obj.notes);
  }
}

class LocalGoalAdapter extends TypeAdapter<LocalGoal> {
  @override
  final int typeId = 13;

  @override
  LocalGoal read(BinaryReader reader) {
    return LocalGoal(
      id: reader.read() as String,
      uid: reader.read() as String,
      updatedAtMs: reader.read() as int,
      hours: reader.read() as double?,
      dirty: reader.read() as bool,
      deleted: reader.read() as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalGoal obj) {
    writer
      ..write(obj.id)
      ..write(obj.uid)
      ..write(obj.updatedAtMs)
      ..write(obj.hours)
      ..write(obj.dirty)
      ..write(obj.deleted);
  }
}

class SyncStateEntryAdapter extends TypeAdapter<SyncStateEntry> {
  @override
  final int typeId = 14;

  @override
  SyncStateEntry read(BinaryReader reader) {
    return SyncStateEntry(
      collection: reader.read() as String,
      lastPullMs: reader.read() as int,
      lastPushMs: reader.read() as int,
    );
  }

  @override
  void write(BinaryWriter writer, SyncStateEntry obj) {
    writer
      ..write(obj.collection)
      ..write(obj.lastPullMs)
      ..write(obj.lastPushMs);
  }
}

class LocalConflictAdapter extends TypeAdapter<LocalConflict> {
  @override
  final int typeId = 15;

  @override
  LocalConflict read(BinaryReader reader) {
    return LocalConflict(
      collection: reader.read() as String,
      entityId: reader.read() as String,
      localUpdatedAtMs: reader.read() as int,
      remoteUpdatedAtMs: reader.read() as int,
      resolvedWithRemote: reader.read() as bool,
      timestampMs: reader.read() as int,
    );
  }

  @override
  void write(BinaryWriter writer, LocalConflict obj) {
    writer
      ..write(obj.collection)
      ..write(obj.entityId)
      ..write(obj.localUpdatedAtMs)
      ..write(obj.remoteUpdatedAtMs)
      ..write(obj.resolvedWithRemote)
      ..write(obj.timestampMs);
  }
}
