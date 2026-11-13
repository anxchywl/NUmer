import functionsTest from 'firebase-functions-test';
import * as admin from 'firebase-admin';
import { auth, db } from '../../src/shared/admin';
import { normalizeEmail, sha256Hex } from '../../src/auth/codes';
import { deleteAccountCallable } from '../../src/account/delete_account';
import { onUserDeletionRequested, purgeUser, sweepPurgedUsers } from '../../src/account/purge_user';
import * as functions from 'firebase-functions/v1';
import { onStudySessionWrite } from '../../src/aggregates/triggers';
import { createAggregateHandlers } from '../../src/aggregates/handlers';
import { syncPublicProfile } from '../../src/profiles/public_profile';
import { deleteGroupCascade } from '../../src/groups/cleanup';
import { onGroupMemberWrite } from '../../src/groups/membership_index';
import { onGroupMemberDelete } from '../../src/groups/triggers';

const test = functionsTest({ projectId: 'demo-numer' });
const callDelete = test.wrap(deleteAccountCallable);
const deliverSession = test.wrap(onStudySessionWrite);
const deliverMemberWrite = test.wrap(onGroupMemberWrite);
const deliverMemberDelete = test.wrap(onGroupMemberDelete);
const deliverMarker = test.wrap(onUserDeletionRequested);
const incrementalSession = test.wrap(
  functions.firestore
    .document('users/{userId}/sessions/{sessionId}')
    .onWrite(createAggregateHandlers({ mode: 'on', shadowPercent: 0 }).onSession),
);

const subcollections = [
  'courses', 'studyTimes', 'courseGoals', 'courseProgress', 'sessions', 'studySessions', 'goals',
  'reflections', 'preferences', 'groupMemberships', 'meta', 'aggregates', 'aiLogs', 'stats',
  'habits', 'connections', 'fcmTokens', 'nudgeCooldowns', 'aggState',
];

let runId = 0;
function uniqueUid(name: string): string {
  runId += 1;
  return `${name}-${Date.now()}-${runId}`;
}

function caller(uid: string, email: string | undefined, authTime = Math.floor(Date.now() / 1000)) {
  return { auth: { uid, token: { email, auth_time: authTime } } } as never;
}

function snapshot(path: string, data: Record<string, unknown>) {
  return test.firestore.makeDocumentSnapshot(data, path);
}

const emailOf = (uid: string) => `${uid.toLowerCase()}@deletion.test`;
const resetId = (uid: string) => `reset_${sha256Hex(normalizeEmail(emailOf(uid)))}`;

interface Seeded {
  uid: string;
  other: string;
  owned: string;
  joined: string;
}

async function seed(name: string): Promise<Seeded> {
  const uid = uniqueUid(name);
  const other = `${uid}-other`;
  const owned = `${uid}-owned`;
  const joined = `${uid}-joined`;
  await auth.createUser({ uid, email: emailOf(uid), password: 'delete-pass' });

  const user = db.collection('users').doc(uid);
  const otherUser = db.collection('users').doc(other);
  const batch = db.batch();
  batch.set(user, { profileName: 'Ann', groupIds: [owned, joined], timezoneOffsetMinutes: 300 });
  for (const name of subcollections) {
    batch.set(user.collection(name).doc('seeded'), { value: 1 });
  }
  batch.set(user.collection('sessions').doc('s1'), {
    courseId: 'seeded',
    seconds: 600,
    startUtc: admin.firestore.Timestamp.now(),
  });
  batch.set(user.collection('habits').doc('seeded').collection('logs').doc('l1'), { done: true });
  batch.set(user.collection('groupMemberships').doc(owned), { role: 'owner' });
  batch.set(user.collection('groupMemberships').doc(joined), { role: 'member' });

  batch.set(otherUser, { profileName: 'Bob', groupIds: [owned, joined] });
  batch.set(otherUser.collection('groupMemberships').doc(owned), { role: 'member' });
  batch.set(otherUser.collection('groupMemberships').doc(joined), { role: 'owner' });

  const ownedGroup = db.collection('groups').doc(owned);
  const joinedGroup = db.collection('groups').doc(joined);
  batch.set(ownedGroup, { createdBy: uid, memberCount: 2 });
  batch.set(ownedGroup.collection('members').doc(uid), { role: 'owner' });
  batch.set(ownedGroup.collection('members').doc(other), { role: 'member' });
  batch.set(ownedGroup.collection('aggregates').doc(uid), { totals: {} });
  batch.set(joinedGroup, { createdBy: other, memberCount: 2 });
  batch.set(joinedGroup.collection('members').doc(uid), { role: 'member' });
  batch.set(joinedGroup.collection('members').doc(other), { role: 'owner' });
  batch.set(joinedGroup.collection('aggregates').doc(uid), { totals: {} });
  batch.set(joinedGroup.collection('aggregates').doc(other), { totals: {} });

  batch.set(db.collection('nudges').doc(`${uid}-sent`), { senderId: uid, receiverId: other });
  batch.set(db.collection('nudges').doc(`${uid}-received`), { senderId: other, receiverId: uid });
  batch.set(db.collection('nudges').doc(`${uid}-unrelated`), { senderId: other, receiverId: `${uid}-third` });
  batch.set(db.collection('email_index').doc(emailOf(uid)), { uid, email: emailOf(uid) });
  batch.set(db.collection('authCodes').doc(`verify_${uid}`), { purpose: 'verify' });
  batch.set(db.collection('authCodes').doc(resetId(uid)), { purpose: 'reset' });
  batch.set(db.collection('publicProfiles').doc(uid), { profileName: 'Ann' });
  batch.set(db.collection('groupIndex').doc(uid), { groupIds: [owned, joined] });
  await batch.commit();
  return { uid, other, owned, joined };
}

