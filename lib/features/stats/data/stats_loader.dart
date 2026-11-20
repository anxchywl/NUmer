import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/courses/courses.dart';

import '../models/stats_models.dart';

DateTime strip(DateTime d) => DateTime(d.year, d.month, d.day);

Future<PiePayload> loadPieForDay(DateTime day, List<Course> courses) async {
  final valid = courses.map((c) => c.id).toSet();
  final start = strip(day);
  final isToday = strip(day) == strip(DateTime.now());
  final end = isToday ? DateTime.now() : start.add(const Duration(days: 1));
  final perCourse = await Storage.secondsByCourseBetween(start, end);

  final slices = <Slice>[];
  int total = 0;
  perCourse.forEach((courseId, secs0) {
    if (!valid.contains(courseId)) return;
    final secs = secs0 < 0 ? 0 : secs0;
    if (secs <= 0) return;
    final course = courses.firstWhere((c) => c.id == courseId);
    slices.add(
      Slice(
        id: courseId,
        name: course.name,
        color: course.color,
        seconds: secs,
      ),
    );
    total += secs;
  });

  slices.sort((a, b) => b.seconds.compareTo(a.seconds));
  return PiePayload(slices: slices, totalSeconds: total);
}

Future<BucketsPayload> loadBucketsForRange(
  DateTime start,
  DateTime end,
  Range r,
  List<Course> courses,
) async {
  final buckets = r == Range.week || r == Range.month
      ? await _dayBuckets(start, end, courses)
      : await _monthBuckets(start, courses);
  final totalSecs = buckets.fold<int>(0, (sum, b) => sum + b.totalSeconds);

  return BucketsPayload(buckets: buckets, totalSeconds: totalSecs);
}

Future<List<Bucket>> _dayBuckets(
  DateTime start,
  DateTime end,
  List<Course> courses,
) async {
  final buckets = <Bucket>[];
  final days = end.difference(start).inDays;
  final now = DateTime.now();
  final todayKey = DateTime(now.year, now.month, now.day);

  for (var i = 0; i < days; i++) {
    final dayStart = DateTime(
      start.year,
      start.month,
      start.day,
    ).add(Duration(days: i));
    final isToday =
        DateTime(dayStart.year, dayStart.month, dayStart.day) == todayKey;
    final dayEnd = isToday ? now : dayStart.add(const Duration(days: 1));

    final map = await Storage.secondsByCourseBetween(dayStart, dayEnd);

    final cleaned = _cleanSeconds(map, courses);

    buckets.add(Bucket(date: dayStart, secondsByCourse: cleaned));
  }
  return buckets;
}

Future<List<Bucket>> _monthBuckets(DateTime start, List<Course> courses) async {
  final buckets = <Bucket>[];
  for (var month = 1; month <= 12; month++) {
    final monthStart = DateTime(start.year, month, 1);
    final monthEnd = DateTime(start.year, month + 1, 1);
    final now = DateTime.now();
    final effectiveEnd = (monthEnd.isAfter(now) && now.isAfter(monthStart))
        ? now
        : monthEnd;

    final map = await Storage.secondsByCourseBetween(monthStart, effectiveEnd);
    final cleaned = _cleanSeconds(map, courses);
    buckets.add(
      Bucket(date: monthStart, secondsByCourse: cleaned, isMonth: true),
    );
  }
  return buckets;
}

// every course gets an entry so the chart keeps one segment slot per course
Map<String, int> _cleanSeconds(Map<String, int> map, List<Course> courses) {
  final valid = courses.map((c) => c.id).toSet();
  final cleaned = <String, int>{};
  map.forEach((k, v) {
    if (!valid.contains(k)) return;
    final secs = v < 0 ? 0 : v;
    if (secs > 0) cleaned[k] = secs;
  });
  for (final c in courses) {
    cleaned.putIfAbsent(c.id, () => 0);
  }
  return cleaned;
}

(DateTime, DateTime) rangeBounds(
  DateTime base,
  Range r,
  int shift,
  WeekStart weekStart,
) {
  switch (r) {
    case Range.week:
      final int delta = (weekStart == WeekStart.monday)
          ? (base.weekday - DateTime.monday)
          : (base.weekday % 7);
      final anchor = strip(base.subtract(Duration(days: delta)));
      final start = anchor.add(Duration(days: 7 * shift));
      final end = start.add(const Duration(days: 7));
      return (start, end);

    case Range.month:
      final start0 = DateTime(base.year, base.month, 1);
      final start = DateTime(start0.year, start0.month + shift, 1);
      final end = DateTime(start.year, start.month + 1, 1);
      return (strip(start), strip(end));

    case Range.year:
      final start0 = DateTime(base.year, 1, 1);
      final start = DateTime(start0.year + shift, 1, 1);
      final end = DateTime(start.year + 1, 1, 1);
      return (strip(start), strip(end));
  }
}
