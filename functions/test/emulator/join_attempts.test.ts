import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import { db } from '../../src/shared/admin';
import { joinPrivateGroup } from '../../src/groups/callables';

const test = functionsTest();
const join = test.wrap(joinPrivateGroup);

async function seedGroup(groupId: string) {
  await db.doc(`groups/${groupId}`).set({ visibility: 'private', memberCount: 1 });
  await db.doc(`groups/${groupId}/secrets/settings`).set({ joinCode: 'RIGHT1' });
}

function attempt(uid: string, groupId: string, joinCode: string) {
  return join({ groupId, joinCode }, { auth: { uid } });
}

async function failFiveTimes(uid: string, groupId: string) {
  for (const code of ['WRONG1', 'WRONG2', 'WRONG3', 'short', 'muchlongercode']) {
    await expect(attempt(uid, groupId, code)).rejects.toMatchObject({ code: 'permission-denied' });
  }
}

describe('joinPrivateGroup attempts', () => {
  afterAll(async () => {
    test.cleanup();
    await admin.app().delete();
  });

  it('joins on a correct first attempt without counting it', async () => {
    await seedGroup('first-g');

    await expect(attempt('first-u', 'first-g', 'RIGHT1')).resolves.toEqual({ success: true });

    expect((await db.doc('groups/first-g/members/first-u').get()).exists).toBe(true);
    expect((await db.doc('joinAttempts/first-u_first-g').get()).exists).toBe(false);
  });

  it('refuses a correct code after five wrong ones', async () => {
    await seedGroup('five-g');
    await failFiveTimes('five-u', 'five-g');

    await expect(attempt('five-u', 'five-g', 'RIGHT1')).rejects.toMatchObject({
      code: 'resource-exhausted',
    });
    expect((await db.doc('groups/five-g/members/five-u').get()).exists).toBe(false);
  });

  it('opens a new window after an hour', async () => {
    await seedGroup('window-g');
    await failFiveTimes('window-u', 'window-g');
    const counter = db.doc('joinAttempts/window-u_window-g');
    await counter.update({
      windowStart: admin.firestore.Timestamp.fromMillis(Date.now() - 3601 * 1000),
    });

    await expect(attempt('window-u', 'window-g', 'WRONG1')).rejects.toMatchObject({
      code: 'permission-denied',
    });
    expect((await counter.get()).data()?.count).toBe(1);
    await expect(attempt('window-u', 'window-g', 'RIGHT1')).resolves.toEqual({ success: true });
  });

  it('lets only five of many parallel guesses reach the code', async () => {
    await seedGroup('burst-g');

    const results = await Promise.allSettled(
      Array.from({ length: 12 }, (_, i) => attempt('burst-u', 'burst-g', `WRONG${i}`)),
    );

    const codes = results.map((result) => (result.status === 'rejected' ? result.reason.code : 'joined'));
    expect(codes.filter((code) => code === 'permission-denied')).toHaveLength(5);
    expect(codes.filter((code) => code === 'resource-exhausted')).toHaveLength(7);
    expect((await db.doc('joinAttempts/burst-u_burst-g').get()).data()?.count).toBe(5);
  });

  it('does not count a request that fails for another reason', async () => {
    await db.doc('groups/open-g').set({ visibility: 'public' });

    await expect(attempt('open-u', 'open-g', 'RIGHT1')).rejects.toMatchObject({
      code: 'failed-precondition',
    });

    expect((await db.doc('joinAttempts/open-u_open-g').get()).exists).toBe(false);
  });

  it('keeps earlier wrong attempts after a correct one', async () => {
    await seedGroup('keep-g');
    await expect(attempt('keep-u', 'keep-g', 'WRONG1')).rejects.toMatchObject({ code: 'permission-denied' });

    await expect(attempt('keep-u', 'keep-g', 'RIGHT1')).resolves.toEqual({ success: true });

    expect((await db.doc('joinAttempts/keep-u_keep-g').get()).data()?.count).toBe(1);
  });

  it('refuses every user once the group reaches its daily limit', async () => {
    await seedGroup('busy-g');
    const day = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    await db.doc(`joinAttempts/group_busy-g_${day}`).set({ count: 50 });

    await expect(attempt('busy-u', 'busy-g', 'RIGHT1')).rejects.toMatchObject({
      code: 'resource-exhausted',
    });
  });
});
