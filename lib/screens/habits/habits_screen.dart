import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/habit.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';
import '../../app_state.dart';
import 'habits_calendar_screen.dart';
import 'archived_habits_screen.dart';
import 'widgets/habit_logging_sheet.dart';
import 'habit_details_screen.dart';
import 'add_habit_sheet.dart';
import '../../widgets/progress_circle.dart';
import '../../services/storage.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> with SingleTickerProviderStateMixin {
  // We'll calculate the last 7 days (today + past 6 days) to show circles
  late List<DateTime> _weekDates;
  
  int _selectedTabIndex = 0; // 0 for Today, 1 for Habits
  late DateTime _selectedDate;
  late ScrollController _dateScrollController;

  @override
  void initState() {
    super.initState();
    _updateWeekDates();
    _selectedDate = DateTime.now();
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _dateScrollController = ScrollController();
    
    // Scroll to today (middle of the list)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday(animate: false);
    });
  }

  void _scrollToToday({bool animate = false}) {
    if (_dateScrollController.hasClients) {
      final screenWidth = MediaQuery.of(context).size.width;
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

  void _updateWeekDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    _weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.currentUser?.uid;
    final theme = Theme.of(context);

    if (uid == null) {
      return const Center(child: Text("Please sign in"));
    }

    final habitService = context.watch<HabitService>();

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: CustomScrollView(
          slivers: [
            SliverAppBar(
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
                    _buildTabItem(0, "Progress"),
                    _buildTabItem(1, "My habits"),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ArchivedHabitsScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HabitsCalendarScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            
            if (_selectedTabIndex == 0) ...[
              // Today View: Date Picker
              SliverToBoxAdapter(
                child: _buildHorizontalDatePicker(theme),
              ),
              // Today View: Habit List
              StreamBuilder<List<Habit>>(
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
                    return !h.isGoalMetForPeriod(h.last7, _selectedDate);
                  }).toList();

                  // Apply local shared reordering for Progress tab
                  final localOrder = Storage.getProgressHabitOrder();
                  if (localOrder != null) {
                    habits.sort((a, b) {
                      int idxA = localOrder.indexOf(a.id);
                      int idxB = localOrder.indexOf(b.id);
                      if (idxA == -1 && idxB == -1) return a.sortOrder.compareTo(b.sortOrder);
                      if (idxA == -1) return 1;
                      if (idxB == -1) return -1;
                      return idxA.compareTo(idxB);
                    });
                  }
                  
                  if (habits.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.done_all, size: 48, color: theme.colorScheme.outline),
                            const SizedBox(height: 16),
                            Text("Nothing to do today. Cheers!", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverReorderableList(
                    itemCount: habits.length,
                    onReorder: (oldIndex, newIndex) {
                      final reorderedIds = habits.map((h) => h.id).toList();
                      if (newIndex > oldIndex) newIndex -= 1;
                      final id = reorderedIds.removeAt(oldIndex);
                      reorderedIds.insert(newIndex, id);
                      Storage.saveProgressHabitOrder(reorderedIds);
                      setState(() {});
                    },
                    itemBuilder: (context, index) {
                      final habit = habits[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(habit.id),
                        index: index,
                        child: _buildTodayHabitItem(habit, theme),
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
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final habits = snapshot.data ?? [];

                if (habits.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("No habit yet", style: TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (_) => const AddHabitSheet(),
                              );
                            },
                            child: const Text("Create your first"),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 80),
                  sliver: SliverReorderableList(
                    itemCount: habits.length,
                    onReorder: (oldIndex, newIndex) {
                      habitService.reorderHabits(uid, oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final habit = habits[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(habit.id),
                        index: index,
                        child: _HabitItem(
                          habit: habit,
                          weekDates: _weekDates,
                          onToggle: (date) => _toggleHabit(habit, date),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      floatingActionButton: _selectedTabIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => const AddHabitSheet(),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _toggleHabit(Habit habit, DateTime date) async {
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
      if (mounted) context.read<AppState>().triggerSync();
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 24) / 7; // 24 is the combined horizontal padding (12 * 2)

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
                    DateFormat.E().format(date),
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

  Widget _buildTodayHabitItem(Habit habit, ThemeData theme) {
    final dateKey = _dateKey(_selectedDate);
    final currentValue = habit.last7[dateKey] ?? 0.0;
    final isCompleted = currentValue >= habit.targetValue;

    String requirementText = "Mark as done";
    if (habit.type == HabitType.numeric) {
      requirementText = "${currentValue.toInt()} / ${habit.targetValue.toInt()} ${habit.unit ?? ""} today";
    } else if (habit.type == HabitType.time) {
      final curH = currentValue ~/ 3600;
      final curM = (currentValue % 3600) ~/ 60;
      final tarH = habit.targetValue ~/ 3600;
      final tarM = (habit.targetValue % 3600) ~/ 60;
      
      String curStr = curH > 0 ? "${curH}h ${curM}m" : "${curM}m";
      String tarStr = tarH > 0 ? "${tarH}h ${tarM}m" : "${tarM}m";
      requirementText = "$curStr / $tarStr today";
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                Text(habit.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            onTap: () => _toggleHabit(habit, _selectedDate),
            child: habit.type == HabitType.yesNo
                ? AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCompleted ? habit.color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? habit.color : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background track
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                      ),
                      ProgressCircle(
                        current: currentValue,
                        goal: habit.targetValue,
                        color: habit.color,
                        size: 36,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _dateKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }
}

class _HabitItem extends StatelessWidget {
  final Habit habit;
  final List<DateTime> weekDates;
  final Function(DateTime) onToggle;

  const _HabitItem({
    required this.habit,
    required this.weekDates,
    required this.onToggle,
  });

  String _getFrequencyText() {
    switch (habit.frequencyType) {
      case HabitFrequencyType.daily:
        return "Every day";
      case HabitFrequencyType.specificDays:
        if (habit.frequencyPeriod == HabitPeriod.month) {
          if (habit.weekDays.isEmpty) return "Specific days of month";
          final days = habit.weekDays.toList()..sort();
          return "Days: ${days.join(", ")}";
        } else if (habit.frequencyPeriod == HabitPeriod.year) {
          return "Specific dates";
        }
        if (habit.weekDays.length == 7 || habit.weekDays.isEmpty) {
          return "Every day";
        }
        final days = habit.weekDays.toList()..sort();
        final weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
        return days
            .where((d) => d >= 1 && d <= 7)
            .map((d) => weekdays[d - 1])
            .join(", ");
      case HabitFrequencyType.interval:
        return "Every ${habit.intervalDays} days";
      case HabitFrequencyType.repeatsInPeriod:
        final period = habit.frequencyPeriod?.name ?? "period";
        return "${habit.frequencyGoal ?? 1} times per $period";
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        color: habit.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        IconData(habit.iconCodePoint, fontFamily: habit.iconFamily, fontPackage: habit.iconPackage),
                        color: habit.color,
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
                                  habit.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (habit.currentStreak > 0) ...[
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
                                        "${habit.currentStreak}",
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
                            _getFrequencyText(),
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HabitDetailsScreen(habit: habit)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: weekDates.map((date) {
                      final dateKey =
                          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                      final isCompleted = habit.last7[dateKey] == 1 || (habit.last7[dateKey] ?? 0) >= habit.targetValue;
                      final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

                      final isScheduled = habit.isScheduledFor(date);

                      return GestureDetector(
                        onTap: isScheduled ? () => onToggle(date) : null,
                        child: Column(
                          children: [
                            Text(
                              DateFormat.E().format(date)[0],
                              style: TextStyle(
                                fontSize: 10,
                                color: isToday ? habit.color : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCompleted ? habit.color : (isScheduled ? theme.colorScheme.surfaceContainerHighest : Colors.transparent),
                                shape: BoxShape.circle,
                                border: isToday && !isCompleted ? Border.all(color: habit.color, width: 2) : null,
                              ),
                              child: isCompleted ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
