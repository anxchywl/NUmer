
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
}

class MemberSubjectStats {
  final int totalSeconds;
  final Map<String, SubjectStat> subjectStats;

  const MemberSubjectStats({
    required this.totalSeconds,
    required this.subjectStats,
  });
}

enum StatisticsPeriod { today, last7Days, lastMonth }

extension StatisticsPeriodX on StatisticsPeriod {
  String get label => switch (this) {
        StatisticsPeriod.today => 'Today',
        StatisticsPeriod.last7Days => 'Last 7 days',
        StatisticsPeriod.lastMonth => 'Last month',
      };

  String get shortLabel => switch (this) {
        StatisticsPeriod.today => 'Today',
        StatisticsPeriod.last7Days => '7 days',
        StatisticsPeriod.lastMonth => 'Month',
      };

  
  (DateTime start, DateTime end) getDateRange(DateTime referenceDate) {
    final now = DateTime(referenceDate.year, referenceDate.month, referenceDate.day, 23, 59, 59);
    
    return switch (this) {
      StatisticsPeriod.today => (
        DateTime(now.year, now.month, now.day, 0, 0, 0),
        now,
      ),
      StatisticsPeriod.last7Days => _getCalendarWeekRange(now),
      StatisticsPeriod.lastMonth => (
        DateTime(now.year, now.month, 1, 0, 0, 0),
        now,
      ),
    };
  }

  
  (DateTime start, DateTime end) _getCalendarWeekRange(DateTime referenceDate) {
    
    final weekday = referenceDate.weekday;
    
    
    final daysFromMonday = weekday - 1; 
    
    
    final monday = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
      0,
      0,
      0,
    ).subtract(Duration(days: daysFromMonday));
    
    
    final sunday = DateTime(
      monday.year,
      monday.month,
      monday.day,
      23,
      59,
      59,
    ).add(const Duration(days: 6));
    
    
    final end = referenceDate.isBefore(sunday) ? referenceDate : sunday;
    
    return (monday, end);
  }
}
