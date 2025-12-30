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
    DocumentReference ref;
    if (habit.id.isEmpty || habit.id.contains('_temp')) {
       ref = _db.collection('users').doc(userId).collection('habits').doc();
    } else {
       ref = _db.collection('users').doc(userId).collection('habits').doc(habit.id);
    }
    
    final data = habit.toFirestore();
    
    await ref.set(data);
    
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

    await _db.runTransaction((transaction) async {
      final habitSnap = await transaction.get(habitRef);
      if (!habitSnap.exists) throw Exception("Habit not found");
      final habitData = habitSnap.data() ?? {};

      // 1. Update History
      if (completed) {
        transaction.set(historyRef, {
          'ts': Timestamp.fromDate(DateTime(date.year, date.month, date.day)), 
          't': FieldValue.serverTimestamp(),
          'v': value ?? 1, 
        });
      } else {
        transaction.delete(historyRef);
      }

      // 2. Update Stats
      final statsMap = (habitData['st'] ?? habitData['stats'] ?? {}) as Map<String, dynamic>;
      int total = statsMap['tc'] ?? statsMap['totalCompletions'] ?? 0;
      
      final l7Map = (habitData['l7'] ?? habitData['last7'] ?? {}) as Map<String, dynamic>;
      final alreadyCompleted = l7Map.containsKey(dateKey);

      if (completed && !alreadyCompleted) {
        total++;
      } else if (!completed && alreadyCompleted) {
        total = (total > 0) ? total - 1 : 0;
      }

      // 3. Robust Update for l7
      // If l7 is missing (e.g. after reset or migration), we can't use dot notation ('l7.dateKey').
      // We must check if the map exists in the document snapshot.
      final hasL7Container = habitData.containsKey('l7');
      
      final updates = <String, dynamic>{
        'st.tc': total, // 'st' might also be missing if legacy, but 'st.tc' auto-creates map.
      };
      
      if (completed) {
         if (hasL7Container) {
            updates['l7.$dateKey'] = (value ?? 1.0);
         } else {
            // "l7" doesn't exist, we must create it.
            // NOTE: We cannot mix 'l7.key' and 'l7' in same update if logic was complex, 
            // but here we just write the whole map if it's missing.
            // CAUTION: If we write 'l7': { dateKey: val }, we might overwrite if concurrency?
            // Transaction protects us. 'habitData' is fresh. 
            // If 'l7' is missing in 'habitData', it is really missing.
            
            // However, if we migrated from 'last7' but 'l7' is missing...
            // We should ideally copy 'last7' to 'l7' or just start fresh 'l7'.
            // For compacting, we just start fresh 'l7'. 
            updates['l7'] = { dateKey: (value ?? 1.0) };
         }
      } else {
         // Unchecking
         if (hasL7Container) {
            updates['l7.$dateKey'] = FieldValue.delete();
         }
         // If l7 missing, nothing to delete.
      }
      
      transaction.update(habitRef, updates);
    });

    await recalculateStreak(userId, habit);
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

  Future<void> resetStreak(String userId, String habitId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .update({'st.cs': 0});
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
    int tempStreak = 0;

    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    
    final start = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
    
    DateTime currentCheck = checkDate;
    while (!currentCheck.isBefore(start)) {
       final isScheduled = _isDayScheduledForStreak(habit, currentCheck, fullCompletionMap);
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
       final isScheduled = _isDayScheduledForStreak(habit, longCheck, fullCompletionMap);
       if (isScheduled) {
          if (historyDates.contains(longCheck)) {
             tempStreak++;
             if (tempStreak > longestStreakValue) longestStreakValue = tempStreak;
          } else {
             if (habit.frequencyType == HabitFrequencyType.repeatsInPeriod) {
                if (_isLastDayOfPeriod(habit, longCheck)) {
                   tempStreak = 0;
                }
             } else {
                tempStreak = 0;
             }
          }
       }
       longCheck = longCheck.add(const Duration(days: 1));
    }
    
    await _updateStreaks(userId, habit.id, currentStreakValue, longestStreakValue);
  }

  bool _isDayScheduledForStreak(Habit habit, DateTime date, Map<String, double> completionMap) {
    if (habit.frequencyType == HabitFrequencyType.repeatsInPeriod) {
       final isCompletedToday = (completionMap[_dateKey(date)] ?? 0.0) >= habit.targetValue;
       if (isCompletedToday) return true;

       if (_isLastDayOfPeriod(habit, date)) {
          return !habit.isGoalMetForPeriod(completionMap, date);
       }
       return false;
    }

    return habit.isScheduledFor(date);
  }

  bool _isLastDayOfPeriod(Habit habit, DateTime date) {
    switch (habit.frequencyPeriod) {
      case HabitPeriod.week:
        return date.weekday == DateTime.sunday;
      case HabitPeriod.month:
        final nextDay = date.add(const Duration(days: 1));
        return nextDay.day == 1;
      case HabitPeriod.year:
        return date.month == 12 && date.day == 31;
      default:
        return false;
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
      if (habit.type != HabitType.time) continue; 

      final dateKey = _dateKey(targetDate);
      final habitRef = _db.collection('users').doc(userId).collection('habits').doc(habit.id);
      final historyRef = habitRef.collection('history').doc(dateKey);

      await _db.runTransaction((transaction) async {
        final habitSnap = await transaction.get(habitRef);
        final historySnap = await transaction.get(historyRef);
        
        final habitData = habitSnap.data() ?? {};
        final historyData = historySnap.data() ?? {};

        double currentVal = (historyData['v'] ?? historyData['value'] as num?)?.toDouble() ?? 0.0;
        
        double newVal = currentVal + deltaSeconds;
        if (newVal < 0) newVal = 0; 
        if (newVal > 86399) newVal = 86399;

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
        
        final isCompletedNow = newVal > 0;
        final isCompletedBefore = currentVal > 0;
        
        if (isCompletedNow && !isCompletedBefore) {
          total++;
        } else if (!isCompletedNow && isCompletedBefore) {
          total = (total > 0) ? total - 1 : 0;
        }

        final last7Key = 'l7.$dateKey';
        
        transaction.update(habitRef, {
          'st.tc': total,
          last7Key: isCompletedNow ? newVal : FieldValue.delete(),
        });
      });
      
      await recalculateStreak(userId, habit);
    }
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
