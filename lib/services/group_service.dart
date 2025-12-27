import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';

import '../models/group.dart';
import '../models/group_statistics.dart';
import 'group_aggregation_service.dart';

class GroupService {
  GroupService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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

  
  
  Stream<GroupStatistics> watchGroupStatistics(String groupId, StatisticsPeriod period) {
    final controller = StreamController<GroupStatistics>.broadcast();

    StreamSubscription? membersSub;
    StreamSubscription? aggregatesSub;
    bool hasTerminated = false;
    Set<String> memberIds = {};
    final uid = _uid;
    Timer? dailyRefreshTimer;
    Timer? debounceTimer;
    bool refreshScheduled = false;
    bool isComputing = false;

    Future<void> cleanup({bool shouldCloseController = false}) async {
      await membersSub?.cancel();
      await aggregatesSub?.cancel();
      dailyRefreshTimer?.cancel();
      debounceTimer?.cancel();
      if (shouldCloseController && !controller.isClosed) {
        await controller.close();
      }
    }

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

    void scheduleDailyRefresh() {
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

      
      membersSub ??= _groupsRef
          .doc(groupId)
          .collection('members')
          .snapshots()
          .listen((membersSnap) {
        memberIds = membersSnap.docs.map((d) => d.id).toSet();
        triggerRecompute();
      }, onError: handleStreamError);

      
      aggregatesSub ??= _groupsRef
          .doc(groupId)
          .collection('aggregates')
          .snapshots()
          .listen((_) {
        triggerRecompute();
      }, onError: handleStreamError);

      if (!refreshScheduled) {
        refreshScheduled = true;
        scheduleDailyRefresh();
      }
    }, onError: handleStreamError);

    controller.onCancel = () => cleanup(shouldCloseController: true);

    return controller.stream;
  }

  
  
  Future<MemberSubjectStats> fetchMemberSubjectStats({
    required String groupId,
    required String userId,
    required StatisticsPeriod period,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'getMemberSubjectStats',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    try {
      final result = await callable.call({
        'groupId': groupId,
        'userId': userId,
        'period': switch (period) {
          StatisticsPeriod.today => 'today',
          StatisticsPeriod.last7Days => 'last7Days',
          StatisticsPeriod.lastMonth => 'lastMonth',
        },
        'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final totalSeconds = (data['totalSeconds'] as num?)?.toInt() ?? 0;
      final rawStats = Map<String, dynamic>.from(
        (data['subjectStats'] as Map?) ?? const <String, dynamic>{},
      );
      final subjectStats = <String, SubjectStat>{};
      rawStats.forEach((key, value) {
        final map = Map<String, dynamic>.from(value as Map);
        subjectStats[key] = SubjectStat(
          name: (map['name'] as String?) ?? 'Unknown Course',
          colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF9CA3AF,
          seconds: (map['seconds'] as num?)?.toInt() ?? 0,
        );
      });

      return MemberSubjectStats(
        totalSeconds: totalSeconds,
        subjectStats: subjectStats,
      );
    } on FirebaseFunctionsException catch (e) {
      throw StateError(e.message ?? 'Failed to load subject stats');
    }
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
