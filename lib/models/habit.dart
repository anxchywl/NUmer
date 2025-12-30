import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum HabitType {
  yesNo,
  numeric, // At least X count
  time, // At least X duration
}

enum HabitComparator {
  atLeast,
  lessThan,
  exactly,
  any,
}

enum HabitFrequencyType {
  daily,
  specificDays,
  interval, // Every N days
  repeatsInPeriod, // X times per period
}

enum HabitPeriod {
  week,
  month,
  year,
}

class Habit {
  final String id;
  final String name;
  final Color color;
  final int iconCodePoint; 
  final String? iconFamily;
  final String? iconPackage;
  
  // Category
  final String category; // "Health", "Work", or "Custom"
  
  // Details
  final HabitType type;
  final double targetValue; // 1.0 for YesNo, N for numeric/time
  final String? unit; // "pages", "mins", etc.
  final HabitComparator comparator; // New field
  
  // Frequency
  final HabitFrequencyType frequencyType;
  final Set<int> weekDays; // 1-7 for specificDays
  final int intervalDays; // for interval type
  final HabitPeriod? frequencyPeriod; // for repeatsInPeriod
  final int? frequencyGoal; // X times per period
  
  // Schedule
  final DateTime startDate;
  final DateTime? endDate;

  // Stats
  final int totalCompletions;
  final int currentStreak;
  final int longestStreak;
  
  final Map<String, double> last7;
  final bool archived;
  final DateTime createdAt;

  // Course Integration
  final List<String> connectedCourseIds;

  // Reminder Settings
  final bool hasReminder;
  final int? reminderHour;   // 0-23
  final int? reminderMinute; // 0-59

  Habit({
    required this.id,
    required this.name,
    required this.color,
    this.iconCodePoint = 0xe156,
    this.iconFamily,
    this.iconPackage,
    this.category = "Other",
    this.type = HabitType.yesNo,
    this.targetValue = 1.0,
    this.unit,
    this.comparator = HabitComparator.atLeast,
    this.frequencyType = HabitFrequencyType.specificDays, // Default to specificDays (or daily implied empty)
    this.weekDays = const {},
    this.intervalDays = 1,
    this.frequencyPeriod,
    this.frequencyGoal,
    required this.startDate,
    this.endDate,
    this.totalCompletions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.last7 = const {},
    this.archived = false,
    required this.createdAt,
    this.connectedCourseIds = const [],
    this.hasReminder = false,
    this.reminderHour,
    this.reminderMinute,
  });

  bool get isDaily => frequencyType == HabitFrequencyType.daily;
  
