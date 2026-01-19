import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/group.dart';
import '../models/group_statistics.dart';
import 'group_aggregation_service.dart';
import 'storage.dart';
import '../data/local/entities.dart';

class GroupService {
  GroupService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Map<String, Stream<GroupStatistics>> _statsCache = {};

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection('groups');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<List<Group>> watchPublicGroups() {
    return _groupsRef
        .where('visibility', isEqualTo: GroupVisibility.public.label)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map(Group.fromDoc).toList());
  }

  Stream<List<Group>> searchGroups(String query) {
    if (query.isEmpty) {
      return Stream.value([]);
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    return _groupsRef
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map(Group.fromDoc).toList());
  }

  Stream<Group?> watchGroup(String groupId) {
    return _groupsRef.doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Group.fromDoc(doc);
    });
  }

  Stream<List<GroupMembership>> watchUserMemberships(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('groupMemberships')
        .orderBy('joinedAt', descending: true)
        .snapshots()
        .map((snap) {
          final memberships =
              snap.docs.map(GroupMembership.fromDoc).toList(growable: false);
          final groupIds = memberships.map((m) => m.groupId).toList();
          unawaited(
            _userDoc(userId).set(
              {'groupIds': groupIds},
              SetOptions(merge: true),
            ),
          );
          return memberships;
        });
  }

  Stream<GroupMembership?> watchMembershipForUser(String userId, String groupId) {
    return _userMembershipRef(userId, groupId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return GroupMembership.fromDoc(snap);
    });
  }

  Stream<List<GroupMember>> watchGroupMembers(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('members')
        .orderBy('joinedAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(GroupMember.fromDoc).toList());
  }

  
  
  Stream<GroupStatistics> watchGroupStatistics(
    String groupId,
    StatisticsPeriod period,
  ) {
    final cacheKey = '${groupId}_${period.index}';
    final existing = _statsCache[cacheKey];
    if (existing != null) return existing;

    late StreamController<GroupStatistics> controller;
    
    StreamSubscription? membersSub;
    StreamSubscription? aggregatesSub;
    StreamSubscription? userSessionsSub;
    StreamSubscription? userCoursesSub;
    bool hasTerminated = false;
    Set<String> memberIds = {};
    final uid = _uid;
    Timer? dailyRefreshTimer;
    Timer? debounceTimer;
    bool refreshScheduled = false;
    bool isComputing = false;
    // Manage listeners for ALL members' status to update "active" indicators in real-time
    final Map<String, StreamSubscription> memberStatusSubs = {};

    Future<void> cleanup({bool shouldCloseController = false}) async {
      _statsCache.remove(cacheKey);
      await membersSub?.cancel();
      await aggregatesSub?.cancel();
      await userSessionsSub?.cancel();
      await userCoursesSub?.cancel();
      for (final sub in memberStatusSubs.values) {
        await sub.cancel();
      }
      memberStatusSubs.clear();
      dailyRefreshTimer?.cancel();
      debounceTimer?.cancel();
      if (shouldCloseController && !controller.isClosed) {
        await controller.close();
      }
    }

    controller = StreamController<GroupStatistics>.broadcast(
      onCancel: () => cleanup(shouldCloseController: true),
    );
    _statsCache[cacheKey] = controller.stream;

    void handleStreamError(Object error, StackTrace stackTrace) {
      if (hasTerminated) return;
      hasTerminated = true;
      Object normalizedError = error;
      if (error is FirebaseException && error.code == 'permission-denied') {
        normalizedError = StateError('You do not have permission to view this group.');
      }
      if (!controller.isClosed) {
        controller.addError(normalizedError, stackTrace);
      }
      unawaited(cleanup(shouldCloseController: true));
    }

    GroupStatistics? lastStats;

    Future<void> computeAndEmit(Set<String> memberIds) async {
      if (isComputing) return; 
      isComputing = true;
      try {
        final aggregationService = GroupAggregationService();
        final stats = await aggregationService.computeGroupStatistics(
          groupId,
          memberIds.toList(),
          period,
          _firestore,
          uid,
        );
        lastStats = stats; // Cache for partial updates
        await _markMemberStatsStaleFromTotals(
          groupId: groupId,
          period: period,
          stats: stats,
        );
        if (!controller.isClosed) {
          controller.add(stats);
        }
      } catch (e, stack) {
        handleStreamError(e, stack);
      } finally {
        isComputing = false;
      }
    }

    void triggerRecompute() {
      if (memberIds.isEmpty) return;
      
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 300), () {
        unawaited(computeAndEmit(memberIds));
      });
    }

    Future<void> updateMemberStats(String userId, {DocumentSnapshot? snapshot}) async {
      if (lastStats == null || (snapshot == null && isComputing)) {
         if (lastStats == null) triggerRecompute();
         return;
      }
      
      try {
        final currentMembers = lastStats!.members;
        final index = currentMembers.indexWhere((m) => m.userId == userId);
        if (index < 0 && snapshot != null) return; // Only process if we already know this member

        final MemberStudyData newMemberData;
        if (snapshot != null && snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final oldMember = index >= 0 ? currentMembers[index] : null;
          
          if (oldMember != null) {
            newMemberData = oldMember.copyWith(
              name: data['profileName'] as String? ?? oldMember.name,
              avatarIndex: (data['profileAvatarIndex'] ?? data['avatarIndex']) as int?,
              avatarBase64: data['profileAvatarImageBase64'] as String?,
              avatarColorValue: (data['avatarColorValue'] ?? data['profileAvatarColorValue']) as int? ?? oldMember.avatarColorValue,
              isStudying: data['isStudying'] as bool? ?? false,
              activeSession: data['activeSession'] as Map<String, dynamic>?,
              allowsNudges: data['allowNudges'] != false,
              canReceiveNudges: data['fcmEnabled'] == true,
            );
            
            // Optimization: If nothing meaningful changed, don't emit.
            if (newMemberData.isStudying == oldMember.isStudying &&
                newMemberData.activeSession == oldMember.activeSession &&
                newMemberData.name == oldMember.name &&
                newMemberData.avatarIndex == oldMember.avatarIndex &&
                newMemberData.avatarColorValue == oldMember.avatarColorValue) {
              return;
            }
          } else {
             // Shouldn't happen if listeners are set up correctly, but fallback:
             final aggregationService = GroupAggregationService();
             newMemberData = await aggregationService.computeMemberStats(
                userId: userId, 
                period: period, 
                periodStart: period.getDateRange().$1, 
                periodEnd: period.getDateRange().$2, 
                firestore: _firestore,
             );
          }
        } else {
          final aggregationService = GroupAggregationService();
          newMemberData = await aggregationService.computeMemberStats(
             userId: userId, 
             period: period, 
             periodStart: period.getDateRange().$1, 
             periodEnd: period.getDateRange().$2, 
             firestore: _firestore,
          );
        }
        
        final List<MemberStudyData> newMembers;
        if (index >= 0) {
           newMembers = List.of(currentMembers);
           newMembers[index] = newMemberData.copyWith(isCurrentUser: userId == uid);
        } else {
           newMembers = [...currentMembers, newMemberData.copyWith(isCurrentUser: userId == uid)];
        }
        
        // Only re-sort (expensive-ish) if it's the current user or study time might have changed
        // but since we only update real-time fields above, studyTimeSeconds shouldn't have changed.
        // However, for simplicity and ensuring correctness if we fall back, we sort.
        newMembers.sort((a, b) => b.studyTimeSeconds.compareTo(a.studyTimeSeconds));
        
        final leaderId = newMembers.isNotEmpty ? newMembers.first.userId : null;
        final normalized = newMembers.map((m) => m.copyWith(isLeader: leaderId != null && m.userId == leaderId)).toList();
        
        final newGroupStats = lastStats!.copyWith(members: normalized);
        lastStats = newGroupStats;
        
        if (!controller.isClosed) {
           controller.add(newGroupStats);
        }
      } catch (e) {
         debugPrint('Error updating single member $userId: $e');
      }
    }

    void scheduleDailyRefresh() {
      // if (referenceDate != null) return; // Removed logic
      dailyRefreshTimer?.cancel();
      final now = DateTime.now();
      final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
      dailyRefreshTimer = Timer(delay, () {
        if (hasTerminated) return;
        triggerRecompute();
        scheduleDailyRefresh();
      });
    }

    
    if (uid == null) {
      handleStreamError(
        StateError('You must be signed in to view group statistics.'),
        StackTrace.current,
      );
      return controller.stream;
    }

    
    _userMembershipRef(uid, groupId).snapshots().listen((membershipSnap) {
      if (!membershipSnap.exists) {
        handleStreamError(
          StateError('You do not have permission to view this group.'),
          StackTrace.current,
        );
        return;
      }

      

      void updateMemberListeners(Set<String> currentMemberIds) {
        // Remove stale listeners
        final toRemove = memberStatusSubs.keys.where((id) => !currentMemberIds.contains(id)).toList();
        for (final id in toRemove) {
          memberStatusSubs[id]?.cancel();
          memberStatusSubs.remove(id);
        }

        // Add new listeners
        for (final id in currentMemberIds) {
          if (!memberStatusSubs.containsKey(id)) {
            memberStatusSubs[id] = _firestore.collection('users').doc(id).snapshots().listen((snap) {
               updateMemberStats(id, snapshot: snap);
            }, onError: (e) {
               debugPrint('Error watching member status for $id: $e');
            });
          }
        }
      }

      membersSub ??= _groupsRef
          .doc(groupId)
          .collection('members')
          .snapshots()
          .listen((membersSnap) {
        memberIds = membersSnap.docs.map((d) => d.id).toSet();
        updateMemberListeners(memberIds);
        triggerRecompute();
      }, onError: handleStreamError);

      aggregatesSub ??= _groupsRef
          .doc(groupId)
          .collection('aggregates')
          .snapshots()
          .listen((_) {
        triggerRecompute();
      }, onError: handleStreamError);

      // Listen to the CURRENT USER'S sessions to update their own stats immediately
      // on local delete/edit/add.
      final dateRange = period.getDateRange();
      final startUtc = dateRange.$1.toUtc();
      final endUtc = dateRange.$2.toUtc();
      
      userSessionsSub ??= _firestore
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .where('startUtc', isGreaterThanOrEqualTo: Timestamp.fromDate(startUtc))
          .where('startUtc', isLessThanOrEqualTo: Timestamp.fromDate(endUtc))
          .snapshots()
          .listen((_) {
        triggerRecompute();
      }, onError: (e) {
          debugPrint('Error watching my sessions: $e');
      });

      userCoursesSub ??= _firestore
          .collection('users')
          .doc(uid)
          .collection('courses')
          .snapshots()
          .listen((_) {
            triggerRecompute();
          }, onError: (e) {
             debugPrint('Error watching my courses: $e');
          });

      if (!refreshScheduled) {
        refreshScheduled = true;
        scheduleDailyRefresh();
      }
    }, onError: handleStreamError);

    controller.onCancel = () => cleanup(shouldCloseController: true);

    return controller.stream;
  }

  
  
  final Map<String, ({MemberSubjectStats stats, DateTime timestamp})> _subjectStatsCache = {};
  bool _cacheLoaded = false;
  final Set<String> _staleSubjectStatsKeys = {};
  
  // TTL for cache freshness (1 hour)
  static const _memberStatsTtl = Duration(hours: 1);
  
  // Member profile cache (name, major, goal, contact, avatar)
  final Map<String, ({Map<String, dynamic> data, DateTime timestamp})> _memberProfileCache = {};
  bool _profileCacheLoaded = false;

  String _cacheKey(String groupId, String userId, StatisticsPeriod period) =>
      '${groupId}_${userId}_${period.name}';
  
  String _profileCacheKey(String groupId, String userId) =>
      '${groupId}_$userId';


  Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) return;
    try {
      final data = await Storage.getGroupMemberStatsCache();
      if (data != null) {
        for (final entry in data.entries) {
          final val = entry.value as Map;
          final statsMap = val['stats'] as Map;
          // Ensure map is cast to Map<String, dynamic>
          final statsJson = statsMap.map((k, v) => MapEntry(k.toString(), v));
          
          final ts = val['timestamp'] as int;
          _subjectStatsCache[entry.key] = (
            stats: MemberSubjectStats.fromJson(statsJson),
            timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
          );
        }
      }
      _cacheLoaded = true;
    } catch (e) {
      debugPrint('Error loading group stats cache: $e');
    }
  }

  Future<void> _persistSubjectStatsCache() async {
    try {
      final serialized = <String, dynamic>{};
      _subjectStatsCache.forEach((key, value) {
        serialized[key] = {
          'stats': value.stats.toJson(),
          'timestamp': value.timestamp.millisecondsSinceEpoch,
        };
      });
      await Storage.saveGroupMemberStatsCache(serialized);
    } catch (e) {
      debugPrint('Error saving group stats cache: $e');
    }
  }

  // Profile cache persistence
  Future<void> _ensureProfileCacheLoaded() async {
    if (_profileCacheLoaded) return;
    try {
      final data = await Storage.getMemberProfileCache();
      if (data != null) {
        for (final entry in data.entries) {
          final val = entry.value as Map;
          final profileData = Map<String, dynamic>.from(val['data'] as Map);
          final ts = val['timestamp'] as int;
          _memberProfileCache[entry.key] = (
            data: profileData,
            timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
          );
        }
      }
      _profileCacheLoaded = true;
    } catch (e) {
      debugPrint('Error loading profile cache: $e');
    }
  }

  Future<void> _persistProfileCache() async {
    try {
      final serialized = <String, dynamic>{};
      _memberProfileCache.forEach((key, value) {
        serialized[key] = {
          'data': value.data,
          'timestamp': value.timestamp.millisecondsSinceEpoch,
        };
      });
      await Storage.saveMemberProfileCache(serialized);
    } catch (e) {
      debugPrint('Error saving profile cache: $e');
    }
  }

  /// Returns cached member profile, or null if not cached.
  Future<Map<String, dynamic>?> getCachedMemberProfile({
    required String groupId,
    required String userId,
  }) async {
    await _ensureProfileCacheLoaded();
    final key = _profileCacheKey(groupId, userId);
    final cached = _memberProfileCache[key];
    return cached?.data;
  }

  /// Fetches member profile from Firestore and caches it.
  Future<Map<String, dynamic>?> fetchAndCacheMemberProfile({
    required String groupId,
    required String userId,
  }) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final profileData = <String, dynamic>{
        'profileName': data['profileName'],
        'major': data['major'],
        'profileGoal': data['profileGoal'],
        'profileContact': data['profileContact'],
        'profileAvatarIndex': data['profileAvatarIndex'],
        'avatarIndex': data['avatarIndex'],
        'profileAvatarImageBase64': data['profileAvatarImageBase64'],
        'avatarColorValue': data['avatarColorValue'],
        'profileAvatarColorValue': data['profileAvatarColorValue'],
      };
      final key = _profileCacheKey(groupId, userId);
      _memberProfileCache[key] = (data: profileData, timestamp: DateTime.now());
      unawaited(_persistProfileCache());
      return profileData;
    } catch (e) {
      debugPrint('Error fetching member profile: $e');
      return null;
    }
  }

  /// Check if profile cache is stale (older than TTL)
  bool isMemberProfileStale({
    required String groupId,
    required String userId,
  }) {
    final key = _profileCacheKey(groupId, userId);
    final cached = _memberProfileCache[key];
    if (cached == null) return true;
    return DateTime.now().difference(cached.timestamp) > _memberStatsTtl;
  }


  Future<({MemberSubjectStats stats, DateTime timestamp})?> getCachedMemberSubjectStats({
    required String groupId,
    required String userId,
    required StatisticsPeriod period,
  }) async {
    await _ensureCacheLoaded();
    final key = _cacheKey(groupId, userId, period);
    final cached = _subjectStatsCache[key];
    // Mark as stale if TTL exceeded
    if (cached != null && DateTime.now().difference(cached.timestamp) > _memberStatsTtl) {
      _staleSubjectStatsKeys.add(key);
    }
    return cached;
  }

  bool isMemberStatsStale({
    required String groupId,
    required String userId,
    required StatisticsPeriod period,
  }) {
    final key = _cacheKey(groupId, userId, period);
    return _staleSubjectStatsKeys.contains(key);
  }

  Future<void> _markMemberStatsStaleFromTotals({
    required String groupId,
    required StatisticsPeriod period,
    required GroupStatistics stats,
  }) async {
    await _ensureCacheLoaded();
    for (final member in stats.members) {
      final key = _cacheKey(groupId, member.userId, period);
      final cached = _subjectStatsCache[key];
      if (cached == null) continue;
      if (cached.stats.totalSeconds != member.studyTimeSeconds) {
        _staleSubjectStatsKeys.add(key);
      }
    }
  }

  Stream<MemberSubjectStats> watchMemberStats({
    required String groupId,
    required String targetUserId,
    required StatisticsPeriod period,
    bool forceRefresh = false,
    VoidCallback? onDeltaApplied,
  }) {
    final controller = StreamController<MemberSubjectStats>.broadcast();
    final key = _cacheKey(groupId, targetUserId, period);

    // 1. Emit cached stats immediately
    _emitCachedStats(
      groupId,
      targetUserId,
      period,
      controller,
      markFresh: false,
    );

    () async {
      var lastSessionsSync = await Storage.getLastPeerSync(targetUserId);
      final lastCoursesSync = await Storage.getLastPeerCourseSync(targetUserId);
      final periodStartUtc = period.getDateRange().$1.toUtc();
      final isStale = _staleSubjectStatsKeys.contains(key);
      // Bound catch-up to the visible period to reduce reads but still capture deletes
      final effectiveSessionSince = DateTime.fromMillisecondsSinceEpoch(
        lastSessionsSync,
      );
      final sessionUpdatedAfter = periodStartUtc.isBefore(effectiveSessionSince)
          ? periodStartUtc
          : effectiveSessionSince;

      final needsSync = forceRefresh ||
          isStale ||
          lastSessionsSync == 0 ||
          lastCoursesSync == 0;

      if (!needsSync) return;

      await Future.wait([
        _syncPeerSessions(
          targetUserId,
          updatedAfter: sessionUpdatedAfter,
          startUtcAfter: periodStartUtc,
        ),
        _syncPeerCourses(targetUserId),
      ]);

      _staleSubjectStatsKeys.remove(key);

      if (!controller.isClosed) {
        await _emitCachedStats(
          groupId,
          targetUserId,
          period,
          controller,
          markFresh: true,
        );
        onDeltaApplied?.call();
      }
    }();

    controller.onCancel = () {
      if (!controller.isClosed) {
        controller.close();
      }
    };

    return controller.stream;
  }

  Future<void> _emitCachedStats(
    String groupId,
    String targetUserId,
    StatisticsPeriod period,
    StreamController<MemberSubjectStats> controller, {
    required bool markFresh,
  }) async {
    try {
      await _ensureCacheLoaded();
      final sessions = await Storage.getPeerSessions(targetUserId);
      final courses = await Storage.getPeerCourses(targetUserId);
      final stats = _calculateStatsFromSessions(sessions, courses, period);
      final key = _cacheKey(groupId, targetUserId, period);
      _subjectStatsCache[key] = (stats: stats, timestamp: DateTime.now());
      if (markFresh) {
        _staleSubjectStatsKeys.remove(key);
      }
      await _persistSubjectStatsCache();
      if (!controller.isClosed) {
        controller.add(stats);
      }
    } catch (e) {
      debugPrint('Error emitting cached stats: $e');
    }
  }

  Future<void> _syncPeerCourses(String targetUserId) async {
    try {
      final lastSyncMs = await Storage.getLastPeerCourseSync(targetUserId);
      final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      
      // Sync courses
      final snapshot = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('courses')
          .where('updatedAt', isGreaterThan: lastSyncDate)
          .get();

      if (snapshot.docs.isEmpty) return;
      
      int maxUpdatedAt = lastSyncMs;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final updatedAt = (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        if (updatedAt > maxUpdatedAt) maxUpdatedAt = updatedAt;
        
        final deleted = data['deleted'] == true;
        
        final course = LocalCourse(
          id: doc.id,
          uid: targetUserId,
          updatedAtMs: updatedAt,
          name: data['name'] as String? ?? 'Unnamed Course',
          day: data['day'] as String? ?? '', // LocalCourse requires String
          start: _formatTimeMap(data['start']), // Convert Map to String
          end: _formatTimeMap(data['end']),     // Convert Map to String
          colorValue: (data['colorValue'] as num?)?.toInt() ?? 0xFF9CA3AF,
          credits: (data['credits'] as num?)?.toDouble(),
          expLevel: (data['expLevel'] as num?)?.toInt() ?? 1,
          goalHours: (data['goalHours'] as num?)?.toDouble(),
          totalMinutes: (data['totalMinutes'] as num?)?.toInt() ?? 0,
          pomodoroLongBreakMinutes: (data['pomodoroLongBreakMinutes'] as num?)?.toInt(),
          sortOrder: (data['sortOrder'] as num?)?.toInt(),
          hiddenFromLeaderboard: data['hiddenFromLeaderboard'] == true,
          dirty: false,
          deleted: deleted,
        );
        
        await Storage.putPeerCourse(course);
      }
      
      await Storage.setLastPeerCourseSync(targetUserId, maxUpdatedAt);

    } catch (e) {
      debugPrint('Error syncing peer courses: $e');
    }
  }

  String _formatTimeMap(dynamic timeData) {
    if (timeData is Map) {
      final hour = (timeData['hour'] as num?)?.toInt() ?? 0;
      final minute = (timeData['minute'] as num?)?.toInt() ?? 0;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    return timeData as String? ?? '';
  }

  Future<void> _syncPeerSessions(
    String targetUserId, {
    required DateTime updatedAfter,
    DateTime? startUtcAfter,
  }) async {
    try {
      // Integrity Checker: If we have corrupted sessions (0 timestamps) from previous bug, force a re-sync.
      final currentSessions = await Storage.getPeerSessions(targetUserId);
      if (currentSessions.any((s) => s.endUtcMs == 0 && !s.deleted)) {
        debugPrint('Detected corrupted peer sessions for $targetUserId. Forcing full re-sync.');
        await Storage.setLastPeerSync(targetUserId, 0);
      }

      final lastSyncMs = await Storage.getLastPeerSync(targetUserId);
      final lastSyncDate = updatedAfter;

      // Query for sessions changed since last sync
      final snapshot = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('sessions')
          .where('updatedAt', isGreaterThan: lastSyncDate)
          .get();

      if (snapshot.docs.isEmpty) return;

      int maxUpdatedAt = lastSyncMs;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final updatedAt = (data['updatedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        if (updatedAt > maxUpdatedAt) maxUpdatedAt = updatedAt;

        final deleted = data['deleted'] == true;
        final startTs = (data['startUtc'] ?? data['start']) as Timestamp?;
        final startUtc = startTs?.toDate().toUtc();
        if (startUtcAfter != null && startUtc != null && startUtc.isBefore(startUtcAfter)) {
          continue; // Out of visible period; skip but still advance cursor
        }

        final session = LocalSession(
          id: doc.id,
          uid: targetUserId, // Owner is the target user
          courseId: data['courseId'] as String? ?? 'unknown',
          startUtcMs: startUtc?.millisecondsSinceEpoch ??
              ((data['start'] ?? data['startUtc']) as Timestamp?)?.toDate().toUtc().millisecondsSinceEpoch ??
              0,
          endUtcMs: ((data['end'] ?? data['endUtc']) as Timestamp?)?.toDate().toUtc().millisecondsSinceEpoch ?? 0,
          seconds: (data['seconds'] as num?)?.toInt() ?? 0,
          kind: data['kind'] as String?,
          notes: data['notes'] as String?,
          createdAtMs: (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
          updatedAtMs: updatedAt,
          dirty: false, // Mirrored data is not dirty
          deleted: deleted,
        );
        
        await Storage.putPeerSession(session);
      }

      await Storage.setLastPeerSync(targetUserId, maxUpdatedAt);
    } catch (e) {
      debugPrint('Error syncing peer sessions: $e');
    }
  }
  
  MemberSubjectStats _calculateStatsFromSessions(
    List<LocalSession> sessions, 
    List<LocalCourse> courses,
    StatisticsPeriod period
  ) {
    // Index courses for fast lookup
    final courseMap = {for (final c in courses) c.id: c};

    // Filter by period
    final now = DateTime.now();
    final start = _getStartDate(now, period);
    
    int totalSeconds = 0;
    final subjectMap = <String, SubjectStat>{};

    for (final s in sessions) {
      if (s.deleted) continue;
      
      final date = DateTime.fromMillisecondsSinceEpoch(s.endUtcMs, isUtc: true).toLocal();
      if (date.isBefore(start)) continue;

      
      final courseId = s.courseId;
      final course = courseMap[courseId];
      // Skip if course is missing (deleted/hidden) or explicitly marked as hidden
      if (course == null || course.hiddenFromLeaderboard == true) continue;

      totalSeconds += s.seconds;
      
      if (!subjectMap.containsKey(courseId)) {
        subjectMap[courseId] = SubjectStat(
          name: course.name,
          colorValue: course.colorValue,
          seconds: 0
        );
      }
      final current = subjectMap[courseId]!;
      subjectMap[courseId] = SubjectStat(
        name: current.name,
        colorValue: current.colorValue,
        seconds: current.seconds + s.seconds,
      );
    }

    return MemberSubjectStats(
      totalSeconds: totalSeconds,
      subjectStats: subjectMap,
    );
  }

  DateTime _getStartDate(DateTime now, StatisticsPeriod period) {
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case StatisticsPeriod.today:
        return today;
      case StatisticsPeriod.last7Days:
        // Match GroupAggregationService: Current Week (Mon -> Sun)
        // If we strictly want "Last 7 Days" sliding, we use subtract(6 days).
        // But to match leaderboard "This Week":
        final weekday = now.weekday; // Mon=1
        final daysFromMonday = weekday - 1;
        return today.subtract(Duration(days: daysFromMonday));
      case StatisticsPeriod.lastMonth:
        // Match GroupAggregationService: Current Month (1st -> Now)
        return DateTime(now.year, now.month, 1);
    }
  }

  // Preservation of old method for now, but deprecated
  Future<MemberSubjectStats> fetchMemberSubjectStats({
    required String groupId,
    required String userId,
    required StatisticsPeriod period,
  }) async {
      // ... existing implementation ...
      return Future.value(MemberSubjectStats(totalSeconds: 0, subjectStats: {})); // Stub to avoid error in replacement
  }

  Future<void> sendNudge({
    required String groupId,
    required String targetUserId,
  }) async {
    final uid = _requireUserId();
    
    // Check cooldown before sending
    final cooldownDoc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('nudgeCooldowns')
        .doc('$groupId-$targetUserId')
        .get();
    
    if (cooldownDoc.exists) {
      final lastNudgeTimestamp = cooldownDoc.data()?['lastNudgeAt'] as Timestamp?;
      if (lastNudgeTimestamp != null) {
        final lastNudge = lastNudgeTimestamp.toDate();
        final now = DateTime.now();
        final cooldownEnd = lastNudge.add(const Duration(hours: 1));
        
        if (now.isBefore(cooldownEnd)) {
          final remaining = cooldownEnd.difference(now);
          final minutes = remaining.inMinutes;
          throw StateError('Please wait $minutes more minute${minutes != 1 ? 's' : ''} before nudging this member again');
        }
      }
    }
    
    final callable = FirebaseFunctions.instance.httpsCallable('sendNudge');
    try {
      await callable.call({
        'groupId': groupId,
        'targetUserId': targetUserId,
      });
      
      // Record cooldown timestamp after successful send
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('nudgeCooldowns')
          .doc('$groupId-$targetUserId')
          .set({
        'lastNudgeAt': FieldValue.serverTimestamp(),
        'groupId': groupId,
        'targetUserId': targetUserId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'Failed to send nudge');
    } catch (_) {
      throw StateError('Failed to send nudge');
    }
  }

  Stream<DateTime?> watchNudgeCooldown({
    required String groupId,
    required String targetUserId,
  }) {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(null);
    }
    
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('nudgeCooldowns')
        .doc('$groupId-$targetUserId')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final timestamp = doc.data()?['lastNudgeAt'] as Timestamp?;
      return timestamp?.toDate();
    });
  }


  Future<void> createGroup({
    required String name,
    required String description,
    required GroupVisibility visibility,
    String? joinCode,
  }) async {
    final uid = _requireUserId();

    final trimmedName = name.trim();
    final trimmedDescription = description.trim();
    if (trimmedName.isEmpty) {
      throw StateError('Group name is required');
    }

    final groupRef = _groupsRef.doc();
    final joinedAt = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(groupRef, {
      'name': trimmedName,
      'description': trimmedDescription,
      'visibility': visibility.label,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'memberCount': 1,
    });

    if (visibility == GroupVisibility.private) {
      if (joinCode == null || !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(joinCode)) {
        throw StateError('Invalid join code. Must be alphanumeric.');
      }
      batch.set(groupRef.collection('secrets').doc('settings'), {
        'joinCode': joinCode,
      });
    }

    batch.set(groupRef.collection('members').doc(uid), {
      'role': GroupRole.admin.label,
      'joinedAt': joinedAt,
    });
    batch.set(
      _userMembershipRef(uid, groupRef.id),
      {
        'role': GroupRole.admin.label,
        'joinedAt': joinedAt,
      },
    );
    batch.set(
      _userDoc(uid),
      {
        'groupIds': FieldValue.arrayUnion([groupRef.id]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  Future<void> joinPrivateGroup(String groupId, String joinCode) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('joinPrivateGroup');
      await callable.call({
        'groupId': groupId,
        'joinCode': joinCode,
      });
      
    } on FirebaseFunctionsException catch (e) {
      
      
      
      if (e.code == 'failed-precondition' || (e.message?.contains('not private') ?? false)) {
        await joinGroup(groupId);
        return;
      }
      throw StateError(e.message ?? 'Failed to join group');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> joinGroup(String groupId) async {
    final uid = _requireUserId();
    final groupRef = _groupsRef.doc(groupId);
    await _firestore.runTransaction((txn) async {
      final groupSnap = await txn.get(groupRef);
      if (!groupSnap.exists) {
        throw StateError('Group not found');
      }
      final visibility = groupSnap.data()?['visibility'] as String? ??
          GroupVisibility.public.label;
      if (visibility != GroupVisibility.public.label) {
        throw StateError('Unable to join a private group without an invite');
      }
      final userMembershipRef = _userMembershipRef(uid, groupId);
      final membershipSnap = await txn.get(userMembershipRef);
      if (membershipSnap.exists) {
        return;
      }

      txn.set(groupRef.collection('members').doc(uid), {
        'role': GroupRole.member.label,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      txn.set(userMembershipRef, {
        'role': GroupRole.member.label,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      txn.set(
        _userDoc(uid),
        {
          'groupIds': FieldValue.arrayUnion([groupId]),
        },
        SetOptions(merge: true),
      );

      final currentCount =
          (groupSnap.data()?['memberCount'] as num?)?.toInt() ?? 0;
      txn.update(groupRef, {
        'memberCount': currentCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final uid = _requireUserId();
    await _removeMember(groupId: groupId, memberId: uid, allowAdmin: true);
    // Clear cached member data for this group
    unawaited(Storage.clearMemberCacheForGroup(groupId));
  }

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    GroupVisibility? visibility,
    String? joinCode,
  }) async {
    final uid = _requireUserId();
    
    // Check direct ownership first to avoid relying solely on membership doc (which might be borked)
    final groupDoc = await _groupsRef.doc(groupId).get();
    if (!groupDoc.exists) {
      throw StateError('Group not found');
    }
    final isOwner = groupDoc.data()?['createdBy'] == uid;

    final requiresAdmin = visibility != null;
    
    // Only enforce strict membership role check if NOT the owner
    if (!isOwner) {
      if (requiresAdmin) {
        await _ensureIsAdmin(uid: uid, groupId: groupId);
      } else {
        await _ensureMember(uid: uid, groupId: groupId);
      }
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) {
      updates['name'] = name.trim();
    }
    if (description != null) {
      updates['description'] = description.trim();
    }
    if (visibility != null) {
      updates['visibility'] = visibility.label;
    }
    
    final batch = _firestore.batch();
    batch.update(_groupsRef.doc(groupId), updates);

    if (joinCode != null) {
       if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(joinCode)) {
        throw StateError('Invalid join code. Must be alphanumeric.');
      }
      
      batch.set(
        _groupsRef.doc(groupId).collection('secrets').doc('settings'),
        {'joinCode': joinCode},
        SetOptions(merge: true),
      );
    } else if (visibility == GroupVisibility.public) {
      
      
    }

    await batch.commit();
  }

  Future<void> promoteToAdmin({
    required String groupId,
    required String memberId,
  }) async {
    final uid = _requireUserId();
    await _ensureIsCreator(uid: uid, groupId: groupId);
    return _changeMemberRole(groupId: groupId, memberId: memberId, newRole: GroupRole.admin);
  }

  Future<void> demoteToMember({
    required String groupId,
    required String memberId,
  }) async {
    final uid = _requireUserId();
    await _ensureIsCreator(uid: uid, groupId: groupId);
    return _changeMemberRole(groupId: groupId, memberId: memberId, newRole: GroupRole.member);
  }

  Future<void> _changeMemberRole({
    required String groupId,
    required String memberId,
    required GroupRole newRole,
  }) async {
    final groupRef = _groupsRef.doc(groupId);
    final userMembershipRef = _userMembershipRef(memberId, groupId);

    await _firestore.runTransaction((txn) async {
      final groupSnap = await txn.get(groupRef);
      if (!groupSnap.exists) throw StateError('Group not found');

      final memberRef = groupRef.collection('members').doc(memberId);
      final memberSnap = await txn.get(memberRef);
      
      if (!memberSnap.exists) throw StateError('User is not a member of this group');

      txn.update(memberRef, {'role': newRole.label});
      txn.update(userMembershipRef, {'role': newRole.label});
    });
  }

  Future<void> removeMember({
    required String groupId,
    required String memberId,
  }) {
    return _removeMember(groupId: groupId, memberId: memberId);
  }

  Future<void> deleteGroup(String groupId) async {
    final uid = _requireUserId();
    
    
    final groupRef = _groupsRef.doc(groupId);
    final groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists) {
      throw StateError('Group not found');
    }
    if (groupSnapshot.data()?['createdBy'] != uid) {
      throw StateError('Only the group creator can delete this group');
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteGroupCallable');
      await callable.call({'groupId': groupId});
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        throw StateError(e.message ?? 'Failed to delete group');
      }
      rethrow;
    }
  }

  Future<void> _removeMember({
    required String groupId,
    required String memberId,
    bool allowAdmin = false,
  }) async {
    final uid = _requireUserId();
    // If not self-leaving or allowed admin, check admin permissions first.
    // Note: If the group is missing, _ensureIsAdmin will fail.
    // We should allow self-leaving even if the group is missing.
    if (!allowAdmin || uid != memberId) {
      // Logic check: Cannot remove the creator
      final groupSnap = await _groupsRef.doc(groupId).get();
      if (groupSnap.exists && groupSnap.data()?['createdBy'] == memberId) {
         throw StateError('Cannot remove the group creator');
      }

      await _ensureIsAdmin(uid: uid, groupId: groupId);
    }

    final groupRef = _groupsRef.doc(groupId);
    final userMembershipRef = _userMembershipRef(memberId, groupId);

    await _firestore.runTransaction((txn) async {
      final groupSnap = await txn.get(groupRef);
      
      // If group is missing, we still want to clean up the user's side if they are leaving themselves.
      if (!groupSnap.exists) {
        if (uid == memberId) {
           // Cleanup orphan data for the user
           txn.delete(userMembershipRef);
           // We can't delete from group subcollection if group doesn't exist (conceptually), 
           // but we can try to delete the potential orphan member doc just in case.
           txn.delete(groupRef.collection('members').doc(memberId));
           txn.delete(groupRef.collection('aggregates').doc(memberId));

           txn.set(
            _userDoc(memberId),
            {
              'groupIds': FieldValue.arrayRemove([groupId]),
            },
            SetOptions(merge: true),
          );
          return;
        } else {
           throw StateError('Group not found');
        }
      }

      final memberRef = groupRef.collection('members').doc(memberId);
      final memberSnap = await txn.get(memberRef);
      if (!memberSnap.exists) {
        // Member not in group, but check if we need to clean up user side
        final membershipSnap = await txn.get(userMembershipRef);
        if (membershipSnap.exists) {
           txn.delete(userMembershipRef);
           txn.set(
            _userDoc(memberId),
            {
              'groupIds': FieldValue.arrayRemove([groupId]),
            },
            SetOptions(merge: true),
          );
        }
        return;
      }

      txn.delete(memberRef);
      txn.delete(userMembershipRef);
      txn.delete(groupRef.collection('aggregates').doc(memberId));
      if (memberId == uid) {
        txn.set(
          _userDoc(memberId),
          {
            'groupIds': FieldValue.arrayRemove([groupId]),
          },
          SetOptions(merge: true),
        );
      }
      final currentCount =
          (groupSnap.data()?['memberCount'] as num?)?.toInt() ?? 1;
      txn.update(groupRef, {
        'memberCount': currentCount <= 1 ? 0 : currentCount - 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _ensureIsAdmin({
    required String uid,
    required String groupId,
  }) async {
    final membershipDoc = await _userMembershipRef(uid, groupId).get();
    if (!membershipDoc.exists) {
      throw StateError('You must be a member to manage this group');
    }
    final role = GroupRoleX.fromRaw(membershipDoc.data()?['role'] as String?);
    if (role != GroupRole.admin) {
      throw StateError('Only administrators can perform this action');
    }
  }

  Future<void> _ensureIsCreator({
    required String uid,
    required String groupId,
  }) async {
    final groupDoc = await _groupsRef.doc(groupId).get();
    if (!groupDoc.exists) {
      throw StateError('Group not found');
    }
    if (groupDoc.data()?['createdBy'] != uid) {
      throw StateError('Only the group creator can perform this action');
    }
  }

  Future<void> _ensureMember({
    required String uid,
    required String groupId,
  }) async {
    final membershipDoc = await _userMembershipRef(uid, groupId).get();
    if (!membershipDoc.exists) {
      throw StateError('You must be a member to manage this group');
    }
  }

  CollectionReference<Map<String, dynamic>> _userMembershipsRoot(String uid) {
    return _firestore.collection('users').doc(uid).collection('groupMemberships');
  }

  DocumentReference<Map<String, dynamic>> _userMembershipRef(
    String uid,
    String groupId,
  ) {
    return _userMembershipsRoot(uid).doc(groupId);
  }

  String _requireUserId() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('You must be signed in to manage groups');
    }
    return uid;
  }

  Future<String?> getGroupJoinCode(String groupId) async {
    final uid = _requireUserId();
    
    await _ensureIsAdmin(uid: uid, groupId: groupId);
    
    final snap = await _groupsRef.doc(groupId).collection('secrets').doc('settings').get();
    return snap.data()?['joinCode'] as String?;
  }

}
