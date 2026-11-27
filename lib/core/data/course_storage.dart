import 'package:numer_app/core/data/entities.dart';
import 'package:numer_app/core/data/local_database.dart';
import 'package:numer_app/features/courses/course.dart';

abstract final class CourseStorage {
  static final LocalDatabase _db = LocalDatabase.instance;

  static void _ensureUser() {
    if (_db.currentUid == null) {
      throw StateError('Storage accessed without configuring user');
    }
  }

  static int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;

  static List<Course> _mapCourses(Iterable<LocalCourse> source) {
    return source
        .where((c) => !c.deleted)
        .map(
          (c) => Course(
            id: c.id,
            name: c.name,
            day: c.day,
            start: c.start,
            end: c.end,
            colorValue: c.colorValue,
            credits: c.credits,
            expLevel: c.expLevel,
            sortOrder: c.sortOrder,
            hiddenFromLeaderboard: c.hiddenFromLeaderboard,
          ),
        )
        .toList();
  }

  static Future<List<Course>> getCourses() async {
    _ensureUser();
    final items = _db.courses().toList();
    await _ensureCourseOrder(items);
    final courses = _mapCourses(items);
    courses.sort(_compareCourseOrder);
    return courses;
  }

  static Future<void> saveCourses(List<Course> courses) async {
    _ensureUser();
    final box = _db.coursesBox;
    final uid = _db.currentUid!;
    final now = _now();

    // the list may be stale, so a missing course is not a delete
    for (final course in courses) {
      final existing = box.get(course.id);
      if (existing == null) {
        final created = LocalCourse(
          id: course.id,
          uid: uid,
          updatedAtMs: now,
          name: course.name,
          day: course.day,
          start: course.start,
          end: course.end,
          colorValue: course.colorValue,
          credits: course.credits,
          expLevel: course.expLevel,
          goalHours: _db.getGoalById(course.id)?.hours,
          totalMinutes: 0,
          pomodoroLongBreakMinutes: null,
          sortOrder: course.sortOrder,
          hiddenFromLeaderboard: course.hiddenFromLeaderboard,
          dirty: true,
          deleted: false,
        );
        await box.put(created.id, created);
        continue;
      }

      bool changed = false;
      void update<T>(T current, T value, void Function(T) assign) {
        if (current != value) {
          assign(value);
          changed = true;
        }
      }

      update(existing.name, course.name, (v) => existing.name = v);
      update(existing.day, course.day, (v) => existing.day = v);
      update(existing.start, course.start, (v) => existing.start = v);
      update(existing.end, course.end, (v) => existing.end = v);
      update(
        existing.colorValue,
        course.colorValue,
        (v) => existing.colorValue = v,
      );
      update(existing.credits, course.credits, (v) => existing.credits = v);
      update(existing.expLevel, course.expLevel, (v) => existing.expLevel = v);
      if (course.sortOrder != null) {
        update(
          existing.sortOrder,
          course.sortOrder,
          (v) => existing.sortOrder = v,
        );
      }
      update(
        existing.hiddenFromLeaderboard,
        course.hiddenFromLeaderboard,
        (v) => existing.hiddenFromLeaderboard = v,
      );
      if (existing.deleted) {
        existing.deleted = false;
        changed = true;
      }
      if (changed) {
        existing.updatedAtMs = now;
        existing.dirty = true;
        await existing.save();
      }
    }
  }

  static Future<void> deleteCourse(String id) async {
    _ensureUser();
    final entry = _db.getCourseById(id);
    if (entry == null || entry.deleted) return;
    entry
      ..deleted = true
      ..dirty = true
      ..updatedAtMs = _now();
    await entry.save();
  }

  static int _compareCourseOrder(Course a, Course b) {
    final ao = a.sortOrder;
    final bo = b.sortOrder;
    if (ao == null && bo == null) return 0;
    if (ao == null) return 1;
    if (bo == null) return -1;
    return ao.compareTo(bo);
  }

  static Future<void> _ensureCourseOrder(List<LocalCourse> items) async {
    if (items.isEmpty) return;
    final hasAnyOrder = items.any((c) => c.sortOrder != null);
    var nextOrder = 0;
    if (hasAnyOrder) {
      final maxExisting = items
          .where((c) => c.sortOrder != null)
          .map((c) => c.sortOrder!)
          .fold<int>(0, (prev, v) => v > prev ? v : prev);
      nextOrder = maxExisting + 1;
    }
    final now = _now();
    for (final course in items) {
      if (course.sortOrder != null) continue;
      course.sortOrder = nextOrder++;
      course.updatedAtMs = now;
      course.dirty = true;
      await course.save();
    }
  }
}
