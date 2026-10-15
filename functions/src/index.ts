import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

function isEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === 'true' || !!process.env.FIREBASE_EMULATOR_HUB;
}

function requireAppCheck(context: functions.https.CallableContext) {
  return; // DISABLED: Allow access even if App Check fails
  /*
  if (isEmulator()) {
    return;
  }
  if (!context.app) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'App Check token is required.'
    );
  }
  */
}

async function deleteQueryBatch(
  query: FirebaseFirestore.Query,
  batchSize = 250,
) {
  while (true) {
    const snapshot = await query.limit(batchSize).get();
    if (snapshot.empty) break;
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    if (snapshot.size < batchSize) break;
  }
}

async function deleteUserCollections(userId: string, names: string[]) {
  const userRef = db.collection('users').doc(userId);
  await Promise.all(
    names.map((name) => deleteQueryBatch(userRef.collection(name))),
  );
}

async function deleteGroupCascade(groupRef: FirebaseFirestore.DocumentReference) {
  const groupId = groupRef.id;
  const membersSnap = await groupRef.collection('members').get();
  const memberIds = membersSnap.docs.map((doc) => doc.id);

  await db.recursiveDelete(groupRef);

  const chunkSize = 400;
  for (let i = 0; i < memberIds.length; i += chunkSize) {
    const batch = db.batch();
    const slice = memberIds.slice(i, i + chunkSize);
    for (const memberId of slice) {
      const userRef = db.collection('users').doc(memberId);
      const membershipRef = userRef.collection('groupMemberships').doc(groupId);
      batch.delete(membershipRef);
      batch.set(
        userRef,
        { groupIds: admin.firestore.FieldValue.arrayRemove(groupId) },
        { merge: true },
      );
    }
    await batch.commit();
  }
}

