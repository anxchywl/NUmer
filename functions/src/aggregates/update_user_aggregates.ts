import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import {
  AggregatePayload,
  Contribution,
  derivePayload,
  localDays,
  timezoneOf,
  UserFields,
  userFieldsOf,
} from './derive';
import { contributionOf } from './ledger';
import { updateIfExists } from '../shared/user_writes';

export interface LegacyInputs {
  userExists: boolean;
  groupIds: string[];
  user: UserFields;
  hiddenCourseIds: Set<string>;
  contributions: Contribution[];
  reads: number;
}

export async function loadLegacyInputs(userId: string, now: Date): Promise<LegacyInputs> {
  const userRef = db.collection('users').doc(userId);
  const membershipsSnap = await userRef.collection('groupMemberships').get();
  const groupIds = membershipsSnap.docs.map(d => d.id);

  const profileSnap = await userRef.get();
  const user = userFieldsOf(profileSnap.data());
  const timezoneOffsetMinutes = timezoneOf(user);
  const days = localDays(timezoneOffsetMinutes, now);

  const coursesSnap = await userRef.collection('courses').get();
  const hiddenCourseIds = new Set<string>();
  coursesSnap.docs.forEach(doc => {
    if (doc.data().hiddenFromLeaderboard === true) {
      hiddenCourseIds.add(doc.id);
    }
  });
  console.log(`[updateUserAggregates] userId=${userId} groups=${groupIds.length} hiddenCourses=${hiddenCourseIds.size}`);
  const sessionsSnap = await userRef
    .collection('sessions')
    .where('startUtc', '>=', admin.firestore.Timestamp.fromDate(days.breakdownQueryStart))
    .get();

  const contributions: Contribution[] = [];
  sessionsSnap.docs.forEach(sdoc => {
    const value = contributionOf(sdoc.data(), timezoneOffsetMinutes, days.windowStartDay);
    if (!value) return;
    contributions.push({ sessionId: sdoc.id, courseId: value.c, day: value.d, seconds: value.s });
  });

  return {
    userExists: profileSnap.exists,
    groupIds,
    user,
    hiddenCourseIds,
    contributions,
    reads: membershipsSnap.size + 1 + coursesSnap.size + sessionsSnap.size,
  };
}

export function aggregateRefs(userId: string, groupIds: string[]) {
  return [
    ...groupIds.map(groupId => db.collection('groups').doc(groupId).collection('aggregates').doc(userId)),
    db.collection('users').doc(userId).collection('aggregates').doc('statistics'),
  ];
}

export function aggregateDocument(payload: AggregatePayload) {
  return { ...payload, updatedAt: admin.firestore.FieldValue.serverTimestamp() };
}

export async function writeAggregates(userId: string, groupIds: string[], payload: AggregatePayload) {
  const batch = db.batch();
  const data = aggregateDocument(payload);
  for (const ref of aggregateRefs(userId, groupIds)) {
    batch.set(ref, data, { merge: true });
  }
  await batch.commit();
}

export async function updateUserAggregates(userId: string) {
  const now = new Date();
  const inputs = await loadLegacyInputs(userId, now);
  if (!inputs.userExists) return { payload: null, reads: inputs.reads };
  const updated = await updateIfExists(db.collection('users').doc(userId), { groupIds: inputs.groupIds });
  if (!updated) return { payload: null, reads: inputs.reads };
  const payload = derivePayload({
    userId,
    user: inputs.user,
    hiddenCourseIds: inputs.hiddenCourseIds,
    contributions: inputs.contributions,
    now,
  });
  await writeAggregates(userId, inputs.groupIds, payload);
  return { payload, reads: inputs.reads };
}
