import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/shared/widgets/tip_icon.dart';

import '../models/stats_models.dart';
import 'period_bar_chart.dart';
import 'period_range_selector.dart';
import 'stats_section_container.dart';

class PeriodStatsSection extends StatelessWidget {
  final Range range;
  final int shift;
  final DateTime start;
  final DateTime end;
  final Future<BucketsPayload> bucketsFuture;
  final List<Course> courses;
  final WeekStart weekStart;
  final BucketTooltip? tooltip;
  final ValueChanged<Range> onSetRange;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<BucketTooltip> onShowTooltip;
  final VoidCallback onDismissTooltip;

  const PeriodStatsSection({
    super.key,
    required this.range,
    required this.shift,
    required this.start,
    required this.end,
    required this.bucketsFuture,
    required this.courses,
    required this.weekStart,
    required this.tooltip,
    required this.onSetRange,
    required this.onPrev,
    required this.onNext,
    required this.onShowTooltip,
    required this.onDismissTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return StatsSectionContainer(
      title: AppLocalizations.of(context)!.periodStatistics,
      trailingHeader: TipIcon(
        title: AppLocalizations.of(context)!.tip,
        message: AppLocalizations.of(context)!.chartTip,
      ),
      child: Column(
        children: [
          PeriodRangeControl(range: range, onSetRange: onSetRange),
          PeriodRangeNavigator(
            range: range,
            shift: shift,
            start: start,
            end: end,
            onPrev: onPrev,
            onNext: onNext,
          ),
          PeriodBarChart(
            range: range,
            shift: shift,
            bucketsFuture: bucketsFuture,
            courses: courses,
            weekStart: weekStart,
            tooltip: tooltip,
            onShowTooltip: onShowTooltip,
            onDismissTooltip: onDismissTooltip,
          ),
        ],
      ),
    );
  }
}
