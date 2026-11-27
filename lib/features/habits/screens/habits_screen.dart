import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:numer_app/app/app_state.dart';
import 'package:numer_app/features/account/account.dart';
import 'package:numer_app/features/auth/auth.dart';
import 'package:numer_app/l10n/app_localizations.dart';
import 'package:numer_ui/numer_ui.dart';
import 'package:provider/provider.dart';

import '../data/habit_service.dart';
import '../habit_dates.dart';
import '../models/habit.dart';
import '../widgets/habit_logging_sheet.dart';
import '../widgets/habits_clearances.dart';
import '../widgets/habits_date_picker.dart';
import '../widgets/habits_list_tab.dart';
import '../widgets/habits_progress_tab.dart';
import 'add_habit_sheet.dart';
import 'archived_habits_screen.dart';
import 'habits_calendar_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen>
    with SingleTickerProviderStateMixin {
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

  void _recenterIfToday() {
    if (mounted && _selectedDate.day == DateTime.now().day) {
      _scrollToToday(animate: true);
    }
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _recenterIfToday();
  }

  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse && _fabVisible) {
      setState(() => _fabVisible = false);
    } else if (notification.direction == ScrollDirection.forward &&
        !_fabVisible) {
      setState(() => _fabVisible = true);
    }
    return false;
  }

  void _onHabitPlaced(bool wasLast) {
    setState(() {});
    // After placing, check if all sorted - scroll to today
    if (wasLast) {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => _scrollToToday(animate: true),
      );
    }
  }

  void _clearOptimisticOrder() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _optimisticHabitOrder != null) {
        setState(() => _optimisticHabitOrder = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.currentUser?.uid;

    if (uid == null) {
      final l10n = AppLocalizations.of(context)!;
      return Center(child: Text(l10n.habitsPleaseSignIn));
    }

    final habitService = context.watch<HabitService>();

    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onUserScroll,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            _buildTabSwitch(context),
            if (_selectedTabIndex == 0)
              ...habitsProgressSlivers(
                context: context,
                habitsStream: () => habitService.habitsStream(uid),
                selectedDate: _selectedDate,
                calendarKey: _calendarKey,
                datePicker: _buildDatePicker,
                onPlaced: _onHabitPlaced,
                onToggle: (habit) => _toggleHabit(habit, _selectedDate),
              )
            else
              _buildListTab(habitService, uid),
          ],
        ),
      ),
      floatingActionButton: Visibility(
        visible: _selectedTabIndex == 1,
        child: _buildFab(context),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isIos(context) ? iosFabBottomLift(context) : 0,
      ),
      child: NumerFab(
        icon: Icons.add,
        label: AppLocalizations.of(context)!.habitsAddHabit,
        onPressed: _showAddHabitSheet,
        visible: _fabVisible,
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ShellHeader(
      title: Text(l10n.habitsNavLabel, style: context.text.screenTitle),
      actions: [
        IconButton(
          tooltip: l10n.archivedHabitsTitle,
          icon: const Icon(Icons.archive_outlined),
          onPressed: () => _openScreen(const ArchivedHabitsScreen()),
        ),
        IconButton(
          tooltip: l10n.habitsCalendarTitle,
          icon: const Icon(Icons.calendar_month),
          onPressed: () => _openScreen(const HabitsCalendarScreen()),
        ),
      ],
    );
  }

  Widget _buildTabSwitch(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NumerSpace.lg,
          vertical: NumerSpace.sm,
        ),
        child: SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.habitsTabProgress)),
            ButtonSegment(value: 1, label: Text(l10n.habitsTabList)),
          ],
          selected: {_selectedTabIndex},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => _selectTab(selection.first),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    HapticFeedback.selectionClick();
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
    if (index == 0) {
      Future.delayed(
        const Duration(milliseconds: 50),
        () => _scrollToToday(animate: true),
      );
    }
  }

  Widget _buildListTab(HabitService habitService, String uid) {
    // Stream Builder for Habits (Overiew)
    return StreamBuilder<List<Habit>>(
      stream: habitService.habitsStream(uid),
      builder: (context, snapshot) => HabitsListSliver(
        snapshot: snapshot,
        weekDates: _weekDates,
        optimisticOrder: _optimisticHabitOrder,
        onOrderSynced: _clearOptimisticOrder,
        onReorder: (order, oldIndex, newIndex) {
          // Optimistic update
          setState(() => _optimisticHabitOrder = order);

          // Actual background sync
          habitService.reorderHabits(uid, oldIndex, newIndex);
        },
        onToggle: _toggleHabit,
        onReturn: _recenterIfToday,
        onCreate: _showAddHabitSheet,
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
