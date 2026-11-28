import 'package:numer_app/core/data/grade_entities.dart';
import 'package:numer_app/core/data/local_database.dart';

abstract final class GradeStorage {
  static final LocalDatabase _db = LocalDatabase.instance;

  static void _ensureUser() {
    if (_db.currentUid == null) {
      throw StateError('Storage accessed without configuring user');
    }
  }

  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static List<LocalCourseGrade> courseGrades() {
    _ensureUser();
    return _db.courseGrades().map(_copyGrade).toList();
  }

  static List<LocalSemester> semesters() {
    _ensureUser();
    return _db.semesters().map(_copySemester).toList();
  }

  static Future<void> putCourseGrade({
    required String courseId,
    required String semesterId,
    required String? gradeLetter,
    required List<LocalAssignment> assignments,
  }) async {
    _ensureUser();
    final existing = _db.getCourseGradeById(courseId);
    if (existing == null) {
      await _db.putCourseGrade(
        LocalCourseGrade(
          id: courseId,
          uid: _db.currentUid!,
          updatedAtMs: _now(),
          semesterId: semesterId,
          gradeLetter: gradeLetter,
          assignments: _copyAssignments(assignments),
        ),
      );
      return;
    }
    final changed =
        existing.deleted ||
        existing.semesterId != semesterId ||
        existing.gradeLetter != gradeLetter ||
        !_sameAssignments(existing.assignments, assignments);
    if (!changed) return;
    existing
      ..semesterId = semesterId
      ..gradeLetter = gradeLetter
      ..assignments = _copyAssignments(assignments)
      ..deleted = false
      ..dirty = true
      ..updatedAtMs = _now();
    await existing.save();
  }

  static Future<void> deleteCourseGrade(String courseId) async {
    _ensureUser();
    final entry = _db.getCourseGradeById(courseId);
    if (entry == null || entry.deleted) return;
    entry
      ..deleted = true
      ..dirty = true
      ..updatedAtMs = _now();
    await entry.save();
  }

  static Future<void> putSemester({
    required String id,
    required String name,
    required int position,
  }) async {
    _ensureUser();
    final existing = _db.getSemesterById(id);
    if (existing == null) {
      await _db.putSemester(
        LocalSemester(
          id: id,
          uid: _db.currentUid!,
          updatedAtMs: _now(),
          name: name,
          position: position,
        ),
      );
      return;
    }
    final changed =
        existing.deleted ||
        existing.name != name ||
        existing.position != position;
    if (!changed) return;
    existing
      ..name = name
      ..position = position
      ..deleted = false
      ..dirty = true
      ..updatedAtMs = _now();
    await existing.save();
  }

  static Future<void> deleteSemester(String id) async {
    _ensureUser();
    final entry = _db.getSemesterById(id);
    if (entry == null || entry.deleted) return;
    entry
      ..deleted = true
      ..dirty = true
      ..updatedAtMs = _now();
    await entry.save();
  }

  static String? courseCode(String courseId) {
    _ensureUser();
    return _db.getCourseById(courseId)?.code;
  }

  static Future<void> setCourseCode(String courseId, String? code) async {
    _ensureUser();
    final course = _db.getCourseById(courseId);
    if (course == null || course.code == code) return;
    course
      ..code = code
      ..dirty = true
      ..updatedAtMs = _now();
    await course.save();
  }

  // stored records never share objects with callers, so an in-place edit is seen as a change
  static LocalCourseGrade _copyGrade(LocalCourseGrade g) => LocalCourseGrade(
    id: g.id,
    uid: g.uid,
    updatedAtMs: g.updatedAtMs,
    semesterId: g.semesterId,
    gradeLetter: g.gradeLetter,
    assignments: _copyAssignments(g.assignments),
    dirty: g.dirty,
    deleted: g.deleted,
  );

  static LocalSemester _copySemester(LocalSemester s) => LocalSemester(
    id: s.id,
    uid: s.uid,
    updatedAtMs: s.updatedAtMs,
    name: s.name,
    position: s.position,
    dirty: s.dirty,
    deleted: s.deleted,
  );

  static List<LocalAssignment> _copyAssignments(List<LocalAssignment> list) => [
    for (final a in list)
      LocalAssignment(
        id: a.id,
        name: a.name,
        weight: a.weight,
        maximumScore: a.maximumScore,
        earnedScore: a.earnedScore,
      ),
  ];

  static bool _sameAssignments(
    List<LocalAssignment> a,
    List<LocalAssignment> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.id != y.id ||
          x.name != y.name ||
          x.weight != y.weight ||
          x.maximumScore != y.maximumScore ||
          x.earnedScore != y.earnedScore) {
        return false;
      }
    }
    return true;
  }
}
