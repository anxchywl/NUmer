import 'dart:async';

import 'package:flutter/material.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/courses/courses.dart';
import 'package:numer_app/features/habits/habits.dart';
import 'package:numer_app/features/history/history.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../data/habit_stats_loader.dart';
import '../data/stats_loader.dart';
import '../models/stats_models.dart';
import '../widgets/day_stats_section.dart';
import '../widgets/habit_statistics.dart';
import '../widgets/heatmap_calendar.dart';
import '../widgets/heatmap_section.dart';
import '../widgets/period_stats_section.dart';
import '../widgets/stats_section_container.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  DateTime _day = strip(DateTime.now());
  bool get _isToday => strip(DateTime.now()) == _day;
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
      _day = strip(DateTime.now());
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
                      _day = strip(selected);
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
    final (prevStart, _) = rangeBounds(
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

  Future<void> _openHistory() async {
    final dayStart = strip(_day);
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
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final courses = state.courses;
    final weekStart = state.weekStart;
    final bottomScrollClearance = _bottomScrollClearance(context);

    final pieFuture = loadPieForDay(_day, courses);

    final (start, end) = rangeBounds(DateTime.now(), _range, _shift, weekStart);
    final bucketsFuture = loadBucketsForRange(start, end, _range, courses);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _appBar(context),
          SliverToBoxAdapter(child: _daySection(pieFuture)),
          SliverToBoxAdapter(
            child: _periodSection(
              start,
              end,
              bucketsFuture,
              courses,
              weekStart,
            ),
          ),
          SliverToBoxAdapter(
            child: HeatmapSection(
              range: _range,
              shift: _shift,
              weekStart: weekStart,
              bucketsFuture: bucketsFuture,
              courses: courses,
            ),
          ),
          SliverToBoxAdapter(child: _habitSection(context)),
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottomScrollClearance),
          ),
        ],
      ),
    );
  }

  double _bottomScrollClearance(BuildContext context) {
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
    return bottomScrollClearance;
  }

  Widget _appBar(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      title: Text(
        AppLocalizations.of(context)!.statistics,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _daySection(Future<PiePayload> pieFuture) {
    return DayStatsSection(
      day: _day,
      isToday: _isToday,
      pieFuture: pieFuture,
      sliceTooltip: _sliceTooltip,
      onPrevDay: _prevDay,
      onNextDay: _nextDay,
      onGoToday: _goToday,
      onPickDay: () => _pickDay(context),
      onSliceTap: (tap) => setState(() => _sliceTooltip = tap),
      onDismissTooltip: () => setState(() => _sliceTooltip = null),
      onOpenHistory: _openHistory,
    );
  }

  Widget _periodSection(
    DateTime start,
    DateTime end,
    Future<BucketsPayload> bucketsFuture,
    List<Course> courses,
    WeekStart weekStart,
  ) {
    return PeriodStatsSection(
      range: _range,
      shift: _shift,
      start: start,
      end: end,
      bucketsFuture: bucketsFuture,
      courses: courses,
      weekStart: weekStart,
      tooltip: _tooltip,
      onSetRange: _setRange,
      onPrev: _prevRange,
      onNext: _nextRange,
      onShowTooltip: (tooltip) => setState(() => _tooltip = tooltip),
      onDismissTooltip: () => setState(() => _tooltip = null),
    );
  }

  Widget _habitSection(BuildContext context) {
    return StatsSectionContainer(
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
    );
  }
}
