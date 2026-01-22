import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/local/entities.dart';
import '../data/local/local_database.dart';
import '../models/habit.dart';
import '../models/habit_category.dart';
import 'storage.dart';

class HabitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _writeMutex = _Mutex();

  // -- Categories (Local Only) --

  final _categoryController = StreamController<List<HabitCategory>>.broadcast();

  Stream<List<HabitCategory>> getCategories(String uid) {
    _loadLocalCategories(); // Initial load
    return _categoryController.stream;
  }
  
  // -- History Updates --
  final _historyUpdateController = StreamController<void>.broadcast();
  Stream<void> get historyUpdates => _historyUpdateController.stream;

  Future<void> _loadLocalCategories() async {
    final cats = await Storage.getHabitCategories();
    _categoryController.add(cats);
  }

  Future<void> createCategory(String uid, HabitCategory category) async {
    final current = await Storage.getHabitCategories();
    final updated = [...current, category];
    await Storage.saveHabitCategories(updated);
    _categoryController.add(updated);
  }

  Future<void> deleteCategory(String uid, String categoryId) async {
    final current = await Storage.getHabitCategories();
    final updated = current.where((c) => c.id != categoryId).toList();
    await Storage.saveHabitCategories(updated);
    _categoryController.add(updated);
  }

  // -- Habits --

  // -- Habits --

  Stream<List<Habit>> habitsStream(String userId) {
    // HYBRID STREAM: Local First + Remote Sync
    // 1. Create a controller to emit the "view" of habits (sourced from Local Storage)
    final controller = StreamController<List<Habit>>();
    
    // Helper to load & emit local habits
    void emitLocal() {
       final locals = Storage.getHabitsFromCache(); // This is synchronous and fast
       final activeLocals = locals.where((h) => !h.archived);
       
       final habits = activeLocals.map((lh) => _localHabitToHabit(lh)).toList();
       
       habits.sort((a, b) {
          int cmp = a.sortOrder.compareTo(b.sortOrder);
          if (cmp != 0) return cmp;
          return a.createdAt.compareTo(b.createdAt);
       });
       
       if (!controller.isClosed) {
         controller.add(habits);
       }
    }

    // 2. Initial Emit
    emitLocal();
    
    // 3. Listen to LOCAL updates (triggered by toggleCompletion, etc)
    final localSub = _historyUpdateController.stream.listen((_) {
       emitLocal();
    });

    controller.onCancel = () {
       localSub.cancel();
       controller.close();
    };
    
    return controller.stream;
  }

  // Helper to save a Habit snapshot from Firestore into Local Storage (Hive) without creating dirty writes
    // Removed remote snapshot ingestion; we rely on SyncService pull + local cache.

  Future<List<Habit>> getHabits(String userId) async {
    // Prefer Local Cache for one-shot reads too?
    // For now, let's keep getHabits as Remote-Source-of-Truth or switch to Local?
    // Let's match the stream behavior: Return local.
    final locals = Storage.getHabitsFromCache();
    final active = locals.where((h) => !h.archived).map((lh) => _localHabitToHabit(lh)).toList();
     active.sort((a, b) {
      int cmp = a.sortOrder.compareTo(b.sortOrder);
      if (cmp != 0) return cmp;
      return a.createdAt.compareTo(b.createdAt);
    });
    return active;
  }
  
  // Legacy remote fetch (renamed or kept for reference?)
  // keeping original getHabits replacement above.
  
  // Cache for archived habits to avoid repeated fetches

  // Cache for archived habits to avoid repeated fetches
  List<Habit>? _archivedHabitsCache;
  DateTime? _archivedHabitsCacheTime;

  /// Fetches archived habits with caching (one-time read, not a live stream)
  Future<List<Habit>> getArchivedHabits(String userId, {bool forceRefresh = false}) async {
    // Return cache if less than 5 minutes old
    if (!forceRefresh && 
        _archivedHabitsCache != null && 
        _archivedHabitsCacheTime != null &&
        DateTime.now().difference(_archivedHabitsCacheTime!).inMinutes < 5) {
      return _archivedHabitsCache!;
    }
    
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .where('ar', isEqualTo: true) // Server-side filter
        .get();
        
    final habits = snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
    habits.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    _archivedHabitsCache = habits;
    _archivedHabitsCacheTime = DateTime.now();
    
    return habits;
  }

  /// Invalidate archived cache (call after archive/unarchive actions)
  void invalidateArchivedHabitsCache() {
    _archivedHabitsCache = null;
    _archivedHabitsCacheTime = null;
  }

  Stream<List<Habit>> archivedHabitsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .where('ar', isEqualTo: true) // Server-side filter
        .snapshots()
        .map((snapshot) {
          final habits = snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
          habits.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return habits;
        });
  }

  Future<void> unarchiveHabit(String userId, String habitId) async {
    // LOCAL-FIRST: Update local cache immediately
    final local = Storage.getHabitById(habitId);
    if (local != null) {
      local.archived = false;
      local.dirty = true;
      local.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
      await local.save();
      
      // Recalculate streak for UI consistency
      final habit = _localHabitToHabit(local);
      await recalculateStreak(userId, habit);
    }
  }

  Habit _localHabitToHabit(LocalHabit lh) {
    // Rebuild last7 from local history to keep UI/state consistent with recent edits
    final Map<String, double> last7 =
        _decodeJsonMap(lh.last7Json)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {};
    // Ensure history overrides last7 (e.g., when toggling rapidly or setting to 0)
    final resetAtMs = lh.resetAtMs ?? 0;
    for (final entry in Storage.getHabitHistoryFromCache(lh.id)) {
      if (resetAtMs > 0 && entry.updatedAtMs < resetAtMs) {
        continue;
      }
      if (entry.deleted || (entry.value ?? 0) <= 0) {
        last7.remove(entry.dateKey);
      } else {
        last7[entry.dateKey] = entry.value ?? 0.0;
      }
    }

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
      last7: last7,
      archived: lh.archived,
      createdAt: DateTime.fromMillisecondsSinceEpoch(lh.createdAtMs),
      connectedCourseIds: lh.connectedCourseIds,
    );
  }

  Future<void> toggleCompletion({
    required String userId,
    required Habit habit,
    required DateTime date,
    required bool completed,
    double? value,
    bool mondayFirst = true,
  }) async {
    return _writeMutex.protect(() async {
      // Prevent toggling for dates before start date
      final d = DateTime(date.year, date.month, date.day);
      final s = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
      if (d.isBefore(s)) return;

      // RULE: Enforce Period Limits
      if (completed && habit.frequencyType == HabitFrequencyType.repeatsInPeriod) {
         final localHistory = Storage.getHabitHistoryFromCache(habit.id);
         final completionMap = <String, double>{};
         for (final entry in localHistory) {
           if (!entry.deleted && (entry.value ?? 1.0) >= habit.targetValue) {
             completionMap[entry.dateKey] = entry.value ?? 1.0;
           }
         }
         if (habit.isGoalMetForPeriod(completionMap, date, mondayFirst: mondayFirst)) {
            return;
         }
      }

      final dateKey = _dateKey(date);

      // Manual component calculation for time habits
      double? manualComponent;
      if (completed && habit.type == HabitType.time) {
         final dayStart = DateTime(date.year, date.month, date.day);
         final dayEnd = dayStart.add(const Duration(days: 1));
         final secondsMap = await Storage.secondsByCourseBetween(dayStart, dayEnd);
         
         double autoSeconds = 0.0;
         for (var cid in habit.connectedCourseIds) {
            autoSeconds += (secondsMap[cid] ?? 0);
         }
         
         final targetV = value ?? 1.0;
         double m = targetV - autoSeconds;
         if (m < 0) m = 0;
         manualComponent = m;
      }

      // LOCAL-FIRST: Write to Hive cache immediately
      final localHistoryId = '${habit.id}_$dateKey';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      
      if (completed) {
        final localEntry = LocalHabitHistory(
          id: localHistoryId,
          uid: userId,
          habitId: habit.id,
          dateKey: dateKey,
          completedAtMs: d.millisecondsSinceEpoch,
          updatedAtMs: nowMs,
          value: value ?? 1.0,
          manualValue: manualComponent,
          dirty: true,
          deleted: false,
        );
        await Storage.putHabitHistory(localEntry);
      } else {
        final existing = Storage.getHabitHistoryFromCache(habit.id)
            .where((e) => e.dateKey == dateKey)
            .firstOrNull;
        if (existing != null) {
          existing.deleted = true;
          existing.dirty = true;
          existing.updatedAtMs = nowMs;
          await Storage.putHabitHistory(existing);
        } else {
          final tombstone = LocalHabitHistory(
            id: localHistoryId,
            uid: userId,
            habitId: habit.id,
            dateKey: dateKey,
            completedAtMs: d.millisecondsSinceEpoch,
            updatedAtMs: nowMs,
            value: 0,
            manualValue: null,
            dirty: true,
            deleted: true,
          );
          await Storage.putHabitHistory(tombstone);
        }
      }

      // Update streak
      await recalculateStreak(userId, habit, mondayFirst: mondayFirst);
      
      // Update Total Completions and last7
      final localHabit = Storage.getHabitById(habit.id);
      if (localHabit != null) {
         int currentTotal = localHabit.totalCompletions;
         if (completed) {
           currentTotal++;
         } else {
           currentTotal = (currentTotal > 0) ? currentTotal - 1 : 0;
         }
         localHabit.totalCompletions = currentTotal;
         
         final Map<String, dynamic> last7 = localHabit.last7Json.isNotEmpty
             ? jsonDecode(localHabit.last7Json) 
             : {};
         if (completed) {
            last7[dateKey] = value ?? 1.0;
         } else {
            last7.remove(dateKey);
         }
         localHabit.last7Json = jsonEncode(last7);
         
         localHabit.dirty = true;
         localHabit.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
         await localHabit.save();
      }
      
      // Verification logic removed for production
      
      // Notify listeners
      _historyUpdateController.add(null);
    });
  }

  Future<void> createHabit(String userId, Habit habit) async {
    // 1. Determine if updating or creating
    bool isUpdate = habit.id.isNotEmpty && !habit.id.contains('_temp');
    
    // 1. Get current habits to find max sort order if NEW
    int newSortOrder = habit.sortOrder;
    if (!isUpdate) {
      final currentHabits = await getHabits(userId);
      int maxSortOrder = -1;
      if (currentHabits.isNotEmpty) {
        maxSortOrder = currentHabits
            .map((h) => h.sortOrder)
            .reduce((curr, next) => curr > next ? curr : next);
      }
      newSortOrder = maxSortOrder + 1;
    }
    
    // 2. Assign sort order
    final habitWithOrder = habit.copyWith(sortOrder: newSortOrder);

    DocumentReference ref;
    String finalId = habitWithOrder.id;
    if (habitWithOrder.id.isEmpty || habitWithOrder.id.contains('_temp')) {
       ref = _db.collection('users').doc(userId).collection('habits').doc();
       finalId = ref.id;
    } else {
       ref = _db.collection('users').doc(userId).collection('habits').doc(habitWithOrder.id);
    }
    
    final habitWithId = habitWithOrder.copyWith(id: finalId);

    // LOCAL-FIRST: Write to Hive cache immediately
    final localHabit = LocalHabit(
      id: habitWithId.id,
      uid: userId,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      name: habitWithId.name,
      colorValue: habitWithId.color.toARGB32(),
      iconCodePoint: habitWithId.iconCodePoint,
      iconFamily: habitWithId.iconFamily,
      iconPackage: habitWithId.iconPackage,
      category: habitWithId.category,
      typeIndex: habitWithId.type.index,
      targetValue: habitWithId.targetValue,
      unit: habitWithId.unit,
      comparatorIndex: habitWithId.comparator.index,
      frequencyTypeIndex: habitWithId.frequencyType.index,
      weekDays: habitWithId.weekDays.toList(),
      intervalDays: habitWithId.intervalDays,
      frequencyPeriodIndex: habitWithId.frequencyPeriod?.index,
      frequencyGoal: habitWithId.frequencyGoal,
      startDateMs: habitWithId.startDate.millisecondsSinceEpoch,
      endDateMs: habitWithId.endDate?.millisecondsSinceEpoch,
      totalCompletions: habitWithId.totalCompletions,
      currentStreak: habitWithId.currentStreak,
      longestStreak: habitWithId.longestStreak,
      sortOrder: habitWithId.sortOrder,
      last7Json: jsonEncode(habitWithId.last7),
      archived: habitWithId.archived,
      createdAtMs: habitWithId.createdAt.millisecondsSinceEpoch,
      connectedCourseIds: habitWithId.connectedCourseIds,
      dirty: true,
    );
    await Storage.putHabit(localHabit);
    
    await recalculateStreak(userId, habitWithId);
  }

  /// Load history for a month/range
  Future<List<HabitHistoryEntry>> getHistory(
      String userId, String habitId, DateTime start, DateTime end) async {
    
    // Query by ID range (IDs are YYYY-MM-DD strings)
    final startKey = _dateKey(start);
    final endKey = _dateKey(end);

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .collection('history')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
        .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
        .get();

    return snapshot.docs.map((d) => HabitHistoryEntry.fromFirestore(d)).toList();
  }

  Future<void> deleteHabit(String userId, String habitId) async {
    await Storage.removeHabitFromOrder(habitId);

    // LOCAL-FIRST: Mark as deleted in local cache
    final local = Storage.getHabitById(habitId);
    if (local != null) {
      local.deleted = true;
      local.dirty = true;
      local.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
      await local.save();
    }

    // Mark associated history locally as deleted so sync can propagate deletions
    final history = Storage.getHabitHistoryFromCache(habitId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final entry in history) {
      entry.deleted = true;
      entry.dirty = true;
      entry.updatedAtMs = nowMs;
      await Storage.putHabitHistory(entry);
    }

    _historyUpdateController.add(null);
  }

  Future<void> reorderHabits(String userId, int oldIndex, int newIndex) async {
    final habits = Storage.getHabitsFromCache(includeDeleted: false)
        .where((h) => !h.archived)
        .map(_localHabitToHabit)
        .toList();
    if (oldIndex < 0 || oldIndex >= habits.length) return;
    if (newIndex < 0 || newIndex > habits.length) return;
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final updated = List<Habit>.from(habits);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < updated.length; i++) {
      final lh = Storage.getHabitById(updated[i].id);
      if (lh == null) continue;
      lh.sortOrder = i;
      lh.updatedAtMs = nowMs;
      lh.dirty = true;
      await lh.save();
    }

    _historyUpdateController.add(null);
  }

  Future<void> resetHabitProgress(String userId, String habitId) async {
     final nowMs = DateTime.now().millisecondsSinceEpoch;
     final db = LocalDatabase.instance;

     // Clear local history entries (including pending dirty ones).
     final history = Storage.getHabitHistoryFromCache(habitId);
     for (final entry in history) {
       await db.habitHistoryBox.delete(entry.id);
     }

     // Reset habit stats locally
     final habit = Storage.getHabitById(habitId);
     if (habit != null) {
       habit.totalCompletions = 0;
       habit.currentStreak = 0;
       habit.longestStreak = 0;
       habit.last7Json = '{}';
       habit.resetAtMs = nowMs;
       habit.resetPending = true;
       habit.updatedAtMs = nowMs;
       habit.dirty = true;
       await habit.save();
     }

     _historyUpdateController.add(null);
  }

  Future<void> recalculateStreak(String userId, Habit habit, {bool mondayFirst = true}) async {
    // LOCAL-ONLY calculation. No Firestore reads.
    final localHistory = Storage.getHabitHistoryFromCache(habit.id);
    
    // Create a map for fast lookup
    final fullCompletionMap = <String, double>{};
    for (final entry in localHistory) {
      if (!entry.deleted && (entry.value ?? 1.0) >= habit.targetValue) {
        fullCompletionMap[entry.dateKey] = entry.value ?? 1.0;
      }
    }

    int currentStreakValue = 0;
    int longestStreakValue = 0;

    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    
    // Determine Effective Start Date: Earliest of (Habit Start Date, Earliest History)
    // This fixes the issue where backfilled data/started-earlier data wasn't counting towards streaks
    // because the loop strictly stopped at 'startDate'.
    DateTime start = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
    if (fullCompletionMap.isNotEmpty) {
       final sortedKeys = fullCompletionMap.keys.toList()..sort();
       if (sortedKeys.isNotEmpty) {
          final firstKey = sortedKeys.first;
          final parts = firstKey.split('-');
          if (parts.length == 3) {
             final firstDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
             if (firstDate.isBefore(start)) {
                start = firstDate;
             }
          }
       }
    }

    if (habit.frequencyType == HabitFrequencyType.repeatsInPeriod) {
       // --- Period-based Streak ---
       // A streak is defined as consecutive periods where the goal count was met.
       
       // 1. Current Streak (Backwards)
       DateTime pStart = _getPeriodStart(habit, checkDate, mondayFirst: mondayFirst);
       
       // Fix: Ensure we check periods that CONTAIN the effective start date.
       // (pStart of 'Jan 1' is Before 'Jan 5', but the period includes Jan 5, so we must process it).
       // Loop continues as long as the Period END is NOT before the Start Date.
       while (!_getPeriodEnd(habit, pStart).isBefore(start)) {
          final pEnd = _getPeriodEnd(habit, pStart);
          
          // Count usage in this period
          int completions = 0;
          for (final dateKey in fullCompletionMap.keys) {
             final parts = dateKey.split('-');
             if (parts.length != 3) continue;
             // Using effective start date logic implicitly by just checking pStart/pEnd bounds
             final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
             
             if (!d.isBefore(pStart) && !d.isAfter(pEnd)) {
                if ((fullCompletionMap[dateKey] ?? 0.0) >= habit.targetValue) {
                  completions++; 
                }
             }
          }
          
          final bool met = completions >= (habit.frequencyGoal ?? 1);
          final bool isCurrentPeriod = !checkDate.isBefore(pStart) && !checkDate.isAfter(pEnd);
          
          if (met) {
             currentStreakValue++;
          } else {
             // Not met
             if (isCurrentPeriod) {
                // Current period In-Progress: doesn't break streak, but doesn't add to it (unless met)
             } else {
                // Past failed period -> Break Streak
                break;
             }
          }
          
          pStart = _subtractPeriod(habit, pStart);
       }
       
       // 2. Longest Streak (Forward)
       // Iterate periods forward from start
       int tempStreak = 0;
       pStart = _getPeriodStart(habit, start, mondayFirst: mondayFirst); // Start from effective start's period
       
       // We need to iterate until checkDate (Current Period)
       while (!pStart.isAfter(checkDate)) {
           final pEnd = _getPeriodEnd(habit, pStart);
           
           int completions = 0;
           for (final dateKey in fullCompletionMap.keys) {
               final parts = dateKey.split('-');
               if (parts.length != 3) continue;
               final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
               if (!d.isBefore(pStart) && !d.isAfter(pEnd)) {
                  if ((fullCompletionMap[dateKey] ?? 0.0) >= habit.targetValue) {
                     completions++;
                  }
               }
           }
           
           if (completions >= (habit.frequencyGoal ?? 1)) {
              tempStreak++;
              if (tempStreak > longestStreakValue) longestStreakValue = tempStreak;
           } else {
              tempStreak = 0;
           }
           pStart = _addPeriod(habit, pStart);
       }

    } else {
       // --- Day-based Streak (Daily or Specific Days) ---
       
       // 1. Current Streak
       DateTime walker = checkDate;
       while (!walker.isBefore(start)) {
          final isScheduled = habit.isScheduledFor(walker);
          if (isScheduled) {
             final dateKey = _dateKey(walker);
             final isDone = fullCompletionMap.containsKey(dateKey);
             
             if (isDone) {
                currentStreakValue++;
             } else {
                // Not done
                final isToday = walker.year == checkDate.year && walker.month == checkDate.month && walker.day == checkDate.day;
                if (isToday) {
                   // Today not done yet? Streak continues from yesterday. Don't break.
                } else {
                   // Past scheduled day missed -> Break
                   break;
                }
             }
          }
          walker = walker.subtract(const Duration(days: 1));
       }
       
       // 2. Longest Streak
       int tempStreak = 0;
       walker = start;
       while (!walker.isAfter(checkDate)) {
           final isScheduled = habit.isScheduledFor(walker);
           if (isScheduled) {
               final dateKey = _dateKey(walker);
               if (fullCompletionMap.containsKey(dateKey)) {
                   tempStreak++;
                   if (tempStreak > longestStreakValue) longestStreakValue = tempStreak;
               } else {
                   tempStreak = 0; 
               }
           }
           walker = walker.add(const Duration(days: 1));
       }
    }
    
    await _updateStreaks(userId, habit.id, currentStreakValue, longestStreakValue);
  }

  DateTime _getPeriodStart(Habit habit, DateTime date, {bool mondayFirst = true}) {
    switch (habit.frequencyPeriod) {
      case HabitPeriod.week:
        final offset = mondayFirst ? (date.weekday - 1) : (date.weekday % 7);
        return DateTime(date.year, date.month, date.day - offset);
      case HabitPeriod.month:
        return DateTime(date.year, date.month, 1);
      case HabitPeriod.year:
        return DateTime(date.year, 1, 1);
      default:
        return date;
    }
  }

  DateTime _getPeriodEnd(Habit habit, DateTime date, {bool mondayFirst = true}) {
    final start = _getPeriodStart(habit, date, mondayFirst: mondayFirst);
    switch (habit.frequencyPeriod) {
      case HabitPeriod.week:
        return start.add(const Duration(days: 6));
      case HabitPeriod.month:
        return DateTime(start.year, start.month + 1, 0);
      case HabitPeriod.year:
        return DateTime(start.year, 12, 31);
      default:
        return date;
    }
  }

  DateTime _addPeriod(Habit habit, DateTime date) {
    switch (habit.frequencyPeriod) {
      case HabitPeriod.week:
        return date.add(const Duration(days: 7));
      case HabitPeriod.month:
        return DateTime(date.year, date.month + 1, 1);
      case HabitPeriod.year:
        return DateTime(date.year + 1, 1, 1);
      default:
        return date.add(const Duration(days: 1));
    }
  }

  DateTime _subtractPeriod(Habit habit, DateTime date) {
    switch (habit.frequencyPeriod) {
      case HabitPeriod.week:
        return date.subtract(const Duration(days: 7));
      case HabitPeriod.month:
        return DateTime(date.year, date.month - 1, 1);
      case HabitPeriod.year:
        return DateTime(date.year - 1, 1, 1);
      default:
        return date.subtract(const Duration(days: 1));
    }
  }


  Future<void> _updateStreaks(String userId, String habitId, int current, int longest) async {
    // LOCAL-FIRST: Update Hive immediately for instant UI feedback
    final local = Storage.getHabitById(habitId);
    if (local != null) {
       local.currentStreak = current;
       local.longestStreak = longest;
       local.dirty = true;
       local.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
       await local.save();
    }
    
    // Remote update in background (fire-and-forget)
    unawaited(_syncStreaksToFirebase(userId, habitId, current, longest));
    
    // Notify listeners
    _historyUpdateController.add(null);
  }

  Future<void> _syncStreaksToFirebase(String userId, String habitId, int current, int longest) async {
    // DISABLING direct remote overwrite.
    // SyncService will handle syncing the 'Habit' which contains these stats.
    // This function previously risked overwriting local with partial data or causing race conditions.
    return;
  }

  Future<void> updateHistory(String userId, String habitId, DateTime date, double value) async {
    final dateKey = _dateKey(date);
    
    // LOCAL-FIRST: Update local cache immediately
    final localHistoryId = '${habitId}_$dateKey';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final d = DateTime(date.year, date.month, date.day);

    if (value > 0) {
      // Get existing entry to increment version
      final existing = Storage.getHabitHistoryFromCache(habitId)
          .where((e) => e.dateKey == dateKey)
          .firstOrNull;
      final newVersion = (existing?.version ?? 0) + 1;
      
      final localEntry = LocalHabitHistory(
          id: localHistoryId,
          uid: userId,
          habitId: habitId,
          dateKey: dateKey,
          completedAtMs: d.millisecondsSinceEpoch,
          updatedAtMs: nowMs,
          value: value,
          dirty: true,
          deleted: false,
          version: newVersion,
      );
      await Storage.putHabitHistory(localEntry);
    } else {
        // Mark as deleted in local cache
        final existing = Storage.getHabitHistoryFromCache(habitId)
            .where((e) => e.dateKey == dateKey)
            .firstOrNull;
        if (existing != null) {
            existing.deleted = true;
            existing.dirty = true;
            existing.updatedAtMs = nowMs;
            existing.version = existing.version + 1;
            await Storage.putHabitHistory(existing);
        }
    }

    // Need habit object for streak recalc
    // We can fetch from local storage for speed
    final localHabit = Storage.getHabitById(habitId);
    if (localHabit != null) {
       final habit = _localHabitToHabit(localHabit);
       await recalculateStreak(userId, habit);
    }

    _historyUpdateController.add(null);
  }

  Future<void> updateHabitProgressFromCourse({
    required String userId, 
    required String courseId, 
    required DateTime date,
    required int deltaSeconds
  }) async {
    if (deltaSeconds == 0) return;

    final allHabits = Storage.getHabitsFromCache(includeDeleted: false)
        .where((h) => !h.archived && h.connectedCourseIds.contains(courseId))
        .map(_localHabitToHabit)
        .toList();
    final relevantHabits = allHabits;

    for (var habit in relevantHabits) {
      // 1. Check start date
      final targetDate = DateTime(date.year, date.month, date.day);
      final start = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
      if (targetDate.isBefore(start)) continue; 
      if (habit.endDate != null) {
        final end = DateTime(habit.endDate!.year, habit.endDate!.month, habit.endDate!.day);
        if (targetDate.isAfter(end)) continue;
      }

      // Respect the schedule to avoid logging on rest days
      if (!habit.isScheduledFor(targetDate)) continue;

      // 2. Check type logic
      // Time habits are now handled by syncTimeHabitsForCourse (recalculation-based)
      // This method only handles YesNo habits for auto-completion on session activity
      if (habit.type != HabitType.yesNo) continue; 

      final dateKey = _dateKey(targetDate);
      final historyEntries = Storage.getHabitHistoryFromCache(habit.id);
      final existing = historyEntries
          .where((e) => e.dateKey == dateKey)
          .firstOrNull;
      final currentVal = existing != null && !existing.deleted
          ? (existing.value ?? 0.0)
          : 0.0;

      // For YesNo, any session means "Done" (1.0).
      // If already done, skip.
      if (currentVal >= habit.targetValue) {
        continue;
      }
      final newVal = habit.targetValue; // Mark as done

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final entry = existing ??
          LocalHabitHistory(
            id: '${habit.id}_$dateKey',
            uid: userId,
            habitId: habit.id,
            dateKey: dateKey,
            completedAtMs: targetDate.millisecondsSinceEpoch,
            updatedAtMs: nowMs,
            value: newVal,
            dirty: true,
            deleted: false,
          );
      entry
        ..completedAtMs = targetDate.millisecondsSinceEpoch
        ..updatedAtMs = nowMs
        ..value = newVal
        ..deleted = false
        ..dirty = true;
      await Storage.putHabitHistory(entry);

      final lh = Storage.getHabitById(habit.id);
      if (lh != null) {
        final wasMet = currentVal >= habit.targetValue;
        if (!wasMet && newVal >= habit.targetValue) {
          lh.totalCompletions = lh.totalCompletions + 1;
        }
        final last7 =
            lh.last7Json.isNotEmpty ? _decodeJsonMap(lh.last7Json) ?? {} : {};
        last7[dateKey] = newVal;
        lh.last7Json = jsonEncode(last7);
        lh.updatedAtMs = nowMs;
        lh.dirty = true;
        await lh.save();
      }

      await recalculateStreak(userId, habit); // keep streak in sync locally
    }

    _historyUpdateController.add(null);
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> checkAndRevertHabitCompletion(String userId, String courseId, DateTime date) async {
    // 1. Get all relevant habits
    final habits = await getHabits(userId);
    final relevant = habits.where((h) => 
       !h.archived && 
       h.type == HabitType.yesNo && 
       h.connectedCourseIds.contains(courseId)
    );

    for (var habit in relevant) {
       final dateKey = _dateKey(date);
       // 2. Check if currently completed in local cache
       final history = Storage.getHabitHistoryFromCache(habit.id)
           .where((e) => e.dateKey == dateKey && !e.deleted && (e.value ?? 0) > 0)
           .firstOrNull;
       if (history == null) continue; // Not completed, nothing to revert

       // 3. Check if ANY connected course has sessions on this day
       bool hasActivity = false;
       final dayStart = DateTime(date.year, date.month, date.day);
       final dayEnd = dayStart.add(const Duration(days: 1));
       
       // We check ALL connected sessions, not just the one deleted.
       final secondsMap = await Storage.secondsByCourseBetween(dayStart, dayEnd);
       
       for (var cId in habit.connectedCourseIds) {
          if (secondsMap.containsKey(cId) && (secondsMap[cId] ?? 0) > 0) {
             hasActivity = true;
             break;
          }
       }
       
       if (!hasActivity) {
          // 4. Revert completion
          await toggleCompletion(
            userId: userId, 
            habit: habit, 
            date: date, 
            completed: false
          );
       }
    }
  }

  Future<void> syncTimeHabitsForCourse(String userId, String courseId, DateTime date, {double? knownDelta}) async {
    final habits = await getHabits(userId);
    final connected = habits.where((h) => 
      !h.archived && 
      h.type == HabitType.time && 
      h.connectedCourseIds.contains(courseId)
    );
    
    for (var habit in connected) {
      if (habit.isScheduledFor(date)) {
        await syncTimeHabitProgress(userId, habit, date, knownDelta: knownDelta);
      }
    }
  }

  Future<void> syncTimeHabitProgress(String userId, Habit habit, DateTime date, {double? knownDelta}) async {
    if (habit.type != HabitType.time) return;

    final dateKey = _dateKey(date);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // v = Total, m = Manual
    final historyEntries = Storage.getHabitHistoryFromCache(habit.id);
    final existing = historyEntries
        .where((e) => e.dateKey == dateKey)
        .firstOrNull;
    double v = existing?.value ?? 0.0;
    double? m = existing?.manualValue;

    // 2. Calculate Session Total (S)
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final secondsMap = await Storage.secondsByCourseBetween(dayStart, dayEnd);

    double autoSeconds = 0.0;
    for (var cid in habit.connectedCourseIds) {
      autoSeconds += (secondsMap[cid] ?? 0);
    }

    // 3. Logic to determine m if missing (Migration)
    if (m == null) {
      if (autoSeconds > 0 || (knownDelta != null && knownDelta != 0)) {
        // We deduce what S WAS before this change to know how much of v was manual.
        final sOld = autoSeconds - (knownDelta ?? 0.0);
        // m = v - sOld
        m = v - sOld;
        if (m < 0) m = 0; // Safety
      } else {
        // No info, assume v is mostly manual relative to current auto
        m = v - autoSeconds;
        if (m < 0) m = 0;
      }
    }

    // 4. Calculate New Total
    final double mValue = m;
    final newTotal = mValue + autoSeconds;

    // 5. Update local history
    if (newTotal > 0) {
      final entry = existing ??
          LocalHabitHistory(
            id: '${habit.id}_$dateKey',
            uid: userId,
            habitId: habit.id,
            dateKey: dateKey,
            completedAtMs: dayStart.millisecondsSinceEpoch,
            updatedAtMs: nowMs,
            value: newTotal,
            manualValue: mValue,
            dirty: true,
            deleted: false,
          );
      entry
        ..completedAtMs = dayStart.millisecondsSinceEpoch
        ..updatedAtMs = nowMs
        ..value = newTotal
        ..manualValue = mValue
        ..deleted = false
        ..dirty = true;
      await Storage.putHabitHistory(entry);
    } else if (existing != null) {
      existing.deleted = true;
      existing.dirty = true;
      existing.updatedAtMs = nowMs;
      await Storage.putHabitHistory(existing);
    }

    // Update stats locally
    final lh = Storage.getHabitById(habit.id);
    if (lh != null) {
      final isCompletedBefore = v >= habit.targetValue;
      final isNowMet = newTotal >= habit.targetValue;
      if (isNowMet && !isCompletedBefore) {
        lh.totalCompletions = lh.totalCompletions + 1;
      } else if (!isNowMet && isCompletedBefore) {
        lh.totalCompletions =
            lh.totalCompletions > 0 ? lh.totalCompletions - 1 : 0;
      }
      final last7 =
          lh.last7Json.isNotEmpty ? _decodeJsonMap(lh.last7Json) ?? {} : {};
      if (newTotal > 0) {
        last7[dateKey] = newTotal;
      } else {
        last7.remove(dateKey);
      }
      lh.last7Json = jsonEncode(last7);
      lh.updatedAtMs = nowMs;
      lh.dirty = true;
      await lh.save();
    }

    await recalculateStreak(userId, habit);
    _historyUpdateController.add(null);
  }

  Map<String, dynamic>? _decodeJsonMap(String json) {
    if (json.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(json) as Map);
    } catch (_) {
      return null;
    }
  }
}

class _Mutex {
  Future<void> _last = Future.value();
  
  Future<T> protect<T>(Future<T> Function() block) async {
    final previous = _last;
    final completer = Completer<void>();
    _last = completer.future;

    try {
       await previous;
    } catch (_) {
       // Ignore previous errors
    }

    try {
      return await block();
    } finally {
      completer.complete();
    }
  }
}
