import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';

import '../data/stats_labels.dart';
import '../models/stats_models.dart';
import '../stats_format.dart';
import 'chart_tooltip.dart';

class PeriodChartData {
  final BuildContext context;
  final List<Bucket> buckets;
  final List<Course> courses;
  final Range range;
  final WeekStart weekStart;
  final TimeUnit unit;
  final double interval;
  final double maxY;
  final int totalSeconds;
  final ValueChanged<BucketTooltip> onShowTooltip;

  const PeriodChartData({
    required this.context,
    required this.buckets,
    required this.courses,
    required this.range,
    required this.weekStart,
    required this.unit,
    required this.interval,
    required this.maxY,
    required this.totalSeconds,
    required this.onShowTooltip,
  });

  BarChartData chartData(List<BarChartGroupData> groups) {
    return BarChartData(
      alignment: BarChartAlignment.spaceBetween,
      minY: 0,
      maxY: maxY,
      barGroups: groups,
      gridData: _grid(),
      titlesData: FlTitlesData(
        leftTitles: _leftTitles(),
        bottomTitles: _bottomTitles(),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      barTouchData: _touch(),
    );
  }

  FlGridData _grid() {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: interval,
      getDrawingHorizontalLine: (v) =>
          FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1),
    );
  }

  AxisTitles _leftTitles() {
    return AxisTitles(
      axisNameWidget: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          unitLabel(unit, context),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      axisNameSize: 22,
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        interval: interval,
        getTitlesWidget: (v, meta) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            fmtAxisTick(v, unit),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  AxisTitles _bottomTitles() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        getTitlesWidget: (v, meta) {
          final idx = v.toInt();
          if (idx < 0 || idx >= buckets.length) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              xLabel(context, buckets[idx], range, weekStart),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        },
      ),
    );
  }

  BarTouchData _touch() {
    return BarTouchData(
      enabled: totalSeconds > 0,
      handleBuiltInTouches: false,
      touchTooltipData: BarTouchTooltipData(
        getTooltipItem: (group, groupIndex, rod, rodIndex) => null,
      ),
      touchCallback: _handleTouch,
    );
  }

  void _handleTouch(FlTouchEvent event, BarTouchResponse? response) {
    if (!context.mounted) return;

    // If the user lifts their finger or moves away from bars,
    // we don't clear the tooltip immediately.
    // This allows the pop-up to stay visible on the last selected point.
    if (response == null || response.spot == null) {
      return;
    }

    final anchor = extractLocal(event);
    if (anchor == null) return;

    final idx = response.spot!.touchedBarGroupIndex;
    if (idx < 0 || idx >= buckets.length) {
      return;
    }

    final bucket = buckets[idx];
    onShowTooltip(
      BucketTooltip(
        anchor: anchor,
        title: tooltipTitle(context, bucket, range),
        items: buildTooltipDetails(context, bucket, courses),
      ),
    );
  }
}