async function exists(path: string) {
  return (await db.doc(path).get()).exists;
}

async function authUserExists(uid: string) {
  try {
    await auth.getUser(uid);
    return true;
  } catch (err) {
    if ((err as { code?: string }).code === 'auth/user-not-found') return false;
    throw err;
  }
}

async function expectPurged({ uid, other, owned, joined }: Seeded) {
  expect(await db.collection('users').doc(uid).listCollections()).toEqual([]);
  expect(await exists(`users/${uid}`)).toBe(false);
  expect(await exists(`email_index/${emailOf(uid)}`)).toBe(false);
  expect(await exists(`authCodes/verify_${uid}`)).toBe(false);
  expect(await exists(`authCodes/${resetId(uid)}`)).toBe(false);
  expect(await exists(`publicProfiles/${uid}`)).toBe(false);
  expect(await exists(`groupIndex/${uid}`)).toBe(false);
  expect(await exists(`nudges/${uid}-sent`)).toBe(false);
  expect(await exists(`nudges/${uid}-received`)).toBe(false);
  expect(await exists(`nudges/${uid}-unrelated`)).toBe(true);
  expect(await exists(`groups/${owned}`)).toBe(false);
  expect(await exists(`groups/${joined}/members/${uid}`)).toBe(false);
  expect(await exists(`groups/${joined}/aggregates/${uid}`)).toBe(false);
  expect((await db.doc(`groups/${joined}`).get()).get('memberCount')).toBe(1);
  expect((await db.doc(`users/${other}`).get()).get('groupIds')).toEqual([joined]);
  expect(await exists(`users/${other}/groupMemberships/${owned}`)).toBe(false);
  expect(await authUserExists(uid)).toBe(false);
  expect(await exists(`accountEvents/deleted_${uid}`)).toBe(true);
  expect((await db.doc(`deletedUsers/${uid}`).get()).get('status')).toBe('done');
}

afterAll(() => test.cleanup());

