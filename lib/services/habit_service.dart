import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/habit.dart';

class HabitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // We might inject AuthService or pass uid directly. 
  // For simplicity, let's assume we get the UID from the UI or Auth provider.
  // But standard pattern in this app seems to be simple services.
  // Let's rely on the caller to provide UID or current user.
  
  // Actually, looking at main.dart, it seems we use Providers.
  // We can facilitate it by accepting a uid in methods or constructor if scoped.
  // Let's use methods with userId to be safe and stateless if used as a singleton/provider.

  Stream<List<Habit>> habitsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .where('archived', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Habit.fromFirestore(doc)).toList());
  }

  Future<void> createHabit(String userId, Habit habit) async {
    // We let Firestore generate ID or use the one in model if we generated it client-side.
    // If habit.id is empty or temp, we might want a new doc ref.
    DocumentReference ref;
    if (habit.id.isEmpty || habit.id.contains('_temp')) {
       ref = _firestore.collection('users').doc(userId).collection('habits').doc();
    } else {
       ref = _firestore.collection('users').doc(userId).collection('habits').doc(habit.id);
    }
    
    // Ensure we use the ref ID
    final data = habit.toFirestore();
    // timestamp updates?
    
    await ref.set(data);
  }

  Future<void> toggleCompletion({
    required String userId,
    required String habitId,
    required DateTime date,
    required bool completed,
  }) async {
    final dateKey = _dateKey(date);
    final habitRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('habits')
        .doc(habitId);
    final historyRef = habitRef.collection('history').doc(dateKey);

    return _firestore.runTransaction((transaction) async {
      final habitSnap = await transaction.get(habitRef);
      if (!habitSnap.exists) throw Exception("Habit not found");

      // 1. Update History
      if (completed) {
        transaction.set(historyRef, {
          'date': dateKey, // Store as string for easy reading? Or Timestamp?
          // Let's store Date as Timestamp for range queries, and ID as String for uniqueness
          'dateTimestamp': Timestamp.fromDate(DateTime(date.year, date.month, date.day)), 
          'completedAt': FieldValue.serverTimestamp(),
          'value': 1, 
        });
      } else {
        transaction.delete(historyRef);
      }

      // 2. Update Stats (Optimistic / Simple counter)
      // Note: accurate streak calculation usually requires reading history.
      // For now, we just increment/decrement total. 
      // Streaks are complex to do in a single atomic increment without more data.
      // We will skip complex streak logic in transaction for MVP and just do totals + last7.
      
      final currentStats = habitSnap.data()?['stats'] as Map<String, dynamic>? ?? {};
      int total = currentStats['totalCompletions'] ?? 0;
      
      if (completed) {
        total++;
      } else {
        total = (total > 0) ? total - 1 : 0;
      }

      // 3. Update Last7 Cache
      // We need to merge this new status into the map.
      // Firestore allows updating nested map fields with dot notation.
      final last7Key = 'last7.$dateKey';
      
      transaction.update(habitRef, {
        'stats.totalCompletions': total,
        // If uncompleting, removing key; if completing, adding key.
        last7Key: completed ? 1 : FieldValue.delete(),
      });
    });
  }

  /// Load history for a month/range
  Future<List<HabitHistoryEntry>> getHistory(
      String userId, String habitId, DateTime start, DateTime end) async {
    // Start/End inclusive?
    // Convert to string keys or timestamps depending on index.
    // In toggleCompletion I wrote 'dateTimestamp' so let's use that.
    
    final s = Timestamp.fromDate(start);
    final e = Timestamp.fromDate(end);

    final snapshot = await _firestore
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

  String _dateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
