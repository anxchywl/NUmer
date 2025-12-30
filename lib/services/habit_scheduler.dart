
// import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart'; // REMOVED
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/habit.dart';
import 'notifications.dart';

/// Utility for scheduling habit reminders based on frequency rules.
/// Android: Uses AndroidAlarmManager for exact background execution + chaining.
/// iOS: Uses local notifications scheduling.
class HabitScheduler {
  
  static Future<void> schedule(Habit habit, {List<DateTime> history = const []}) async {
    // Feature disabled. Just cancel any existing.
    await cancel(habit);
  }

  static Future<void> cancel(Habit habit) async {
    final id = habit.id.hashCode & 0x7FFFFFFF;
    debugPrint("HabitScheduler: Cancelling $id");
    
    // if (Platform.isAndroid) {
    //     await AndroidAlarmManager.cancel(id);
    // }
    // Also cancel any pending local notification (iOS or fallback)
    await Notifs.cancel(id);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('habit_next_time_$id');
    await prefs.remove('habit_data_$id');
  }
  
  /// Call this on app startup to recover any missed chains
  static Future<void> rescheduleAll(List<Habit> habits) async {
     // Feature disabled.
  }
}
