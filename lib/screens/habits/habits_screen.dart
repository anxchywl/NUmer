import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:numer_app/models/habit.dart';
import 'package:numer_app/services/auth_service.dart';
import 'package:numer_app/services/habit_service.dart';
import 'package:numer_app/app_state.dart';
import 'package:numer_app/screens/habits/habits_calendar_screen.dart';
import 'package:numer_app/screens/habits/archived_habits_screen.dart';
import 'package:numer_app/screens/habits/widgets/habit_logging_sheet.dart';
import 'package:numer_app/screens/habits/widgets/eisenhower_matrix_widget.dart';
import 'package:numer_app/screens/habits/widgets/habit_sorter_card.dart';
import 'package:numer_app/screens/habits/widgets/habit_completion_indicator.dart';
import 'package:numer_app/screens/habits/habit_details_screen.dart';
import 'package:numer_app/screens/habits/add_habit_sheet.dart';

import 'package:numer_app/services/storage.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> with SingleTickerProviderStateMixin {
  static const String _createNewLabel = 'Create new';

  // We'll calculate the last 7 days (today + past 6 days) to show circles
  late List<DateTime> _weekDates;
  WeekStart? _lastWeekStart;
  
  int _selectedTabIndex = 0; // 0 for Today, 1 for Habits
  late DateTime _selectedDate;
  late ScrollController _dateScrollController;
  bool _hasScrolledToToday = false;
  final GlobalKey _calendarKey = GlobalKey();
  
  // Optimistic Reordering State
  List<String>? _optimisticHabitOrder;
  bool _fabVisible = true;

  @override
  void initState() {
    super.initState();
    _updateWeekDates(WeekStart.monday);
    _selectedDate = DateTime.now();
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _dateScrollController = ScrollController();
    
    // Scroll to today (middle of the list)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday(animate: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final weekStart = context.read<AppState>().weekStart;
    if (_lastWeekStart != weekStart) {
      setState(() => _updateWeekDates(weekStart));
    }
  }

  void _scrollToToday({bool animate = false}) {
    if (!mounted) return;
    if (_dateScrollController.hasClients) {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday(animate: animate));
        return;
      }
      final itemWidth = (screenWidth - 24) / 7;
      final offset = 12 + 30 * itemWidth + itemWidth / 2 - screenWidth / 2;
      if (animate) {
        _dateScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _dateScrollController.jumpTo(offset);
      }
    }
  }

  void _updateWeekDates(WeekStart weekStart) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _lastWeekStart = weekStart;
    final offset = _weekStartOffset(today, weekStart);
    final start = today.subtract(Duration(days: offset));
    _weekDates = List.generate(7, (i) => start.add(Duration(days: i)));
  }

  bool _isFutureDate(DateTime date) {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dateMidnight = DateTime(date.year, date.month, date.day);
    return dateMidnight.isAfter(todayMidnight);
  }

  int _weekStartOffset(DateTime date, WeekStart weekStart) {
    if (weekStart == WeekStart.monday) {
      return (date.weekday - DateTime.monday).clamp(0, 6);
    }
    return date.weekday % 7;
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  bool _isIos(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.iOS;

  double _iosBottomNavClearance(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBottomOffset = bottomInset > 0 ? (bottomInset * 0.38) : 4.0;
    const navHeight = 66.0;
    const extra = 8.0;
    return navHeight + navBottomOffset + extra;
  }

  double _iosFabBottomLift(BuildContext context) {
    // Keep pill close to nav while staying clear of overlap.
    final lift = _iosBottomNavClearance(context) - 36.0;
    return lift > 0 ? lift : 0;
  }

  double _iosTopContentClearance(BuildContext context) {
    if (!_isIos(context)) return 0;
    return 12;
  }

  double _progressBottomClearance(BuildContext context) {
    return _isIos(context)
        ? _iosBottomNavClearance(context)
        : MediaQuery.of(context).padding.bottom + 24;
  }

  void _showAddHabitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddHabitSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.currentUser?.uid;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (uid == null) {
      return Center(child: Text(l10n.habitsPleaseSignIn));
    }

    final habitService = context.watch<HabitService>();

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.reverse && _fabVisible) {
            setState(() => _fabVisible = false);
          } else if (notification.direction == ScrollDirection.forward &&
              !_fabVisible) {
            setState(() => _fabVisible = true);
          }
          return false;
        },
        child: CustomScrollView(slivers: [
            SliverAppBar(
              systemOverlayStyle: theme.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              floating: true,
              snap: true,
              pinned: false,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              title: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTabItem(0, l10n.habitsTabProgress),
                    _buildTabItem(1, l10n.habitsTabList),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ArchivedHabitsScreen(),
                      ),
                    );
                    if (mounted && _selectedDate.day == DateTime.now().day) {
                      _scrollToToday(animate: true);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HabitsCalendarScreen(),
                      ),
                    );
                    if (mounted && _selectedDate.day == DateTime.now().day) {
                      _scrollToToday(animate: true);
                    }
                  },
                ),
              ],
            ),
            
            if (_selectedTabIndex == 0) ...[
              if (_isIos(context))
                SliverToBoxAdapter(
                  child: SizedBox(height: _iosTopContentClearance(context)),
                ),
              // Today View: Check if Eisenhower Matrix is enabled
              StreamBuilder<List<Habit>>(
                stream: habitService.habitsStream(uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SliverToBoxAdapter(child: SizedBox());
                  final allHabits = snapshot.data!;
                  final appState = context.watch<AppState>();
                  
                  // If Eisenhower Matrix is enabled, show matrix UI
                  if (appState.eisenhowerMatrixEnabled) {
                    final placements = Storage.getHabitQuadrantPlacements();
                    
                    // Filter: Hide habits if period goal is met AND not done today
                    final filteredHabits = allHabits.where((h) {
                      if (!h.isScheduledFor(_selectedDate)) return false;
                      // Check completion status for the selected date
                      final dateKey = _dateKey(_selectedDate); 
                      final currentValue = h.last7[dateKey] ?? 0.0;
                      final isCompletedOnDate = currentValue >= h.targetValue;
                      
                      // Show if completed on this date OR period goal NOT met.
                      if (isCompletedOnDate) return true;
                      return !h.isGoalMetForPeriod(h.last7, _selectedDate, mondayFirst: appState.weekStart == WeekStart.monday);
                    }).toList();

                    final unsortedHabits = filteredHabits.where((h) => !placements.containsKey(h.id)).toList();
                    
                    // Full-screen matrix layout
                    final screenHeight = MediaQuery.of(context).size.height;
                    final topPadding = MediaQuery.of(context).padding.top;
                    final bottomPadding = MediaQuery.of(context).padding.bottom;
                    final availableHeight = screenHeight - topPadding - kToolbarHeight - bottomPadding - 20;
                    
                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height: availableHeight - _progressBottomClearance(context),
                        child: Column(
                          children: [
                            // Top Area: Sorter OR Calendar Strip
                            unsortedHabits.isNotEmpty
                                ? HabitSorterCard(
                                    key: ValueKey(unsortedHabits.first.id),
                                    habit: unsortedHabits.first,
                                    onPlaced: () {
                                      setState(() {});
                                      // After placing, check if all sorted - scroll to today
                                      if (unsortedHabits.length == 1) {
                                        Future.delayed(const Duration(milliseconds: 100), () => _scrollToToday(animate: true));
                                      }
                                    },
                                  )
                                : KeyedSubtree(
                                    key: _calendarKey,
                                    child: _buildHorizontalDatePicker(theme),
                                  ),
                            
                            // Matrix grid
                            Expanded(
                              child: EisenhowerMatrixWidget(
                                habits: filteredHabits.where((h) => placements.containsKey(h.id)).toList(),
                                selectedDate: _selectedDate,
                                onHabitTap: (habit) => _toggleHabit(habit, _selectedDate),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Regular view - render date picker first
                  return const SliverToBoxAdapter(child: SizedBox());
                },
              ),
              // Regular Today View components (only when matrix is disabled)
              Builder(
                builder: (context) {
                  final appState = context.watch<AppState>();
                  if (appState.eisenhowerMatrixEnabled) {
                    return const SliverToBoxAdapter(child: SizedBox());
                  }
                  return SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: _calendarKey,
                      child: _buildHorizontalDatePicker(theme),
                    ),
                  );
                },
              ),
              // Today View: Habit List (only when matrix is disabled)
              Builder(
                builder: (context) {
                  final appState = context.watch<AppState>();
                  if (appState.eisenhowerMatrixEnabled) {
                    return const SliverToBoxAdapter(child: SizedBox());
                  }
                  return StreamBuilder<List<Habit>>(
                stream: habitService.habitsStream(uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SliverToBoxAdapter(child: SizedBox());
                  final habits = snapshot.data!.where((h) {
                    if (!h.isScheduledFor(_selectedDate)) return false;
                    
                    // Check completion status for the selected date
                    final dateKey = _dateKey(_selectedDate); 
                    final currentValue = h.last7[dateKey] ?? 0.0;
                    final isCompletedOnDate = currentValue >= h.targetValue;
                    
                    // RULE: Show if completed on this date OR period goal NOT met.
                    // This allows users to see/edit their progress today even if the goal was just met,
                    // and ensures the habit reappears if progress drops below the threshold.
                    if (isCompletedOnDate) return true;
                    return !h.isGoalMetForPeriod(h.last7, _selectedDate, mondayFirst: appState.weekStart == WeekStart.monday);
                  }).toList();

                  // Unified Order: Use valid habits stream order directly.
                  // This ensures consistency with "My Habits" and Statistics.
                  
                  if (habits.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: _progressBottomClearance(context),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.done_all, size: 48, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(l10n.habitsEmptyToday, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: EdgeInsets.only(
                      bottom: _progressBottomClearance(context),
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final habit = habits[index];
                          return _buildTodayHabitItem(habit, theme, l10n);
                        },
                        childCount: habits.length,
                      ),
                    ),
                  );
                },
              );
                },
              ),
            ] else 
            // Stream Builder for Habits (Overiew)
            StreamBuilder<List<Habit>>(
              stream: habitService.habitsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(child: Text(l10n.habitsListError(snapshot.error.toString()))),
                  );
                }
                
                // Use existing data even during loading - prevents flicker
                final habits = snapshot.data ?? [];

                if (habits.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.habitsEmptyListTitle, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _showAddHabitSheet,
                            child: const Text(_createNewLabel),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                  // Apply optimistic reordering if active
                  List<Habit> displayHabits = List.from(habits);
                  if (_optimisticHabitOrder != null) {
                    final orderMap = _optimisticHabitOrder!.asMap().map((k, v) => MapEntry(v, k));
                    
                    // Check if server data has caught up (same order as optimistic)
                    bool synced = true;
                    if (displayHabits.length == _optimisticHabitOrder!.length) {
                       for (int i = 0; i < displayHabits.length; i++) {
                         if (displayHabits[i].id != _optimisticHabitOrder![i]) {
                           synced = false;
                           break;
                         }
                       }
                    } else {
                       synced = false;
                    }

                    if (synced) {
                      // Server caught up, clear optimistic state
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _optimisticHabitOrder != null) {
                           setState(() => _optimisticHabitOrder = null);
                        }
                      });
                    } else {
                      // Apply optimistic sort
                      displayHabits.sort((a, b) {
                        final idxA = orderMap[a.id] ?? 9999;
                        final idxB = orderMap[b.id] ?? 9999;
                        return idxA.compareTo(idxB);
                      });
                    }
                  }

                  return SliverPadding(
                    padding: EdgeInsets.only(
                      bottom: _isIos(context)
                          ? _iosBottomNavClearance(context)
                          : MediaQuery.of(context).padding.bottom + 80,
                    ),
                    sliver: SliverReorderableList(
                      itemCount: displayHabits.length,
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final item = displayHabits.removeAt(oldIndex);
                        displayHabits.insert(newIndex, item);
                        
                        // Optimistic update
                        setState(() {
                          _optimisticHabitOrder = displayHabits.map((h) => h.id).toList();
                        });

                        // Actual background sync
                        habitService.reorderHabits(uid, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final habit = displayHabits[index];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(habit.id),
                          index: index,
                          child: _HabitItem(
                            habit: habit,
                            weekDates: _weekDates,
                            onToggle: (date) => _toggleHabit(habit, date),
                            onReturn: () {
                              if (_selectedDate.day == DateTime.now().day) {
                                _scrollToToday(animate: true);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
              },
            ),

        ]),
      ),
      floatingActionButton: Visibility(
        visible: _selectedTabIndex == 1,
        maintainState: true,
        maintainAnimation: false,
        maintainSize: false,
        child: _isIos(context)
            ? AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutQuart,
                offset: _fabVisible ? Offset.zero : const Offset(0, 0.22),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutQuart,
                  opacity: _fabVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_fabVisible,
                    child: Padding(
                      padding:
                          EdgeInsets.only(bottom: _iosFabBottomLift(context)),
                      child: _IosLiquidActionPill(
                        icon: Icons.add,
                        label: _createNewLabel,
                        onPressed: _showAddHabitSheet,
                      ),
                    ),
                  ),
                ),
              )
            : AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutQuart,
                offset: _fabVisible ? Offset.zero : const Offset(0, 0.22),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutQuart,
                  opacity: _fabVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_fabVisible,
                    child: FloatingActionButton(
                      onPressed: _showAddHabitSheet,
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _toggleHabit(Habit habit, DateTime date) async {
    if (_isFutureDate(date)) return;
    HapticFeedback.lightImpact();
    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    if (habit.type == HabitType.yesNo) {
      final dateKey = _dateKey(date);
      final isCompleted = habit.last7[dateKey] != null;
      await context.read<HabitService>().toggleCompletion(
            userId: uid,
            habit: habit,
            date: date,
            completed: !isCompleted,
          );
    } else {
      // Show numeric/time input bottom sheet
      final dateKey = _dateKey(date);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => HabitLoggingSheet(
          habit: habit,
          date: date,
          userId: uid,
          initialValue: habit.last7[dateKey],
        ),
      );
    }
  }

  Widget _buildTabItem(int index, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTabIndex != index) {
            setState(() => _selectedTabIndex = index);
            if (index == 0) {
              Future.delayed(const Duration(milliseconds: 50), () => _scrollToToday(animate: true));
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalDatePicker(ThemeData theme) {
    final localeName = AppLocalizations.of(context)!.localeName;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Trigger centering when calendar is first rendered (especially in matrix mode)
    if (!_hasScrolledToToday && _selectedDate.day == today.day && _selectedDate.month == today.month && _selectedDate.year == today.year) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasScrolledToToday) {
          _scrollToToday(animate: false);
          setState(() => _hasScrolledToToday = true);
        }
      });
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 24) / 7; // Show 7 items

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: 61, // 30 days back + today + 30 days forward
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, index) {
          final date = today.add(Duration(days: index - 30));
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: itemWidth - 8, // Subtract margin
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : (isToday ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent),
                borderRadius: BorderRadius.circular(16),
                border: isToday && !isSelected ? Border.all(color: theme.colorScheme.primary, width: 1) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E(localeName).format(date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayHabitItem(Habit habit, ThemeData theme, AppLocalizations l10n) {
    final dateKey = _dateKey(_selectedDate);
    final currentValue = habit.last7[dateKey] ?? 0.0;
    final isFuture = _isFutureDate(_selectedDate);
    final isDark = theme.brightness == Brightness.dark;
    final localeName = l10n.localeName;
    final numberFormat = NumberFormat.decimalPattern(localeName);
    final appState = context.read<AppState>();
    final useLightTitle =
        appState.homeSummaryRange == HomeSummaryRange.off &&
            habit.connectedCourseIds.isEmpty;

    String requirementText;
    if (habit.type == HabitType.numeric) {
      final unit = (habit.unit ?? "").trim();
      final currentStr = numberFormat.format(currentValue.toInt());
      final targetStr = numberFormat.format(habit.targetValue.toInt());
      requirementText = unit.isNotEmpty
          ? l10n.habitRequirementToday(currentStr, targetStr, unit)
          : l10n.habitRequirementTodayNoUnit(currentStr, targetStr);
    } else if (habit.type == HabitType.time) {
      final curStr = _formatDurationHms(currentValue);
      final tarStr = _formatDurationHms(habit.targetValue);
      requirementText = l10n.habitRequirementTodayNoUnit(curStr, tarStr);
    } else {
      requirementText = l10n.habitRequirementMarkDone;
    }

    final row = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: habit.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              IconData(habit.iconCodePoint, fontFamily: habit.iconFamily, fontPackage: habit.iconPackage),
              color: habit.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: TextStyle(
                    fontWeight: useLightTitle ? FontWeight.w500 : FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  requirementText,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: isFuture ? null : () => _toggleHabit(habit, _selectedDate),
            child: HabitCompletionIndicator(
              habit: habit,
              currentValue: currentValue,
              size: 36,
            ),
          ),
        ],
      ),
    );
    if (!isFuture) return row;
    return Opacity(opacity: 0.5, child: row);
  }

  String _formatDurationHms(double seconds) {
    final totalSeconds = seconds.round().clamp(0, 359999).toInt();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;
    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = secs.toString().padLeft(2, '0');
    return "$hStr:$mStr:$sStr";
  }

  String _dateKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }
}

