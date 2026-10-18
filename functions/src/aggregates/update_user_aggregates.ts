import * as admin from 'firebase-admin';
import { db } from '../shared/admin';

export async function updateUserAggregates(userId: string) {
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
