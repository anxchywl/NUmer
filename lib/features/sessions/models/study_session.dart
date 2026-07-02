import 'package:hive/hive.dart';

@HiveType(typeId: 1)
class StudySession extends HiveObject {
  @HiveField(0)
  String courseId;

  @HiveField(1)
  DateTime startUtc;

  @HiveField(2)
  DateTime endUtc;

  @HiveField(3)
  int seconds;

  @HiveField(4)
  String? kind;

  StudySession({
    required this.courseId,
    required this.startUtc,
    required this.endUtc,
    required this.seconds,
    this.kind,
  });
}

class StudySessionAdapter extends TypeAdapter<StudySession> {
  @override
  final int typeId = 1;

  @override
  StudySession read(BinaryReader reader) {
    final courseId = reader.read() as String;
    final startUtc = reader.read() as DateTime;
    final endUtc = reader.read() as DateTime;
    final seconds = reader.read() as int;
    final kind = reader.read() as String?;
    return StudySession(
      courseId: courseId,
      startUtc: startUtc,
      endUtc: endUtc,
      seconds: seconds,
      kind: kind,
    );
  }

  @override
  void write(BinaryWriter writer, StudySession obj) {
    writer
      ..write(obj.courseId)
      ..write(obj.startUtc)
      ..write(obj.endUtc)
      ..write(obj.seconds)
      ..write(obj.kind);
  }
}