class _IosLiquidActionPill extends StatelessWidget {
  const _IosLiquidActionPill({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black.withValues(alpha: 0.88);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.11 : 0.22),
                Colors.white.withValues(alpha: isDark ? 0.05 : 0.12),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.24),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.035),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitItem extends StatefulWidget {
  final Habit habit;
  final List<DateTime> weekDates; // Base week dates from parent (current week)
  final Function(DateTime) onToggle;
  final VoidCallback? onReturn;

  const _HabitItem({
    required this.habit,
    required this.weekDates,
    required this.onToggle,
    this.onReturn,
  });

  @override
  State<_HabitItem> createState() => _HabitItemState();
}

class _HabitItemState extends State<_HabitItem> {
  int _weekOffset = 0; // 0 = current week, -1 = last week, +1 = next week
  /// Tracks date keys currently being toggled (pending confirmation from service)
  final Set<String> _pendingKeys = {};

  /// Calculate the allowed minimum week offset based on habit start date
  int get _minWeekOffset {
    final now = DateTime.now();
    
    // Find start of current week
    final weekStart = context.read<AppState>().weekStart;
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStartOffset = _weekStartOffset(today, weekStart);
    final currentWeekStart = today.subtract(Duration(days: currentWeekStartOffset));
    
    // Find start of the week containing start date
    final startDate = DateTime(widget.habit.startDate.year, widget.habit.startDate.month, widget.habit.startDate.day);
    final startWeekStartOffset = _weekStartOffset(startDate, weekStart);
    final startWeekStart = startDate.subtract(Duration(days: startWeekStartOffset));
    
    // Calculate weeks between these two boundaries
    final daysDiff = currentWeekStart.difference(startWeekStart).inDays;
    final weeksDiff = (daysDiff / 7).round();
    
    // Minimum offset is negative (going back in time)
    return -weeksDiff;
  }

