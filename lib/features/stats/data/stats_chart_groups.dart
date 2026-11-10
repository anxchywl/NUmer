import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:numer_app/features/courses/courses.dart';

import '../models/stats_models.dart';

typedef _Segment = ({double from, double to, Color color});

(List<BarChartGroupData>, double) buildAnimatedGroups(
  List<Bucket> buckets,
  List<Course> courses,
  double unitScale,
  double t,
  double barWidth,
) {
  final groups = <BarChartGroupData>[];
  double fullMaxY = 0;
  const double stagger = 0.03;

  final courseById = {for (final c in courses) c.id: c};

  for (var i = 0; i < buckets.length; i++) {
    final b = buckets[i];

    final (segs, accFinal) = _courseSegments(b, courseById, unitScale);

    fullMaxY = math.max(fullMaxY, accFinal);

    final start = i * stagger;
    final localT = (t - start) / (1 - start);
    final tt = localT.clamp(0.0, 1.0);

    groups.add(_animatedGroup(i, segs, accFinal, tt, barWidth));
  }

  return (groups, fullMaxY);
}

(List<_Segment>, double) _courseSegments(
  Bucket b,
  Map<String, Course> courseById,
  double unitScale,
) {
  double accFinal = 0;
  final segs = <_Segment>[];

  final entries = b.secondsByCourse.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  for (final e in entries) {
    final course = courseById[e.key];
    if (course == null) continue;
    final segValue = (e.value / unitScale).toDouble();
    if (segValue <= 0) continue;
    final from = accFinal;
    final to = accFinal + segValue;
    accFinal = to;
    segs.add((from: from, to: to, color: course.color));
  }
  return (segs, accFinal);
}

BarChartGroupData _animatedGroup(
  int i,
  List<_Segment> segs,
  double accFinal,
  double tt,
  double barWidth,
) {
  final items = <BarChartRodStackItem>[];
  for (final s in segs) {
    final from = s.from * tt;
    final to = s.to * tt;
    if (to > from) items.add(BarChartRodStackItem(from, to, s.color));
  }
  final hasData = items.isNotEmpty;

  return BarChartGroupData(
    x: i,
    barRods: [
      BarChartRodData(
        toY: hasData ? (accFinal * tt) : 0,
        width: barWidth,
        color: Colors.transparent,
        borderRadius: hasData ? BorderRadius.circular(6) : BorderRadius.zero,
        rodStackItems: hasData ? items : const [],
      ),
    ],
  );
}
