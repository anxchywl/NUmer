import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../data/stats_loader.dart';
import '../models/stats_models.dart';
import 'stats_block.dart';
import 'stats_section_container.dart';

typedef _CourseSeconds = ({String name, int seconds, Color? color});

class HeatmapSection extends StatelessWidget {
  final Range range;
  final int shift;
  final WeekStart weekStart;
  final Future<BucketsPayload> bucketsFuture;
  final List<Course> courses;

  const HeatmapSection({
    super.key,
    required this.range,
    required this.shift,
    required this.weekStart,
    required this.bucketsFuture,
    required this.courses,
  });

  @override
  Widget build(BuildContext context) {
    return StatsSectionContainer(
      title: (range == Range.week)
          ? '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisWeek}'
          : (range == Range.month)
          ? '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisMonth}'
          : '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisYear}',
      useCard: false,
      child: FutureBuilder<BucketsPayload>(
        future: bucketsFuture,
        builder: (context, snap) {
          final payload = snap.data ?? const BucketsPayload.empty();
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: _content(payload),
          );
        },
      ),
    );
  }

  Widget _content(BucketsPayload payload) {
    final buckets = payload.buckets;
    final totalSecs = payload.totalSeconds;
    final (most, least) = _mostAndLeast(buckets);

    if (range == Range.year) {
      return _yearBlock(totalSecs, most, least);
    }
    final activeDays = buckets.where((b) => b.totalSeconds > 0).length;
    final avgSecs = activeDays > 0 ? (totalSecs ~/ activeDays) : 0;
    return _block(totalSecs, avgSecs, most, least);
  }

  (_CourseSeconds, _CourseSeconds) _mostAndLeast(List<Bucket> buckets) {
    final perCourse = <String, int>{};
    for (final b in buckets) {
      b.secondsByCourse.forEach((id, secs0) {
        final secs = secs0 < 0 ? 0 : secs0;
        perCourse[id] = (perCourse[id] ?? 0) + secs;
      });
    }

    final courseById = {for (final c in courses) c.id: c};
    final positive =
        perCourse.entries
            .where((e) => courseById.containsKey(e.key) && e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    _CourseSeconds most = (name: '—', seconds: 0, color: null);
    _CourseSeconds least = (name: '—', seconds: 0, color: null);

    if (positive.isNotEmpty) {
      _CourseSeconds describe(MapEntry<String, int> e) => (
        name: courseById[e.key]!.name,
        seconds: e.value,
        color: courseById[e.key]!.color,
      );
      most = describe(positive.first);
      least = describe(positive.last);
    }
    return (most, least);
  }

  Widget _yearBlock(int totalSecs, _CourseSeconds most, _CourseSeconds least) {
    final (start, end) = rangeBounds(DateTime.now(), range, shift, weekStart);
    final days = end.difference(start).inDays;
    return FutureBuilder<List<Map<String, int>>>(
      future: Storage.dailySeries(start, days),
      builder: (context, daySnap) {
        final list = daySnap.data ?? const <Map<String, int>>[];
        final activeDays = list.where((m) => m.values.any((s) => s > 0)).length;
        final avgSecs = activeDays > 0 ? (totalSecs ~/ activeDays) : 0;
        return _block(totalSecs, avgSecs, most, least);
      },
    );
  }

  Widget _block(
    int totalSecs,
    int avgSecs,
    _CourseSeconds most,
    _CourseSeconds least,
  ) {
    return StatsBlock(
      totalSecs: totalSecs,
      avgSecs: avgSecs,
      mostName: most.name,
      mostSecs: most.seconds,
      mostColor: most.color,
      leastName: least.name,
      leastSecs: least.seconds,
      leastColor: least.color,
    );
  }
}
