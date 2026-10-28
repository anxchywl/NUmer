import 'package:numer_app/features/groups/models/group_statistics.dart';

class GroupAggregationService {
  GroupAggregationService();

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Build a [MemberStudyData] from a stored aggregate document.
  /// Exposed so the leaderboard can render directly from aggregates without
  /// pulling full session history.
  MemberStudyData memberFromAggregateData({
    required Map<String, dynamic> data,
    required StatisticsPeriod period,
    required String userId,
    required String? currentUserId,
  }) {
    final name = (data['name'] as String?) ?? '';
    final avatarIndex =
        (data['profileAvatarIndex'] as num?)?.toInt() ??
        (data['avatarIndex'] as num?)?.toInt();
    final avatarBase64 =
        data['profileAvatarImageBase64'] as String? ??
        data['avatarBase64'] as String?;
    final avatarColorValue =
        (data['avatarColorValue'] as num?)?.toInt() ??
        (data['profileAvatarColorValue'] as num?)?.toInt() ??
        0xFF6366F1;
    final lastStudyDate = data['lastStudyDate'] as String?;

    final rawBreakdown = (data['dailyBreakdown'] as List?) ?? [];
    final dailyBreakdown = rawBreakdown.map((e) {
      final map = e as Map<String, dynamic>;
      final date = DateTime.parse(map['date'] as String);
      final seconds = (map['seconds'] as num).toInt();
      return DailyStudyEntry(date: date, studyTimeSeconds: seconds);
    }).toList();
    final totals = data['totals'] as Map<String, dynamic>?;

    // Sum up totals based on the OBSERVER'S perspective of "Today", "Last 7 Days", etc.
    final now = DateTime.now();
    final todayKey = _dateKey(now);

    final (periodStart, periodEnd) = period.getDateRange();

    int periodSeconds = 0;
    int observerTodaySeconds = 0;
    int observerMonthSeconds = 0;

    final monthStart = DateTime(now.year, now.month, 1);

    if (dailyBreakdown.isEmpty && totals != null) {
      final todayTotal = (totals['today'] as num?)?.toInt() ?? 0;
      final last7Total = (totals['last7Days'] as num?)?.toInt() ?? 0;
      final lastMonthTotal = (totals['lastMonth'] as num?)?.toInt() ?? 0;
      observerTodaySeconds = todayTotal;
      observerMonthSeconds = lastMonthTotal;
      periodSeconds = switch (period) {
        StatisticsPeriod.today => todayTotal,
        StatisticsPeriod.last7Days => last7Total,
        StatisticsPeriod.lastMonth => lastMonthTotal,
      };
    } else {
      for (final entry in dailyBreakdown) {
        final entryKey = _dateKey(entry.date);

        if (entryKey == todayKey) {
          observerTodaySeconds += entry.studyTimeSeconds;
        }

        if (entry.date.year == monthStart.year &&
            entry.date.month == monthStart.month) {
          observerMonthSeconds += entry.studyTimeSeconds;
        }

        if (entry.date.isAfter(
              periodStart.subtract(const Duration(seconds: 1)),
            ) &&
            entry.date.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
          periodSeconds += entry.studyTimeSeconds;
        }
      }
    }

    // Note: Aggregates don't typically include real-time study status,
    // but we can set them to defaults or they'll be updated by downstream listeners.
    return MemberStudyData(
      userId: userId,
      name: name,
      avatarUrl: null,
      avatarBase64: avatarBase64,
      avatarIndex: avatarIndex,
      avatarColorValue: avatarColorValue,
      studyTimeSeconds: periodSeconds,
      todayStudyTimeSeconds: observerTodaySeconds,
      monthStudyTimeSeconds: observerMonthSeconds,
      isLeader: false,
      isCurrentUser: userId == currentUserId,
      dailyBreakdown: dailyBreakdown,
      lastStudyDate: lastStudyDate,
      isStudying: false, // Will be updated by listeners
    );
  }
}
