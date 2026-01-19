import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../../models/habit.dart';
import '../../data/local/entities.dart';
import '../../services/auth_service.dart';
import '../../services/habit_service.dart';
import '../../services/storage.dart';
import '../../services/sync_service.dart';
import '../../app_state.dart';
import 'habit_details_screen.dart';
import '../../l10n/app_localizations.dart';

class ArchivedHabitsScreen extends StatefulWidget {
  const ArchivedHabitsScreen({super.key});

  @override
  State<ArchivedHabitsScreen> createState() => _ArchivedHabitsScreenState();
}

class _ArchivedHabitsScreenState extends State<ArchivedHabitsScreen> {

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final uid = auth.currentUser?.uid;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final syncService = context.watch<SyncService>();
    final appState = context.read<AppState>();

    if (uid == null) {
      return Scaffold(body: Center(child: Text(l10n.habitsPleaseSignIn)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.archivedHabitsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => appState.triggerSync(full: true),
          ),
        ],
        bottom: syncService.status == SyncStatus.syncing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: theme.colorScheme.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              )
            : null,
      ),
      body: ValueListenableBuilder(
        valueListenable: Storage.getHabitsBox().listenable(),
        builder: (context, Box<LocalHabit> box, _) {
          final archivedHabits = box.values
              .where((h) => h.archived && !h.deleted)
              .toList();
          
          archivedHabits.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));

          if (archivedHabits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(l10n.archivedHabitsEmpty, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: archivedHabits.length,
            itemBuilder: (context, index) {
              final localHabit = archivedHabits[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(localHabit.colorValue).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      IconData(localHabit.iconCodePoint, fontFamily: localHabit.iconFamily, fontPackage: localHabit.iconPackage),
                      color: Color(localHabit.colorValue),
                      size: 20,
                    ),
                  ),
                  title: Text(localHabit.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(l10n.habitArchivedLabel, style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                  trailing: TextButton(
                    onPressed: () => _unarchive(context, uid, localHabit),
                    child: Text(l10n.habitUnarchiveAction),
                  ),
                  onTap: () {
                    // Convert LocalHabit to Habit for details screen
                    final habit = _localHabitToHabit(localHabit);
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

  void _unarchive(BuildContext context, String uid, LocalHabit localHabit) {
    // 1. Update local cache immediately
    localHabit.archived = false;
    localHabit.dirty = true;
    localHabit.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    localHabit.save();
    
    // 2. Sync to Firebase in background via HabitService
    final habitService = context.read<HabitService>();
    habitService.unarchiveHabit(uid, localHabit.id);
  }

  Habit _localHabitToHabit(LocalHabit lh) {
    return Habit(
      id: lh.id,
      name: lh.name,
      color: Color(lh.colorValue),
      iconCodePoint: lh.iconCodePoint,
      iconFamily: lh.iconFamily,
      iconPackage: lh.iconPackage,
      category: lh.category,
      type: HabitType.values[lh.typeIndex],
      targetValue: lh.targetValue,
      unit: lh.unit,
      comparator: HabitComparator.values[lh.comparatorIndex],
      frequencyType: HabitFrequencyType.values[lh.frequencyTypeIndex],
      weekDays: lh.weekDays.toSet(),
      intervalDays: lh.intervalDays,
      frequencyPeriod: lh.frequencyPeriodIndex != null ? HabitPeriod.values[lh.frequencyPeriodIndex!] : null,
      frequencyGoal: lh.frequencyGoal,
      startDate: DateTime.fromMillisecondsSinceEpoch(lh.startDateMs),
      endDate: lh.endDateMs != null ? DateTime.fromMillisecondsSinceEpoch(lh.endDateMs!) : null,
      totalCompletions: lh.totalCompletions,
      currentStreak: lh.currentStreak,
      longestStreak: lh.longestStreak,
      sortOrder: lh.sortOrder,
      last7: _parseLast7(lh.last7Json),
      archived: lh.archived,
      createdAt: DateTime.fromMillisecondsSinceEpoch(lh.createdAtMs),
      connectedCourseIds: lh.connectedCourseIds,
    );
  }

  Map<String, double> _parseLast7(String json) {
    if (json.isEmpty || json == '{}') return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {};
    } catch (_) {
      return {};
    }
  }
}