  int _weekStartOffset(DateTime date, WeekStart weekStart) {
    if (weekStart == WeekStart.monday) {
      return (date.weekday - DateTime.monday).clamp(0, 6);
    }
    return date.weekday % 7;
  }

  String _formatWeekRange(List<DateTime> dates) {
    if (dates.isEmpty) return "";
    final start = dates.first;
    final end = dates.last;
    
    // Format according to prompt: dd.mm.yy – dd.mm.yy
    const startFormat = "dd.MM.yy";
    const endFormat = "dd.MM.yy";
    
    return "${DateFormat(startFormat).format(start)} – ${DateFormat(endFormat).format(end)}";
  }

  /// Maximum week offset is 1 (allow one week future)
  int get _maxWeekOffset => 1;

  /// Get the week dates for the current offset
  List<DateTime> get _currentWeekDates {
    if (_weekOffset == 0) {
      return widget.weekDates;
    }
    return widget.weekDates.map((d) => d.add(Duration(days: _weekOffset * 7))).toList();
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    
    if (velocity > 300) {
      // Swiped right → go to previous week
      if (_weekOffset > _minWeekOffset) {
        setState(() => _weekOffset--);
      }
    } else if (velocity < -300) {
      // Swiped left → go to next week
      if (_weekOffset < _maxWeekOffset) {
        setState(() => _weekOffset++);
      }
    }
  }