async function removeUserMemberships(userId: string, ownedGroupIds: Set<string>) {
  const membershipSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('groupMemberships')
    .get();

  const chunkSize = 400;
  for (let i = 0; i < membershipSnapshot.docs.length; i += chunkSize) {
    const slice = membershipSnapshot.docs.slice(i, i + chunkSize);
    const groupIds = slice.map((doc) => doc.id);
    const groupSnaps = await Promise.all(
      groupIds.map((groupId) => db.collection('groups').doc(groupId).get()),
    );

    const batch = db.batch();
    for (let j = 0; j < slice.length; j++) {
      const membership = slice[j];
      const groupId = membership.id;
      const groupSnap = groupSnaps[j];
      const groupRef = db.collection('groups').doc(groupId);

      batch.delete(groupRef.collection('members').doc(userId));
      batch.delete(groupRef.collection('aggregates').doc(userId));
      batch.delete(membership.ref);

      if (!ownedGroupIds.has(groupId) && groupSnap.exists) {
        batch.set(
          groupRef,
          {
            memberCount: admin.firestore.FieldValue.increment(-1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }
    await batch.commit();
  }
}



function startOfDay(d: Date) {
  // Return start of day in UTC
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 0, 0, 0));
}

type PeriodKey = 'today' | 'last7Days' | 'lastMonth';

function resolvePeriodRange(period: PeriodKey, timezoneOffsetMinutes = 0) {
  const offsetMs = timezoneOffsetMinutes * 60 * 1000;
  const shiftedNow = new Date(Date.now() + offsetMs); // pretend server is in the caller's TZ

  const endOfTodayShifted = new Date(Date.UTC(
    shiftedNow.getUTCFullYear(),
    shiftedNow.getUTCMonth(),
    shiftedNow.getUTCDate(),
    23, 59, 59, 999,
  ));

  let startShifted: Date;
  let endShifted: Date = endOfTodayShifted;

  if (period === 'today') {
    startShifted = new Date(Date.UTC(
      shiftedNow.getUTCFullYear(),
      shiftedNow.getUTCMonth(),
      shiftedNow.getUTCDate(),
      0, 0, 0, 0,
    ));
  } else if (period === 'last7Days') {
    const weekday = shiftedNow.getUTCDay(); // Sunday = 0
    const daysFromMonday = (weekday + 6) % 7;
    const monday = new Date(Date.UTC(
      shiftedNow.getUTCFullYear(),
      shiftedNow.getUTCMonth(),
      shiftedNow.getUTCDate() - daysFromMonday,
      0, 0, 0, 0,
    ));
    const sunday = new Date(Date.UTC(
      monday.getUTCFullYear(),
      monday.getUTCMonth(),
      monday.getUTCDate() + 6,
      23, 59, 59, 999,
    ));
    startShifted = monday;
    endShifted = endOfTodayShifted < sunday ? endOfTodayShifted : sunday;
  } else {
    // lastMonth (current calendar month)
    startShifted = new Date(Date.UTC(
      shiftedNow.getUTCFullYear(),
      shiftedNow.getUTCMonth(),
      1,
      0, 0, 0, 0,
    ));
  }

  // Shift back to real UTC for the query
  return {
    start: new Date(startShifted.getTime() - offsetMs),
    end: new Date(endShifted.getTime() - offsetMs),
  };
}


async function updateUserAggregates(userId: string) {
  // Get groups the user is a member of
  const membershipsSnap = await db.collection('users').doc(userId).collection('groupMemberships').get();
  const groupIds = membershipsSnap.docs.map(d => d.id);
  await db.collection('users').doc(userId).set(
    { groupIds },
    { merge: true },
  );

  const profileSnap = await db.collection('users').doc(userId).get();
  const profile = profileSnap.data() || {};
  const name = (profile.profileName as string) || '';
  const avatarIndex = profile.avatarIndex ?? null;
  const avatarColorValue = profile.avatarColorValue ?? 0xFF6366F1;
  const timezoneOffsetMinutes = Number.isFinite(profile.timezoneOffsetMinutes)
    ? Number(profile.timezoneOffsetMinutes)
    : 0;

  const offsetMs = timezoneOffsetMinutes * 60 * 1000;
  const now = new Date();
  // User's "now" wall-clock time
  const shiftedNow = new Date(now.getTime() + offsetMs);

  // Today Start in User's TZ, converted back to real UTC for comparison
  const todayStartLocal = new Date(Date.UTC(
    shiftedNow.getUTCFullYear(),
    shiftedNow.getUTCMonth(),
    shiftedNow.getUTCDate(),
    0, 0, 0, 0
  ));
  const todayStart = new Date(todayStartLocal.getTime() - offsetMs);

  // Week start (Monday) in User's TZ, converted back to real UTC
  const weekday = shiftedNow.getUTCDay();
  const daysFromMonday = (weekday + 6) % 7;
  const mondayStartLocal = new Date(Date.UTC(
    shiftedNow.getUTCFullYear(),
    shiftedNow.getUTCMonth(),
    shiftedNow.getUTCDate() - daysFromMonday,
    0, 0, 0, 0
  ));
  const last7Start = new Date(mondayStartLocal.getTime() - offsetMs);

  // Month start in User's TZ, converted back to real UTC
  const monthStartLocal = new Date(Date.UTC(
    shiftedNow.getUTCFullYear(),
    shiftedNow.getUTCMonth(),
    1,
    0, 0, 0, 0
  ));
  const monthStart = new Date(monthStartLocal.getTime() - offsetMs);

  // Extended Breakdown Start (35 days ago to cover all periods reliably)
  const breakdownStartLocal = new Date(todayStartLocal.getTime() - 34 * 24 * 3600 * 1000);
  const breakdownQueryStart = new Date(breakdownStartLocal.getTime() - offsetMs);

  // Fetch user courses to check for hiddenFromLeaderboard
  const coursesSnap = await db.collection('users').doc(userId).collection('courses').get();
  const hiddenCourseIds = new Set<string>();
  coursesSnap.docs.forEach(doc => {
    if (doc.data().hiddenFromLeaderboard === true) {
      hiddenCourseIds.add(doc.id);
    }
  });
  console.log(`[updateUserAggregates] userId=${userId} groups=${groupIds.length} hiddenCourses=${hiddenCourseIds.size}`);
  const sessionsSnap = await db.collection('users').doc(userId)
    .collection('sessions')
    .where('startUtc', '>=', admin.firestore.Timestamp.fromDate(breakdownQueryStart))
    .get();

  let totalToday = 0, total7 = 0, totalMonth = 0;
  const dailyMap = new Map<string, number>();
  let lastStudyDate = '';

  sessionsSnap.docs.forEach(sdoc => {
    const sd = sdoc.data();
    const ts = sd.startUtc as admin.firestore.Timestamp | undefined;
    const seconds = (sd.seconds as number) || 0;
    const deleted = (sd.deleted as boolean) || false;
    const courseId = (sd.courseId as string) || '';

    if (!ts || deleted || seconds <= 0) return;
    if (hiddenCourseIds.has(courseId)) return; // Exclude hidden courses

    const dtUtc = ts.toDate();

    // Convert UTC point to User's Local Date String for grouping
    const dtLocal = new Date(dtUtc.getTime() + offsetMs);
    const dayKey = dtLocal.toISOString().slice(0, 10);
    dailyMap.set(dayKey, (dailyMap.get(dayKey) || 0) + seconds);

    // Track latest study date
    if (dayKey > lastStudyDate) {
      lastStudyDate = dayKey;
    }

    if (dtUtc >= monthStart) {
      totalMonth += seconds;
    }
    if (dtUtc >= last7Start) {
      total7 += seconds;
    }
    if (dtUtc >= todayStart) {
      totalToday += seconds;
    }
  });

  const dailyBreakdown: { date: string; seconds: number }[] = [];
  // Use User's Local clock to iterate days for the last 35 days
  for (let d = new Date(breakdownStartLocal); d <= shiftedNow; d.setDate(d.getDate() + 1)) {
    const key = d.toISOString().slice(0, 10);
    dailyBreakdown.push({ date: key, seconds: dailyMap.get(key) || 0 });
  }

  const aggregatePayload = {
    userId,
    name,
    avatarIndex,
    avatarColorValue,
    timezoneOffsetMinutes,
    totals: {
      today: totalToday,
      last7Days: total7,
      lastMonth: totalMonth,
    },
    dailyBreakdown,
    lastStudyDate,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const batch = db.batch();

  // Write to group aggregates
  for (const groupId of groupIds) {
    const ref = db.collection('groups').doc(groupId).collection('aggregates').doc(userId);
    batch.set(ref, aggregatePayload, { merge: true });
  }

  // Write to user aggregates
  const userAggregateRef = db.collection('users').doc(userId).collection('aggregates').doc('statistics');
  batch.set(userAggregateRef, aggregatePayload, { merge: true });

  await batch.commit();
}

export const onStudySessionWrite = functions.firestore
  .document('users/{userId}/sessions/{sessionId}')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    console.log(`[onStudySessionWrite] userId=${userId}`);
    await updateUserAggregates(userId);
  });

export const onCourseWrite = functions.firestore
  .document('users/{userId}/courses/{courseId}')
  .onWrite(async (change, context) => {
    const { userId } = context.params;

    // Check if hiddenFromLeaderboard changed
    const before = change.before.data();
    const after = change.after.data();

    // If it's a delete or create, we might need to update.
    // If update, check if hidden status changed.
    const hiddenBefore = before?.hiddenFromLeaderboard === true;
    const hiddenAfter = after?.hiddenFromLeaderboard === true;

    if (hiddenBefore !== hiddenAfter || !before || !after) {
      console.log(`[onCourseWrite] userId=${userId} courseId=${context.params.courseId} hidden=${hiddenAfter}`);
      await updateUserAggregates(userId);
    }
  });

export const onGroupMemberDelete = functions.firestore
  .document('groups/{groupId}/members/{memberId}')
  .onDelete(async (_snap, context) => {
    const { groupId, memberId } = context.params;
    const userRef = db.collection('users').doc(memberId);
    const batch = db.batch();

    batch.delete(userRef.collection('groupMemberships').doc(groupId));
    batch.set(userRef, {
      groupIds: admin.firestore.FieldValue.arrayRemove(groupId),
    }, { merge: true });
    batch.delete(db.collection('groups').doc(groupId).collection('aggregates').doc(memberId));

    try {
      await batch.commit();
    } catch (err) {
      functions.logger.warn('Failed to clean up after member removal', err);
    }
  });

export const deleteGroup = functions.firestore
  .document('groups/{groupId}')
  .onDelete(async (snap, context) => {
    // This is a backup cleanup trigger, but we'll also implement a callable for direct deletion
    // to ensure we can handle the recursive delete properly and return success/failure to client.
    // Actually, let's just make it a Callable function that the client calls.
  });

export const deleteGroupCallable = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
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

export const deleteAccountCallable = functions.https.onCall(async (_data, context) => {
  requireAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const userId = context.auth.uid;

  const ownedGroupsSnap = await db
    .collection('groups')
    .where('createdBy', '==', userId)
    .get();
  const ownedGroupIds = new Set(ownedGroupsSnap.docs.map((doc) => doc.id));

  await removeUserMemberships(userId, ownedGroupIds);

  for (const groupDoc of ownedGroupsSnap.docs) {
    await deleteGroupCascade(groupDoc.ref);
  }

  const userRef = db.collection('users').doc(userId);
  await deleteUserCollections(userId, [
    'courses',
    'studyTimes',
    'courseGoals',
    'courseProgress',
    'sessions',
    'studySessions',
    'goals',
    'reflections',
    'preferences',
    'groupMemberships',
    'meta',
    'aggregates',
    'aiLogs',
    'stats',
  ]);

  await db.recursiveDelete(userRef);
  await admin.auth().deleteUser(userId);

  return { success: true };
});

export const joinPrivateGroup = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
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
  requireAppCheck(context);
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

export const sendNudge = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be authenticated.');
  }

  const groupId = typeof data?.groupId === 'string' ? data.groupId : '';
  const targetUserId = typeof data?.targetUserId === 'string' ? data.targetUserId : '';
  const senderId = context.auth.uid;

  if (!groupId || !targetUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId and targetUserId are required.');
  }
  if (targetUserId === senderId) {
    throw new functions.https.HttpsError('failed-precondition', 'You cannot nudge yourself.');
  }

  const groupRef = db.collection('groups').doc(groupId);
  const [groupSnap, senderMembershipSnap, targetMembershipSnap, targetProfileSnap, senderProfileSnap, targetTokensSnap] = await Promise.all([
    groupRef.get(),
    groupRef.collection('members').doc(senderId).get(),
    groupRef.collection('members').doc(targetUserId).get(),
    db.collection('users').doc(targetUserId).get(),
    db.collection('users').doc(senderId).get(),
    db.collection('users').doc(targetUserId).collection('fcmTokens').get(),
  ]);

  if (!groupSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Group not found.');
  }
  if (!senderMembershipSnap.exists || !targetMembershipSnap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Both users must be members of this group.');
  }
  if (!targetProfileSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Target profile not found.');
  }

  const targetData = targetProfileSnap.data() || {};
  const senderData = senderProfileSnap.data() || {};

  const allowsNudges = targetData.allowNudges !== false;
  if (!allowsNudges) {
    throw new functions.https.HttpsError('failed-precondition', 'This member has disabled nudges.');
  }

  const tokens = targetTokensSnap.docs
    .map((doc) => (doc.data().token as string | undefined) ?? doc.id)
    .filter((token): token is string => typeof token === 'string' && token.trim().length > 0);
  if (tokens.length == 0) {
    throw new functions.https.HttpsError('failed-precondition', 'This member cannot receive nudges right now.');
  }

  const senderName =
    (senderData.profileName as string | undefined)?.trim() ||
    (senderData.displayName as string | undefined)?.trim() ||
    'Someone';

  // Determine target user's preferred language. Support 'ru', 'en', 'kk' (Kazakh).
  const rawLang = ((targetData.language as string | undefined) ||
    (targetData.locale as string | undefined) ||
    (targetData.languageCode as string | undefined) ||
    'en').toLowerCase();
  const lang = rawLang.startsWith('ru') ? 'ru' : (rawLang.startsWith('kk') || rawLang.startsWith('kz') || rawLang.startsWith('kaz') ? 'kk' : 'en');

  // Phrase templates with a <username> placeholder. Localized variants for en/ru/kk.
  const phrases: Record<string, string[]> = {
    en: [
      '<username> nudged you — time to study 💡',
      '<username> thinks it’s study time 👀',
      '<username> sent a nudge — let’s start',
      'Hey, <username> is studying right now 💪',
      "<username> says: a little focus won’t hurt 🙂",
      'Study call from <username> 📚',
      '<username> nudged you — join the grind',
      'Time to focus! <username> is waiting',
      '<username> believes in your study streak 🔥',
      'Quick nudge from <username> - let’s go',
      "<username> says it’s a good moment to study",
      "You’ve got a study ping from <username>",
      '<username> just gave you a focus nudge',
      'Time to lock in - <username> is on it',
      '<username> is studying, join in!',
      'A small nudge from <username> to get started',
      "<username> thinks now’s a good time 📖",
      'Study alert from <username> - let’s do this',
      '<username> invited you to study together',
      "Let’s go - <username> just nudged you",
      "<username> says: don’t miss today’s progress",
      "<username> thinks now is a good moment to learn things",
    ],
    ru: [
      '<username> подтолкнул вас — время учиться 💡',
      '<username> думает, что пора учиться 👀',
      '<username> отправил напоминание — давайте начнём',
      'Привет, <username> сейчас учится 💪',
      '<username> говорит: немного сосредоточенности не повредит 🙂',
      'Зов к учёбе от <username> 📚',
      '<username> подтолкнул вас — присоединяйтесь',
      'Время сосредоточиться! <username> ждёт',
      '<username> верит в вашу серию занятий 🔥',
      'Быстрый nudge от <username> — поехали',
      '<username> говорит, что сейчас хорошее время для учёбы',
      'У вас учебный пинг от <username>',
      '<username> только что дал вам толчок для фокуса',
      'Пора врубиться — <username> уже в деле',
      '<username> учится, присоединяйся!',
      'Небольшое напоминание от <username>, чтобы начать',
      '<username> считает, что сейчас подходящее время 📖',
      'Учебное оповещение от <username> — вперёд',
      '<username> пригласил вас учиться вместе',
      'Вперёд — <username> только что подтолкнул вас',
      '<username> говорит: не упускай прогресс сегодня',
      '<username> считает, что сейчас хорошее время для новых знаний',
    ],
    kk: [
      '<username> сізге серпін берді — оқу уақыты 💡',
      '<username> ойлайды: оқу уақыты келді 👀',
      '<username> нұсқау жіберді — бастайық',
      'Ей, <username> қазір оқып жатыр 💪',
      '<username> айтты: сәл зейін қою зиян келтірмейді 🙂',
      '<username>-тан оқу шақыруы 📚',
      '<username> сізге серпін берді — қосылыңыз',
      'Зейін қой! <username> сізді күтіп тұр',
      '<username> сенің оқу тізбегіңе сенеді 🔥',
      '<username>-тан жедел серпін — бастайық',
      '<username> айтты: бұл оқуға жақсы сәт',
      '<username>-тан оқу хабарламасы сізге келді',
      '<username> сізге фокус толқынын жіберді',
      'Уақыт құлыптау — <username> қазір бастады',
      '<username> оқып жатыр, қосылыңыз!',
      '<username>-тан кішкене серпін — бастау үшін',
      '<username> ойлайды, қазір жақсы уақыт 📖',
      '<username>-тан оқу ескертуі — жасайық',
      '<username> бірге оқу үшін шақырды',
      'Алға — <username> сізге серпін берді',
      '<username> айтты: бүгінгі ілгерілеуді жіберіп алмаңыз',
      '<username> ойлайды: қазір жаңа нәрселер үйренуге жақсы сәт',
    ],
  };

  const list = phrases[lang] || phrases.en;
  const template = list[Math.floor(Math.random() * list.length)];
  const body = template.replace(/<username>/g, senderName);

  const titles: Record<string, string> = {
    en: 'Nudge',
    ru: 'Напоминание',
    kk: 'Ескерту',
  };
  const title = titles[lang] || titles.en;

  try {
    const now = admin.firestore.FieldValue.serverTimestamp();
    
    // 1. Store the nudge persistently
    await db.collection('nudges').add({
      senderId,
      receiverId: targetUserId,
      groupId,
      title,
      body,
      timestamp: now,
      status: 'pending',
    });

    // 2. Attempt FCM Push (Instant Delivery)
    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        type: 'nudge',
        groupId,
        senderId,
        targetUserId,
      },
    });

    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((resp, index) => {
        if (!resp.success) {
          const code = resp.error?.code ?? '';
          if (code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token') {
            invalidTokens.push(tokens[index]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        const batch = db.batch();
        for (const token of invalidTokens) {
          batch.delete(
            db.collection('users').doc(targetUserId).collection('fcmTokens').doc(token),
          );
        }
        await batch.commit();
      }
    }

    // Notice we removed the "successCount == 0" throw Error because
    // the nudge is safely stored in Firestore for delivery on app open.
    if (response.successCount === 0) {
      functions.logger.info(`0 devices received push. Nudge is saved in Firestore for ${targetUserId}.`);
    }

    return { success: true };
  } catch (err) {
    functions.logger.error('Failed to process nudge', err);
    if (err instanceof functions.https.HttpsError) {
      throw err;
    }
    throw new functions.https.HttpsError('internal', err instanceof Error ? err.message : 'Failed to send nudge.');
  }
});
