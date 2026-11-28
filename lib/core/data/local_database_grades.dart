part of 'local_database.dart';

extension LocalDatabaseGrades on LocalDatabase {
  Iterable<LocalCourseGrade> courseGrades({bool includeDeleted = false}) {
    final values = _courseGradesBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((g) => !g.deleted);
  }

  List<LocalCourseGrade> dirtyCourseGrades() =>
      (_courseGradesBox?.values ?? const Iterable<LocalCourseGrade>.empty())
          .where((g) => g.dirty)
          .toList(growable: false);

  LocalCourseGrade? getCourseGradeById(String id) => _courseGradesBox?.get(id);

  Future<void> putCourseGrade(LocalCourseGrade grade) async {
    await _courseGradesBox?.put(grade.id, grade);
  }

  Iterable<LocalSemester> semesters({bool includeDeleted = false}) {
    final values = _semestersBox?.values ?? const Iterable.empty();
    if (includeDeleted) return values;
    return values.where((s) => !s.deleted);
  }

  List<LocalSemester> dirtySemesters() =>
      (_semestersBox?.values ?? const Iterable<LocalSemester>.empty())
          .where((s) => s.dirty)
          .toList(growable: false);

  LocalSemester? getSemesterById(String id) => _semestersBox?.get(id);

  Future<void> putSemester(LocalSemester semester) async {
    await _semestersBox?.put(semester.id, semester);
  }
}