  String _getFrequencyText(AppLocalizations l10n, String localeName) {
    final numberFormat = NumberFormat.decimalPattern(localeName);
    switch (widget.habit.frequencyType) {
      case HabitFrequencyType.daily:
        return l10n.habitFrequencyEveryDay;
      case HabitFrequencyType.specificDays:
        if (widget.habit.frequencyPeriod == HabitPeriod.month) {
          if (widget.habit.weekDays.isEmpty) return l10n.habitFrequencySpecificMonth;
          final days = widget.habit.weekDays.toList()..sort();
          final dayLabels = days.map((d) => numberFormat.format(d)).join(", ");
          return l10n.habitFrequencyDaysLabel(dayLabels);
        } else if (widget.habit.frequencyPeriod == HabitPeriod.year) {
          return l10n.habitFrequencySpecificDates;
        }
        if (widget.habit.weekDays.length == 7 || widget.habit.weekDays.isEmpty) {
          return l10n.habitFrequencyEveryDay;
        }
        final days = widget.habit.weekDays.toList()..sort();
        final labels = days
            .where((d) => d >= 1 && d <= 7)
            .map((d) => _weekdayLabel(d, localeName))
            .join(", ");
        return l10n.habitFrequencyDaysLabel(labels);
      case HabitFrequencyType.interval:
        final work = widget.habit.intervalDays;
        final rest = widget.habit.frequencyGoal ?? 0;
        return '$work x $rest';
      case HabitFrequencyType.repeatsInPeriod:
        final period = _periodLabel(widget.habit.frequencyPeriod ?? HabitPeriod.week, l10n).toLowerCase();
        final count = widget.habit.frequencyGoal ?? 1;
        return l10n.habitFrequencyTimesPerPeriod(count, period);
    }
  }