describe('account deletion', () => {
  it('removes everything about the user, also after late triggers', async () => {
    const seeded = await seed('full');
    const { uid, joined } = seeded;
    const session = (await db.doc(`users/${uid}/sessions/s1`).get()).data()!;

    await expect(callDelete({}, caller(uid, emailOf(uid)))).resolves.toEqual({ success: true });
    expect((await auth.getUser(uid)).disabled).toBe(true);
    await purgeUser(uid);

    const sessionPath = `users/${uid}/sessions/s1`;
    await deliverSession(
      test.makeChange(snapshot(sessionPath, session), snapshot(sessionPath, {})),
      { params: { userId: uid, sessionId: 's1' } },
    );
    const memberPath = `groups/${joined}/members/${uid}`;
    await deliverMemberWrite(
      test.makeChange(snapshot(memberPath, { role: 'member' }), snapshot(memberPath, {})),
      { params: { groupId: joined, memberId: uid } },
    );
    await deliverMemberDelete(snapshot(memberPath, { role: 'member' }), {
      params: { groupId: joined, memberId: uid },
    });

    await expectPurged(seeded);
    const event = (await db.doc(`accountEvents/deleted_${uid}`).get()).data();
    expect(event).toMatchObject({
      type: 'account.deleted',
      issuer: `https://securetoken.google.com/${process.env.GCLOUD_PROJECT}`,
      subject: uid,
      status: 'pending',
    });
    const marker = (await db.doc(`deletedUsers/${uid}`).get()).data();
    expect(marker).toMatchObject({ uid, emailHash: sha256Hex(normalizeEmail(emailOf(uid))) });
  });

  it('reaches the same end state with one event when run twice', async () => {
    const seeded = await seed('twice');
    const { uid } = seeded;
    await callDelete({}, caller(uid, emailOf(uid)));
    await purgeUser(uid);
    const first = (await db.doc(`accountEvents/deleted_${uid}`).get()).get('occurredAt');

    await db.doc(`deletedUsers/${uid}`).update({ status: 'pending' });
    await purgeUser(uid);

    await expectPurged(seeded);
    const events = await db.collection('accountEvents').where('subject', '==', uid).get();
    expect(events.size).toBe(1);
    expect(events.docs[0].get('occurredAt').isEqual(first)).toBe(true);
  });

  it('finishes when the auth user is already gone', async () => {
    const seeded = await seed('no-auth');
    const { uid } = seeded;
    await callDelete({}, caller(uid, emailOf(uid)));
    await auth.deleteUser(uid);
    await db.doc(`authCodes/${resetId(uid)}`).delete();

    await purgeUser(uid);

    await expectPurged(seeded);
  });

  it('runs the purge when the marker is created or a retry is requested', async () => {
    const seeded = await seed('trigger');
    const { uid } = seeded;
    await callDelete({}, caller(uid, emailOf(uid)));
    const path = `deletedUsers/${uid}`;
    const pending = (await db.doc(path).get()).data()!;

    await deliverMarker(
      test.makeChange(snapshot(path, pending), snapshot(path, pending)),
      { params: { uid } },
    );
    expect(await exists(`users/${uid}`)).toBe(true);

    await deliverMarker(test.makeChange(snapshot(path, {}), snapshot(path, pending)), { params: { uid } });
    await expectPurged(seeded);
    expect(onUserDeletionRequested.__endpoint.eventTrigger?.retry).toBe(true);
  });

  it('asks for the purge again when called while it is pending', async () => {
    const { uid } = await seed('retry');
    await callDelete({}, caller(uid, emailOf(uid)));
    expect((await db.doc(`deletedUsers/${uid}`).get()).get('retryRequestedAt')).toBeUndefined();

    await expect(callDelete({}, caller(uid, emailOf(uid)))).resolves.toEqual({ success: true });

    const marker = await db.doc(`deletedUsers/${uid}`).get();
    expect(marker.get('status')).toBe('pending');
    expect(marker.get('retryRequestedAt')).toBeInstanceOf(admin.firestore.Timestamp);
  });

  it('stores a null email hash for an account without an email', async () => {
    const uid = uniqueUid('no-email');
    await auth.createUser({ uid });
    await callDelete({}, caller(uid, undefined));
    expect((await db.doc(`deletedUsers/${uid}`).get()).get('emailHash')).toBeNull();
    await purgeUser(uid);
    expect(await authUserExists(uid)).toBe(false);
  });

  it('sweeps documents written after the purge', async () => {
    const { uid } = await seed('sweep');
    const recent = (await seed('sweep-recent')).uid;
    for (const id of [uid, recent]) {
      await callDelete({}, caller(id, emailOf(id)));
      await purgeUser(id);
      await db.doc(`users/${id}/sessions/late`).set({ seconds: 60 });
      await db.doc(`publicProfiles/${id}`).set({ profileName: 'Late' });
    }
    const threeHoursAgo = admin.firestore.Timestamp.fromMillis(Date.now() - 3 * 3600 * 1000);
    await db.doc(`deletedUsers/${uid}`).update({ completedAt: threeHoursAgo });

    await sweepPurgedUsers();

    expect(await exists(`users/${uid}/sessions/late`)).toBe(false);
    expect(await exists(`publicProfiles/${uid}`)).toBe(false);
    expect((await db.doc(`deletedUsers/${uid}`).get()).get('sweptAt')).toBeInstanceOf(admin.firestore.Timestamp);
    expect(await exists(`users/${recent}/sessions/late`)).toBe(true);
    expect((await db.doc(`deletedUsers/${recent}`).get()).get('sweptAt')).toBeNull();
  });

  describe('with a recent sign-in required', () => {
    beforeAll(() => {
      process.env.DELETE_REQUIRES_RECENT_AUTH = 'on';
    });

    afterAll(() => {
      delete process.env.DELETE_REQUIRES_RECENT_AUTH;
    });

    it('rejects a sign-in from 10 minutes ago and changes nothing', async () => {
      const uid = uniqueUid('stale');
      await auth.createUser({ uid });
      const tenMinutesAgo = Math.floor(Date.now() / 1000) - 600;

      await expect(callDelete({}, caller(uid, undefined, tenMinutesAgo))).rejects.toMatchObject({
        code: 'failed-precondition',
        details: { reason: 'recent-login-required' },
      });
      expect((await auth.getUser(uid)).disabled).toBe(false);
      expect(await exists(`deletedUsers/${uid}`)).toBe(false);
      await auth.deleteUser(uid);
    });

    it('accepts a fresh sign-in', async () => {
      const uid = uniqueUid('fresh');
      await auth.createUser({ uid });
      await expect(callDelete({}, caller(uid, undefined))).resolves.toEqual({ success: true });
      await purgeUser(uid);
    });
  });
});

