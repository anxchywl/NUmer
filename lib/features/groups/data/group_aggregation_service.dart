import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:numer_app/features/groups/models/group_statistics.dart';


class GroupAggregationService {
  GroupAggregationService();

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  
  
  Future<GroupStatistics> computeGroupStatistics(
    String groupId,
    List<String> memberIds,
    StatisticsPeriod period,
    FirebaseFirestore firestore,
    String? currentUserId, {
    DateTime? referenceDate,
  }) async {
    final dateRange = period.getDateRange();
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

    if (isCurrentUser) {
      try {
        final sessionData = await computeMemberStats(
          userId: userId,
          period: period,
          periodStart: periodStart,
          periodEnd: periodEnd,
          firestore: firestore,
        );
        return sessionData.copyWith(isCurrentUser: isCurrentUser);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          rethrow;
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error computing sessions for user $userId: $e');
      }
    }

    
    // For everyone (including current user if session compute failed or wasn't tried first for recent optimization),
    // we try stored aggregates.
    MemberStudyData? aggregateData;
    
    // 1. Try Group-specific aggregate
    aggregateData = await _readAggregate(
      firestore
          .collection('groups')
          .doc(groupId)
          .collection('aggregates')
          .doc(userId),
      period: period,
      currentUserId: currentUserId,
      userId: userId,
    );
    
    // 2. Try User-global aggregate if group one failed
    aggregateData ??= await _readAggregate(
      firestore
          .collection('users')
          .doc(userId)
          .collection('aggregates')
          .doc('statistics'),
      period: period,
      currentUserId: currentUserId,
      userId: userId,
    );

    // 3. Fetch LIVE user status to overlay on top of historical aggregates
    // This ensures that if the user is currently studying, we show it immediately
    // even if the aggregate is hours old.
    Map<String, dynamic>? liveUserData;
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        liveUserData = userDoc.data();
      }
    } catch (e) {
      debugPrint('Error fetching live user data for $userId: $e');
    }

    if (aggregateData != null) {
       // Merge live data if available
       if (liveUserData != null) {
         return aggregateData.copyWith(
           name: (liveUserData['profileName'] as String?) ?? aggregateData.name,
           avatarIndex: (liveUserData['profileAvatarIndex'] as int?) ?? liveUserData['avatarIndex'] as int? ?? aggregateData.avatarIndex,
           avatarBase64: liveUserData['profileAvatarImageBase64'] as String? ?? aggregateData.avatarBase64,
           avatarColorValue: (liveUserData['avatarColorValue'] as int?) ?? (liveUserData['profileAvatarColorValue'] as int?) ?? aggregateData.avatarColorValue,
           isStudying: (liveUserData['isStudying'] as bool?) ?? false,
           activeSession: liveUserData['activeSession'] as Map<String, dynamic>?,
           allowsNudges: (liveUserData['allowNudges'] as bool?) != false,
           canReceiveNudges: (liveUserData['fcmEnabled'] as bool?) == true,
         );
       }
       return aggregateData;
    }

    // Fallback for others or if aggregate doesn't exist
    if (!isCurrentUser) {
      try {
        final sessionData = await computeMemberStats(
          userId: userId,
          period: period,
          periodStart: period.getDateRange().$1,
          periodEnd: period.getDateRange().$2,
          firestore: firestore,
        );
        return sessionData.copyWith(isCurrentUser: isCurrentUser);
      } catch (e) {
        debugPrint('Error computing stats from sessions for $userId: $e');
      }
    }
    
    // If we have live data but no stats, return empty member with live status
    // Note: _emptyMemberData fetches the user profile internally, so we can just call it
    // if we don't have an aggregate or manual session stats.
    if (liveUserData != null) {
       // We already fetched liveUserData, so we can construct the object manually to save a read,
       // or just call _emptyMemberData if we want to be safe/consistent.
       // Since we have the data, let's use it to avoid another read inside _emptyMemberData!
       return MemberStudyData(
          userId: userId,
          name: (liveUserData['profileName'] as String?) ?? userId,
          avatarUrl: null,
          avatarBase64: liveUserData['profileAvatarImageBase64'] as String?,
          avatarIndex: (liveUserData['profileAvatarIndex'] as int?) ?? liveUserData['avatarIndex'] as int?,
          avatarColorValue: (liveUserData['avatarColorValue'] as int?) ?? (liveUserData['profileAvatarColorValue'] as int?) ?? 0xFF6366F1,
          studyTimeSeconds: 0,
          todayStudyTimeSeconds: 0,
          monthStudyTimeSeconds: 0,
          isLeader: false,
          isCurrentUser: isCurrentUser,
          dailyBreakdown: const [],
          isStudying: (liveUserData['isStudying'] as bool?) ?? false,
          activeSession: liveUserData['activeSession'] as Map<String, dynamic>?,
          allowsNudges: (liveUserData['allowNudges'] as bool?) != false,
          canReceiveNudges: (liveUserData['fcmEnabled'] as bool?) == true,
       );
    }
    
    // Final fallback: use _emptyMemberData which will try to fetch profile again
    return await _emptyMemberData(
      userId: userId,
      firestore: firestore,
      isCurrentUser: isCurrentUser,
    );
  }

  
  Future<MemberStudyData> computeMemberStats({
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

    // Fetch courses to check for hidden status
    final coursesSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('courses')
        .get();
        
    final hiddenCourseIds = <String>{};
    for (final doc in coursesSnap.docs) {
      if (doc.data()['hiddenFromLeaderboard'] == true) {
        hiddenCourseIds.add(doc.id);
      }
    }

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

      
      
      final courseId = (sessionData['courseId'] as String?) ?? '';
      if (hiddenCourseIds.contains(courseId)) continue;

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

  // Include ongoing active session time if applicable
  if (userData['isStudying'] == true) {
    final active = userData['activeSession'] as Map<String, dynamic>?;
    if (active != null) {
      final aStartVal = active['startUtc'];
      final aCourseId = active['courseId'] as String?;
      
      if (aStartVal is Timestamp && !hiddenCourseIds.contains(aCourseId)) {
        final startUtc = aStartVal.toDate();
        final now = DateTime.now();
        final startLocal = startUtc.toLocal();
        final diff = now.difference(startUtc).inSeconds;
        
        // Sanity check: cap at 3h and ignore future starts
        if (diff > 0 && diff < 3600 * 3) {
          if (startUtc.isAfter(periodStartUtc.subtract(const Duration(seconds: 1))) && 
              startUtc.isBefore(periodEndUtc.add(const Duration(seconds: 1)))) {
            periodSeconds += diff;
          }

          final sessionDay = DateTime(startLocal.year, startLocal.month, startLocal.day);
          if (sessionDay.isAtSameMomentAs(today)) {
            todaySeconds += diff;
          }

          if (startLocal.year == monthStart.year && startLocal.month == monthStart.month) {
            monthSeconds += diff;
          }
        }
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
      todayStudyTimeSeconds: todaySeconds,
      monthStudyTimeSeconds: monthSeconds,
      isLeader: false,
      isCurrentUser: false,
      dailyBreakdown: const [],
      isStudying: (userData['isStudying'] as bool?) ?? false,
      activeSession: userData['activeSession'] as Map<String, dynamic>?,
      allowsNudges: (userData['allowNudges'] as bool?) != false,
      canReceiveNudges: (userData['fcmEnabled'] as bool?) == true,
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
    bool isStudying = false;
    Map<String, dynamic>? activeSession;
    bool allowsNudges = true;
    bool canReceiveNudges = false;

    try {
      final userDoc = await firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData != null) {
        name = (userData['profileName'] as String?) ?? name;
        avatarIndex = userData['profileAvatarIndex'] as int? ?? userData['avatarIndex'] as int?;
        avatarBase64 = userData['profileAvatarImageBase64'] as String?;
        avatarColorValue = (userData['avatarColorValue'] as int?) ?? (userData['profileAvatarColorValue'] as int?) ?? avatarColorValue;
        isStudying = (userData['isStudying'] as bool?) ?? false;
        activeSession = userData['activeSession'] as Map<String, dynamic>?;
        allowsNudges = (userData['allowNudges'] as bool?) != false;
        canReceiveNudges = (userData['fcmEnabled'] as bool?) == true;
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
      isStudying: isStudying,
      activeSession: activeSession,
      allowsNudges: allowsNudges,
      canReceiveNudges: canReceiveNudges,
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
      
      return memberFromAggregateData(
        data: data,
        period: period,
        userId: userId,
        currentUserId: currentUserId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Build a [MemberStudyData] from a stored aggregate document.
  /// Exposed so the leaderboard can render directly from aggregates without
  /// pulling full session history.
  MemberStudyData memberFromAggregateData({
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

        if (entry.date.year == monthStart.year && entry.date.month == monthStart.month) {
          observerMonthSeconds += entry.studyTimeSeconds;
        }

        if (entry.date.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
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

  
  Future<MemberSubjectStats> fetchMemberSubjectStats({
    required String userId,
    required StatisticsPeriod period,
    required FirebaseFirestore firestore,
  }) async {
    final range = period.getDateRange();
    final start = DateTime(range.$1.year, range.$1.month, range.$1.day);
    final end = DateTime(range.$2.year, range.$2.month, range.$2.day, 23, 59, 59, 999);

    final userDoc = await firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    final sessionsSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('sessions')
        .where('startUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(start.toUtc()))
        .where('startUtc', isLessThanOrEqualTo: Timestamp.fromDate(end.toUtc()))
        .get();

    // Fetch courses to check for hidden status
    final coursesSnap = await firestore
        .collection('users')
        .doc(userId)
        .collection('courses')
        .get();
        
    final hiddenCourseIds = <String>{};
    for (final doc in coursesSnap.docs) {
      if (doc.data()['hiddenFromLeaderboard'] == true) {
        hiddenCourseIds.add(doc.id);
      }
    }

    int totalSeconds = 0;
    final courseTotals = <String, int>{};

    for (final doc in sessionsSnap.docs) {
      final data = doc.data();
      final deleted = (data['deleted'] as bool?) ?? false;
      final seconds = (data['seconds'] as int?) ?? 0;
      if (deleted || seconds <= 0) continue;

      final courseId = (data['courseId'] as String?) ?? 'unknown';
      if (hiddenCourseIds.contains(courseId)) continue;
      
      totalSeconds += seconds;
    courseTotals.update(courseId, (value) => value + seconds, ifAbsent: () => seconds);
  }

  // Include ongoing active session if applicable
  if (userData['isStudying'] == true) {
    final active = userData['activeSession'] as Map<String, dynamic>?;
    if (active != null) {
      final aStartVal = active['startUtc'];
      final aCourseId = active['courseId'] as String?;

      if (aStartVal is Timestamp && !hiddenCourseIds.contains(aCourseId)) {
        final startUtc = aStartVal.toDate();
        final now = DateTime.now();
        final diff = now.difference(startUtc).inSeconds;

        if (diff > 0 && diff < 3600 * 3) {
           final rangeStart = start.toUtc();
           final rangeEnd = end.toUtc();
           
           if (startUtc.isAfter(rangeStart.subtract(const Duration(seconds: 1))) && 
               startUtc.isBefore(rangeEnd.add(const Duration(seconds: 1)))) {
             final cid = aCourseId ?? 'unknown';
             totalSeconds += diff;
             courseTotals.update(cid, (value) => value + diff, ifAbsent: () => diff);
           }
        }
      }
    }
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
        // Skip hidden courses
        if (data['hiddenFromLeaderboard'] == true) continue;
        
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
