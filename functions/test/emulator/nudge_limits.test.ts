import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import { db } from '../../src/shared/admin';
import { sendNudge } from '../../src/nudges/send_nudge';

const test = functionsTest();
const nudge = test.wrap(sendNudge);

async function seedMember(groupId: string, userId: string, profile: object = {}) {
  await db.doc(`groups/${groupId}/members/${userId}`).set({ role: 'member' });
  await db.doc(`users/${userId}`).set(profile);
  await db.doc(`users/${userId}/fcmTokens/token-${userId}`).set({ token: `token-${userId}` });
}

async function seedGroup(groupId: string, senderId: string) {
  await db.doc(`groups/${groupId}`).set({ createdBy: senderId });
  await seedMember(groupId, senderId);
}

function send(senderId: string, groupId: string, targetUserId: string) {
  return nudge({ groupId, targetUserId }, { auth: { uid: senderId } });
}

describe('sendNudge limits', () => {
  beforeAll(() => {
    jest.spyOn(admin.messaging(), 'sendEachForMulticast').mockImplementation(async (message) => ({
      successCount: message.tokens.length,
      failureCount: 0,
      responses: message.tokens.map(() => ({ success: true })),
    }));
  });

  afterAll(async () => {
    jest.restoreAllMocks();
    test.cleanup();
    await admin.app().delete();
  });

  it('rejects a second nudge to the same target within an hour', async () => {
    await seedGroup('cool-g', 'cool-sender');
    await seedMember('cool-g', 'cool-target');

    await expect(send('cool-sender', 'cool-g', 'cool-target')).resolves.toEqual({ success: true });
    await expect(send('cool-sender', 'cool-g', 'cool-target')).rejects.toMatchObject({
      code: 'resource-exhausted',
    });
  });

  it('rejects the 31st nudge of a day', async () => {
    await seedGroup('day-g', 'day-sender');
    const targets = Array.from({ length: 31 }, (_, i) => `day-target-${i}`);
    await Promise.all(targets.map((target) => seedMember('day-g', target)));

    for (const target of targets.slice(0, 30)) {
      await expect(send('day-sender', 'day-g', target)).resolves.toEqual({ success: true });
    }
    await expect(send('day-sender', 'day-g', targets[30])).rejects.toMatchObject({
      code: 'resource-exhausted',
      message: 'Daily nudge limit reached.',
    });
  });

  it('does not use up the limit when validation fails', async () => {
    await seedGroup('valid-g', 'valid-sender');
    await seedMember('valid-g', 'valid-target', { allowNudges: false });

    await expect(send('valid-sender', 'valid-g', 'valid-target')).rejects.toMatchObject({
      code: 'failed-precondition',
    });
    const used = await db.doc('nudgeLimits/valid-sender_valid-target').get();
    expect(used.exists).toBe(false);

    await db.doc('users/valid-target').set({ allowNudges: true });
    await expect(send('valid-sender', 'valid-g', 'valid-target')).resolves.toEqual({ success: true });
  });
});