describe('writes racing a deletion', () => {
  async function deliverSessionCreate(trigger: typeof deliverSession, uid: string) {
    const path = `users/${uid}/sessions/s1`;
    const session = (await db.doc(path).get()).data()!;
    await trigger(test.makeChange(snapshot(path, {}), snapshot(path, session)), {
      params: { userId: uid, sessionId: 's1' },
      timestamp: new Date().toISOString(),
    });
  }

  async function clearAggregates({ uid, owned, joined }: Seeded) {
    await Promise.all([
      db.doc(`groups/${owned}/aggregates/${uid}`).delete(),
      db.doc(`groups/${joined}/aggregates/${uid}`).delete(),
    ]);
  }

  async function aggregatesOf({ uid, owned, joined }: Seeded) {
    return Promise.all([
      exists(`groups/${owned}/aggregates/${uid}`),
      exists(`groups/${joined}/aggregates/${uid}`),
      exists(`users/${uid}/aggregates/statistics`),
    ]);
  }

  it('skips the legacy aggregate write once the user is marked, before the purge starts', async () => {
    const seeded = await seed('legacy-race');
    await clearAggregates(seeded);
    await callDelete({}, caller(seeded.uid, emailOf(seeded.uid)));

    await deliverSessionCreate(deliverSession, seeded.uid);

    expect(await aggregatesOf(seeded)).toEqual([false, false, false]);
    expect(await exists(`users/${seeded.uid}/groupMemberships/${seeded.joined}`)).toBe(true);
  });

  it('skips the incremental aggregate write once the user is marked', async () => {
    const seeded = await seed('incremental-race');
    await clearAggregates(seeded);
    await callDelete({}, caller(seeded.uid, emailOf(seeded.uid)));

    await deliverSessionCreate(incrementalSession, seeded.uid);

    expect(await aggregatesOf(seeded)).toEqual([false, false, false]);
  });

  it('still writes aggregates for an unmarked user', async () => {
    const seeded = await seed('unmarked');
    await clearAggregates(seeded);

    await deliverSessionCreate(deliverSession, seeded.uid);

    expect(await aggregatesOf(seeded)).toEqual([true, true, true]);
    await callDelete({}, caller(seeded.uid, emailOf(seeded.uid)));
    await purgeUser(seeded.uid);
  });

  it('removes group documents written back after the groups step, in the purge and in the sweep', async () => {
    const seeded = await seed('leftovers');
    const { uid, joined } = seeded;
    await callDelete({}, caller(uid, emailOf(uid)));
    await purgeUser(uid);
    const marker = db.doc(`deletedUsers/${uid}`);
    expect((await marker.get()).get('groupIds')).toEqual(expect.arrayContaining([seeded.owned, joined]));

    const writeBack = () => Promise.all([
      db.doc(`groups/${joined}/aggregates/${uid}`).set({ name: 'Ann' }),
      db.doc(`groups/${joined}/members/${uid}`).set({ role: 'member' }),
    ]);
    await writeBack();
    await marker.update({ status: 'pending' });
    await purgeUser(uid);
    expect(await exists(`groups/${joined}/aggregates/${uid}`)).toBe(false);
    expect(await exists(`groups/${joined}/members/${uid}`)).toBe(false);

    await writeBack();
    await marker.update({ completedAt: admin.firestore.Timestamp.fromMillis(Date.now() - 3 * 3600 * 1000) });
    await sweepPurgedUsers();
    expect(await exists(`groups/${joined}/aggregates/${uid}`)).toBe(false);
    expect(await exists(`groups/${joined}/members/${uid}`)).toBe(false);
    await expectPurged(seeded);
  });

  it('writes no group index or public profile for a marked user', async () => {
    const seeded = await seed('mirrors');
    const { uid, joined } = seeded;
    await callDelete({}, caller(uid, emailOf(uid)));
    await db.doc(`groupIndex/${uid}`).delete();

    const memberPath = `groups/${joined}/members/${uid}`;
    await deliverMemberWrite(
      test.makeChange(snapshot(memberPath, {}), snapshot(memberPath, { role: 'member' })),
      { params: { groupId: joined, memberId: uid } },
    );
    await syncPublicProfile(uid);

    expect(await exists(`groupIndex/${uid}`)).toBe(false);
    expect(await exists(`publicProfiles/${uid}`)).toBe(false);
    expect(await exists(`users/${uid}`)).toBe(true);
  });

  it('leaves a marker to purge from when disabling the user fails', async () => {
    const uid = 'u'.repeat(129);

    await expect(callDelete({}, caller(uid, undefined))).rejects.toMatchObject({
      code: 'auth/invalid-uid',
    });

    const marker = await db.doc(`deletedUsers/${uid}`).get();
    expect(marker.get('status')).toBe('pending');
    await db.doc(`deletedUsers/${uid}`).delete();
  });
});

