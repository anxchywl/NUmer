import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../models/stats_models.dart';
import '../stats_format.dart';

String xLabel(BuildContext context, Bucket b, Range r, WeekStart weekStart) {
  switch (r) {
    case Range.week:
      final l10n = AppLocalizations.of(context)!;
      final w = (weekStart == WeekStart.sunday)
          ? [
              l10n.sun,
              l10n.mon,
              l10n.tue,
              l10n.wed,
              l10n.thu,
              l10n.fri,
              l10n.sat,
            ]
          : [
              l10n.mon,
              l10n.tue,
              l10n.wed,
              l10n.thu,
              l10n.fri,
              l10n.sat,
              l10n.sun,
            ];
      final idx = (weekStart == WeekStart.sunday)
          ? (b.date.weekday % 7)
          : (b.date.weekday - 1);
      final safe = idx.clamp(0, 6);
      return w[safe];

    case Range.month:
      const marks = {5, 10, 15, 20, 25, 30};
      return marks.contains(b.date.day) ? '${b.date.day}' : '';

    case Range.year:
      return '${b.date.month}';
  }
}

String periodLabel(
  BuildContext context,
  DateTime start,
  DateTime end,
  Range r,
) {
  switch (r) {
    case Range.week:
      final s = fmtDateShort(start, context);
      final e = fmtDateShort(end.subtract(const Duration(days: 1)), context);
      return '$s – $e';
    case Range.month:
      return '${monthName(context, start.month)} ${start.year}';
    case Range.year:
      return '${start.year}';
  }
}

String tooltipTitle(BuildContext context, Bucket b, Range r) {
  switch (r) {
    case Range.week:
    case Range.month:
      return fmtDateLong(b.date, context);
    case Range.year:
      return '${monthName(context, b.date.month)} ${b.date.year}';
  }
}

List<TooltipItem> buildTooltipDetails(
  BuildContext context,
  Bucket b,
  List<Course> courses,
) {
  final courseById = {for (final c in courses) c.id: c};
  final items = <TooltipItem>[];
  final sortedEntries = b.secondsByCourse.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in sortedEntries) {
    final secs = entry.value;
    if (secs <= 0) continue;
    final c = courseById[entry.key];
    if (c == null) continue;
    items.add(
      TooltipItem(color: c.color, label: c.name, valueHms: fmtHMS(secs)),
    );
  }
  if (items.isEmpty) {
    items.add(
      TooltipItem(
        color: Theme.of(context).colorScheme.outline,
        label: 'No study',
        valueHms: '00:00:00',
      ),
    );
  }
  return items;
}
