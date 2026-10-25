import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:numer_app/features/habits/models/habit.dart';
import 'package:numer_app/features/auth/data/auth_service.dart';
import 'package:numer_app/features/habits/data/habit_service.dart';
import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/features/habits/widgets/habit_day_sheet.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_app/app/app_state.dart';

class HabitsCalendarScreen extends StatefulWidget {
  const HabitsCalendarScreen({super.key});

  @override
  State<HabitsCalendarScreen> createState() => _HabitsCalendarScreenState();
}

class _HabitsCalendarScreenState extends State<HabitsCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();

  // Local cache for progress: monthKey -> { dateKey -> { habitId -> value } }
  final Map<String, Map<String, Map<String, double>>> _progressCache = {};

  // Current view's progress (populated from cache)
  Map<String, Map<String, double>> _progressByDate = {};

  List<Habit> _allHabits = [];
  bool _isLoading = true;
  bool _isLoadingMonth = false; // For individual month loading indicator
  StreamSubscription<List<Habit>>? _habitsSub;
  String? _userId;

  // Calendar navigation boundaries
  static final DateTime _minMonth = DateTime(2025, 1);
  DateTime get _maxMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1);
  }

  late PageController _pageController;
  int _totalMonths = 0;

  int _getIndexFromMonth(DateTime month) {
    return (month.year - _minMonth.year) * 12 + (month.month - _minMonth.month);
  }

  DateTime _getMonthFromIndex(int index) {
    return DateTime(_minMonth.year, _minMonth.month + index);
  }

  String _monthKey(DateTime month) => "${month.year}-${month.month}";

  @override
  void initState() {
    super.initState();
    _totalMonths = _getIndexFromMonth(_maxMonth) + 1;
    _pageController = PageController(
      initialPage: _getIndexFromMonth(_focusedMonth),
    );
    _subscribeToHabits();
  }

  /// Subscribe to habits stream ONCE. This is the only Firebase listener.
  void _subscribeToHabits() {
    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _allHabits = [];
      });
      return;
    }

    _userId = uid;
    final habitService = context.read<HabitService>();

    setState(() => _isLoading = true);

    _habitsSub = habitService
        .habitsStream(uid)
        .listen(
          (habits) {
            if (!mounted) return;
            setState(() {
              _allHabits = habits;
              _isLoading = false;
            });
            // Load progress for current month after habits are loaded
            _loadMonthProgress(_focusedMonth);
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
        );
  }

  /// Load progress for a specific month. Uses LOCAL CACHE first, falls back to Firebase.
  Future<void> _loadMonthProgress(DateTime month) async {
    final monthKey = _monthKey(month);

    // Check in-memory cache first - if we have it, use it immediately
    if (_progressCache.containsKey(monthKey)) {
      if (!mounted) return;
      setState(() {
        _progressByDate = _progressCache[monthKey]!;
        _isLoadingMonth = false;
      });
      return;
    }

    // Not in in-memory cache - try local Hive storage first
    if (_userId == null || _allHabits.isEmpty) {
      setState(() => _isLoadingMonth = false);
      return;
    }

    setState(() => _isLoadingMonth = true);

    final start = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final end = nextMonth.subtract(const Duration(days: 1));

    final Map<String, Map<String, double>> newProgress = {};

    try {
      // Load from local Hive cache ONLY (no Firebase reads)
      final historyByHabit = Storage.getAllHabitHistoryForDateRange(start, end);

      for (final entry in historyByHabit.entries) {
        final habitId = entry.key;
        for (final historyEntry in entry.value) {
          if (historyEntry.deleted) continue;
          newProgress.putIfAbsent(historyEntry.dateKey, () => {})[habitId] =
              historyEntry.value ?? 1.0;
        }
      }

      // Store in in-memory cache
      _progressCache[monthKey] = newProgress;

      // Update UI if this is still the focused month
      if (mounted && _monthKey(_focusedMonth) == monthKey) {
        setState(() {
          _progressByDate = newProgress;
          _isLoadingMonth = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMonth = false);
      }
    }
  }

  /// Called when user swipes to a new month
  void _onMonthChanged(int index) {
    final newMonth = _getMonthFromIndex(index);
    setState(() {
      _focusedMonth = newMonth;
    });
    _loadMonthProgress(newMonth);
  }

  void _prevMonth() {
    if (_pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _habitsSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextMonth() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showDaySheet(DateTime date) {
    if (_isLoading) return;

    final dateKey = _dateKey(date);
    final progressMap = _progressByDate[dateKey] ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Sheet handles decoration
      builder: (context) => HabitDaySheet(
        date: date,
        allHabits: _allHabits,
        progressMap: progressMap,
        userId: context.read<AuthController>().currentUser?.uid ?? '',
        isReadOnly: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        systemOverlayStyle: theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          l10n.habitsCalendarTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(Icons.today_rounded, color: theme.colorScheme.primary),
              onPressed: () {
                final today = DateTime.now();
                final targetPage = _getIndexFromMonth(today);
                if (_pageController.hasClients) {
                  _pageController.animateToPage(
                    targetPage,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onMonthChanged,
              itemCount: _totalMonths,
              itemBuilder: (context, index) {
                final month = _getMonthFromIndex(index);
                final monthKey = _monthKey(month);
                final isFocused =
                    month.year == _focusedMonth.year &&
                    month.month == _focusedMonth.month;
                final hasCachedData = _progressCache.containsKey(monthKey);

                // Show loading only if focused AND loading AND no cache
                if (isFocused &&
                    (_isLoading || _isLoadingMonth) &&
                    !hasCachedData) {
                  return Column(
                    children: [
                      _buildWeekdayHeader(theme, context),
                      const SizedBox(height: 12),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ],
                  );
                }

                // Use cached data for this month if available
                final progressData = _progressCache[monthKey] ?? {};
                return _buildCalendarGrid(context, month, progressData);
              },
            ),
          ),

          // Month navigation at bottom
          Container(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: 32,
              top: 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: _focusedMonth.isAfter(_minMonth)
                      ? _prevMonth
                      : null,
                  theme: theme,
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(
                      l10n.localeName,
                    ).format(_focusedMonth).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                _buildNavButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: _focusedMonth.isBefore(_maxMonth)
                      ? _nextMonth
                      : null,
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required ThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: onPressed == null
            ? theme.colorScheme.outline.withValues(alpha: 0.5)
            : theme.colorScheme.primary,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    DateTime month,
    Map<String, Map<String, double>> progressData,
  ) {
    final theme = Theme.of(context);
    final weekStart = context.read<AppState>().weekStart;
    final firstDay = DateTime(month.year, month.month, 1);
    final firstWeekdayOffset = weekStart == WeekStart.monday
        ? (firstDay.weekday - 1)
        : (firstDay.weekday % 7);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        _buildWeekdayHeader(theme, context),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.58, // Taller for hybrid indicators
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final int dayOffset = index - firstWeekdayOffset;
              final date = firstDay.add(Duration(days: dayOffset));

              final isCurrentMonth = date.month == month.month;
              if (!isCurrentMonth) return const SizedBox.shrink();

              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isFuture = date.isAfter(today);

              final dateKey = _dateKey(date);
              final progressMap = progressData[dateKey] ?? {};

              // Determine which habits completed
              final completedHabits = _allHabits
                  .where(
                    (h) =>
                        progressMap.containsKey(h.id) &&
                        progressMap[h.id]! >= h.targetValue,
                  )
                  .toList();

              return GestureDetector(
                onTap: isFuture ? null : () => _showDaySheet(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isToday
                        ? theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          )
                        : isFuture
                        ? theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.1,
                          )
                        : theme.colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                    borderRadius: BorderRadius.circular(14),
                    border: isToday
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.2,
                            ),
                            width: 1,
                          ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "${date.day}",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isFuture
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.3,
                                )
                              : (isToday
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Dots-only indicators
                      if (completedHabits.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 3,
                            runSpacing: 3,
                            children: completedHabits
                                .map(
                                  (h) => Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: isFuture
                                          ? h.color.withValues(alpha: 0.3)
                                          : h.color,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: h.color.withValues(alpha: 0.3),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const Spacer(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(ThemeData theme, BuildContext context) {
    final weekStart = context.read<AppState>().weekStart;
    final narrowWeekdays = MaterialLocalizations.of(context).narrowWeekdays;
    final weekdayLabels = weekStart == WeekStart.monday
        ? [...narrowWeekdays.skip(1), narrowWeekdays.first]
        : narrowWeekdays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: weekdayLabels
            .map(
              (d) => Expanded(
                child: Center(
                  child: Text(
                    d.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.outline,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}
