import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/habit.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';
import 'habit_details_screen.dart';

class ArchivedHabitsScreen extends StatelessWidget {
  const ArchivedHabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.currentUser?.uid;
    final habitService = context.watch<HabitService>();
    final theme = Theme.of(context);

    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Please sign in")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Archived habits"),
      ),
      body: StreamBuilder<List<Habit>>(
        stream: habitService.archivedHabitsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final habits = snapshot.data ?? [];

          if (habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text("No archived habits", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
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
                  title: Text(habit.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Archived", style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () => _unarchive(context, uid, habit.id),
                    child: const Text("Unarchive"),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HabitDetailsScreen(habit: habit),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _unarchive(BuildContext context, String uid, String habitId) {
    context.read<HabitService>().unarchiveHabit(uid, habitId);
  }
}
