import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { requireAppCheck } from '../shared/app_check';
import { PeriodKey, resolvePeriodRange } from '../shared/periods';

export const deleteGroupCallable = functions.https.onCall(async (data, context) => {
  requireAppCheck(context, 'deleteGroupCallable');
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { groupId } = data;
  if (!groupId) {
    throw new functions.https.HttpsError('invalid-argument', 'The function must be called with a groupId.');
  }

  const uid = context.auth.uid;
  const groupRef = db.collection('groups').doc(groupId);
  const groupSnap = await groupRef.get();

  if (!groupSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Group not found');
  }

  if (groupSnap.data()?.createdBy !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Only the group creator can delete this group');
  }

  // 1. Get all members to clean up their user documents
  const membersSnap = await groupRef.collection('members').get();
  const memberIds = membersSnap.docs.map(doc => doc.id);

  // 2. Recursively delete the group and all subcollections
  // This handles members, invites, aggregates, etc.
  await db.recursiveDelete(groupRef);

  // 3. Cleanup user memberships (this might be partially handled by recursiveDelete if they were subcollections, 
  // but user.groupMemberships are in the user document)
  const batch = db.batch();

  for (const memberId of memberIds) {
    const userRef = db.collection('users').doc(memberId);
    const membershipRef = userRef.collection('groupMemberships').doc(groupId);

    batch.delete(membershipRef);
    batch.set(userRef, {
      groupIds: admin.firestore.FieldValue.arrayRemove(groupId)
    }, { merge: true });
  }

  await batch.commit();

  return { success: true };
});

export const joinPrivateGroup = functions.https.onCall(async (data, context) => {
  requireAppCheck(context, 'joinPrivateGroup');
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { groupId, joinCode } = data;
  if (!groupId || !joinCode) {
    throw new functions.https.HttpsError('invalid-argument', 'Group ID and join code are required.');
  }

  // Validate join code format (alphanumeric only)
  if (!/^[a-zA-Z0-9]+$/.test(joinCode)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid join code format.');
  }

  const uid = context.auth.uid;
  const groupRef = db.collection('groups').doc(groupId);

  await db.runTransaction(async (txn) => {
    const groupSnap = await txn.get(groupRef);
    if (!groupSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Group not found');
    }

    const groupData = groupSnap.data();
    const visibility = groupData?.visibility || 'public';

    if (visibility !== 'private') {
      throw new functions.https.HttpsError('failed-precondition', 'This group is not private. You can join it directly.');
    }

    // Check if user is already a member
    const membershipRef = db.collection('users').doc(uid).collection('groupMemberships').doc(groupId);
    const membershipSnap = await txn.get(membershipRef);
    if (membershipSnap.exists) {
      return; // already a member, nothing else to do
    }

    // Verify Join Code
    // We store secrets in a subcollection to prevent public read access via client SDKs
    // Assuming admin creates this doc when setting group to private
    const secretRef = groupRef.collection('secrets').doc('settings');
    const secretSnap = await txn.get(secretRef);

    if (!secretSnap.exists) {
      // Fallback or error if secret config is missing.
      // If no code is set, maybe deny?
      throw new functions.https.HttpsError('internal', 'Group configuration error. No join code set.');
    }

    const storedCode = secretSnap.data()?.joinCode;
    if (storedCode !== joinCode) {
      throw new functions.https.HttpsError('permission-denied', 'Incorrect join code.');
    }

    // Code is correct, add member
    const memberRef = groupRef.collection('members').doc(uid);
    const now = admin.firestore.FieldValue.serverTimestamp();

    txn.set(memberRef, {
      role: 'member',
      joinedAt: now,
    });

    txn.set(membershipRef, {
      groupId,
      role: 'member',
      joinedAt: now,
    });

    txn.set(db.collection('users').doc(uid), {
      groupIds: admin.firestore.FieldValue.arrayUnion(groupId)
    }, { merge: true });

    const currentCount = (groupData?.memberCount || 0) as number;
    txn.update(groupRef, {
      memberCount: currentCount + 1,
      updatedAt: now,
    });
  });

  return { success: true };
});

