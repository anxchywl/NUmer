import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import '../models/habit.dart';
import 'notifications.dart';

/// Entry point for background alarm manager.
/// MUST be top-level for reliability.
@pragma('vm:entry-point')
Future<void> onAlarmFired(int id) async {
  debugPrint("HabitScheduler: Background alarm fired for ID $id");
  try {
    // 1. IMPORTANT: Initialize notifications in this isolate
    // We pass true to skip timezone detection if it might hang
    await Notifs.init(isBackground: true);

    // 2. Load Data
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString('habit_reminder_$id');
    if (dataStr == null) {
        debugPrint("HabitScheduler: No data found for ID $id");
        return;
    }

    final Map<String, dynamic> data = jsonDecode(dataStr);
    final habitId = data['habitId'] as String;
    final habitName = data['habitName'] as String;
    final habitJson = data['habitJson'] as Map<String, dynamic>?;

    // 3. Show Notification
    debugPrint("HabitScheduler: Showing notification for $habitName");
    await Notifs.showNow(
      id: id,
      title: habitName,
      body: "Time for your habit: $habitName",
    );

    // 4. Reschedule next trigger (Android logic)
    if (habitJson != null) {
      final habit = Habit.fromMap(habitId, habitJson);
      await HabitScheduler.scheduleAndroidInternal(habit, []); 
    }
  } catch (e, stack) {
    debugPrint("HabitScheduler: ERROR in onAlarmFired: $e\n$stack");
  }
}

/// Utility for scheduling habit reminders based on frequency rules.
class HabitScheduler {
  /// Computes the next reminder DateTime strictly based on frequency rules.
  static DateTime? getNextTriggerDateTime({
    required DateTime now,
    required Habit habit,
    List<DateTime> history = const [], // Needed for "repeats in period"
  }) {
    if (!habit.hasReminder || habit.reminderHour == null || habit.reminderMinute == null) {
      return null;
    }

    final reminderHour = habit.reminderHour!;
    final reminderMinute = habit.reminderMinute!;
    final start = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);

    // Initial candidate: today at the reminder time
    DateTime candidate = DateTime(now.year, now.month, now.day, reminderHour, reminderMinute);

    // If today is before start date, jump to start date
    if (candidate.isBefore(start)) {
      candidate = DateTime(start.year, start.month, start.day, reminderHour, reminderMinute);
    }

    // Search for the next valid date
    // We search up to 2 years ahead to find a valid date (safeguard)
    for (int i = 0; i < 730; i++) {
      // If candidate is in the future relative to 'now' AND it matches frequency
      if (candidate.isAfter(now) && _isDateMatchingFrequency(candidate, habit, history, start)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }

    return null;
  }

  static bool _isDateMatchingFrequency(DateTime date, Habit habit, List<DateTime> history, DateTime start) {
    final d = DateTime(date.year, date.month, date.day);
    
    // 1. Basic range check
    if (d.isBefore(start)) return false;
    if (habit.endDate != null) {
      final e = DateTime(habit.endDate!.year, habit.endDate!.month, habit.endDate!.day);
      if (d.isAfter(e)) return false;
    }

    // 2. Frequency Rules
    switch (habit.frequencyType) {
      case HabitFrequencyType.daily:
        return true;

      case HabitFrequencyType.specificDays:
        if (habit.frequencyPeriod == HabitPeriod.month) {
          return habit.weekDays.contains(d.day);
        } else if (habit.frequencyPeriod == HabitPeriod.year) {
          final encoded = d.month * 100 + d.day;
          return habit.weekDays.contains(encoded);
        }
        return habit.weekDays.contains(d.weekday);

      case HabitFrequencyType.interval:
        final diff = d.difference(start).inDays;
        final totalCycle = habit.intervalDays + (habit.frequencyGoal ?? 0);
        if (totalCycle <= 0) return true;
        final position = diff % totalCycle;
        return position < habit.intervalDays;

      case HabitFrequencyType.repeatsInPeriod:
        // Always trigger if within the period, user logic handles the rest.
        return true;
    }
  }

  static Future<void> schedule(Habit habit, {List<DateTime> history = const []}) async {
    debugPrint("HabitScheduler: Scheduling #${habit.id} (Reminders: ${habit.hasReminder})");
    
    if (!habit.hasReminder) {
      await cancel(habit);
      return;
    }

    if (Platform.isAndroid) {
        await scheduleAndroidInternal(habit, history);
    } else {
        await _scheduleIOS(habit, history);
    }
  }

  /// Exposed for background use
  static Future<void> scheduleAndroidInternal(Habit habit, List<DateTime> history) async {
    final nextTime = getNextTriggerDateTime(now: DateTime.now(), habit: habit, history: history);
    if (nextTime == null) {
      debugPrint("HabitScheduler: No future trigger found for Android");
      return;
    }

    final int id = habit.id.hashCode.abs();
    debugPrint("HabitScheduler: Scheduling Android alarm for $nextTime (ID: $id)");
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('habit_reminder_$id', jsonEncode({
      'habitId': habit.id,
      'habitName': habit.name,
      'habitJson': habit.toFirestore(), 
    }, toEncodable: (Object? value) {
      if (value is Timestamp) return value.toDate().toIso8601String();
      return value;
    }));

    bool success = await AndroidAlarmManager.oneShotAt(
      nextTime,
      id,
      onAlarmFired,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
    debugPrint("HabitScheduler: Alarm set: $success");
  }

  static Future<void> _scheduleIOS(Habit habit, List<DateTime> history) async {
    final baseId = habit.id.hashCode.abs();
    debugPrint("HabitScheduler: Scheduling iOS notifications for ID $baseId");

    // Clear previous batch (10)
    for (int i = 0; i < 10; i++) {
        await Notifs.cancel(baseId + i);
    }

    DateTime searchStart = DateTime.now();
    for (int i = 0; i < 10; i++) {
       final nextTime = getNextTriggerDateTime(now: searchStart, habit: habit, history: history);
       if (nextTime == null) break;

       debugPrint("HabitScheduler: iOS batch #$i -> $nextTime");
       await Notifs.scheduleOnce(
          id: baseId + i,
          title: habit.name,
          body: "Time for your habit: ${habit.name}",
          whenLocal: nextTime,
       );
       searchStart = nextTime.add(const Duration(seconds: 1));
    }
  }

  /// Cancel any scheduled notifications for the given habit.
  static Future<void> cancel(Habit habit) async {
    final id = habit.id.hashCode.abs();
    debugPrint("HabitScheduler: Cancelling all for $id");
    
    if (Platform.isAndroid) {
        // Only cancel if likely exists or just ignore logs
        await AndroidAlarmManager.cancel(id).catchError((e) => false);
    } else {
        for (int i = 0; i < 10; i++) {
            await Notifs.cancel(id + i);
        }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('habit_reminder_$id');
  }
  
  /// Reschedule all habits with reminders (call on app startup/boot).
  static Future<void> rescheduleAll(List<Habit> habits) async {
    debugPrint("HabitScheduler: Rescheduling ${habits.length} habits");
    for (final habit in habits) {
      await schedule(habit);
    }
  }
}
