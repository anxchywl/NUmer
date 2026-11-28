import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:numer_app/core/data/entities.dart';
import 'package:numer_app/core/data/grade_entities.dart';
import 'package:numer_app/core/data/local_database.dart';

int timestampToMs(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toUtc().millisecondsSinceEpoch;
  }
  if (value is DateTime) {
    return value.toUtc().millisecondsSinceEpoch;
  }
  if (value is int) {
    return value;
  }
  return 0;
}

Map<String, dynamic> courseToRemote(LocalCourse course) {
  return {
    'uid': course.uid,
    'name': course.name,
    'day': course.day,
    'start': course.start,
    'end': course.end,
    'colorValue': course.colorValue,
    'credits': course.credits,
    'expLevel': course.expLevel,
    'goalHours': course.goalHours,
    'totalMinutes': course.totalMinutes,
    'pomodoroLongBreakMinutes': course.pomodoroLongBreakMinutes,
    'sortOrder': course.sortOrder,
    'hiddenFromLeaderboard': course.hiddenFromLeaderboard,
    'code': course.code,
    'deleted': course.deleted,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

Future<void> applyRemoteCourse(
  LocalDatabase db, {
  required String uid,
  required String id,
  required Map<String, dynamic> data,
}) async {
  final updatedAt = timestampToMs(data['updatedAt']);
  var course = db.getCourseById(id);
  if (course == null) {
    course = LocalCourse(
      id: id,
      uid: uid,
      name: data['name'] as String? ?? '',
      day: data['day'] as String? ?? '',
      start: data['start'] as String? ?? '',
      end: data['end'] as String? ?? '',
      colorValue: (data['colorValue'] as num?)?.toInt() ?? 0,
      credits: (data['credits'] as num?)?.toDouble(),
      expLevel: (data['expLevel'] as num?)?.toInt(),
      goalHours: (data['goalHours'] as num?)?.toDouble(),
      totalMinutes: (data['totalMinutes'] as num?)?.toInt() ?? 0,
      pomodoroLongBreakMinutes: (data['pomodoroLongBreakMinutes'] as num?)
          ?.toInt(),
      sortOrder: (data['sortOrder'] as num?)?.toInt(),
      hiddenFromLeaderboard: data['hiddenFromLeaderboard'] == true,
      code: data['code'] as String?,
      updatedAtMs: updatedAt,
      dirty: false,
      deleted: data['deleted'] == true,
    );
    await db.putCourse(course);
    return;
  }

  if (!await _takesRemote(db, course, 'courses', updatedAt)) return;

  course
    ..name = data['name'] as String? ?? course.name
    ..day = data['day'] as String? ?? course.day
    ..start = data['start'] as String? ?? course.start
    ..end = data['end'] as String? ?? course.end
    ..colorValue = (data['colorValue'] as num?)?.toInt() ?? course.colorValue
    ..credits = (data['credits'] as num?)?.toDouble()
    ..expLevel = (data['expLevel'] as num?)?.toInt()
    ..goalHours = (data['goalHours'] as num?)?.toDouble()
    ..sortOrder = (data['sortOrder'] as num?)?.toInt() ?? course.sortOrder
    ..hiddenFromLeaderboard = data['hiddenFromLeaderboard'] == true
    ..code = data['code'] as String?
    ..deleted = data['deleted'] == true
    ..updatedAtMs = updatedAt
    ..dirty = false;
  await course.save();
}

Map<String, dynamic> courseGradeToRemote(LocalCourseGrade grade) {
  return {
    'uid': grade.uid,
    'semesterId': grade.semesterId,
    'gradeLetter': grade.gradeLetter,
    'assignments': [
      for (final a in grade.assignments)
        {
          'id': a.id,
          'name': a.name,
          'weight': a.weight,
          'maximumScore': a.maximumScore,
          'earnedScore': a.earnedScore,
        },
    ],
    'deleted': grade.deleted,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> semesterToRemote(LocalSemester semester) {
  return {
    'uid': semester.uid,
    'name': semester.name,
    'position': semester.position,
    'deleted': semester.deleted,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

Future<void> applyRemoteCourseGrade(
  LocalDatabase db, {
  required String uid,
  required String id,
  required Map<String, dynamic> data,
}) async {
  final updatedAt = timestampToMs(data['updatedAt']);
  final grade = db.getCourseGradeById(id);
  if (grade == null) {
    await db.putCourseGrade(
      LocalCourseGrade(
        id: id,
        uid: uid,
        updatedAtMs: updatedAt,
        semesterId: data['semesterId'] as String? ?? '',
        gradeLetter: data['gradeLetter'] as String?,
        assignments: _assignmentsFromRemote(data['assignments']),
        dirty: false,
        deleted: data['deleted'] == true,
      ),
    );
    return;
  }

  if (!await _takesRemote(db, grade, 'courseGrades', updatedAt)) return;

  grade
    ..semesterId = data['semesterId'] as String? ?? grade.semesterId
    ..gradeLetter = data['gradeLetter'] as String?
    ..assignments = _assignmentsFromRemote(data['assignments'])
    ..deleted = data['deleted'] == true
    ..updatedAtMs = updatedAt
    ..dirty = false;
  await grade.save();
}

Future<void> applyRemoteSemester(
  LocalDatabase db, {
  required String uid,
  required String id,
  required Map<String, dynamic> data,
}) async {
  final updatedAt = timestampToMs(data['updatedAt']);
  final semester = db.getSemesterById(id);
  if (semester == null) {
    await db.putSemester(
      LocalSemester(
        id: id,
        uid: uid,
        updatedAtMs: updatedAt,
        name: data['name'] as String? ?? '',
        position: (data['position'] as num?)?.toInt() ?? 0,
        dirty: false,
        deleted: data['deleted'] == true,
      ),
    );
    return;
  }

  if (!await _takesRemote(db, semester, 'semesters', updatedAt)) return;

  semester
    ..name = data['name'] as String? ?? semester.name
    ..position = (data['position'] as num?)?.toInt() ?? semester.position
    ..deleted = data['deleted'] == true
    ..updatedAtMs = updatedAt
    ..dirty = false;
  await semester.save();
}

Future<bool> _takesRemote(
  LocalDatabase db,
  SyncEntity local,
  String collection,
  int remoteUpdatedAtMs,
) async {
  if (!local.dirty) return true;
  if (remoteUpdatedAtMs <= local.updatedAtMs) return false;
  await db.logConflict(
    collection: collection,
    entityId: local.id,
    localUpdatedAtMs: local.updatedAtMs,
    remoteUpdatedAtMs: remoteUpdatedAtMs,
    resolvedWithRemote: true,
  );
  return true;
}

List<LocalAssignment> _assignmentsFromRemote(Object? value) {
  if (value is! List) return [];
  return [for (final entry in value) ?_assignmentFromRemote(entry)];
}

LocalAssignment? _assignmentFromRemote(Object? entry) {
  if (entry is! Map) return null;
  final id = entry['id'];
  final name = entry['name'];
  final weight = entry['weight'];
  final maximumScore = entry['maximumScore'];
  if (id is! String || name is! String) return null;
  if (weight is! num || maximumScore is! num) return null;
  final earned = entry['earnedScore'];
  return LocalAssignment(
    id: id,
    name: name,
    weight: weight.toDouble(),
    maximumScore: maximumScore.toDouble(),
    earnedScore: earned is num ? earned.toDouble() : null,
  );
}
