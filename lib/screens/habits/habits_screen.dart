import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/habit.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';
import 'add_habit_sheet.dart';
import 'habit_details_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  // We'll calculate the last 7 days (today + past 6 days) to show circles
  late List<DateTime> _weekDates;

  @override
  void initState() {
    super.initState();
    _updateWeekDates();
  }

  void _updateWeekDates() {
    final now = DateTime.now();
    // Generate [Today-6, ..., Today]
    // Or strictly Monday-Sunday? The requirement says "7-day Mon-Sun indicators".
    // That usually means a static week row? Or a rolling window?
    // "last 7 days" vs "this week".
    // Let's implement "Last 7 days" ending today for the rolling window effect,
    // OR "Current Calendar Week".
    // "7-day Mon-Sun indicators" suggests Mon-Sun fixed.
    // Let's do Mon-Sun of current week.
    
    final today = DateTime(now.year, now.month, now.day);
    // Find Monday
    final monday = today.subtract(Duration(days: today.weekday - 1));
    
    _weekDates = List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    // Re-verify auth
    final auth = context.watch<AuthController>();
    final uid = auth.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text("Please sign in"));
    }

    final habitService = context.watch<HabitService>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text("Habits"),
            floating: true,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: () {
                  // TODO: Go to full calendar view or history
                },
              )
            ],
          ),
          
          // Stream Builder for Habits
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
                        const Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text("No habits yet", style: TextStyle(fontSize: 18, color: Colors.grey)),
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
                          child: const Text("Create your first habit"),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final habit = habits[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HabitDetailsScreen(habit: habit),
                            ),
                          );
                        },
                        child: _HabitItem(
                          habit: habit,
                          weekDates: _weekDates,
                          onToggle: (date) => _toggleHabit(habit, date),
                        ),
                      );
                    },
                    childCount: habits.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
      ),
    );
  }



  void _toggleHabit(Habit habit, DateTime date) {
    // Calculate new status
    final dateKey = _dateKey(date);
    final isCompleted = habit.last7[dateKey] == 1;
    final uid = context.read<AuthController>().currentUser!.uid;
    
    // Haptic feedback
    if (!isCompleted) HapticFeedback.mediumImpact();

    // Call service
    context.read<HabitService>().toggleCompletion(
      userId: uid,
      habitId: habit.id,
      date: date,
      completed: !isCompleted,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: habit.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
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
                        Text(habit.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          "${habit.totalCompletions} completions • ${habit.currentStreak} streak",
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                     ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Week Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekDates.map((date) {
                final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                final isCompleted = habit.last7[dateKey] == 1;
                final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;
                
                // Is this day active for this habit?
                // If weekDays is empty, every day is active.
                // If not empty, check if weekday (1-7) is in set.
                final isScheduled = habit.weekDays.isEmpty || habit.weekDays.contains(date.weekday);

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
                          color: isCompleted 
                             ? habit.color 
                             : (isScheduled ? theme.colorScheme.surfaceContainerHighest : Colors.transparent),
                          shape: BoxShape.circle,
                          border: isToday && !isCompleted 
                             ? Border.all(color: habit.color, width: 2)
                             : null,
                        ),
                        child: isCompleted 
                           ? const Icon(Icons.check, size: 18, color: Colors.white)
                           : null,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
