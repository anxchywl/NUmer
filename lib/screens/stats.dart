
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/storage.dart'; 

import '../widgets/heatmap_calendar.dart';
import 'history.dart';
import '../l10n/app_localizations.dart';
import '../widgets/tip_icon.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  
  DateTime _day = _strip(DateTime.now());
  static DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);
  bool get _isToday => _strip(DateTime.now()) == _day;
  _SliceTooltip? _sliceTooltip;

  void _prevDay() => setState(() {
    _day = _day.subtract(const Duration(days: 1));
    _sliceTooltip = null;
  });
  void _nextDay() {
    if (_isToday) return;
    setState(() {
      _day = _day.add(const Duration(days: 1));
      _sliceTooltip = null;
    });
  }
  void _goToday() {
    if (_isToday) return;
    setState(() {
      _day = _strip(DateTime.now());
      _sliceTooltip = null;
    });
  }
  Future<void> _pickDay(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.only(top: 16),
          child: HeatmapCalendar(
            focusedDay: _day,
            selectedDay: _day,
            onDaySelected: (selected, focused) {
              setState(() {
                _day = _strip(selected);
                _sliceTooltip = null;
              });
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  
  _Range _range = _Range.week; 
  int _shift = 0;              

  void _prevRange() => setState(() {
    _shift -= 1;
    _tooltip = null;
  });
  void _nextRange() {
    if (_shift >= 0) return;
    setState(() {
      _shift += 1;
      _tooltip = null;
    });
  }
  void _setRange(_Range r) => setState(() {
        _range = r;
        _shift = 0;
        _tooltip = null;
      });

  
  _BucketTooltip? _tooltip;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final courses = state.courses;
    final weekStart = state.weekStart;

    
    final pieFuture = _loadPieForDay(_day, courses);

    
    final (start, end) = _rangeBounds(DateTime.now(), _range, _shift, weekStart);
    final bucketsFuture = _loadBucketsForRange(start, end, _range, courses);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(AppLocalizations.of(context)!.statistics)),
          SliverToBoxAdapter(
            child: _buildSectionContainer(
              context,
              title: AppLocalizations.of(context)!.dayStatistics,
              trailingHeader: TipIcon(
                title: AppLocalizations.of(context)!.tip,
                message:
                    '${AppLocalizations.of(context)!.dayStatsTipLine1}\n${AppLocalizations.of(context)!.dayStatsTipLine2}\n${AppLocalizations.of(context)!.dayStatsTipLine3}',
              ),
              child: Column(
                children: [
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: AppLocalizations.of(context)!.previousDay,
                          onPressed: _prevDay,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                flex: 2,
                                child: TextButton.icon(
                                  onPressed: () => _pickDay(context),
                                  icon: const Icon(Icons.calendar_today, size: 20),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _fmtDateLong(_day, context),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Theme.of(context).dividerColor),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: OutlinedButton(
                                  onPressed: _isToday ? null : _goToday,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(AppLocalizations.of(context)!.today),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: AppLocalizations.of(context)!.nextDay,
                          onPressed: _isToday ? null : _nextDay,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),

                  
                  FutureBuilder<_PiePayload>(
                    future: pieFuture,
                    builder: (context, snap) {
                      final total = snap.data?.totalSeconds ?? 0;
                      final slices = snap.data?.slices ?? const <_Slice>[];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: _PieChartWithTooltip(
                          totalSeconds: total,
                          slices: slices,
                          tooltip: _sliceTooltip,
                          onSliceTap: (tap) => setState(() => _sliceTooltip = tap),
                          onDismiss: () => setState(() => _sliceTooltip = null),
                        ),
                      );
                    },
                  ),

                  
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.history, size: 18),
                        label: Text(AppLocalizations.of(context)!.history),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          final dayStart = _strip(_day);
                          final dayEnd = _isToday ? DateTime.now() : dayStart.add(const Duration(days: 1));
                          final selectedCourseId = _sliceTooltip?.id;

                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => HistoryScreen(
                                startLocal: dayStart,
                                endLocal: dayEnd,
                                courseId: selectedCourseId,
                              ),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          SliverToBoxAdapter(
            child: _buildSectionContainer(
              context,
              title: AppLocalizations.of(context)!.periodStatistics,
              trailingHeader: TipIcon(
                title: AppLocalizations.of(context)!.tip,
                message: AppLocalizations.of(context)!.chartTip,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _SegChip(label: AppLocalizations.of(context)!.week,  selected: _range == _Range.week,  onTap: () => _setRange(_Range.week)),
                        _SegChip(label: AppLocalizations.of(context)!.month, selected: _range == _Range.month, onTap: () => _setRange(_Range.month)),
                        _SegChip(label: AppLocalizations.of(context)!.year,  selected: _range == _Range.year,  onTap: () => _setRange(_Range.year)),
                      ],
                    ),
                  ),

                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: _prevLabel(context, _range),
                          onPressed: _prevRange,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: null,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Theme.of(context).dividerColor),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _periodLabel(start, end, _range),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _nextLabel(context, _range),
                          onPressed: _shift >= 0 ? null : _nextRange,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                  
                  
                  FutureBuilder<_BucketsPayload>(
                    future: bucketsFuture,
                    builder: (context, snap) {
                      final payload = snap.data ?? const _BucketsPayload.empty();
                      final buckets = payload.buckets;
                      final totalSecs = payload.totalSeconds;

                      final unit = _pickUnit(totalSecs);
                      final unitScale = _scaleForUnit(unit);

                      double maxYFinal = 0;
                      for (final b in buckets) {
                        double sum = 0;
                        for (final s in b.secondsByCourse.values) {
                          sum += s / unitScale;
                        }
                        if (sum > maxYFinal) maxYFinal = sum;
                      }
                      final interval = _niceInterval(maxYFinal);
                      final maxYAdjusted =
                          (maxYFinal == 0 ? 1.0 : (maxYFinal / interval).ceil() * interval);

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: _ChartWithTooltipOverlay(
                          tooltip: _tooltip,
                          onDismiss: () => setState(() => _tooltip = null),
                          child: AspectRatio(
                            aspectRatio: 1.35,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('bars-$_range-$_shift-${unit.name}-$totalSecs'),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, _) {
                                final effectiveT = Curves.easeOutCubic.transform(t);
                                return LayoutBuilder(
                                  builder: (context, c) {
                                    final n = buckets.isEmpty ? 1 : buckets.length;
                                    final chartW = c.maxWidth;

                                    final slot = chartW / n;
                                    final proposed = slot * 0.85;
                                    final bw = proposed.clamp(4.0, 34.0).toDouble();

                                    final (animatedGroups, _) =
                                        _buildAnimatedGroups(buckets, courses, unitScale, effectiveT, bw);

                                    return Stack(
                                      children: [
                                        BarChart(
                                          BarChartData(
                                            alignment: BarChartAlignment.spaceBetween,
                                            minY: 0,
                                            maxY: maxYAdjusted,
                                            barGroups: animatedGroups,
                                            gridData: FlGridData(
                                              show: true,
                                              drawVerticalLine: false,
                                              horizontalInterval: interval,
                                              getDrawingHorizontalLine: (v) =>
                                                  FlLine(color: Theme.of(context).dividerColor, strokeWidth: 1)
                                            ),
                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                axisNameWidget: Padding(
                                                  padding: const EdgeInsets.only(bottom: 6),
                                                  child: Text(
                                                    _unitLabel(unit, context),
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
                                                      _fmtAxisTick(v, unit),
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget: (v, meta) {
                                                    final idx = v.toInt();
                                                    if (idx < 0 || idx >= buckets.length) return const SizedBox.shrink();
                                                    return Padding(
                                                      padding: const EdgeInsets.only(top: 6),
                                                      child: Text(
                                                        _xLabel(buckets[idx], _range, weekStart),
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                              color: Theme.of(context).colorScheme.onSurface,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            ),
                                            borderData: FlBorderData(show: false),
                                            barTouchData: BarTouchData(
                                              enabled: totalSecs > 0,
                                              handleBuiltInTouches: false,
                                              touchTooltipData: BarTouchTooltipData(
                                                getTooltipItem: (group, groupIndex, rod, rodIndex) => null, 
                                              ),
                                              touchCallback: (event, response) {
                                                if (!mounted) return;

                                                // If the user lifts their finger or moves away from bars,
                                                // we don't clear the tooltip immediately.
                                                // This allows the pop-up to stay visible on the last selected point.
                                                if (response == null || response.spot == null) return;

                                                final anchor = _extractLocal(event);
                                                if (anchor == null) return;

                                                final idx = response.spot!.touchedBarGroupIndex;
                                                if (idx < 0 || idx >= buckets.length) return;

                                                final bucket = buckets[idx];
                                                final items = _buildTooltipDetails(bucket, courses);
                                                setState(() {
                                                  _tooltip = _BucketTooltip(
                                                    anchor: anchor,
                                                    title: _tooltipTitle(bucket, _range),
                                                    items: items,
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                          duration: Duration.zero,
                                          curve: Curves.linear,
                                        ),
                                        if (totalSecs == 0)
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: Center(
                                                child: Text(
                                                  AppLocalizations.of(context)!.noData,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        color: Theme.of(context).colorScheme.onSurface.withAlpha((0.55 * 255).round()),
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          
          SliverToBoxAdapter(
            child: _buildSectionContainer(
              context,
                    title: (_range == _Range.week)
                      ? '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisWeek}'
                      : (_range == _Range.month)
                        ? '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisMonth}'
                        : '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisYear}',
              useCard: false,
              child: FutureBuilder<_BucketsPayload>(
                future: bucketsFuture,
                builder: (context, snap) {
                  final payload = snap.data ?? const _BucketsPayload.empty();
                  final buckets = payload.buckets;
                  final totalSecs = payload.totalSeconds;

                  final perCourse = <String, int>{};
                  for (final b in buckets) {
                    b.secondsByCourse.forEach((id, secs0) {
                      final secs = secs0 < 0 ? 0 : secs0;
                      perCourse[id] = (perCourse[id] ?? 0) + secs;
                    });
                  }

                  final courseById = {for (final c in courses) c.id: c};
                  final positive = perCourse.entries
                      .where((e) => courseById.containsKey(e.key) && e.value > 0)
                      .toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  String mostName = '—';
                  int mostSecs = 0;
                  Color? mostColor;
                  String leastName = '—';
                  int leastSecs = 0;
                  Color? leastColor;

                  if (positive.isNotEmpty) {
                    final most = positive.first;
                    mostName = courseById[most.key]!.name;
                    mostSecs = most.value;
                    mostColor = courseById[most.key]!.color;

                    final least = positive.last;
                    leastName = courseById[least.key]!.name;
                    leastSecs = least.value;
                    leastColor = courseById[least.key]!.color;
                  }

                  Widget content;
                  if (_range == _Range.year) {
                    final (start, end) = _rangeBounds(DateTime.now(), _range, _shift, weekStart);
                    final days = end.difference(start).inDays;
                    content = FutureBuilder<List<Map<String, int>>>(
                      future: Storage.dailySeries(start, days),
                      builder: (context, daySnap) {
                        final list = daySnap.data ?? const <Map<String, int>>[];
                        final activeDays = list.where((m) => m.values.any((s) => s > 0)).length;
                        final avgSecs = activeDays > 0 ? (totalSecs ~/ activeDays) : 0;
                        return _StatsBlock(
                          totalSecs: totalSecs,
                          avgSecs: avgSecs,
                          mostName: mostName,
                          mostSecs: mostSecs,
                          mostColor: mostColor,
                          leastName: leastName,
                          leastSecs: leastSecs,
                          leastColor: leastColor,
                        );
                      },
                    );
                  } else {
                    final activeDays = buckets.where((b) => b.totalSeconds > 0).length;
                    final avgSecs = activeDays > 0 ? (totalSecs ~/ activeDays) : 0;
                    content = _StatsBlock(
                      totalSecs: totalSecs,
                      avgSecs: avgSecs,
                      mostName: mostName,
                      mostSecs: mostSecs,
                      mostColor: mostColor,
                      leastName: leastName,
                      leastSecs: leastSecs,
                      leastColor: leastColor,
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: content,
                  );
                },
              ),
            ),
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _buildSectionContainer(
    BuildContext context, {
    required String title,
    required Widget child,
    bool useCard = true,
    Widget? trailingHeader,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (trailingHeader != null) trailingHeader,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: useCard
              ? Container(
                  clipBehavior: Clip.none,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: child,
                )
              : child,
        ),
      ],
    );
  }

  

  Future<_PiePayload> _loadPieForDay(DateTime day, List<Course> courses) async {
    final valid = courses.map((c) => c.id).toSet();
  final start = _strip(day);
  final isToday = _strip(day) == _strip(DateTime.now());
  final end = isToday ? DateTime.now() : start.add(const Duration(days: 1));
    final perCourse = await Storage.secondsByCourseBetween(start, end);

    final slices = <_Slice>[];
    int total = 0;
    perCourse.forEach((courseId, secs0) {
      if (!valid.contains(courseId)) return; 
      final secs = secs0 < 0 ? 0 : secs0;
      if (secs <= 0) return;
      final course = courses.firstWhere((c) => c.id == courseId);
      slices.add(_Slice(
        id: courseId,
        name: course.name,
        color: course.color,
        seconds: secs,
      ));
      total += secs;
    });

    slices.sort((a, b) => b.seconds.compareTo(a.seconds));
    return _PiePayload(slices: slices, totalSeconds: total);
  }

  Future<_BucketsPayload> _loadBucketsForRange(
  DateTime start,
  DateTime end,
  _Range r,
  List<Course> courses,
) async {
  final valid = courses.map((c) => c.id).toSet();
  final buckets = <_Bucket>[];
  int totalSecs = 0;

  if (r == _Range.week || r == _Range.month) {
    final days = end.difference(start).inDays;
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < days; i++) {
      final dayStart = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      final isToday = DateTime(dayStart.year, dayStart.month, dayStart.day) == todayKey;
      final dayEnd = isToday ? now : dayStart.add(const Duration(days: 1));

      final map = await Storage.secondsByCourseBetween(dayStart, dayEnd);

      final cleaned = <String, int>{};
      map.forEach((k, v) {
        if (!valid.contains(k)) return; 
        final secs = v < 0 ? 0 : v;
        if (secs > 0) {
          cleaned[k] = secs;
          totalSecs += secs;
        }
      });

      
      for (final c in courses) {
        cleaned.putIfAbsent(c.id, () => 0);
      }

      buckets.add(_Bucket(date: dayStart, secondsByCourse: cleaned));
    }
  } else {
    
    for (var month = 1; month <= 12; month++) {
      final monthStart = DateTime(start.year, month, 1);
      final monthEnd = DateTime(start.year, month + 1, 1);
      final now = DateTime.now();
      final effectiveEnd = (monthEnd.isAfter(now) && now.isAfter(monthStart)) ? now : monthEnd;

      final map = await Storage.secondsByCourseBetween(monthStart, effectiveEnd);
      final cleaned = <String, int>{};
      map.forEach((k, v) {
        if (!valid.contains(k)) return; 
        final secs = v < 0 ? 0 : v;
        if (secs > 0) {
          cleaned[k] = secs;
          totalSecs += secs;
        }
      });
      for (final c in courses) {
        cleaned.putIfAbsent(c.id, () => 0);
      }
      buckets.add(_Bucket(date: monthStart, secondsByCourse: cleaned, isMonth: true));
    }
  }

  return _BucketsPayload(buckets: buckets, totalSeconds: totalSecs);
}

  

  (List<BarChartGroupData>, double) _buildAnimatedGroups(
  List<_Bucket> buckets,
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

      
      double accFinal = 0;
      final segs = <({double from, double to, Color color})>[];

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

      fullMaxY = math.max(fullMaxY, accFinal);

      
      final start = i * stagger;
      final localT = (t - start) / (1 - start);
      final tt = localT.clamp(0.0, 1.0);

      final items = <BarChartRodStackItem>[];
      for (final s in segs) {
        final from = s.from * tt;
        final to = s.to * tt;
        if (to > from) items.add(BarChartRodStackItem(from, to, s.color));
      }
      final hasData = items.isNotEmpty;

      groups.add(
        BarChartGroupData(
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
        ),
      );
    }

    return (groups, fullMaxY);
  }

  

  (DateTime, DateTime) _rangeBounds(DateTime base, _Range r, int shift, WeekStart weekStart) {
    switch (r) {
      case _Range.week:
        
        final int delta = (weekStart == WeekStart.monday)
            ? (base.weekday - DateTime.monday)                 
            : (base.weekday % 7);                               
        final anchor = _strip(base.subtract(Duration(days: delta)));
        final start = anchor.add(Duration(days: 7 * shift));
        final end = start.add(const Duration(days: 7));
        return (start, end);

      case _Range.month:
        final start0 = DateTime(base.year, base.month, 1);
        final start = DateTime(start0.year, start0.month + shift, 1);
        final end = DateTime(start.year, start.month + 1, 1);
        return (_strip(start), _strip(end));

      case _Range.year:
        final start0 = DateTime(base.year, 1, 1);
        final start = DateTime(start0.year + shift, 1, 1);
        final end = DateTime(start.year + 1, 1, 1);
        return (_strip(start), _strip(end));
    }
  }

  String _xLabel(_Bucket b, _Range r, WeekStart weekStart) {
    switch (r) {
      case _Range.week:
        final l10n = AppLocalizations.of(context)!;
        final w = (weekStart == WeekStart.sunday)
            ? [l10n.sun, l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat]
            : [l10n.mon, l10n.tue, l10n.wed, l10n.thu, l10n.fri, l10n.sat, l10n.sun];
        final idx = (weekStart == WeekStart.sunday)
            ? (b.date.weekday % 7) 
            : (b.date.weekday - 1); 
        final safe = idx.clamp(0, 6);
        return w[safe];

      case _Range.month:
        const marks = {5, 10, 15, 20, 25, 30};
        return marks.contains(b.date.day) ? '${b.date.day}' : '';

      case _Range.year:
        return '${b.date.month}';
    }
  }

  String _periodLabel(DateTime start, DateTime end, _Range r) {
    switch (r) {
      case _Range.week:
        final s = _fmtDateShort(start, context);
        final e = _fmtDateShort(end.subtract(const Duration(days: 1)), context);
        return '$s – $e';
      case _Range.month:
        return '${_monthName(context, start.month)} ${start.year}';
      case _Range.year:
        return '${start.year}';
    }
  }

  String _tooltipTitle(_Bucket b, _Range r) {
    switch (r) {
      case _Range.week:
      case _Range.month:
        return _fmtDateLong(b.date, context);
      case _Range.year:
        return '${_monthName(context, b.date.month)} ${b.date.year}';
    }
  }

  List<_TooltipItem> _buildTooltipDetails(_Bucket b, List<Course> courses) {
    final courseById = {for (final c in courses) c.id: c};
    final items = <_TooltipItem>[];
    final sortedEntries = b.secondsByCourse.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedEntries) {
      final secs = entry.value;
      if (secs <= 0) continue;
      final c = courseById[entry.key];
      if (c == null) continue; 
      items.add(_TooltipItem(color: c.color, label: c.name, valueHms: _fmtHMS(secs)));
    }
    if (items.isEmpty) {
      items.add(_TooltipItem(
        color: Theme.of(context).colorScheme.outline,
        label: 'No study',
        valueHms: '00:00:00',
      ));
    }
    return items;
  }
}


Offset? _extractLocal(FlTouchEvent e) {
  if (e is FlTapUpEvent) return e.localPosition;
  if (e is FlTapDownEvent) return e.localPosition;
  if (e is FlLongPressStart) return e.localPosition;
  if (e is FlLongPressMoveUpdate) return e.localPosition;
  if (e is FlPanDownEvent) return e.localPosition;
  if (e is FlPanUpdateEvent) return e.localPosition;
  if (e is FlPointerHoverEvent) return e.localPosition;
  return null;
}


class _ChartWithTooltipOverlay extends StatelessWidget {
  final _BucketTooltip? tooltip;
  final VoidCallback onDismiss;
  final Widget child;
  const _ChartWithTooltipOverlay({
    required this.tooltip,
    required this.onDismiss,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (tooltip != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
        if (tooltip != null)
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _TooltipLayoutDelegate(
                anchor: tooltip!.anchor,
                screenPadding: 16.0,
              ),
              child: _TooltipBubble(data: tooltip!),
            ),
          ),
      ],
    );
  }
}

class _TooltipBubble extends StatelessWidget {
  final _BucketTooltip data;
  const _TooltipBubble({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
  child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 160,
          maxWidth: 240,
          maxHeight: 400,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final it in data.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: it.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                it.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              it.valueHms,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsBlock extends StatelessWidget {
  final int totalSecs;
  final int avgSecs;
  final String mostName;
  final int mostSecs;
  final Color? mostColor;
  final String leastName;
  final int leastSecs;
  final Color? leastColor;

  const _StatsBlock({
    required this.totalSecs,
    required this.avgSecs,
    required this.mostName,
    required this.mostSecs,
    this.mostColor,
    required this.leastName,
    required this.leastSecs,
    this.leastColor,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const spacing = 12.0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Text(
                l10n.total,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                _fmtTotalVerbose(totalSecs, context)
                    .replaceFirst(' ${l10n.total.toLowerCase()}', ''),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: spacing),
        Row(
          children: [
            Expanded(
              child: _DetailStatCard(
                title: l10n.mostStudied,
                value: mostName,
                subValue: mostSecs > 0 ? _fmtHMS(mostSecs) : null,
                accentColor: mostColor,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: spacing),
            Expanded(
              child: _DetailStatCard(
                title: l10n.leastStudied,
                value: leastName,
                subValue: (leastSecs > 0 && mostSecs > 0) ? _fmtHMS(leastSecs) : null,
                accentColor: leastColor,
                icon: Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: spacing),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.avgPerDay,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _fmtHMS(avgSecs),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subValue;
  final Color? accentColor;
  final IconData icon;

  const _DetailStatCard({
    required this.title,
    required this.value,
    this.subValue,
    this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (accentColor != null)
                Container(
                  width: 3,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subValue != null)
                      Text(
                        subValue!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                           color: Theme.of(context).colorScheme.onSurfaceVariant,
                           fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? theme.colorScheme.onPrimary : null,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary,
      shape: StadiumBorder(side: BorderSide(color: theme.dividerColor)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _PieChartWithTooltip extends StatefulWidget {
  final int totalSeconds;
  final List<_Slice> slices;
  final _SliceTooltip? tooltip;
  final void Function(_SliceTooltip)? onSliceTap;
  final VoidCallback onDismiss;

  const _PieChartWithTooltip({
    required this.totalSeconds,
    required this.slices,
    required this.tooltip,
    required this.onSliceTap,
    required this.onDismiss,
  });

  @override
  State<_PieChartWithTooltip> createState() => _PieChartWithTooltipState();
}

class _PieChartWithTooltipState extends State<_PieChartWithTooltip> {
  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: Stack(
        alignment: Alignment.center,
        children: [
          
SizedBox(
  width: double.infinity,
  height: 300,
  child: LayoutBuilder(
    builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      // Use more realistic max dimensions or better, handle it dynamically.
      // For now, let's just make the boundary checks more robust.
      const tooltipW = 160.0;
      const tooltipH = 80.0;

      final safeLocal = widget.tooltip?.local ?? Offset.zero;
      double left = safeLocal.dx - tooltipW / 2;
      double top  = safeLocal.dy - tooltipH - 12;

      // Ensure it's within the LayoutBuilder constraints with some padding
      if (left < 12) left = 12;
      if (left + tooltipW > w - 12) left = w - tooltipW - 12;

      if (top < 12 && widget.tooltip != null) {
        // If it flies off top, show below the point
        top = safeLocal.dy + 12;
      }
      if (top + tooltipH > h - 12) {
        // If it flies off bottom, push it up
        top = h - tooltipH - 12;
      }

      return Stack(
        alignment: Alignment.center,
        children: [
          
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: widget.slices.isEmpty
    ? [
          PieChartSectionData(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((0.6 * 255).round()),
          value: 1,
          radius: 90,
          showTitle: false,
        ),
      ]
    : [
        for (final s in widget.slices)
          () {
            final percent = widget.totalSeconds == 0
                ? 0
                : s.seconds / widget.totalSeconds;
            final showTitle = percent >= 0.03;
            final label = showTitle
                ? _pieSectionTitle(s.name, s.seconds, context)
                : '';
            return PieChartSectionData(
              color: s.color,
              value: s.seconds.toDouble(),
              radius: 90,
              showTitle: showTitle,
              title: label,
              titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
              titlePositionPercentageOffset: 0.65,
            );
          }(),
      ],
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final touched = response?.touchedSection;
                  if (touched == null) return;
                  final index = touched.touchedSectionIndex;
                  if (index < 0 || index >= widget.slices.length) return;

                  final s = widget.slices[index];
                  final local = event.localPosition;

                  widget.onSliceTap?.call(
                    _SliceTooltip(local: local, id: s.id, name: s.name, seconds: s.seconds),
                  );
                },
              ),
            ),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          ),

        
        if (widget.totalSeconds == 0 || widget.slices.isEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Text(
                  AppLocalizations.of(context)!.noData,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
          
          if (widget.totalSeconds > 0 && widget.slices.isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.total,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmtHMS(widget.totalSeconds),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ],
            ),

          
          if (widget.tooltip != null)
            Positioned.fill(
              child: GestureDetector(
                
                behavior: HitTestBehavior.opaque,
                onTap: widget.onDismiss,
                child: const SizedBox.expand(),
              ),
            ),

          
          if (widget.tooltip != null)
            Positioned(
              left: left,
              top: top,
              child: IntrinsicWidth(
                child: IntrinsicHeight(
                  child: _FadeInTooltipCard(data: widget.tooltip!),
                ),
              ),
            ),
        ],
      );
    },
  ),
),
        ],
      ),
    );
  }
}

class _FadeInTooltipCard extends StatefulWidget {
  final _SliceTooltip data;
  const _FadeInTooltipCard({required this.data});

  @override
  State<_FadeInTooltipCard> createState() => _FadeInTooltipCardState();
}

class _FadeInTooltipCardState extends State<_FadeInTooltipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.data.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _fmtHMS(widget.data.seconds),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SliceTooltip {
  final Offset local;
  final String id;
  final String name;
  final int seconds;
  _SliceTooltip({required this.local, required this.id,  required this.name, required this.seconds});
}

class _Bucket {
  final DateTime date; 
  final Map<String, int> secondsByCourse;
  final bool isMonth;
  _Bucket({
    required this.date,
    required this.secondsByCourse,
    this.isMonth = false,
  });

  int get totalSeconds =>
      secondsByCourse.values.fold<int>(0, (a, b) => a + (b < 0 ? 0 : b));
}

class _BucketTooltip {
  final Offset anchor; 
  final String title;
  final List<_TooltipItem> items;
  _BucketTooltip({required this.anchor, required this.title, required this.items});
}

class _TooltipItem {
  final Color color;
  final String label;
  final String valueHms;
  _TooltipItem({required this.color, required this.label, required this.valueHms});
}

class _Slice {
  final String id;
  final String name;
  final Color color;
  final int seconds;
  const _Slice({
    required this.id,
    required this.name,
    required this.color,
    required this.seconds,
  });
}

class _PiePayload {
  final List<_Slice> slices;
  final int totalSeconds;
  const _PiePayload({required this.slices, required this.totalSeconds});
}

class _BucketsPayload {
  final List<_Bucket> buckets;
  final int totalSeconds;
  const _BucketsPayload({required this.buckets, required this.totalSeconds});
  const _BucketsPayload.empty()
      : buckets = const [],
        totalSeconds = 0;
}




enum _Range { week, month, year }
enum _TimeUnit { seconds, minutes, hours }

class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset anchor;
  final double screenPadding;

  _TooltipLayoutDelegate({required this.anchor, this.screenPadding = 8.0});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    
    return BoxConstraints(
      minWidth: 0,
      maxWidth: constraints.maxWidth,
      minHeight: 0,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    
    

    
    // Center horizontally on anchor
    double left = anchor.dx - (childSize.width / 2);

    // Ensure it doesn't go off the left/right edges
    if (left < screenPadding) left = screenPadding;
    if (left + childSize.width > size.width - screenPadding) {
      left = size.width - childSize.width - screenPadding;
    }

    // Position vertically
    double top;
    if (anchor.dy < size.height / 2) {
      // Show below
      top = anchor.dy + 12;
    } else {
      // Show above
      top = anchor.dy - childSize.height - 12;
    }

    // Ensure it doesn't go off the top/bottom edges
    if (top < screenPadding) top = screenPadding;
    if (top + childSize.height > size.height - screenPadding) {
      top = size.height - childSize.height - screenPadding;
    }

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) {
    return anchor != oldDelegate.anchor;
  }
}

_TimeUnit _pickUnit(int totalSeconds) {
  if (totalSeconds < 60) return _TimeUnit.seconds;
  if (totalSeconds < 3600) return _TimeUnit.minutes;
  return _TimeUnit.hours;
}

double _scaleForUnit(_TimeUnit u) {
  switch (u) {
    case _TimeUnit.seconds: return 1;
    case _TimeUnit.minutes: return 60;
    case _TimeUnit.hours:   return 3600;
  }
}

String _unitLabel(_TimeUnit u, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  switch (u) {
    case _TimeUnit.seconds: return l10n.seconds_plural;
    case _TimeUnit.minutes: return l10n.minutes_plural;
    case _TimeUnit.hours:   return l10n.hours_plural;
  }
}

String _fmtAxisTick(double v, _TimeUnit u) {
  
  String numStr;
  if (v == 0 || v.abs() >= 10) {
    numStr = v.toStringAsFixed(0);
  } else if ((v * 10).round() % 10 == 0) {
    numStr = v.toStringAsFixed(0);
  } else if ((v * 2).round() % 2 == 0) {
    numStr = v.toStringAsFixed(1);
  } else {
    numStr = v.toStringAsFixed(2);
  }
  return numStr;
}

double _niceInterval(double maxY) {
  if (maxY <= 1) return 0.2;
  if (maxY <= 2) return 0.5;
  if (maxY <= 5) return 1.0;
  if (maxY <= 10) return 2.0;
  if (maxY <= 20) return 5.0;
  if (maxY <= 50) return 10.0;
  return 20.0;
}

String _fmtHMS(int s) {
  final h = (s ~/ 3600).toString().padLeft(2, '0');
  final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sec = (s % 60).toString().padLeft(2, '0');
  return '$h:$m:$sec';
}


String _shortTimeLabel(int seconds, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  if (seconds >= 3600) return '${(seconds / 3600).round()}${l10n.hUnit}';
  if (seconds >= 60)   return '${(seconds / 60).round()}${l10n.mUnit}';
  return '$seconds${l10n.sUnit}';
}

String _pieSectionTitle(String name, int seconds, BuildContext context) {
  final timeLabel = _shortTimeLabel(seconds, context);
  final trimmed = name.trim();
  if (trimmed.isEmpty) return timeLabel;

  const maxLine = 12;
  if (trimmed.length <= maxLine) return '$trimmed\n$timeLabel';

  final split = _bestSplitIndex(trimmed);
  String line1;
  String line2;
  if (split > 0 && split < trimmed.length - 1) {
    line1 = trimmed.substring(0, split).trimRight();
    line2 = trimmed.substring(split).trimLeft();
  } else {
    final mid = trimmed.length ~/ 2;
    line1 = trimmed.substring(0, mid).trimRight();
    line2 = trimmed.substring(mid).trimLeft();
  }

  if (line2.isEmpty) return '$line1\n$timeLabel';
  return '$line1\n$line2\n$timeLabel';
}

int _bestSplitIndex(String value) {
  final mid = value.length ~/ 2;
  final left = value.lastIndexOf(' ', mid);
  final right = value.indexOf(' ', mid + 1);
  if (left == -1 && right == -1) return mid;
  if (left == -1) return right;
  if (right == -1) return left;
  return (mid - left) <= (right - mid) ? left : right;
}

String _fmtTotalVerbose(int s, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final parts = <String>[];
  if (h > 0) parts.add('$h ${h == 1 ? l10n.hour : l10n.hours_plural}');
  if (m > 0) parts.add('$m ${m == 1 ? l10n.minute : l10n.minutes_plural}');
  if (sec > 0 || parts.isEmpty) parts.add('$sec ${sec == 1 ? l10n.second : l10n.seconds_plural}');
  return '${parts.join(" ")} ${l10n.total.toLowerCase()}';
}

String _fmtDateShort(DateTime d, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final mo = [l10n.jan, l10n.feb, l10n.mar, l10n.apr, l10n.may, l10n.jun,
              l10n.jul, l10n.aug, l10n.sep, l10n.oct, l10n.nov, l10n.dec];
  final i = (d.month - 1);
  final safe = i < 0 ? 0 : (i > 11 ? 11 : i);
  return '${mo[safe]} ${d.day}';
}

String _fmtDateLong(DateTime d, BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final mo = [l10n.jan, l10n.feb, l10n.mar, l10n.apr, l10n.may, l10n.jun,
              l10n.jul, l10n.aug, l10n.sep, l10n.oct, l10n.nov, l10n.dec];
  final i = (d.month - 1);
  final safe = i < 0 ? 0 : (i > 11 ? 11 : i);
  return '${mo[safe]} ${d.day}, ${d.year}';
}

String _monthName(BuildContext context, int m) {
  final l10n = AppLocalizations.of(context)!;
  switch (m) {
    case 1: return l10n.january;
    case 2: return l10n.february;
    case 3: return l10n.march;
    case 4: return l10n.april;
    case 5: return l10n.may;
    case 6: return l10n.june;
    case 7: return l10n.july;
    case 8: return l10n.august;
    case 9: return l10n.september;
    case 10: return l10n.october;
    case 11: return l10n.november;
    case 12: return l10n.december;
    default: return '';
  }
}

String _prevLabel(BuildContext context, _Range r) {
  final l10n = AppLocalizations.of(context)!;
  switch (r) {
    case _Range.week:  return l10n.previousWeek;
    case _Range.month: return l10n.previousMonth;
    case _Range.year:  return l10n.previousYear;
  }
}

String _nextLabel(BuildContext context, _Range r) {
  final l10n = AppLocalizations.of(context)!;
  switch (r) {
    case _Range.week:  return l10n.nextWeek;
    case _Range.month: return l10n.nextMonth;
    case _Range.year:  return l10n.nextYear;
  }
}
