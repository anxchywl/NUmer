import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:numer_app/features/habits/models/habit_rule.dart';

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

  // Last 7 days history (cached for UI)
  final Map<String, double> last7;

  final bool archived;
  final DateTime createdAt;

  // Connected Courses (for Time habits)
  final List<String> connectedCourseIds;

  // Retroactive Logic
  final List<HabitRule> previousRules;

  Habit({
    required this.id,
    required this.name,
    required this.color,
    required this.iconCodePoint,
    this.iconFamily,
    this.iconPackage,
    required this.category,
    required this.type,
    required this.targetValue,
    this.unit,
    required this.comparator,
    required this.frequencyType,
    this.weekDays = const {},
    this.intervalDays = 0,
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
    this.previousRules = const [],
  });

  bool get isDaily => frequencyType == HabitFrequencyType.daily;

  /// Computes the live current streak, accounting for missed days.
  /// For daily habits: if yesterday was scheduled but not completed, streak is 0.
  /// For other habits: checks if the last scheduled day before today was completed.
  int get liveCurrentStreak {
    // If stored streak is already 0, nothing to compute
    if (currentStreak == 0) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final habitStart = DateTime(startDate.year, startDate.month, startDate.day);

    // For daily habits, just check yesterday
    if (frequencyType == HabitFrequencyType.daily) {
      DateTime checkDate = today.subtract(const Duration(days: 1));
      if (checkDate.isBefore(habitStart)) return currentStreak;

      final yesterdayKey =
          "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      final yesterdayValue = last7[yesterdayKey] ?? 0.0;

      if (yesterdayValue < targetValue) return 0;
      return currentStreak;
    }

    // For specific days habits, find the last scheduled day
    if (frequencyType == HabitFrequencyType.specificDays) {
      for (int i = 1; i <= 7; i++) {
        final checkDate = today.subtract(Duration(days: i));
        if (checkDate.isBefore(habitStart)) break;

        if (isScheduledFor(checkDate)) {
          final dateKey =
              "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
          final value = last7[dateKey] ?? 0.0;

          if (value < targetValue) return 0;
          return currentStreak;
        }
      }
    }

    // For interval habits (e.g., 2 days on, 1 day off)
    if (frequencyType == HabitFrequencyType.interval) {
      // Find the last scheduled "work" day before today
      // Walk back up to the cycle length
      final cycle = intervalDays + (frequencyGoal ?? 0);
      if (cycle <= 0) return currentStreak;

      for (int i = 1; i <= cycle; i++) {
        final checkDate = today.subtract(Duration(days: i));
        if (checkDate.isBefore(habitStart)) break;

        if (isScheduledFor(checkDate)) {
          final dateKey =
              "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
          final value = last7[dateKey] ?? 0.0;

          if (value < targetValue) return 0;
          return currentStreak;
        }
      }
    }

    // For periodic habits (e.g., 3 times per week)
    if (frequencyType == HabitFrequencyType.repeatsInPeriod &&
        frequencyGoal != null) {
      // Identify the previous period
      DateTime periodStart;
      switch (frequencyPeriod) {
        case HabitPeriod.week:
          final offset =
              (today.weekday - 1); // Assuming Monday first for live calculation
          periodStart = today.subtract(Duration(days: offset));
          break;
        case HabitPeriod.month:
          periodStart = DateTime(today.year, today.month, 1);
          break;
        case HabitPeriod.year:
          periodStart = DateTime(today.year, 1, 1);
          break;
        default:
          return currentStreak;
      }

      // The most recently COMPLETED period is the one before periodStart
      DateTime prevPeriodStart;
      switch (frequencyPeriod) {
        case HabitPeriod.week:
          prevPeriodStart = periodStart.subtract(const Duration(days: 7));
          break;
        case HabitPeriod.month:
          prevPeriodStart =
              DateTime(periodStart.year, periodStart.month - 1, 1);
          break;
        case HabitPeriod.year:
          prevPeriodStart = DateTime(periodStart.year - 1, 1, 1);
          break;
        default:
          return currentStreak;
      }

      if (prevPeriodStart.isBefore(habitStart)) {
        // If the previous period started before the habit did, the streak is either valid (from current)
        // or we haven't reached a "missed" state yet.
        return currentStreak;
      }

      // Check if current period is met (if so, streak is definitely safe)
      if (isGoalMetForPeriod(last7, today)) {
        return currentStreak;
      }

      // If current period is NOT met, we need to check if the PREVIOUS period was met.
      // NOTE: last7 might not have enough data for month/year.
      // This is a model limitation, but for "Week" habits (most common), it works.
      // If we don't have enough data, we default to currentStreak to avoid false resets.
      if (frequencyPeriod == HabitPeriod.week) {
        if (!isGoalMetForPeriod(last7, prevPeriodStart)) {
          return 0;
        }
      }
    }

    return currentStreak;
  }

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
    if (map['sd'] is Timestamp) {
      map['sd'] = (map['sd'] as Timestamp).toDate().toIso8601String();
    }
    if (map['ed'] is Timestamp) {
      map['ed'] = (map['ed'] as Timestamp).toDate().toIso8601String();
    }
    if (map['cr'] is Timestamp) {
      map['cr'] = (map['cr'] as Timestamp).toDate().toIso8601String();
    }
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
      freq = HabitFrequencyType
          .values[index.clamp(0, HabitFrequencyType.values.length - 1)];
    } else if (data['frequencyType'] != null) {
      freq = HabitFrequencyType.values.firstWhere(
          (e) => e.name == data['frequencyType'],
          orElse: () => HabitFrequencyType.specificDays);
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
      type = HabitType.values.firstWhere((e) => e.name == data['type'],
          orElse: () => HabitType.yesNo);
    }

    // -- Comparator --
    // Compact: 'co' (int index)
    HabitComparator comparator = HabitComparator.atLeast;
    if (data.containsKey('co')) {
      final index = data['co'] as int;
      comparator = HabitComparator
          .values[index.clamp(0, HabitComparator.values.length - 1)];
    } else if (data['comparator'] != null) {
      comparator = HabitComparator.values.firstWhere(
          (e) => e.name == data['comparator'],
          orElse: () => HabitComparator.atLeast);
    }

    // -- Period --
    // Compact: 'fp' (int index)
    HabitPeriod? period;
    if (data.containsKey('fp') && data['fp'] != null) {
      final index = data['fp'] as int;
      period =
          HabitPeriod.values[index.clamp(0, HabitPeriod.values.length - 1)];
    } else if (data['frequencyPeriod'] != null) {
      period = HabitPeriod.values.firstWhere(
          (e) => e.name == data['frequencyPeriod'],
          orElse: () => HabitPeriod.week);
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
      connectedCourseIds: (get('cc', 'connectedCourseIds') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
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
    map['ar'] = archived;
    if (connectedCourseIds.isNotEmpty) map['cc'] = connectedCourseIds;
    if (previousRules.isNotEmpty) {
      map['pr'] = previousRules.map((r) => r.toJson()).toList();
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
  bool isGoalMetForPeriod(Map<String, double> completionMap, DateTime forDate,
      {bool mondayFirst = true}) {
    if (frequencyType != HabitFrequencyType.repeatsInPeriod) return false;
    if (frequencyGoal == null || frequencyGoal! <= 0) return false;

    // Determine period boundaries
    DateTime periodStart;
    DateTime periodEnd;

    switch (frequencyPeriod) {
      case HabitPeriod.week:
        final weekday = forDate.weekday; // 1=Mon, 7=Sun
        final offset = mondayFirst ? (weekday - 1) : (weekday % 7);
        periodStart =
            DateTime(forDate.year, forDate.month, forDate.day - offset);
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
      // Use inclusive check: periodStart <= entryDate <= periodEnd
      if (!entryDate.isBefore(periodStart) && !entryDate.isAfter(periodEnd)) {
        if ((completionMap[dateKey] ?? 0.0) >= targetValue) count++;
      }
    }

    return count >= (frequencyGoal ?? 1);
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
    List<HabitRule>? previousRules,
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
      previousRules: previousRules ?? this.previousRules,
    );
  }

  /// Returns the effective rule (target/comparator) for a specific date.
  /// If the date is covered by a previous rule (date < rule.endDate), returns that rule.
  /// Otherwise, returns current habit settings.
  HabitRule getRuleForDate(DateTime date) {
    if (previousRules.isEmpty) {
      return HabitRule(
          endDate: DateTime(2100),
          targetValue: targetValue,
          comparator: comparator);
    }

    // Sort rules by endDate ascending just in case
    // (Assuming they are stored sorted, but safety first if performance allows,
    // or just iterate and find the first one where date < endDate)

    // We assume previousRules are non-overlapping history segments.
    // e.g. Rule A (ends Jan 1), Rule B (ends Jan 10).
    // If date is Dec 31, it matches Rule A.
    // If date is Jan 5, it matches Rule B.
    // If date is Jan 12, it matches Current (no rule found).

    // Check against previous rules
    for (final rule in previousRules) {
      if (date.isBefore(rule.endDate)) {
        return rule;
      }
    }

    // Fallback to current
    return HabitRule(
        endDate: DateTime(2100),
        targetValue: targetValue,
        comparator: comparator);
  }
}

class HabitHistoryEntry {
  final String id;
  // final DateTime date; // REMOVED: Redundant with ID, but we keep logic to parse ID if needed
  final DateTime completedAt;
  final String? note;
  final double? value;
  final double? manualValue; // Manual component (non-session time)

  // Helper to get timestamp from ID (for backwards compat)
  DateTime get timestamp => DateTime.tryParse(id) ?? DateTime.now();

  HabitHistoryEntry({
    required this.id,
    required this.completedAt,
    this.note,
    this.value,
    this.manualValue,
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
      // Compact: 'n' (note), 'v' (value), 'm' (manual)
      note: data['n'] ?? data['note'],
      value: (data['v'] ?? data['value'] as num?)?.toDouble(),
      manualValue: (data['m'] as num?)?.toDouble(),
    );
  }
}
