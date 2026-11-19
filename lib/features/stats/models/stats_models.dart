import 'package:flutter/material.dart';

class SliceTooltip {
  final Offset local;
  final String id;
  final String name;
  final int seconds;
  SliceTooltip({
    required this.local,
    required this.id,
    required this.name,
    required this.seconds,
  });
}

class Bucket {
  final DateTime date;
  final Map<String, int> secondsByCourse;
  final bool isMonth;
  Bucket({
    required this.date,
    required this.secondsByCourse,
    this.isMonth = false,
  });

  int get totalSeconds =>
      secondsByCourse.values.fold<int>(0, (a, b) => a + (b < 0 ? 0 : b));
}

class BucketTooltip {
  final Offset anchor;
  final String title;
  final List<TooltipItem> items;
  BucketTooltip({
    required this.anchor,
    required this.title,
    required this.items,
  });
}

class TooltipItem {
  final Color color;
  final String label;
  final String valueHms;
  TooltipItem({
    required this.color,
    required this.label,
    required this.valueHms,
  });
}

class Slice {
  final String id;
  final String name;
  final Color color;
  final int seconds;
  const Slice({
    required this.id,
    required this.name,
    required this.color,
    required this.seconds,
  });
}

class PiePayload {
  final List<Slice> slices;
  final int totalSeconds;
  const PiePayload({required this.slices, required this.totalSeconds});
}

class BucketsPayload {
  final List<Bucket> buckets;
  final int totalSeconds;
  const BucketsPayload({required this.buckets, required this.totalSeconds});
  const BucketsPayload.empty() : buckets = const [], totalSeconds = 0;
}

enum Range { week, month, year }

enum TimeUnit { seconds, minutes, hours }

class HabitStatsResult {
  final int required;
  final int completed;
  final int notCompleted;
  final double completionRate;

  const HabitStatsResult(
    this.required,
    this.completed,
    this.notCompleted,
    this.completionRate,
  );
}