  factory Habit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Habit.fromMap(doc.id, data);
  }

  factory Habit.fromMap(String id, Map<String, dynamic> data) {
    // Migration helpers
    HabitFrequencyType freq = HabitFrequencyType.specificDays;
    Set<int> days = (data['weekDays'] as List<dynamic>?)?.map((e) => e as int).toSet() ?? {};
    if (data['frequencyType'] != null) {
      freq = HabitFrequencyType.values.firstWhere((e) => e.name == data['frequencyType'], orElse: () => HabitFrequencyType.specificDays);
    } else {
       // Legacy fallback: if weekDays empty -> Daily, else SpecificDays
       if (days.isEmpty) freq = HabitFrequencyType.daily;
    }

    HabitType type = HabitType.yesNo;
    if (data['type'] != null) {
      type = HabitType.values.firstWhere((e) => e.name == data['type'], orElse: () => HabitType.yesNo);
    }
    
    HabitComparator comparator = HabitComparator.atLeast;
    if (data['comparator'] != null) {
      comparator = HabitComparator.values.firstWhere((e) => e.name == data['comparator'], orElse: () => HabitComparator.atLeast);
    }
    
    HabitPeriod? period;
    if (data['frequencyPeriod'] != null) {
      period = HabitPeriod.values.firstWhere((e) => e.name == data['frequencyPeriod'], orElse: () => HabitPeriod.week);
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return Habit(
      id: id,
      name: data['name'] ?? 'Unnamed Habit',
      color: Color(data['color'] ?? 0xFF000000),
      iconCodePoint: data['iconCodePoint'] ?? 0xe156,
      iconFamily: data['iconFamily'],
      iconPackage: data['iconPackage'],
      category: data['category'] ?? "Other",
      type: type,
      targetValue: (data['targetValue'] as num?)?.toDouble() ?? 1.0,
      unit: data['unit'],
      comparator: comparator,
      frequencyType: freq,
      weekDays: days,
      intervalDays: data['intervalDays'] ?? 1,
      frequencyPeriod: period,
      frequencyGoal: data['frequencyGoal'],
      startDate: parseDate(data['startDate']) ?? DateTime.now(),
      endDate: parseDate(data['endDate']),
      totalCompletions: data['stats']?['totalCompletions'] ?? 0,
      currentStreak: data['stats']?['currentStreak'] ?? 0,
      longestStreak: data['stats']?['longestStreak'] ?? 0,
      last7: (data['last7'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      archived: data['archived'] ?? false,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
      connectedCourseIds: (data['connectedCourseIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      hasReminder: data['hasReminder'] ?? false,
      reminderHour: data['reminderHour'],
      reminderMinute: data['reminderMinute'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'color': color.toARGB32(),
      'iconCodePoint': iconCodePoint,
      'iconFamily': iconFamily,
      'iconPackage': iconPackage,
      'category': category,
      'type': type.name,
      'targetValue': targetValue,
      'unit': unit,
      'comparator': comparator.name,
      'frequencyType': frequencyType.name,
      'frequencyPeriod': frequencyPeriod?.name,
      'frequencyGoal': frequencyGoal,
      'weekDays': weekDays.toList(),
      'intervalDays': intervalDays,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'stats': {
        'totalCompletions': totalCompletions,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      },
      'last7': last7,
      'archived': archived,
      'createdAt': Timestamp.fromDate(createdAt),
      'connectedCourseIds': connectedCourseIds,
      'hasReminder': hasReminder,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
    };
  }

  bool isScheduledFor(DateTime date) {
    // 1. Check if before start date or after end date
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    if (d.isBefore(s)) return false;
    if (endDate != null) {
      final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (d.isAfter(e)) return false;
    }

    // 2. Frequency Rules
    switch (frequencyType) {
      case HabitFrequencyType.daily:
        return true;
      case HabitFrequencyType.specificDays:
        if (frequencyPeriod == HabitPeriod.month) {
          return weekDays.contains(d.day);
        } else if (frequencyPeriod == HabitPeriod.year) {
          final encoded = d.month * 100 + d.day;
          return weekDays.contains(encoded);
        }
        return weekDays.contains(d.weekday);
      case HabitFrequencyType.interval:
        final diff = d.difference(s).inDays;
        final totalCycle = intervalDays + (frequencyGoal ?? 0);
        if (totalCycle == 0) return true;
        final position = diff % totalCycle;
        return position < intervalDays; // "Work" days are first in cycle
      case HabitFrequencyType.repeatsInPeriod:
        // For "repeats in period", it's technically scheduled EVERY day 
        // until the goal is met? Or just show it every day and let user decide.
        // Usually, these are shown every day of the period.
        return true;
    }
  }
}

class HabitHistoryEntry {
  final String id;
  final DateTime date;
  final DateTime completedAt;
  final String? note;
  final double? value;

  HabitHistoryEntry({
    required this.id,
    required this.date,
    required this.completedAt,
    this.note,
    this.value,
  });

  factory HabitHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HabitHistoryEntry(
      id: doc.id,
      date: (data['date'] is Timestamp) 
          ? (data['date'] as Timestamp).toDate() 
          : DateTime.parse(data['date'] ?? doc.id),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'],
      value: (data['value'] as num?)?.toDouble(),
    );
  }
}
