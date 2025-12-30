import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habit.dart';
import '../models/habit_category.dart';
import 'storage.dart';
import 'habit_scheduler.dart';
import 'notifications.dart';

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

  // We might inject AuthService or pass uid directly. 
  // For simplicity, let's assume we get the UID from the UI or Auth provider.
  // But standard pattern in this app seems to be simple services.
  // Let's rely on the caller to provide UID or current user.
  
  // Actually, looking at main.dart, it seems we use Providers.
  // We can facilitate it by accepting a uid in methods or constructor if scoped.
  // Let's use methods with userId to be safe and stateless if used as a singleton/provider.

  Stream<List<Habit>> habitsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .where('archived', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList());
  }

  Future<List<Habit>> getHabits(String userId) async {
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .where('archived', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList();
  }

  Stream<List<Habit>> archivedHabitsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .where('archived', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList());
  }

  Future<void> unarchiveHabit(String userId, String habitId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .update({'archived': false});
  }

  Future<void> createHabit(String userId, Habit habit) async {
    // We let Firestore generate ID or use the one in model if we generated it client-side.
    // If habit.id is empty or temp, we might want a new doc ref.
    DocumentReference ref;
    if (habit.id.isEmpty || habit.id.contains('_temp')) {
       ref = _db.collection('users').doc(userId).collection('habits').doc();
    } else {
       ref = _db.collection('users').doc(userId).collection('habits').doc(habit.id);
    }
    
    // Ensure we use the ref ID
    final data = habit.toFirestore();
    // timestamp updates?
    
    await ref.set(data);
    
    // Always call schedule. The scheduler handles both scheduling 
    // new alarms and cancelling existing ones if hasReminder is false.
    final savedHabit = Habit.fromMap(ref.id, data);
    await HabitScheduler.schedule(savedHabit);
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

      // 1. Update History
      if (completed) {
        transaction.set(historyRef, {
          'date': dateKey,
          'dateTimestamp': Timestamp.fromDate(DateTime(date.year, date.month, date.day)), 
          'completedAt': FieldValue.serverTimestamp(),
          'value': value ?? 1, 
        });
      } else {
        transaction.delete(historyRef);
      }

      // 2. Update Stats (Totals only, Streak handled below)
      final data = habitSnap.data();
      final currentStats = data?['stats'] as Map<String, dynamic>? ?? {};
      int total = currentStats['totalCompletions'] ?? 0;
      
      final last7Map = data?['last7'] as Map<String, dynamic>? ?? {};
      final alreadyCompleted = last7Map.containsKey(dateKey);

      if (completed && !alreadyCompleted) {
        total++;
      } else if (!completed && alreadyCompleted) {
        total = (total > 0) ? total - 1 : 0;
      }

      final last7Key = 'last7.$dateKey';
      
      transaction.update(habitRef, {
        'stats.totalCompletions': total,
        last7Key: completed ? (value ?? 1.0) : FieldValue.delete(),
      });
    });

    // 3. Recalculate Streak (Outside transaction to avoid read limits/contention)
    // Fire and forget? Or await? Await ensures UI updates after logic.
    await recalculateStreak(userId, habit);
  }

  /// Load history for a month/range
  Future<List<HabitHistoryEntry>> getHistory(
      String userId, String habitId, DateTime start, DateTime end) async {
    // Start/End inclusive?
    // Convert to string keys or timestamps depending on index.
    // In toggleCompletion I wrote 'dateTimestamp' so let's use that.
    
    final s = Timestamp.fromDate(start);
    final e = Timestamp.fromDate(end);

    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .collection('history')
        .where('dateTimestamp', isGreaterThanOrEqualTo: s)
        .where('dateTimestamp', isLessThanOrEqualTo: e)
        .get();

    return snapshot.docs.map((d) => HabitHistoryEntry.fromFirestore(d)).toList();
  }

  Future<void> deleteHabit(String userId, String habitId) async {
    // Cancel any scheduled reminders first
    await Notifs.cancel(habitId.hashCode.abs());
    
    // Note: This does not delete subcollections (history) in Firestore.
    // For a production app, we should use a Cloud Function or recursive delete.
    // MVP: Just delete the habit document.
    await _db.collection('users').doc(userId).collection('habits').doc(habitId).delete();
  }

  Future<void> resetStreak(String userId, String habitId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .update({'stats.currentStreak': 0});
  }

  Future<void> resetHabitProgress(String userId, String habitId) async {
     final habitRef = _db.collection('users').doc(userId).collection('habits').doc(habitId);
     
     // 1. Delete all history docs (Batching for safety)
     // Note: In client SDK we can't delete a collection easily. We must query and delete.
     final historySnap = await habitRef.collection('history').get();
     final batch = _db.batch();
     
     for (var doc in historySnap.docs) {
        batch.delete(doc.reference);
     }
     
     // 2. Reset Stats
     batch.update(habitRef, {
        'stats': {
           'totalCompletions': 0,
           'currentStreak': 0,
           'longestStreak': 0,
        },
        'last7': FieldValue.delete(), // Remove last7 map
     });
     
     await batch.commit();
  }

  /// Recalculates and updates the streak based on history and schedule.
  Future<void> recalculateStreak(String userId, Habit habit) async {
    final historySnap = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habit.id)
        .collection('history')
        .orderBy('dateTimestamp', descending: true)
        .get();

    final historyDates = historySnap.docs.map((doc) {
       // Convert timestamp to DateTime (midnight)
       final ts = doc['dateTimestamp'] as Timestamp;
       final d = ts.toDate();
       return DateTime(d.year, d.month, d.day);
    }).toSet();

    int streak = 0;
    DateTime checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    
    // Safety break
    int daysChecked = 0;
    
    // If we have no history at all, streak is 0.
    if (historyDates.isEmpty) {
       await _updateStreak(userId, habit.id, 0);
       return;
    }

    // We iterate backwards. 
    while (daysChecked < 365 * 5) { // Check up to 5 years back
       final isScheduled = _isDayScheduled(habit, checkDate);
       
       if (isScheduled) {
         final isCompleted = historyDates.contains(checkDate);
         
         if (isCompleted) {
           streak++;
         } else {
           // Not completed.
           // If it's TODAY, allows being incomplete without breaking streak yet?
           // Usually, if I haven't done it today, my streak is "what it was yesterday".
           // But if I missed Yesterday (scheduled), streak is 0.
           final isToday = checkDate.year == DateTime.now().year &&
               checkDate.month == DateTime.now().month &&
               checkDate.day == DateTime.now().day;
               
           if (!isToday) {
             // Break streak
             break;
           }
           // If today is scheduled but not done, we just don't increment, 
           // but we continue to check yesterday to see the existing streak.
         }
       }
       // If not scheduled, skip (streak continues).
       
       checkDate = checkDate.subtract(const Duration(days: 1));
       daysChecked++;
    }
    
    await _updateStreak(userId, habit.id, streak);
  }

  Future<void> _updateStreak(String userId, String habitId, int streak) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId)
        .update({'stats.currentStreak': streak});
  }

  bool _isDayScheduled(Habit habit, DateTime date) {
    // If date is before start date, it's not scheduled (or rather, doesn't count)
    final start = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
    if (date.isBefore(start)) return false;

    switch (habit.frequencyType) {
      case HabitFrequencyType.daily:
        return true;
      case HabitFrequencyType.specificDays:
        return habit.weekDays.contains(date.weekday);
      case HabitFrequencyType.interval:
        // habit.startDate is always set
        final start = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
        final diff = date.difference(start).inDays;
        return diff % habit.intervalDays == 0;
      case HabitFrequencyType.repeatsInPeriod:
        return true; 
    }
  }

  Future<void> updateHabitProgressFromCourse({
    required String userId, 
    required String courseId, 
    required DateTime date,
    required int deltaSeconds
  }) async {
    if (deltaSeconds == 0) return;

    // Query active habits that are connected to this course (or were)
    final snapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('habits')
        .where('archived', isEqualTo: false)
        .where('connectedCourseIds', arrayContains: courseId)
        .get();

    // We update each habit
    for (var doc in snapshot.docs) {
      final habit = Habit.fromFirestore(doc);
      
      // 1. Check start date
      final targetDate = DateTime(date.year, date.month, date.day);
      final start = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
      if (targetDate.isBefore(start)) continue; 

      // 2. Check type logic - we only sync time habits (implied by "time added")
      if (habit.type != HabitType.time) continue; 

      final dateKey = _dateKey(targetDate);
      final habitRef = _db.collection('users').doc(userId).collection('habits').doc(habit.id);
      final historyRef = habitRef.collection('history').doc(dateKey);

      await _db.runTransaction((transaction) async {
        final habitSnap = await transaction.get(habitRef);
        final historySnap = await transaction.get(historyRef);
        
        // Calculate new value
        double currentVal = 0.0;
        if (historySnap.exists) {
           currentVal = (historySnap.data()?['value'] as num?)?.toDouble() ?? 0.0;
        }
        
        double newVal = currentVal + deltaSeconds;
        if (newVal < 0) newVal = 0; // Prevent negative

        // Update History
        if (newVal > 0) {
          transaction.set(historyRef, {
            'date': dateKey,
            'dateTimestamp': Timestamp.fromDate(targetDate), 
            'completedAt': FieldValue.serverTimestamp(), // Update completed at? Or keep original? For sync, maybe just leave it or update.
            'value': newVal, 
          }, SetOptions(merge: true));
        } else {
           // If reduced to 0, remove entry
           transaction.delete(historyRef);
        }

        // Update Stats & Last 7 (Totals logic)
        final data = habitSnap.data();
        if (data == null) return;
        
        final currentStats = data['stats'] as Map<String, dynamic>? ?? {};
        int total = currentStats['totalCompletions'] ?? 0;
        
        // Actually reliance on last7 for 'wasCompleted' might be shaky if >7 days.
        // But for transaction correctness of 'totalCompletions', we should rely on transition 0 -> >0 or >0 -> 0.

        final isCompletedNow = newVal > 0;
        final isCompletedBefore = currentVal > 0;
        
        if (isCompletedNow && !isCompletedBefore) {
          total++;
        } else if (!isCompletedNow && isCompletedBefore) {
          total = (total > 0) ? total - 1 : 0;
        }

        final last7Key = 'last7.$dateKey';
        
        transaction.update(habitRef, {
          'stats.totalCompletions': total,
          last7Key: isCompletedNow ? newVal : FieldValue.delete(),
        });
      });
      
      // Recalculate streak after update
      await recalculateStreak(userId, habit);
    }
  }

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
