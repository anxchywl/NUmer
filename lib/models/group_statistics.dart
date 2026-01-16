
class GroupStatistics {
  final String groupId;
  final List<MemberStudyData> members;
  final DateTime periodStart;
  final DateTime periodEnd;

  GroupStatistics({
    required this.groupId,
    required this.members,
    required this.periodStart,
    required this.periodEnd,
  });

  
  int get averageStudyTimeSeconds {
    if (members.isEmpty) return 0;
    final total = members.fold<int>(0, (acc, m) => acc + m.studyTimeSeconds);
    final avg = total / members.length;
    if (avg.isNaN || avg.isInfinite) return 0;
    return avg.toInt();
  }

  
  int get totalStudyTimeSeconds {
    return members.fold<int>(0, (acc, m) => acc + m.studyTimeSeconds);
  }

  
  MemberStudyData? get bestPerformer {
    if (members.isEmpty) return null;
    return members.reduce((a, b) => a.studyTimeSeconds > b.studyTimeSeconds ? a : b);
  }

  
  MemberStudyData? get lowestPerformer {
    if (members.isEmpty) return null;
    return members.reduce((a, b) => a.studyTimeSeconds < b.studyTimeSeconds ? a : b);
  }

  
  MemberStudyData? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  GroupStatistics copyWith({
    String? groupId,
    List<MemberStudyData>? members,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    return GroupStatistics(
      groupId: groupId ?? this.groupId,
      members: members ?? this.members,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
    );
  }
}

class MemberStudyData {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? avatarBase64;
  final int? avatarIndex;
  final int avatarColorValue;
  final int studyTimeSeconds;
  final int todayStudyTimeSeconds;
  final int monthStudyTimeSeconds;
  final bool isLeader;
  final bool isCurrentUser;
  final List<DailyStudyEntry> dailyBreakdown;
  final String? lastStudyDate;

  const MemberStudyData({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.avatarBase64,
    this.avatarIndex,
    required this.avatarColorValue,
    required this.studyTimeSeconds,
    required this.todayStudyTimeSeconds,
    required this.monthStudyTimeSeconds,
    required this.isLeader,
    required this.isCurrentUser,
    required this.dailyBreakdown,
    this.lastStudyDate,
  });

  MemberStudyData copyWith({
    String? userId,
    String? name,
    String? avatarUrl,
    String? avatarBase64,
    int? avatarIndex,
    int? avatarColorValue,
    int? studyTimeSeconds,
    int? todayStudyTimeSeconds,
    int? monthStudyTimeSeconds,
    bool? isLeader,
    bool? isCurrentUser,
    List<DailyStudyEntry>? dailyBreakdown,
    String? lastStudyDate,
  }) {
    return MemberStudyData(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      studyTimeSeconds: studyTimeSeconds ?? this.studyTimeSeconds,
      todayStudyTimeSeconds: todayStudyTimeSeconds ?? this.todayStudyTimeSeconds,
      monthStudyTimeSeconds: monthStudyTimeSeconds ?? this.monthStudyTimeSeconds,
      isLeader: isLeader ?? this.isLeader,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      dailyBreakdown: dailyBreakdown ?? this.dailyBreakdown,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    );
  }

  
  double getPercentageOfAverage(int groupAverage) {
    if (groupAverage == 0) return 100.0;
    final pct = (studyTimeSeconds / groupAverage) * 100.0;
    if (pct.isNaN || pct.isInfinite) return 0.0;
    return pct;
  }

  
  String getFormattedStudyTime() => _formatSeconds(studyTimeSeconds);

  String getFormattedTodayStudyTime() => _formatSeconds(todayStudyTimeSeconds);

  String getFormattedMonthStudyTime() =>
      _formatSeconds(monthStudyTimeSeconds);

  String _formatSeconds(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class DailyStudyEntry {
  final DateTime date;
  final int studyTimeSeconds;

  DailyStudyEntry({
    required this.date,
    required this.studyTimeSeconds,
  });

  String getFormattedTime() {
    final hours = studyTimeSeconds ~/ 3600;
    final minutes = (studyTimeSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

class SubjectStat {
  final String name;
  final int colorValue;
  final int seconds;

  const SubjectStat({
    required this.name,
    required this.colorValue,
    required this.seconds,
  });
  Map<String, dynamic> toJson() => {
        'name': name,
        'colorValue': colorValue,
        'seconds': seconds,
      };

  factory SubjectStat.fromJson(Map<dynamic, dynamic> json) {
    return SubjectStat(
      name: json['name'] as String,
      colorValue: (json['colorValue'] as num).toInt(),
      seconds: (json['seconds'] as num).toInt(),
    );
  }
}

class MemberSubjectStats {
  final int totalSeconds;
  final Map<String, SubjectStat> subjectStats;

  const MemberSubjectStats({
    required this.totalSeconds,
    required this.subjectStats,
  });

  Map<String, dynamic> toJson() => {
        'totalSeconds': totalSeconds,
        'subjectStats': subjectStats.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory MemberSubjectStats.fromJson(Map<String, dynamic> json) {
    final rawStatsMap = json['subjectStats'] as Map?;
    final subjectStats = <String, SubjectStat>{};
    
    if (rawStatsMap != null) {
      for (final entry in rawStatsMap.entries) {
        final key = entry.key.toString();
        final val = entry.value as Map;
        subjectStats[key] = SubjectStat.fromJson(val);
      }
    }

    return MemberSubjectStats(
      totalSeconds: (json['totalSeconds'] as num).toInt(),
      subjectStats: subjectStats,
    );
  }
}

enum StatisticsPeriod { today, last7Days, lastMonth }

extension StatisticsPeriodX on StatisticsPeriod {
  String get label => switch (this) {
        StatisticsPeriod.today => 'Today',
        StatisticsPeriod.last7Days => 'This week',
        StatisticsPeriod.lastMonth => 'This month',
      };

  String get shortLabel => switch (this) {
        StatisticsPeriod.today => 'Today',
        StatisticsPeriod.last7Days => 'Week',
        StatisticsPeriod.lastMonth => 'Month',
      };

  
  (DateTime start, DateTime end) getDateRange() {
    final now = DateTime.now();
    
    return switch (this) {
      StatisticsPeriod.today => (
        DateTime(now.year, now.month, now.day, 0, 0, 0),
        now, // End is now (current moment)
      ),
      StatisticsPeriod.last7Days => _getCurrentWeekRange(now),
      StatisticsPeriod.lastMonth => (
        DateTime(now.year, now.month, 1, 0, 0, 0),
        now, // End is now
      ),
    };
  }

  
  (DateTime start, DateTime end) _getCurrentWeekRange(DateTime now) {
    // Mon = 1 ... Sun = 7
    final weekday = now.weekday;
    final daysFromMonday = weekday - 1; 

    final monday = DateTime(
      now.year,
      now.month,
      now.day,
      0,
      0,
      0,
    ).subtract(Duration(days: daysFromMonday));

    // We can just return 'now' as the end, effectively "This Week (so far)"
    // Or we can return the end of the week. 
    // The prompt says "browsing past/future ranges" is removed.
    // "Today / This week / This month".
    
    return (monday, now); 
  }
}
