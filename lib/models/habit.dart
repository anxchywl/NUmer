import 'dart:convert';
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
  final HabitComparator comparator; 
  
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
  final int sortOrder;
  
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
    this.frequencyType = HabitFrequencyType.specificDays, // Default to specificDays
    this.weekDays = const {},
    this.intervalDays = 1,
    this.frequencyPeriod,
    this.frequencyGoal,
    required this.startDate,
    this.endDate,
    this.totalCompletions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.sortOrder = 0,
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

  factory Habit.fromJson(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    return Habit.fromMap(data['id'], data);
  }

  String toJson() {
    final map = toFirestore();
    map['id'] = id;
    // Replace Timestamps with ISO Strings for JSON
    if (map['sd'] is Timestamp) map['sd'] = (map['sd'] as Timestamp).toDate().toIso8601String();
    if (map['ed'] is Timestamp) map['ed'] = (map['ed'] as Timestamp).toDate().toIso8601String();
    if (map['cr'] is Timestamp) map['cr'] = (map['cr'] as Timestamp).toDate().toIso8601String();
    return jsonEncode(map);
  }

  factory Habit.fromMap(String id, Map<String, dynamic> data) {
    // Helper to get from compact key OR legacy key
    T? get<T>(String compactKey, String legacyKey) {
      if (data.containsKey(compactKey)) return data[compactKey] as T?;
      if (data.containsKey(legacyKey)) return data[legacyKey] as T?;
      return null;
    }

    // Migration helpers
    HabitFrequencyType freq = HabitFrequencyType.specificDays;
    Set<int> days = {};
    
    // -- Frequency --
    // Compact: 'fq' (int index)
    // Legacy: 'frequencyType' (String name)
    if (data.containsKey('fq')) {
      final index = data['fq'] as int;
      freq = HabitFrequencyType.values[index.clamp(0, HabitFrequencyType.values.length - 1)];
    } else if (data['frequencyType'] != null) {
      freq = HabitFrequencyType.values.firstWhere((e) => e.name == data['frequencyType'], orElse: () => HabitFrequencyType.specificDays);
    } 

    // -- WeekDays --
    // Compact: 'wd' (List<int>)
    // Legacy: 'weekDays' (List<dynamic>)
    final rawDays = get('wd', 'weekDays');
    if (rawDays is List) {
      days = rawDays.map((e) => e as int).toSet();
    }
    
    // Legacy fallback logic for types
    if (!data.containsKey('fq') && !data.containsKey('frequencyType')) {
        // If really old legacy and weekDays empty -> Daily
        if (days.isEmpty) freq = HabitFrequencyType.daily;
    }

    // -- Type --
    // Compact: 't' (int index)
    HabitType type = HabitType.yesNo;
    if (data.containsKey('t')) {
       final index = data['t'] as int;
       type = HabitType.values[index.clamp(0, HabitType.values.length - 1)];
    } else if (data['type'] != null) {
       type = HabitType.values.firstWhere((e) => e.name == data['type'], orElse: () => HabitType.yesNo);
    }
    
    // -- Comparator --
    // Compact: 'co' (int index)
    HabitComparator comparator = HabitComparator.atLeast;
    if (data.containsKey('co')) {
       final index = data['co'] as int;
       comparator = HabitComparator.values[index.clamp(0, HabitComparator.values.length - 1)];
    } else if (data['comparator'] != null) {
       comparator = HabitComparator.values.firstWhere((e) => e.name == data['comparator'], orElse: () => HabitComparator.atLeast);
    }
    
    // -- Period --
    // Compact: 'fp' (int index)
    HabitPeriod? period;
    if (data.containsKey('fp') && data['fp'] != null) {
       final index = data['fp'] as int;
       period = HabitPeriod.values[index.clamp(0, HabitPeriod.values.length - 1)];
    } else if (data['frequencyPeriod'] != null) {
       period = HabitPeriod.values.firstWhere((e) => e.name == data['frequencyPeriod'], orElse: () => HabitPeriod.week);
    }

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is Timestamp) return d.toDate();
      if (d is String) return DateTime.tryParse(d);
      return null;
    }
    
    // -- Stats --
    // Compact: 'st' (Map) { 'tc': int, 'cs': int, 'ls': int }
    // Legacy: 'stats' (Map) { 'totalCompletions': ..., ... }
    final stats = get('st', 'stats') as Map<String, dynamic>? ?? {};
    int totalC = stats['tc'] ?? stats['totalCompletions'] ?? 0;
    int curS = stats['cs'] ?? stats['currentStreak'] ?? 0;
    int longS = stats['ls'] ?? stats['longestStreak'] ?? 0;

    // -- Reminder --
    // Compact: 'rm' (int minutes from midnight)
    // Legacy: 'reminderHour', 'reminderMinute'
    bool hasRem = false; 
    int? rHour;
    int? rMin;
    
    if (data.containsKey('rm') && data['rm'] != null) {
      int minutes = data['rm'] as int;
      rHour = minutes ~/ 60;
      rMin = minutes % 60;
      hasRem = true;
    } else {
      hasRem = data['hasReminder'] ?? false;
      rHour = data['reminderHour'];
      rMin = data['reminderMinute'];
    }

    return Habit(
      id: id,
      name: get('n', 'name') ?? 'Unnamed Habit',
      color: Color(get('cl', 'color') ?? 0xFF000000),
      iconCodePoint: get('ic', 'iconCodePoint') ?? 0xe156,
      iconFamily: get('if', 'iconFamily'),
      iconPackage: get('ip', 'iconPackage'),
      category: get('ca', 'category') ?? "Other",
      type: type,
      targetValue: (get('tv', 'targetValue') as num?)?.toDouble() ?? 1.0,
      unit: get('u', 'unit'),
      comparator: comparator,
      frequencyType: freq,
      weekDays: days,
      intervalDays: get('iv', 'intervalDays') ?? 1,
      frequencyPeriod: period,
      frequencyGoal: get('fg', 'frequencyGoal'),
      startDate: parseDate(get('sd', 'startDate')) ?? DateTime.now(),
      endDate: parseDate(get('ed', 'endDate')),
      
      // Flattened stats for constructor
      totalCompletions: totalC,
      currentStreak: curS,
      longestStreak: longS,
      
      sortOrder: (get('so', 'sortOrder') as num?)?.toInt() ?? 0,
      
      // last7: Compact 'l7', Legacy 'last7'
      last7: (get('l7', 'last7') as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
          
      archived: get('ar', 'archived') ?? false,
      createdAt: parseDate(get('cr', 'createdAt')) ?? DateTime.now(),
      connectedCourseIds: (get('cc', 'connectedCourseIds') as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      
      hasReminder: hasRem,
      reminderHour: rHour,
      reminderMinute: rMin,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'n': name,
      'cl': color.toARGB32(),
      'ic': iconCodePoint,
      // 'if': iconFamily, // Only if not null
      // 'ip': iconPackage, // Only if not null
      'ca': category,
      't': type.index,
      'tv': targetValue,
      'co': comparator.index,
      'fq': frequencyType.index,
      'wd': weekDays.toList(),
      'iv': intervalDays,
      'sd': Timestamp.fromDate(startDate),
      
      'st': {
        'tc': totalCompletions,
        'cs': currentStreak,
        'ls': longestStreak,
      },
      'so': sortOrder,
      'l7': last7,
      'cr': Timestamp.fromDate(createdAt),
    };
    
    if (iconFamily != null) map['if'] = iconFamily;
    if (iconPackage != null) map['ip'] = iconPackage;
    if (unit != null) map['u'] = unit;
    if (frequencyPeriod != null) map['fp'] = frequencyPeriod!.index;
    if (frequencyGoal != null) map['fg'] = frequencyGoal;
    if (endDate != null) map['ed'] = Timestamp.fromDate(endDate!);
    if (archived) map['ar'] = true;
    if (connectedCourseIds.isNotEmpty) map['cc'] = connectedCourseIds;
    
    if (hasReminder && reminderHour != null && reminderMinute != null) {
      map['rm'] = reminderHour! * 60 + reminderMinute!;
    }
    
    return map;
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
        // Usually shown every day of the period.
        return true;
    }
  }

  /// Returns true if this habit should be hidden because the period goal has been met.
  bool isGoalMetForPeriod(Map<String, double> completionMap, DateTime forDate) {
    if (frequencyType != HabitFrequencyType.repeatsInPeriod) return false;
    if (frequencyGoal == null || frequencyGoal! <= 0) return false;
    
    // Determine period boundaries
    DateTime periodStart;
    DateTime periodEnd;
    
    switch (frequencyPeriod) {
      case HabitPeriod.week:
        // Week starts Monday
        final weekday = forDate.weekday; // 1=Mon, 7=Sun
        periodStart = DateTime(forDate.year, forDate.month, forDate.day - (weekday - 1));
        periodEnd = periodStart.add(const Duration(days: 6));
        break;
      case HabitPeriod.month:
        periodStart = DateTime(forDate.year, forDate.month, 1);
        periodEnd = DateTime(forDate.year, forDate.month + 1, 0);
        break;
      case HabitPeriod.year:
        periodStart = DateTime(forDate.year, 1, 1);
        periodEnd = DateTime(forDate.year, 12, 31);
        break;
      default:
        return false;
    }
    
    // Count completions in period from completionMap
    int count = 0;
    for (final dateKey in completionMap.keys) {
      final parts = dateKey.split('-');
      if (parts.length != 3) continue;
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) continue;
      
      final entryDate = DateTime(y, m, d);
      // Use inclusive check for start and end of period
      if (!entryDate.isBefore(periodStart) && !entryDate.isAfter(periodEnd)) {
        if ((completionMap[dateKey] ?? 0.0) >= targetValue) count++;
      }
    }
    
    return count >= frequencyGoal!;
  }

  Habit copyWith({
    String? id,
    String? name,
    Color? color,
    int? iconCodePoint,
    String? iconFamily,
    String? iconPackage,
    String? category,
    HabitType? type,
    double? targetValue,
    String? unit,
    HabitComparator? comparator,
    HabitFrequencyType? frequencyType,
    Set<int>? weekDays,
    int? intervalDays,
    HabitPeriod? frequencyPeriod,
    int? frequencyGoal,
    DateTime? startDate,
    DateTime? endDate,
    int? totalCompletions,
    int? currentStreak,
    int? longestStreak,
    int? sortOrder,
    Map<String, double>? last7,
    bool? archived,
    DateTime? createdAt,
    List<String>? connectedCourseIds,
    bool? hasReminder,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFamily: iconFamily ?? this.iconFamily,
      iconPackage: iconPackage ?? this.iconPackage,
      category: category ?? this.category,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      comparator: comparator ?? this.comparator,
      frequencyType: frequencyType ?? this.frequencyType,
      weekDays: weekDays ?? this.weekDays,
      intervalDays: intervalDays ?? this.intervalDays,
      frequencyPeriod: frequencyPeriod ?? this.frequencyPeriod,
      frequencyGoal: frequencyGoal ?? this.frequencyGoal,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalCompletions: totalCompletions ?? this.totalCompletions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      sortOrder: sortOrder ?? this.sortOrder,
      last7: last7 ?? this.last7,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      connectedCourseIds: connectedCourseIds ?? this.connectedCourseIds,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}

class HabitHistoryEntry {
  final String id;
  // final DateTime date; // REMOVED: Redundant with ID, but we keep logic to parse ID if needed
  final DateTime completedAt;
  final String? note;
  final double? value;

  HabitHistoryEntry({
    required this.id,
    required this.completedAt,
    this.note,
    this.value,
  });
  
  // Helper to get date from ID
  DateTime get date {
    return DateTime.tryParse(id) ?? DateTime.now();
  }

  factory HabitHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime cAt = DateTime.now();
    // Compact: 't' (Timestamp)
    // Legacy: 'completedAt' (Timestamp)
    if (data['t'] != null) {
      cAt = (data['t'] as Timestamp).toDate();
    } else if (data['completedAt'] is Timestamp) {
      cAt = (data['completedAt'] as Timestamp).toDate();
    }
    
    return HabitHistoryEntry(
      id: doc.id,
      completedAt: cAt,
      // Compact: 'n' (note), 'v' (value)
      note: data['n'] ?? data['note'],
      value: (data['v'] ?? data['value'] as num?)?.toDouble(),
    );
  }
}
