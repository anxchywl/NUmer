import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum HabitType {
  yesNo,
  numeric, // At least X count
  time, // At least X duration
}

enum HabitFrequencyType {
  daily,
  specificDays,
  interval, // Every N days
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
  
  // Frequency
  final HabitFrequencyType frequencyType;
  final Set<int> weekDays; // 1-7 for specificDays
  final int intervalDays; // for interval type
  
  // Schedule
  final DateTime startDate;
  final DateTime? endDate;

  // Stats
  final int totalCompletions;
  final int currentStreak;
  final int longestStreak;
  
  final Map<String, int> last7;
  final bool archived;
  final DateTime createdAt;

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
    this.frequencyType = HabitFrequencyType.specificDays, // Default to specificDays (or daily implied empty)
    this.weekDays = const {},
    this.intervalDays = 1,
    required this.startDate,
    this.endDate,
    this.totalCompletions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.last7 = const {},
    this.archived = false,
    required this.createdAt,
  });

  bool get isDaily => frequencyType == HabitFrequencyType.daily;
  
  // Helper to check if habit is active on a given date logic...
  // (We'll implement actual scheduling logic in service/UI)

  factory Habit.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
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

    return Habit(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Habit',
      color: Color(data['color'] ?? 0xFF000000),
      iconCodePoint: data['iconCodePoint'] ?? 0xe156,
      iconFamily: data['iconFamily'],
      iconPackage: data['iconPackage'],
      category: data['category'] ?? "Other",
      type: type,
      targetValue: (data['targetValue'] as num?)?.toDouble() ?? 1.0,
      unit: data['unit'],
      frequencyType: freq,
      weekDays: days,
      intervalDays: data['intervalDays'] ?? 1,
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(), // Fallback to now for legacy
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      totalCompletions: data['stats']?['totalCompletions'] ?? 0,
      currentStreak: data['stats']?['currentStreak'] ?? 0,
      longestStreak: data['stats']?['longestStreak'] ?? 0,
      last7: Map<String, int>.from(data['last7'] ?? {}),
      archived: data['archived'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      'frequencyType': frequencyType.name,
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
    };
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