export const getMemberSubjectStats = functions.https.onCall(async (data, context) => {
  requireAppCheck(context, 'getMemberSubjectStats');
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const groupId = typeof data?.groupId === 'string' ? data.groupId : '';
  const userId = typeof data?.userId === 'string' ? data.userId : '';
  const periodRaw = data?.period as PeriodKey | undefined;
  const timezoneOffsetMinutes = Number.isFinite(data?.timezoneOffsetMinutes)
    ? Number(data.timezoneOffsetMinutes)
    : 0;

  if (!groupId || !userId) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId and userId are required.');
  }
  if (!periodRaw || !['today', 'last7Days', 'lastMonth'].includes(periodRaw)) {
    throw new functions.https.HttpsError('invalid-argument', 'period must be one of today, last7Days, lastMonth.');
  }

  const callerId = context.auth.uid;
  const groupRef = db.collection('groups').doc(groupId);
  const [groupSnap, callerMembershipSnap, targetMembershipSnap, targetAggregateSnap] = await Promise.all([
    groupRef.get(),
    groupRef.collection('members').doc(callerId).get(),
    groupRef.collection('members').doc(userId).get(),
    groupRef.collection('aggregates').doc(userId).get(),
  ]);

  if (!groupSnap.exists) {
    throw new functions.https.HttpsError('not-found', `Group ${groupId} not found.`);
  }
  if (!callerMembershipSnap.exists) {
    const groupData = groupSnap.data();
    if (groupData?.visibility !== 'public') {
      throw new functions.https.HttpsError('permission-denied', 'You are not a member of this group.');
    }
  }
  // Check if target is a member OR has data in the group (aggregates)
  if (!targetMembershipSnap.exists && !targetAggregateSnap.exists) {
    const groupData = groupSnap.data();
    if (groupData?.visibility !== 'public') {
      throw new functions.https.HttpsError('not-found', `User ${userId} is not a member of group ${groupId}.`);
    }
  }

  const { start, end } = resolvePeriodRange(periodRaw, timezoneOffsetMinutes);
  const sessionsSnap = await db.collection('users').doc(userId)
    .collection('sessions')
    .where('startUtc', '>=', admin.firestore.Timestamp.fromDate(start))
    .where('startUtc', '<=', admin.firestore.Timestamp.fromDate(end))
    .get();

  const courseTotals = new Map<string, number>();
  let totalSeconds = 0;

  for (const doc of sessionsSnap.docs) {
    const data = doc.data();
    const deleted = (data.deleted as boolean) || false;
    const seconds = (data.seconds as number) || 0;
    if (deleted || seconds <= 0) continue;
    const courseId = (data.courseId as string) || 'unknown';
    totalSeconds += seconds;
    courseTotals.set(courseId, (courseTotals.get(courseId) || 0) + seconds);
  }

  const subjectStats: Record<string, { name: string; colorValue: number; seconds: number }> = {};
  const courseIds = Array.from(courseTotals.keys());
  const coursesRef = db.collection('users').doc(userId).collection('courses');
  const chunkSize = 10;
  for (let i = 0; i < courseIds.length; i += chunkSize) {
    const chunk = courseIds.slice(i, i + chunkSize);
    const snap = await coursesRef.where(admin.firestore.FieldPath.documentId(), 'in', chunk).get();
    for (const courseDoc of snap.docs) {
      const cdata = courseDoc.data();
      const name = typeof cdata.name === 'string' && cdata.name.trim().length > 0
        ? cdata.name
        : 'Unknown Course';
      const colorValue = typeof cdata.colorValue === 'number' ? cdata.colorValue : 0xFF9CA3AF;
      subjectStats[courseDoc.id] = {
        name,
        colorValue,
        seconds: courseTotals.get(courseDoc.id) || 0,
      };
    }
  }

  // Fill in any missing course details with defaults
  for (const [courseId, seconds] of courseTotals.entries()) {
    if (!subjectStats[courseId]) {
      subjectStats[courseId] = {
        name: 'Unknown Course',
        colorValue: 0xFF9CA3AF,
        seconds,
      };
    }
  }

  return {
    totalSeconds,
    subjectStats,
  };
});