  String _periodLabel(HabitPeriod period, AppLocalizations l10n) {
    switch (period) {
      case HabitPeriod.week:
        return l10n.habitPeriodWeek;
      case HabitPeriod.month:
        return l10n.habitPeriodMonth;
      case HabitPeriod.year:
        return l10n.habitPeriodYear;
    }
  }

  String _weekdayLabel(int weekday, String localeName) {
    final baseMonday = DateTime(2024, 1, 1);
    final date = baseMonday.add(Duration(days: weekday - 1));
    return DateFormat.E(localeName).format(date);
  }

  bool _isFutureDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateMidnight = DateTime(date.year, date.month, date.day);
    return dateMidnight.isAfter(today);
  }

  bool _isBeforeStartDate(DateTime date) {
    final dateMidnight = DateTime(date.year, date.month, date.day);
    final startMidnight = DateTime(widget.habit.startDate.year, widget.habit.startDate.month, widget.habit.startDate.day);
    return dateMidnight.isBefore(startMidnight);
  }

  String _dateKey(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  Future<void> _handleToggle(DateTime date) async {
    // Defer state changes to the service; no optimistic UI flips to avoid stale caches.
    final key = _dateKey(date);
    
    // Prevent double-taps on same key while pending
    if (_pendingKeys.contains(key)) return;
    
    // Mark as pending (NO optimistic state change - wait for service confirmation)
    setState(() => _pendingKeys.add(key));

    try {
      await widget.onToggle(date);
    } finally {
      // Remove from pending when complete (success or failure)
      // The actual state update will come via widget.habit.last7 from stream
      if (mounted) {
        setState(() => _pendingKeys.remove(key));
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final localeName = l10n.localeName;
    final frequencyText = _getFrequencyText(l10n, localeName);
    final weekDates = _currentWeekDates;
    final appState = context.read<AppState>();
    final useLightTitle =
        appState.homeSummaryRange == HomeSummaryRange.off &&
            widget.habit.connectedCourseIds.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: widget.habit.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        IconData(widget.habit.iconCodePoint, fontFamily: widget.habit.iconFamily, fontPackage: widget.habit.iconPackage),
                        color: widget.habit.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.habit.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight:
                                        useLightTitle ? FontWeight.w500 : FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.habit.liveCurrentStreak > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.local_fire_department, size: 12, color: Colors.orange),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${widget.habit.liveCurrentStreak}",
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            frequencyText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HabitDetailsScreen(habit: widget.habit)),
                        );
                        // Re-center on return if today is selected
                        widget.onReturn?.call();
                      },
                    ),
                  ],
                ),
                Divider(
                  height: 32,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                // Week navigation row with arrows and date range
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left arrow (go to previous week)
                    GestureDetector(
                      onTap: _weekOffset > _minWeekOffset 
                          ? () => setState(() => _weekOffset--) 
                          : null,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _weekOffset > _minWeekOffset
                              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_left,
                          size: 18,
                          color: _weekOffset > _minWeekOffset
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    // Week date range label
                    Expanded(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _weekOffset == 0 
                                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _weekOffset == 0
                                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _formatWeekRange(_currentWeekDates),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _weekOffset == 0 
                                  ? theme.colorScheme.primary 
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontWeight: _weekOffset == 0 ? FontWeight.bold : FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Right arrow (go to next week)
                    GestureDetector(
                      onTap: _weekOffset < _maxWeekOffset 
                          ? () => setState(() => _weekOffset++) 
                          : null,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _weekOffset < _maxWeekOffset
                              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: _weekOffset < _maxWeekOffset
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Swipeable 7-day row
                GestureDetector(
                  onHorizontalDragEnd: _handleSwipe,
                  child: SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: weekDates.map((date) {
                        final dateKey = _dateKey(date);
                        final isSaving = _pendingKeys.contains(dateKey);
                        final currentVal = widget.habit.last7[dateKey] ?? 0.0;
                        final isCompleted = currentVal >= widget.habit.targetValue;
                        final isPartialProgress = widget.habit.type != HabitType.yesNo && currentVal > 0 && currentVal < widget.habit.targetValue;
                        
                        final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

                        // Determine styling state
                        final isPreStart = _isBeforeStartDate(date);
                        final isFuture = _isFutureDate(date);
                        final isScheduled = widget.habit.isScheduledFor(date);
                        final isGoalMet = widget.habit.isGoalMetForPeriod(
                          widget.habit.last7, 
                          date,
                          mondayFirst: context.read<AppState>().weekStart == WeekStart.monday,
                        );
                        final isLocked = !isCompleted && isGoalMet;
                        
                        // Active: Today or past scheduled days
                        final isActive = !isPreStart && !isFuture && isScheduled;
                        
                        // Interaction only allowed on active days and NOT locked and NOT saving
                        final canInteract = isActive && !isLocked && !isSaving;

                        // Styling Logic
                        Color textColor;
                        if (isPreStart || !isScheduled || isLocked) {
                           // A, C & Locked: Not required, pre-start or locked -> Muted
                           textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
                        } else if (isFuture) {
                           // B: Future Required -> Regular normal color (same as active)
                           textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
                        } else {
                           // Active
                           textColor = isToday ? widget.habit.color : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
                        }

                        // Determine Circle Decoration and Child
                        BoxDecoration circleDeco;
                        Widget? circleChild;
                        
                        if (isPreStart || !isScheduled) {
                           // Hidden (transparent)
                           circleDeco = const BoxDecoration(color: Colors.transparent);
                        } else if (isFuture || isLocked) {
                           // Visible but disabled (muted background)
                           circleDeco = BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                           );
                        } else {
                           // Active / Today / Past
                            circleDeco = BoxDecoration(
                              color: isCompleted
                                  ? widget.habit.color
                                  : (isPartialProgress 
                                      ? widget.habit.color.withValues(alpha: 0.15)
                                      : (isScheduled ? theme.colorScheme.surfaceContainerHighest : Colors.transparent)),
                              shape: BoxShape.circle,
                              border: (isToday || isPartialProgress) 
                                  ? Border.all(color: widget.habit.color, width: isPartialProgress ? 2 : 2) 
                                  : null,
                            );
                            if (isCompleted) {
                               circleChild = const Icon(Icons.check, size: 18, color: Colors.white);
                            }
                        }

                        final dateItem = GestureDetector(
                          onTap: canInteract ? () => _handleToggle(date) : null,
                          child: Column(
                            children: [
                              Text(
                                DateFormat.E(localeName).format(date),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textColor,
                                  fontWeight: (isToday && isScheduled) ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: circleDeco,
                                alignment: Alignment.center,
                                child: circleChild,
                              ),
                            ],
                          ),
                        );

                        return dateItem;
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
