import 'package:numer_app/features/habits/data/habit_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:numer_app/features/courses/course.dart';
import 'package:numer_app/features/habits/models/habit.dart';
import 'package:numer_app/core/data/storage.dart';

import 'package:numer_app/features/stats/widgets/heatmap_calendar.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/history/screens/history.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import '../models/stats_models.dart';
import '../stats_format.dart';
import '../widgets/chart_tooltip.dart';
import '../data/habit_stats_loader.dart';
import '../widgets/habit_statistics.dart';
import '../widgets/pie_chart_with_tooltip.dart';
import '../widgets/stats_block.dart';
import '../widgets/stats_section_container.dart';
import 'package:numer_app/shared/widgets/tip_icon.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _day = _strip(DateTime.now());
  static DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);
  bool get _isToday => _strip(DateTime.now()) == _day;
  SliceTooltip? _sliceTooltip;

  void _prevDay() {
    final minDate = DateTime(2025, 1, 1);
    final prevDay = _day.subtract(const Duration(days: 1));
    if (prevDay.isBefore(minDate)) return;

    setState(() {
      _day = prevDay;
      _sliceTooltip = null;
    });
  }

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
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HeatmapCalendar(
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Range _range = Range.week;
  int _shift = 0;

  void _prevRange() {
    final minDate = DateTime(2025, 1, 1);
    final weekStart = context.read<AppState>().weekStart;
    final (prevStart, _) = _rangeBounds(
      DateTime.now(),
      _range,
      _shift - 1,
      weekStart,
    );

    if (prevStart.isBefore(minDate)) return;

    setState(() {
      _shift -= 1;
      _tooltip = null;
    });
  }

  void _nextRange() {
    if (_shift >= 0) return;
    setState(() {
      _shift += 1;
      _tooltip = null;
    });
  }

  void _setRange(Range r) => setState(() {
    _range = r;
    _shift = 0;
    _tooltip = null;
  });

  BucketTooltip? _tooltip;

  // -- Habit Stats State --
  String? _selectedHabitId;

  Map<String, HabitStatsResult>? _allHabitsStatsCache;
  bool _loadingHabitsStats = false;
  StreamSubscription<void>? _historyUpdatesSub;

  // Cache key to detect if we need to reload
  // For now, load once or on demand.

  final DateTime _habitStatsMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  late PageController _habitPageCtrl;

  @override
  void initState() {
    super.initState();
    _habitPageCtrl = PageController(viewportFraction: 0.85);

    // Listen for history updates to invalidate cache
    final habitService = context.read<HabitService>();
    _historyUpdatesSub = habitService.historyUpdates.listen((_) {
      // Invalidate cache and trigger reload
      if (mounted) {
        setState(() {
          _allHabitsStatsCache = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _habitPageCtrl.dispose();
    _historyUpdatesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAllHabitsStats(List<Habit> habits) async {
    if (_loadingHabitsStats) return;
    setState(() => _loadingHabitsStats = true);

    final results = <String, HabitStatsResult>{};

    for (final habit in habits) {
      if (habit.archived) continue;
      final stats = await computeHabitStats(habit);
      results[habit.id] = stats;
    }

    if (mounted) {
      setState(() {
        _allHabitsStatsCache = results;
        _loadingHabitsStats = false;
      });
    }
  }

  void _selectInitialHabit(List<Habit> habits) {
    if (_selectedHabitId == null && habits.isNotEmpty) {
      _selectedHabitId = habits.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final courses = state.courses;
    final weekStart = state.weekStart;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final mediaQuery = MediaQuery.of(context);
    final navBottomOffset = mediaQuery.padding.bottom > 0
        ? (mediaQuery.padding.bottom * 0.38)
        : 4.0;
    const navHeight = 66.0;
    const extra = 12.0;
    final bottomScrollClearance = isIOS
        ? navHeight + navBottomOffset + extra
        : 24.0;

    final pieFuture = _loadPieForDay(_day, courses);

    final (start, end) = _rangeBounds(
      DateTime.now(),
      _range,
      _shift,
      weekStart,
    );
    final bucketsFuture = _loadBucketsForRange(start, end, _range, courses);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              AppLocalizations.of(context)!.statistics,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StatsSectionContainer(
              title: AppLocalizations.of(context)!.dayStatistics,
              trailingHeader: TipIcon(
                title: AppLocalizations.of(context)!.tip,
                message:
                    '${AppLocalizations.of(context)!.dayStatsTipLine1}\n${AppLocalizations.of(context)!.dayStatsTipLine2}\n${AppLocalizations.of(context)!.dayStatsTipLine3}',
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      fmtDateLong(_day, context),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Theme.of(context).dividerColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: OutlinedButton(
                                  onPressed: _isToday ? null : _goToday,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppLocalizations.of(context)!.today,
                                    ),
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
                  FutureBuilder<PiePayload>(
                    future: pieFuture,
                    builder: (context, snap) {
                      final total = snap.data?.totalSeconds ?? 0;
                      final slices = snap.data?.slices ?? const <Slice>[];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: PieChartWithTooltip(
                          totalSeconds: total,
                          slices: slices,
                          tooltip: _sliceTooltip,
                          onSliceTap: (tap) =>
                              setState(() => _sliceTooltip = tap),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () async {
                          final dayStart = _strip(_day);
                          final dayEnd = _isToday
                              ? DateTime.now()
                              : dayStart.add(const Duration(days: 1));
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
            child: StatsSectionContainer(
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
                        SegChip(
                          label: AppLocalizations.of(context)!.week,
                          selected: _range == Range.week,
                          onTap: () => _setRange(Range.week),
                        ),
                        SegChip(
                          label: AppLocalizations.of(context)!.month,
                          selected: _range == Range.month,
                          onTap: () => _setRange(Range.month),
                        ),
                        SegChip(
                          label: AppLocalizations.of(context)!.year,
                          selected: _range == Range.year,
                          onTap: () => _setRange(Range.year),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: prevLabel(context, _range),
                          onPressed: _prevRange,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: null,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _periodLabel(start, end, _range),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: nextLabel(context, _range),
                          onPressed: _shift >= 0 ? null : _nextRange,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<BucketsPayload>(
                    future: bucketsFuture,
                    builder: (context, snap) {
                      final payload = snap.data ?? const BucketsPayload.empty();
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
                          tooltip: _tooltip,
                          onDismiss: () => setState(() => _tooltip = null),
                          child: AspectRatio(
                            aspectRatio: 1.35,
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(
                                'bars-$_range-$_shift-${unit.name}-$totalSecs',
                              ),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, _) {
                                final effectiveT = Curves.easeOutCubic
                                    .transform(t);
                                return LayoutBuilder(
                                  builder: (context, c) {
                                    final n = buckets.isEmpty
                                        ? 1
                                        : buckets.length;
                                    final chartW = c.maxWidth;

                                    final slot = chartW / n;
                                    final proposed = slot * 0.85;
                                    final bw = proposed
                                        .clamp(4.0, 34.0)
                                        .toDouble();

                                    final (
                                      animatedGroups,
                                      _,
                                    ) = _buildAnimatedGroups(
                                      buckets,
                                      courses,
                                      unitScale,
                                      effectiveT,
                                      bw,
                                    );

                                    return Stack(
                                      children: [
                                        BarChart(
                                          BarChartData(
                                            alignment:
                                                BarChartAlignment.spaceBetween,
                                            minY: 0,
                                            maxY: maxYAdjusted,
                                            barGroups: animatedGroups,
                                            gridData: FlGridData(
                                              show: true,
                                              drawVerticalLine: false,
                                              horizontalInterval: interval,
                                              getDrawingHorizontalLine: (v) =>
                                                  FlLine(
                                                    color: Theme.of(
                                                      context,
                                                    ).dividerColor,
                                                    strokeWidth: 1,
                                                  ),
                                            ),
                                            titlesData: FlTitlesData(
                                              leftTitles: AxisTitles(
                                                axisNameWidget: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 6,
                                                      ),
                                                  child: Text(
                                                    unitLabel(unit, context),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                                axisNameSize: 22,
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 44,
                                                  interval: interval,
                                                  getTitlesWidget: (v, meta) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 8,
                                                        ),
                                                    child: Text(
                                                      fmtAxisTick(v, unit),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
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
                                                    if (idx < 0 ||
                                                        idx >= buckets.length) {
                                                      return const SizedBox.shrink();
                                                    }
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 6,
                                                          ),
                                                      child: Text(
                                                        _xLabel(
                                                          buckets[idx],
                                                          _range,
                                                          weekStart,
                                                        ),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .onSurface,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              rightTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                              topTitles: const AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: false,
                                                ),
                                              ),
                                            ),
                                            borderData: FlBorderData(
                                              show: false,
                                            ),
                                            barTouchData: BarTouchData(
                                              enabled: totalSecs > 0,
                                              handleBuiltInTouches: false,
                                              touchTooltipData:
                                                  BarTouchTooltipData(
                                                    getTooltipItem:
                                                        (
                                                          group,
                                                          groupIndex,
                                                          rod,
                                                          rodIndex,
                                                        ) => null,
                                                  ),
                                              touchCallback: (event, response) {
                                                if (!mounted) return;

                                                // If the user lifts their finger or moves away from bars,
                                                // we don't clear the tooltip immediately.
                                                // This allows the pop-up to stay visible on the last selected point.
                                                if (response == null ||
                                                    response.spot == null) {
                                                  return;
                                                }

                                                final anchor = extractLocal(
                                                  event,
                                                );
                                                if (anchor == null) return;

                                                final idx = response
                                                    .spot!
                                                    .touchedBarGroupIndex;
                                                if (idx < 0 ||
                                                    idx >= buckets.length) {
                                                  return;
                                                }

                                                final bucket = buckets[idx];
                                                final items =
                                                    _buildTooltipDetails(
                                                      bucket,
                                                      courses,
                                                    );
                                                setState(() {
                                                  _tooltip = BucketTooltip(
                                                    anchor: anchor,
                                                    title: _tooltipTitle(
                                                      bucket,
                                                      _range,
                                                    ),
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
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.noData,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withAlpha(
                                                              (0.55 * 255)
                                                                  .round(),
                                                            ),
                                                        fontWeight:
                                                            FontWeight.w700,
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
            child: StatsSectionContainer(
              title: (_range == Range.week)
                  ? '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisWeek}'
                  : (_range == Range.month)
                  ? '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisMonth}'
                  : '${AppLocalizations.of(context)!.courseStatistics} ${AppLocalizations.of(context)!.overThisYear}',
              useCard: false,
              child: FutureBuilder<BucketsPayload>(
                future: bucketsFuture,
                builder: (context, snap) {
                  final payload = snap.data ?? const BucketsPayload.empty();
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
                  final positive =
                      perCourse.entries
                          .where(
                            (e) => courseById.containsKey(e.key) && e.value > 0,
                          )
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
                  if (_range == Range.year) {
                    final (start, end) = _rangeBounds(
                      DateTime.now(),
                      _range,
                      _shift,
                      weekStart,
                    );
                    final days = end.difference(start).inDays;
                    content = FutureBuilder<List<Map<String, int>>>(
                      future: Storage.dailySeries(start, days),
                      builder: (context, daySnap) {
                        final list = daySnap.data ?? const <Map<String, int>>[];
                        final activeDays = list
                            .where((m) => m.values.any((s) => s > 0))
                            .length;
                        final avgSecs = activeDays > 0
                            ? (totalSecs ~/ activeDays)
                            : 0;
                        return StatsBlock(
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
                    final activeDays = buckets
                        .where((b) => b.totalSeconds > 0)
                        .length;
                    final avgSecs = activeDays > 0
                        ? (totalSecs ~/ activeDays)
                        : 0;
                    content = StatsBlock(
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
          SliverToBoxAdapter(
            child: StatsSectionContainer(
              title: AppLocalizations.of(context)!.habitStatistics,
              child: HabitStatistics(
                statsByHabit: _allHabitsStatsCache,
                loading: _loadingHabitsStats,
                pageController: _habitPageCtrl,
                reportMonth: _habitStatsMonth,
                onLoadStats: _loadAllHabitsStats,
                onHabitsShown: _selectInitialHabit,
                onHabitSelected: (id) => setState(() => _selectedHabitId = id),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottomScrollClearance),
          ),
        ],
      ),
    );
  }

  Future<PiePayload> _loadPieForDay(DateTime day, List<Course> courses) async {
    final valid = courses.map((c) => c.id).toSet();
    final start = _strip(day);
    final isToday = _strip(day) == _strip(DateTime.now());
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

  Future<BucketsPayload> _loadBucketsForRange(
    DateTime start,
    DateTime end,
    Range r,
    List<Course> courses,
  ) async {
    final valid = courses.map((c) => c.id).toSet();
    final buckets = <Bucket>[];
    int totalSecs = 0;

    if (r == Range.week || r == Range.month) {
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

        buckets.add(Bucket(date: dayStart, secondsByCourse: cleaned));
      }
    } else {
      for (var month = 1; month <= 12; month++) {
        final monthStart = DateTime(start.year, month, 1);
        final monthEnd = DateTime(start.year, month + 1, 1);
        final now = DateTime.now();
        final effectiveEnd = (monthEnd.isAfter(now) && now.isAfter(monthStart))
            ? now
            : monthEnd;

        final map = await Storage.secondsByCourseBetween(
          monthStart,
          effectiveEnd,
        );
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
        buckets.add(
          Bucket(date: monthStart, secondsByCourse: cleaned, isMonth: true),
        );
      }
    }

    return BucketsPayload(buckets: buckets, totalSeconds: totalSecs);
  }

  (List<BarChartGroupData>, double) _buildAnimatedGroups(
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
              borderRadius: hasData
                  ? BorderRadius.circular(6)
                  : BorderRadius.zero,
              rodStackItems: hasData ? items : const [],
            ),
          ],
        ),
      );
    }

    return (groups, fullMaxY);
  }

  (DateTime, DateTime) _rangeBounds(
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
        final anchor = _strip(base.subtract(Duration(days: delta)));
        final start = anchor.add(Duration(days: 7 * shift));
        final end = start.add(const Duration(days: 7));
        return (start, end);

      case Range.month:
        final start0 = DateTime(base.year, base.month, 1);
        final start = DateTime(start0.year, start0.month + shift, 1);
        final end = DateTime(start.year, start.month + 1, 1);
        return (_strip(start), _strip(end));

      case Range.year:
        final start0 = DateTime(base.year, 1, 1);
        final start = DateTime(start0.year + shift, 1, 1);
        final end = DateTime(start.year + 1, 1, 1);
        return (_strip(start), _strip(end));
    }
  }

  String _xLabel(Bucket b, Range r, WeekStart weekStart) {
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

  String _periodLabel(DateTime start, DateTime end, Range r) {
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

  String _tooltipTitle(Bucket b, Range r) {
    switch (r) {
      case Range.week:
      case Range.month:
        return fmtDateLong(b.date, context);
      case Range.year:
        return '${monthName(context, b.date.month)} ${b.date.year}';
    }
  }

  List<TooltipItem> _buildTooltipDetails(Bucket b, List<Course> courses) {
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
}
