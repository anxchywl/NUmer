import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/habit.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';

class HabitDetailsScreen extends StatefulWidget {
  final Habit habit;
  const HabitDetailsScreen({super.key, required this.habit});

  @override
  State<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends State<HabitDetailsScreen> {
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, bool> _history = {};
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = context.read<AuthController>().currentUser?.uid;
    if (uid == null) return;

    final start = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    final end = DateTime(_focusedDay.year, _focusedDay.month + 2, 0);

    final entries = await context.read<HabitService>().getHistory(
      uid, 
      widget.habit.id, 
      start, 
      end
    );

    if (!mounted) return;

    setState(() {
      _history = {
        for (var e in entries) 
          DateTime(e.date.year, e.date.month, e.date.day): true
      };
      _isLoadingHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habit = widget.habit; 

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        bottom: _isLoadingHistory 
           ? const PreferredSize(
               preferredSize: Size.fromHeight(2), 
               child: LinearProgressIndicator(minHeight: 2),
             )
           : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Edit habit
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Stats Header
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: "Streak",
                    value: "${habit.currentStreak}",
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                  ),
                  _StatItem(
                    label: "Total",
                    value: "${habit.totalCompletions}",
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),
                  _StatItem(
                    label: "Best",
                    value: "${habit.longestStreak}",
                    icon: Icons.emoji_events,
                    color: Colors.purple,
                  ),
                ],
              ),
            ),

            // Calendar
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 10, 16),
                  lastDay: DateTime.utc(2030, 3, 14),
                  focusedDay: _focusedDay,
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    _loadHistory();
                  },
                  calendarFormat: CalendarFormat.month,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                       final isCompleted = _history.containsKey(DateTime(day.year, day.month, day.day));
                       if (isCompleted) {
                         return Container(
                           margin: const EdgeInsets.all(6.0),
                           alignment: Alignment.center,
                           decoration: BoxDecoration(
                             color: habit.color,
                             shape: BoxShape.circle,
                           ),
                           child: Text(
                             day.day.toString(),
                             style: const TextStyle(color: Colors.white),
                           ),
                         );
                       }
                       return null;
                    },
                    todayBuilder: (context, day, focusedDay) {
                       final isCompleted = _history.containsKey(DateTime(day.year, day.month, day.day));
                       return Container(
                         margin: const EdgeInsets.all(6.0),
                         alignment: Alignment.center,
                         decoration: BoxDecoration(
                           color: isCompleted ? habit.color : Colors.transparent,
                           border: Border.all(color: theme.colorScheme.primary, width: 2),
                           shape: BoxShape.circle,
                         ),
                         child: Text(
                           day.day.toString(),
                           style: TextStyle(color: isCompleted ? Colors.white : theme.colorScheme.onSurface),
                         ),
                       );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _confirmDelete(BuildContext context) async {
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
