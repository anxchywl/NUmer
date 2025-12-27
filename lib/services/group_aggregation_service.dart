import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_statistics.dart';


class GroupAggregationService {
  GroupAggregationService();

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  
  
  Future<GroupStatistics> computeGroupStatistics(
    String groupId,
    List<String> memberIds,
    StatisticsPeriod period,
    FirebaseFirestore firestore,
    String? currentUserId,
  ) async {
    final now = DateTime.now();
    final dateRange = period.getDateRange(now);
    final periodStart = dateRange.$1;
    final periodEnd = dateRange.$2;

    final members = await Future.wait(
      memberIds.map(
        (userId) => _computeMemberStatistics(
          userId: userId,
          period: period,
          periodStart: periodStart,
          periodEnd: periodEnd,
          firestore: firestore,
          groupId: groupId,
          currentUserId: currentUserId,
        ),
      ),
    );

    
    members.sort((a, b) => b.studyTimeSeconds.compareTo(a.studyTimeSeconds));

    
    final leaderId = members.isNotEmpty ? members.first.userId : null;
    final normalizedMembers = members
        .map((m) => m.copyWith(isLeader: leaderId != null && m.userId == leaderId))
        .toList();

    return GroupStatistics(
      groupId: groupId,
      members: normalizedMembers,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  
  Future<MemberStudyData> _computeMemberStatistics({
    required String userId,
    required StatisticsPeriod period,
    required DateTime periodStart,
    required DateTime periodEnd,
    required FirebaseFirestore firestore,
    required String groupId,
    String? currentUserId,
  }) async {
    final isCurrentUser = userId == currentUserId;

    try {
      final sessionData = await _computeFromSessions(
        userId: userId,
        period: period,
        periodStart: periodStart,
        periodEnd: periodEnd,
        firestore: firestore,
      );
      return sessionData.copyWith(isCurrentUser: isCurrentUser);
    } on FirebaseException catch (e) {
      // If it's not a permission issue, rethrow so calling code can handle it.
      if (e.code != 'permission-denied') {
        rethrow;
      }
      // Permission denied: fall through to fallback aggregate reads.
    } catch (e) {
      // Log unexpected errors and fall back to aggregates or defaults.
      // ignore: avoid_print
      print('Error computing sessions for user $userId: $e');
    }

    
    final groupAggregate = await _readAggregate(
      firestore
          .collection('groups')
          .doc(groupId)
          .collection('aggregates')
          .doc(userId),
      period: period,
      currentUserId: currentUserId,
      userId: userId,
    );
    if (groupAggregate != null) return groupAggregate;

    
    final userAggregate = await _readAggregate(
      firestore
          .collection('users')
          .doc(userId)
          .collection('aggregates')
          .doc('statistics'),
      period: period,
      currentUserId: currentUserId,
      userId: userId,
    );
    if (userAggregate != null) return userAggregate;

    
    return _emptyMemberData(
      userId: userId,
      firestore: firestore,
      isCurrentUser: isCurrentUser,
    );
  }

  
  Future<MemberStudyData> _computeFromSessions({
    required String userId,
    required StatisticsPeriod period,
    required DateTime periodStart,
    required DateTime periodEnd,
    required FirebaseFirestore firestore,
  }) async {
    final userDoc = await firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final name = (userData['profileName'] as String?) ?? userId;
    final avatarIndex = userData['profileAvatarIndex'] as int? ?? userData['avatarIndex'] as int?;
    final avatarBase64 = userData['profileAvatarImageBase64'] as String?;
    final avatarColorValue = (userData['avatarColorValue'] as int?) ?? (userData['profileAvatarColorValue'] as int?) ?? 0xFF6366F1;

    
    final periodStartUtc = periodStart.toUtc();
    final periodEndUtc = periodEnd.toUtc();

    
    final sessionsSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('startUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStartUtc))
        .where('startUtc', isLessThanOrEqualTo: Timestamp.fromDate(periodEndUtc))
        .get();

    int periodSeconds = 0;
    int todaySeconds = 0;
    int monthSeconds = 0;

    final nowLocal = DateTime.now();
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final monthStart = DateTime(nowLocal.year, nowLocal.month, 1);

    for (final sessionDoc in sessionsSnap.docs) {
      final sessionData = sessionDoc.data();
      final deleted = (sessionData['deleted'] as bool?) ?? false;
      final seconds = (sessionData['seconds'] as int?) ?? 0;
      
      if (deleted || seconds <= 0) continue;

      final startUtc = (sessionData['startUtc'] as Timestamp?)?.toDate();
      if (startUtc == null) continue;
      final startLocal = startUtc.toLocal();

      
      
      if (startUtc.isAfter(periodStartUtc.subtract(const Duration(seconds: 1))) && 
          startUtc.isBefore(periodEndUtc.add(const Duration(seconds: 1)))) {
        periodSeconds += seconds;
      }

      
      final sessionDay = DateTime(startLocal.year, startLocal.month, startLocal.day);
      if (sessionDay.isAtSameMomentAs(today)) {
        todaySeconds += seconds;
      }

      
      if (startLocal.year == monthStart.year && startLocal.month == monthStart.month) {
        monthSeconds += seconds;
      }
    }

    return MemberStudyData(
      userId: userId,
      name: name,
      avatarUrl: null,
      avatarBase64: avatarBase64,
      avatarIndex: avatarIndex,
      avatarColorValue: avatarColorValue,
      studyTimeSeconds: periodSeconds,
      todayStudyTimeSeconds: todaySeconds,
      monthStudyTimeSeconds: monthSeconds,
      isLeader: false,
      isCurrentUser: false,
      dailyBreakdown: const [],
    );
  }

  Future<MemberStudyData> _emptyMemberData({
    required String userId,
    required FirebaseFirestore firestore,
    required bool isCurrentUser,
  }) async {
    String name = userId;
    int? avatarIndex;
    String? avatarBase64;
    int avatarColorValue = 0xFF6366F1;

    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData != null) {
        name = (userData['profileName'] as String?) ?? name;
        avatarIndex = userData['profileAvatarIndex'] as int? ?? userData['avatarIndex'] as int?;
        avatarBase64 = userData['profileAvatarImageBase64'] as String?;
        avatarColorValue = (userData['avatarColorValue'] as int?) ?? (userData['profileAvatarColorValue'] as int?) ?? avatarColorValue;
      }
    } catch (_) {
      // Failed to fetch user profile; return defaults below.
      // ignore: avoid_print
      print('Failed to fetch user profile for $userId; using defaults.');
    }

    return MemberStudyData(
      userId: userId,
      name: name,
      avatarUrl: null,
      avatarBase64: avatarBase64,
      avatarIndex: avatarIndex,
      avatarColorValue: avatarColorValue,
      studyTimeSeconds: 0,
      todayStudyTimeSeconds: 0,
      monthStudyTimeSeconds: 0,
      isLeader: false,
      isCurrentUser: isCurrentUser,
      dailyBreakdown: const [],
    );
  }

  Future<MemberStudyData?> _readAggregate(
    DocumentReference<Map<String, dynamic>> ref, {
    required StatisticsPeriod period,
    required String? currentUserId,
    required String userId,
  }) async {
    try {
      final aggregateDoc = await ref.get();
      if (!aggregateDoc.exists) return null;
      final data = aggregateDoc.data();
      if (data == null) return null;
      
      
      
      return _memberFromAggregateData(
        data: data,
        period: period,
        userId: userId,
        currentUserId: currentUserId,
      );
    } catch (_) {
      return null;
    }
  }

  MemberStudyData _memberFromAggregateData({
    required Map<String, dynamic> data,
    required StatisticsPeriod period,
    required String userId,
    required String? currentUserId,
  }) {
    final name = (data['name'] as String?) ?? userId;
    final avatarIndex = (data['profileAvatarIndex'] as num?)?.toInt() ??
        (data['avatarIndex'] as num?)?.toInt();
    final avatarBase64 = data['profileAvatarImageBase64'] as String? ?? data['avatarBase64'] as String?;
    final avatarColorValue = (data['avatarColorValue'] as num?)?.toInt() ??
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
    
    // For "Last 7 Days", we want the current calendar week (Monday to Sunday) or just last 7 days?
    // The StatisticsPeriod.getDateRange uses calendar week (Monday start).
    final (periodStart, periodEnd) = period.getDateRange(now);
    
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

        // Is it today?
        if (entryKey == todayKey) {
          observerTodaySeconds += entry.studyTimeSeconds;
        }

        // Is it in the current calendar month?
        if (entry.date.year == monthStart.year && entry.date.month == monthStart.month) {
          observerMonthSeconds += entry.studyTimeSeconds;
        }

        // Is it in the requested period (today/last7/month)?
        // Note: we use inclusive comparison for the date range
        if (entry.date.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
            entry.date.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
          periodSeconds += entry.studyTimeSeconds;
        }
      }
    }

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
    );
  }

  
  Future<MemberSubjectStats> fetchMemberSubjectStats({
    required String userId,
    required StatisticsPeriod period,
    required FirebaseFirestore firestore,
  }) async {
    final now = DateTime.now();
    final range = period.getDateRange(now);
    final start = DateTime(range.$1.year, range.$1.month, range.$1.day);
    final end = DateTime(range.$2.year, range.$2.month, range.$2.day, 23, 59, 59, 999);

    final sessionsSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('startUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(start.toUtc()))
        .where('startUtc', isLessThanOrEqualTo: Timestamp.fromDate(end.toUtc()))
        .get();

    int totalSeconds = 0;
    final courseTotals = <String, int>{};

    for (final doc in sessionsSnap.docs) {
      final data = doc.data();
      final deleted = (data['deleted'] as bool?) ?? false;
      final seconds = (data['seconds'] as int?) ?? 0;
      if (deleted || seconds <= 0) continue;

      totalSeconds += seconds;
      final courseId = (data['courseId'] as String?) ?? 'unknown';
      courseTotals.update(courseId, (value) => value + seconds, ifAbsent: () => seconds);
    }

    if (courseTotals.isEmpty) {
      return const MemberSubjectStats(totalSeconds: 0, subjectStats: {});
    }

    final courseInfo = <String, ({String name, int colorValue})>{};
    final courseIds = courseTotals.keys.toList();
    final coursesRef = firestore
        .collection('users')
        .doc(userId)
        .collection('courses');

    const chunkSize = 10;
    for (var i = 0; i < courseIds.length; i += chunkSize) {
      final chunk = courseIds.sublist(i, i + chunkSize > courseIds.length ? courseIds.length : i + chunkSize);
      final query = await coursesRef.where(FieldPath.documentId, whereIn: chunk).get();
      for (final courseDoc in query.docs) {
        final data = courseDoc.data();
        final rawName = data['name'] as String?;
        courseInfo[courseDoc.id] = (
          name: rawName != null && rawName.trim().isNotEmpty ? rawName : 'Unknown Course',
          colorValue: (data['colorValue'] as int?) ?? 0xFF9CA3AF,
        );
      }
    }

    final subjectStats = <String, SubjectStat>{};
    courseTotals.forEach((courseId, seconds) {
      final info = courseInfo[courseId];
      subjectStats[courseId] = SubjectStat(
        name: info?.name ?? 'Unknown Course',
        colorValue: info?.colorValue ?? 0xFF9CA3AF,
        seconds: seconds,
      );
    });

    return MemberSubjectStats(
      totalSeconds: totalSeconds,
      subjectStats: subjectStats,
    );
  }
}
