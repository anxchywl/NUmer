import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/l10n/app_localizations.dart';

import '../data/stats_chart_groups.dart';
import '../models/stats_models.dart';
import '../stats_format.dart';
import 'chart_tooltip.dart';
import 'period_chart_data.dart';

class PeriodBarChart extends StatelessWidget {
  final Range range;
  final int shift;
  final Future<BucketsPayload> bucketsFuture;
  final List<Course> courses;
  final WeekStart weekStart;
  final BucketTooltip? tooltip;
  final ValueChanged<BucketTooltip> onShowTooltip;
  final VoidCallback onDismissTooltip;

  const PeriodBarChart({
    super.key,
    required this.range,
    required this.shift,
    required this.bucketsFuture,
    required this.courses,
    required this.weekStart,
    required this.tooltip,
    required this.onShowTooltip,
    required this.onDismissTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BucketsPayload>(
      future: bucketsFuture,
      builder: (context, snap) =>
          _chart(snap.data ?? const BucketsPayload.empty()),
    );
  }

  Widget _chart(BucketsPayload payload) {
    final buckets = payload.buckets;
    final totalSecs = payload.totalSeconds;

    final unit = pickUnit(totalSecs);
    final unitScale = scaleForUnit(unit);

    double maxYFinal = 0;
    for (final b in buckets) {
      double sum = 0;
      for (final s in b.secondsByCourse.values) {
        sum += s / unitScale;
      }
      if (sum > maxYFinal) maxYFinal = sum;
    }
    final interval = niceInterval(maxYFinal);
    final maxYAdjusted = (maxYFinal == 0
        ? 1.0
        : (maxYFinal / interval).ceil() * interval);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ChartWithTooltipOverlay(
        tooltip: tooltip,
        onDismiss: onDismissTooltip,
        child: AspectRatio(
          aspectRatio: 1.35,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('bars-$range-$shift-${unit.name}-$totalSecs'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              final effectiveT = Curves.easeOutCubic.transform(t);
              return LayoutBuilder(
                builder: (context, c) {
                  final data = PeriodChartData(
                    context: context,
                    buckets: buckets,
                    courses: courses,
                    range: range,
                    weekStart: weekStart,
                    unit: unit,
                    interval: interval,
                    maxY: maxYAdjusted,
                    totalSeconds: totalSecs,
                    onShowTooltip: onShowTooltip,
                  );
                  return _stack(context, c.maxWidth, data, effectiveT);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stack(
    BuildContext context,
    double chartW,
    PeriodChartData data,
    double effectiveT,
  ) {
    final buckets = data.buckets;
    final n = buckets.isEmpty ? 1 : buckets.length;

    final slot = chartW / n;
    final proposed = slot * 0.85;
    final bw = proposed.clamp(4.0, 34.0).toDouble();

    final (animatedGroups, _) = buildAnimatedGroups(
      buckets,
      courses,
      scaleForUnit(data.unit),
      effectiveT,
      bw,
    );

    return Stack(
      children: [
        BarChart(
          data.chartData(animatedGroups),
          duration: Duration.zero,
          curve: Curves.linear,
        ),
        if (data.totalSeconds == 0) _noData(context),
      ],
    );
  }

  Widget _noData(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noData,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((0.55 * 255).round()),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
