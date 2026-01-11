import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habit.dart';
import '../models/habit_category.dart';
import 'storage.dart';

class HabitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Stream<List<Habit>> habitsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .snapshots()
        .map((snapshot) {
          final habits = snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
          // Filter archived client-side to handle both simplified 'ar' field and legacy 'archived'
          final active = habits.where((h) => !h.archived).toList();
          
          active.sort((a, b) {
            int cmp = a.sortOrder.compareTo(b.sortOrder);
            if (cmp != 0) return cmp;
            return a.createdAt.compareTo(b.createdAt);
          });
          return active;
        });
  }

  Future<List<Habit>> getHabits(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .get();
        
    final habits = snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
    final active = habits.where((h) => !h.archived).toList();
    
    active.sort((a, b) {
      int cmp = a.sortOrder.compareTo(b.sortOrder);
      if (cmp != 0) return cmp;
      return a.createdAt.compareTo(b.createdAt);
    });
    return active;
  }

  Stream<List<Habit>> archivedHabitsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .snapshots()
        .map((snapshot) {
          final habits = snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
          final archived = habits.where((h) => h.archived).toList();
          archived.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return archived;
        });
  }

  Future<void> unarchiveHabit(String userId, String habitId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .update({
          'archived': FieldValue.delete(), // Remove legacy
          'ar': FieldValue.delete(),       // Remove new (omitted = false)
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
    
    final data = habitWithOrder.toFirestore();
    
    await ref.set(data);
    
    // Use the correctly identified ID for streak calculation
    final habitWithId = habitWithOrder.copyWith(id: finalId);
    await recalculateStreak(userId, habitWithId);
  }

  Future<void> toggleCompletion({
    required String userId,
    required Habit habit,
    required DateTime date,
    required bool completed,
    double? value,
  }) async {
    final dateKey = _dateKey(date);
    final habitRef = _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habit.id);
    final historyRef = habitRef.collection('history').doc(dateKey);

    // If Time habit manual update (setting a value), we need to calculate 'm' (manual component).
    double? manualComponent;
    if (completed && habit.type == HabitType.time) {
       // We need to know current Session Total (S) to deduce Manual (m = v - S)
       // We can't do this inside transaction easily if using Storage (hive) + Firestore.
       // So we fetch Storage data OUTSIDE.
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

    await _db.runTransaction((transaction) async {
      final habitSnap = await transaction.get(habitRef);
      if (!habitSnap.exists) throw Exception("Habit not found");
      final habitData = habitSnap.data() ?? {};

      // 1. Update History
      if (completed) {
        final data = {
          'ts': Timestamp.fromDate(DateTime(date.year, date.month, date.day)), 
          'updatedAt': FieldValue.serverTimestamp(),
          'v': value ?? 1.0, 
        };
        if (manualComponent != null) {
           data['m'] = manualComponent;
        }
        transaction.set(historyRef, data, SetOptions(merge: true));
      } else {
        transaction.delete(historyRef);
      }

      // 2. Update Stats
      final statsMap = (habitData['st'] ?? habitData['stats'] ?? {}) as Map<String, dynamic>;
      int total = statsMap['tc'] ?? statsMap['totalCompletions'] ?? 0;
      
      final l7Map = (habitData['l7'] ?? habitData['last7'] ?? {}) as Map<String, dynamic>;
      // Refined logic:
      final double oldVal = (l7Map[dateKey] as num?)?.toDouble() ?? 0.0;
      final bool wasMet = oldVal >= habit.targetValue;
      final bool nowMet = completed && (value ?? 1.0) >= habit.targetValue;

      if (nowMet && !wasMet) {
        total++;
      } else if (!nowMet && wasMet) {
        total = (total > 0) ? total - 1 : 0;
      }

      // 3. Robust Update for l7
      final hasL7Container = habitData.containsKey('l7');
      
      final updates = <String, dynamic>{
        'st.tc': total, 
      };
      
      // We want to show partial progress in UI, so update l7 if value > 0
      final double effectiveValue = value ?? ((habit.type == HabitType.yesNo) ? 1.0 : 0.0);
      final shouldShowInL7 = completed && effectiveValue > 0;
      
      if (shouldShowInL7) {
         if (hasL7Container) {
            updates['l7.$dateKey'] = (value ?? 1.0);
         } else {
            updates['l7'] = { dateKey: (value ?? 1.0) };
         }
      } else {
         if (hasL7Container) {
            updates['l7.$dateKey'] = FieldValue.delete();
         }
      }
      
      transaction.update(habitRef, updates);
    });

    await recalculateStreak(userId, habit);
    _historyUpdateController.add(null);
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

    final habitRef = _db.collection('users').doc(userId).collection('habits').doc(habitId);
    
    final historySnap = await habitRef.collection('history').get();
    if (historySnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (var doc in historySnap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    
    await habitRef.delete();
    _historyUpdateController.add(null);
  }

  Future<void> reorderHabits(String userId, int oldIndex, int newIndex) async {
    final habits = await getHabits(userId);
    if (oldIndex < 0 || oldIndex >= habits.length) return;
    if (newIndex < 0 || newIndex > habits.length) return;
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final updated = List<Habit>.from(habits);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    
    final batch = _db.batch();
    for (var i = 0; i < updated.length; i++) {
      final ref = _db.collection('users').doc(userId).collection('habits').doc(updated[i].id);
      batch.update(ref, {'so': i}); // New key 'so'
    }
    await batch.commit();
  }

  Future<void> resetHabitProgress(String userId, String habitId) async {
     final habitRef = _db.collection('users').doc(userId).collection('habits').doc(habitId);
     
     // 1. Delete all history docs (Chunked Batching)
     final historySnap = await habitRef.collection('history').get();
     final docs = historySnap.docs;

     // Firestore batch limit is 500 operations
     for (var i = 0; i < docs.length; i += 500) {
        final batch = _db.batch();
        final end = (i + 500 < docs.length) ? i + 500 : docs.length;
        for (var j = i; j < end; j++) {
           batch.delete(docs[j].reference);
        }
        await batch.commit();
     }
     
     // 2. Reset Stats
     // We invoke 'l7': {} to initialize the map, preventing "missing field" errors on future updates.
     await habitRef.update({
        'st': {
           'tc': 0,
           'cs': 0,
           'ls': 0,
        },
        'l7': {}, // Initialize empty map
        'last7': FieldValue.delete(), // Remove legacy
     });
     _historyUpdateController.add(null);
  }

  Future<void> recalculateStreak(String userId, Habit habit) async {
    // Fetch ALL history. Sort in memory.
    final historySnap = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habit.id)
        .collection('history')
        .get();

    final historyDocs = historySnap.docs;
    
    // Sort descending by ID (YYYY-MM-DD)
    historyDocs.sort((a, b) => b.id.compareTo(a.id));

    final historyDates = historyDocs.where((doc) {
       final data = doc.data();
       final val = (data['v'] ?? data['value'] as num?)?.toDouble() ?? 0.0;
       return val >= habit.targetValue;
    }).map((doc) {
       final parts = doc.id.split('-');
       if (parts.length == 3) {
         return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
       }
       return DateTime.now();
    }).toSet();

    final fullCompletionMap = historyDocs.fold<Map<String, double>>({}, (map, doc) {
      final data = doc.data();
      map[doc.id] = (data['v'] ?? data['value'] as num?)?.toDouble() ?? 0.0;
      return map;
    });

    int currentStreakValue = 0;
    int longestStreakValue = 0;

    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    final start = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);

    if (habit.frequencyType == HabitFrequencyType.repeatsInPeriod) {
       // --- Period-based Streak (count DAYS, not periods) ---
       DateTime currentPeriodCheck = _getPeriodStart(habit, checkDate);

       // 1. Current Streak (Backwards)
       while (!_getPeriodEnd(habit, currentPeriodCheck).isBefore(start)) {
          final pStart = currentPeriodCheck;
          final pEnd = _getPeriodEnd(habit, pStart);
          final isCurrent = !checkDate.isBefore(pStart) && !checkDate.isAfter(pEnd);
          
          // Count only valid completed days in this period
          int completed = 0;
          for (final dateKey in fullCompletionMap.keys) {
             final parts = dateKey.split('-');
             if (parts.length != 3) continue;
             final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
             
             // Must be within period AND NOT before habit start
             if (!d.isBefore(pStart) && !d.isAfter(pEnd) && !d.isBefore(start)) {
                if ((fullCompletionMap[dateKey] ?? 0.0) >= habit.targetValue) {
                   completed++;
                }
             }
          }
          
          final bool met = completed >= (habit.frequencyGoal ?? 1);
          
          if (isCurrent) {
             // Current active period: always add progress so far
             currentStreakValue += completed;
          } else {
             // Past period: only add if goal was met
             if (met) {
                currentStreakValue += completed;
             } else {
                break; // Streak broken
             }
          }
          currentPeriodCheck = _subtractPeriod(habit, currentPeriodCheck);
       }

       // 2. Longest Streak (Forwards)
       int tempStreak = 0;
       DateTime forwardPeriodCheck = _getPeriodStart(habit, start);
       while (!_getPeriodEnd(habit, forwardPeriodCheck).isBefore(start) && !forwardPeriodCheck.isAfter(checkDate)) {
          final pStart = forwardPeriodCheck;
          final pEnd = _getPeriodEnd(habit, pStart);
          final isCurrent = !checkDate.isBefore(pStart) && !checkDate.isAfter(pEnd);
          
          int completed = 0;
          for (final dateKey in fullCompletionMap.keys) {
             final parts = dateKey.split('-');
             if (parts.length != 3) continue;
             final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
             if (!d.isBefore(pStart) && !d.isAfter(pEnd) && !d.isBefore(start)) {
                if ((fullCompletionMap[dateKey] ?? 0.0) >= habit.targetValue) {
                   completed++;
                }
             }
          }
          
          final bool met = completed >= (habit.frequencyGoal ?? 1);
          
          if (met || isCurrent) {
             tempStreak += completed;
             if (tempStreak > longestStreakValue) longestStreakValue = tempStreak;
          } else {
             tempStreak = 0;
          }
          forwardPeriodCheck = _addPeriod(habit, forwardPeriodCheck);
       }
    } else {
       // --- Day-based Streak ---
       int tempStreak = 0;
       DateTime currentCheck = checkDate;
       
       while (!currentCheck.isBefore(start)) {
          final isScheduled = habit.isScheduledFor(currentCheck);
          if (isScheduled) {
            final isCompleted = historyDates.contains(currentCheck);
            if (isCompleted) {
              currentStreakValue++;
            } else {
              final isToday = currentCheck.year == DateTime.now().year &&
                  currentCheck.month == DateTime.now().month &&
                  currentCheck.day == DateTime.now().day;
              if (!isToday) break;
            }
          }
          currentCheck = currentCheck.subtract(const Duration(days: 1));
       }

       DateTime longCheck = start;
       while (!longCheck.isAfter(checkDate)) {
          final isScheduled = habit.isScheduledFor(longCheck);
          if (isScheduled) {
             if (historyDates.contains(longCheck)) {
                tempStreak++;
                if (tempStreak > longestStreakValue) longestStreakValue = tempStreak;
             } else {
                tempStreak = 0;
             }
          }
          longCheck = longCheck.add(const Duration(days: 1));
       }
    }
    
    await _updateStreaks(userId, habit.id, currentStreakValue, longestStreakValue);
  }

  DateTime _getPeriodStart(Habit habit, DateTime date) {
    switch (habit.frequencyPeriod) {
      case HabitPeriod.week:
        return DateTime(date.year, date.month, date.day - (date.weekday - 1));
      case HabitPeriod.month:
        return DateTime(date.year, date.month, 1);
      case HabitPeriod.year:
        return DateTime(date.year, 1, 1);
      default:
        return date;
    }
  }

  DateTime _getPeriodEnd(Habit habit, DateTime date) {
    final start = _getPeriodStart(habit, date);
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
    await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .update({
          'st.cs': current,
          'st.ls': longest,
        });
    _historyUpdateController.add(null);
  }

  Future<void> updateHistory(String userId, String habitId, DateTime date, double value) async {
    final dateKey = _dateKey(date);
    final historyRef = _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .collection('history')
        .doc(dateKey);

    if (value > 0) {
      await historyRef.set({
        'ts': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'updatedAt': FieldValue.serverTimestamp(),
        'v': value,
      }, SetOptions(merge: true));
    } else {
      await historyRef.delete();
    }
    
    // Recalculate streak after history change
    try {
      final habitSnap = await _db
          .collection('users')
          .doc(userId)
          .collection('habits')
          .doc(habitId)
          .get();
      if (habitSnap.exists) {
        final habit = Habit.fromFirestore(habitSnap);
        await recalculateStreak(userId, habit);
      }
    } catch (_) {}

    _historyUpdateController.add(null);
  }

  Future<void> updateHabitProgressFromCourse({
    required String userId, 
    required String courseId, 
    required DateTime date,
    required int deltaSeconds
  }) async {
    if (deltaSeconds == 0) return;

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .get();

    final allHabits = snapshot.docs.map((d) => Habit.fromFirestore(d));
    final relevantHabits = allHabits.where((h) => 
       !h.archived && h.connectedCourseIds.contains(courseId)
    ).toList();

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
      final habitRef = _db.collection('users').doc(userId).collection('habits').doc(habit.id);
      final historyRef = habitRef.collection('history').doc(dateKey);

      await _db.runTransaction((transaction) async {
        final habitSnap = await transaction.get(habitRef);
        final historySnap = await transaction.get(historyRef);
        
        final habitData = habitSnap.data() ?? {};
        final historyData = historySnap.data() ?? {};

        double currentVal = (historyData['v'] ?? historyData['value'] as num?)?.toDouble() ?? 0.0;
        
        // For YesNo, any session means "Done" (1.0). 
        // If already done, we leave it. If not, we set it to target (usually 1.0).
        if (currentVal >= habit.targetValue) {
          // Already completed, do nothing
          return; 
        }
        final newVal = habit.targetValue; // Mark as done

        if (newVal > 0) {
          transaction.set(historyRef, {
            'ts': Timestamp.fromDate(targetDate), 
            't': FieldValue.serverTimestamp(), 
            'v': newVal, 
          }, SetOptions(merge: true));
        } else {
           transaction.delete(historyRef);
        }

        final statsMap = (habitData['st'] ?? habitData['stats'] ?? {}) as Map<String, dynamic>;
        int total = statsMap['tc'] ?? statsMap['totalCompletions'] ?? 0;
        
        final isCompletedBefore = currentVal >= habit.targetValue;
        // Re-evaluate completion status based on NEW value vs target
        final bool isNowMet = newVal >= habit.targetValue;
        
        if (isNowMet && !isCompletedBefore) {
          total++;
        } else if (!isNowMet && isCompletedBefore) {
          total = (total > 0) ? total - 1 : 0;
        }

        final last7Key = 'l7.$dateKey';
        
        transaction.update(habitRef, {
          'st.tc': total,
          last7Key: newVal > 0 ? newVal : FieldValue.delete(),
        });
      });
      
      await recalculateStreak(userId, habit);
    }
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
       // 2. Check if currently completed
       // We need to fetch the history for this specific habit and day to be sure.
       // Or simpler: check if 'v' > 0 in history.
       final historyRef = _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habit.id)
        .collection('history')
        .doc(dateKey);
       
       final historySnap = await historyRef.get();
       if (!historySnap.exists) continue; // Not completed, nothing to revert

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
    final habitRef = _db.collection('users').doc(userId).collection('habits').doc(habit.id);
    final historyRef = habitRef.collection('history').doc(dateKey);

    await _db.runTransaction((transaction) async {
       // 1. Get current stats
       final habitSnap = await transaction.get(habitRef);
       final historySnap = await transaction.get(historyRef);
       
       final habitData = habitSnap.data() ?? {};
       final historyData = historySnap.data() ?? {};
       
       // v = Total, m = Manual
       double v = (historyData['v'] ?? historyData['value'] as num?)?.toDouble() ?? 0.0;
       double? m = (historyData['m'] as num?)?.toDouble();
       
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
       double newTotal = m + autoSeconds;
       
       // 5. Update
        if (newTotal > 0) {
          transaction.set(historyRef, {
            'ts': Timestamp.fromDate(date), 
            't': FieldValue.serverTimestamp(), 
            'v': newTotal,
            'm': m, 
          }, SetOptions(merge: true));
        } else {
           transaction.delete(historyRef);
        }

        final statsMap = (habitData['st'] ?? habitData['stats'] ?? {}) as Map<String, dynamic>;
        int total = statsMap['tc'] ?? statsMap['totalCompletions'] ?? 0;
        
        final isCompletedBefore = v >= habit.targetValue;
        final isNowMet = newTotal >= habit.targetValue;
        
        if (isNowMet && !isCompletedBefore) {
          total++;
        } else if (!isNowMet && isCompletedBefore) {
          total = (total > 0) ? total - 1 : 0;
        }

        final last7Key = 'l7.$dateKey';
        if (newTotal > 0) {
           transaction.update(habitRef, {
            'st.tc': total,
            last7Key: newTotal,
           });
        } else {
           transaction.update(habitRef, {
            'st.tc': total,
            last7Key: FieldValue.delete(),
           });
        }
    });

    await recalculateStreak(userId, habit);
    _historyUpdateController.add(null);
  }
}
