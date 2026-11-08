import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/features/habits/models/habit.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/features/habits/data/habit_service.dart';
import 'package:numer_app/features/habits/habit_dates.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/habits/screens/habits_calendar_screen.dart';
import 'package:numer_app/features/habits/screens/archived_habits_screen.dart';
import 'package:numer_app/features/habits/widgets/habit_logging_sheet.dart';
import 'package:numer_app/features/habits/widgets/eisenhower_matrix_widget.dart';
import 'package:numer_app/features/habits/widgets/habit_sorter_card.dart';
import 'package:numer_app/features/habits/widgets/habit_list_item.dart';
import 'package:numer_app/features/habits/widgets/ios_liquid_action_pill.dart';
import 'package:numer_app/features/habits/widgets/habits_date_picker.dart';
import 'package:numer_app/features/habits/widgets/today_habit_item.dart';
import 'package:numer_app/features/habits/screens/add_habit_sheet.dart';

import 'package:numer_app/core/data/storage.dart';
import 'package:numer_app/l10n/app_localizations.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen>
    with SingleTickerProviderStateMixin {
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
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
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
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToToday(animate: animate),
        );
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
    final offset = weekStartOffset(today, weekStart);
    final start = today.subtract(Duration(days: offset));
    _weekDates = List.generate(7, (i) => start.add(Duration(days: i)));
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
          if (notification.direction == ScrollDirection.reverse &&
              _fabVisible) {
            setState(() => _fabVisible = false);
          } else if (notification.direction == ScrollDirection.forward &&
              !_fabVisible) {
            setState(() => _fabVisible = true);
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
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
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
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
                  if (!snapshot.hasData) {
                    return const SliverToBoxAdapter(child: SizedBox());
                  }
                  final allHabits = snapshot.data!;
                  final appState = context.watch<AppState>();

                  // If Eisenhower Matrix is enabled, show matrix UI
                  if (appState.eisenhowerMatrixEnabled) {
                    final placements = Storage.getHabitQuadrantPlacements();

                    // Filter: Hide habits if period goal is met AND not done today
                    final filteredHabits = allHabits.where((h) {
                      if (!h.isScheduledFor(_selectedDate)) return false;
                      // Check completion status for the selected date
                      final key = dateKey(_selectedDate);
                      final currentValue = h.last7[key] ?? 0.0;
                      final isCompletedOnDate = currentValue >= h.targetValue;

                      // Show if completed on this date OR period goal NOT met.
                      if (isCompletedOnDate) return true;
                      return !h.isGoalMetForPeriod(
                        h.last7,
                        _selectedDate,
                        mondayFirst: appState.weekStart == WeekStart.monday,
                      );
                    }).toList();

                    final unsortedHabits = filteredHabits
                        .where((h) => !placements.containsKey(h.id))
                        .toList();

                    // Full-screen matrix layout
                    final screenHeight = MediaQuery.of(context).size.height;
                    final topPadding = MediaQuery.of(context).padding.top;
                    final bottomPadding = MediaQuery.of(context).padding.bottom;
                    final availableHeight =
                        screenHeight -
                        topPadding -
                        kToolbarHeight -
                        bottomPadding -
                        20;

                    return SliverToBoxAdapter(
                      child: SizedBox(
                        height:
                            availableHeight - _progressBottomClearance(context),
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
                                        Future.delayed(
                                          const Duration(milliseconds: 100),
                                          () => _scrollToToday(animate: true),
                                        );
                                      }
                                    },
                                  )
                                : KeyedSubtree(
                                    key: _calendarKey,
                                    child: _buildDatePicker(),
                                  ),

                            // Matrix grid
                            Expanded(
                              child: EisenhowerMatrixWidget(
                                habits: filteredHabits
                                    .where((h) => placements.containsKey(h.id))
                                    .toList(),
                                selectedDate: _selectedDate,
                                onHabitTap: (habit) =>
                                    _toggleHabit(habit, _selectedDate),
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
                      child: _buildDatePicker(),
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
                      if (!snapshot.hasData) {
                        return const SliverToBoxAdapter(child: SizedBox());
                      }
                      final habits = snapshot.data!.where((h) {
                        if (!h.isScheduledFor(_selectedDate)) return false;

                        // Check completion status for the selected date
                        final key = dateKey(_selectedDate);
                        final currentValue = h.last7[key] ?? 0.0;
                        final isCompletedOnDate = currentValue >= h.targetValue;

                        // RULE: Show if completed on this date OR period goal NOT met.
                        // This allows users to see/edit their progress today even if the goal was just met,
                        // and ensures the habit reappears if progress drops below the threshold.
                        if (isCompletedOnDate) return true;
                        return !h.isGoalMetForPeriod(
                          h.last7,
                          _selectedDate,
                          mondayFirst: appState.weekStart == WeekStart.monday,
                        );
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
                                  Icon(
                                    Icons.done_all,
                                    size: 48,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l10n.habitsEmptyToday,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: theme.colorScheme.outline,
                                        ),
                                  ),
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
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final habit = habits[index];
                            return TodayHabitItem(
                              habit: habit,
                              selectedDate: _selectedDate,
                              onToggle: () =>
                                  _toggleHabit(habit, _selectedDate),
                            );
                          }, childCount: habits.length),
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
                      child: Center(
                        child: Text(
                          l10n.habitsListError(snapshot.error.toString()),
                        ),
                      ),
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
                            Text(
                              l10n.habitsEmptyListTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
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
                    final orderMap = _optimisticHabitOrder!.asMap().map(
                      (k, v) => MapEntry(v, k),
                    );

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
                          _optimisticHabitOrder = displayHabits
                              .map((h) => h.id)
                              .toList();
                        });

                        // Actual background sync
                        habitService.reorderHabits(uid, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final habit = displayHabits[index];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(habit.id),
                          index: index,
                          child: HabitListItem(
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
          ],
        ),
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
                      padding: EdgeInsets.only(
                        bottom: _iosFabBottomLift(context),
                      ),
                      child: IosLiquidActionPill(
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
    if (isFutureDate(date)) return;
    HapticFeedback.lightImpact();
    final auth = context.read<AuthController>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    if (habit.type == HabitType.yesNo) {
      final key = dateKey(date);
      final isCompleted = habit.last7[key] != null;
      await context.read<HabitService>().toggleCompletion(
        userId: uid,
        habit: habit,
        date: date,
        completed: !isCompleted,
      );
    } else {
      // Show numeric/time input bottom sheet
      final key = dateKey(date);
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
          initialValue: habit.last7[key],
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
              Future.delayed(
                const Duration(milliseconds: 50),
                () => _scrollToToday(animate: true),
              );
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
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Trigger centering when calendar is first rendered (especially in matrix mode)
    if (!_hasScrolledToToday &&
        _selectedDate.day == today.day &&
        _selectedDate.month == today.month &&
        _selectedDate.year == today.year) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasScrolledToToday) {
          _scrollToToday(animate: false);
          setState(() => _hasScrolledToToday = true);
        }
      });
    }

    return HabitsDatePicker(
      // 30 days back + today + 30 days forward
      dates: List.generate(61, (i) => today.add(Duration(days: i - 30))),
      selectedDate: _selectedDate,
      scrollController: _dateScrollController,
      onSelect: (date) => setState(() => _selectedDate = date),
    );
  }
}