describe('group deletion', () => {
  it('updates the members whose user document exists and skips a missing one', async () => {
    const groupId = uniqueUid('group');
    const present = `${groupId}-present`;
    const missing = `${groupId}-missing`;
    const group = db.collection('groups').doc(groupId);
    await db.doc(`users/${present}`).set({ groupIds: [groupId, 'kept'] });
    await db.doc(`users/${present}/groupMemberships/${groupId}`).set({ role: 'member' });
    await db.doc(`users/${missing}/groupMemberships/${groupId}`).set({ role: 'member' });
    await group.set({ createdBy: present });
    await group.collection('members').doc(present).set({ role: 'owner' });
    await group.collection('members').doc(missing).set({ role: 'member' });

    await deleteGroupCascade(group);

    expect((await db.doc(`users/${present}`).get()).get('groupIds')).toEqual(['kept']);
    expect(await exists(`users/${present}/groupMemberships/${groupId}`)).toBe(false);
    expect(await exists(`users/${missing}/groupMemberships/${groupId}`)).toBe(false);
    expect(await exists(`users/${missing}`)).toBe(false);
  });

  it('cleans up after a removed member whose user document is gone', async () => {
    const groupId = uniqueUid('removed');
    const memberId = `${groupId}-member`;
    await db.doc(`users/${memberId}/groupMemberships/${groupId}`).set({ role: 'member' });
    await db.doc(`groups/${groupId}/aggregates/${memberId}`).set({ totals: {} });

    await deliverMemberDelete(snapshot(`groups/${groupId}/members/${memberId}`, { role: 'member' }), {
      params: { groupId, memberId },
    });

    expect(await exists(`users/${memberId}/groupMemberships/${groupId}`)).toBe(false);
    expect(await exists(`groups/${groupId}/aggregates/${memberId}`)).toBe(false);
    expect(await exists(`users/${memberId}`)).toBe(false);
  });
});
