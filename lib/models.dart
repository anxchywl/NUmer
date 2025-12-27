import 'package:hive/hive.dart';
export 'models/course.dart';
export 'models/group.dart';
export 'models/group_statistics.dart';

class AlarmItem {
  final int id;
  final String title;
  final DateTime time; 
  final bool repeatsDaily;

  AlarmItem({
    required this.id,
    required this.title,
    required this.time,
    required this.repeatsDaily,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'time': time.toIso8601String(),
        'repeatsDaily': repeatsDaily,
      };

  static AlarmItem fromJson(Map<String, dynamic> j) => AlarmItem(
        id: j['id'] as int,
        title: j['title'] as String,
        time: DateTime.parse(j['time'] as String).toLocal(),
        repeatsDaily: j['repeatsDaily'] == true,
      );
}



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
