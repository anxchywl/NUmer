import functionsTest from 'firebase-functions-test';
import { db } from '../../src/shared/admin';
import { onUserProfileWrite } from '../../src/profiles/public_profile';

const test = functionsTest({ projectId: 'demo-numer' });
const wrapped = test.wrap(onUserProfileWrite);

async function deliver(uid: string, before: Record<string, unknown>, after: Record<string, unknown>) {
  const path = `users/${uid}`;
  const change = test.makeChange(
    test.firestore.makeDocumentSnapshot(before, path),
    test.firestore.makeDocumentSnapshot(after, path),
  );
  await wrapped(change, { params: { userId: uid } });
}

async function mirrorOf(uid: string) {
  return (await db.doc(`publicProfiles/${uid}`).get()).data();
}

const user = { profileName: 'Aru', email: 'aru@example.test' };

describe('onUserProfileWrite', () => {
  afterAll(() => test.cleanup());

  it('writes the mirror on create', async () => {
    await deliver('create', {}, user);
    const mirror = await mirrorOf('create');
    expect(mirror?.profileName).toBe('Aru');
    expect(mirror?.updatedAt).toBeDefined();
    expect(mirror).not.toHaveProperty('email');
  });

  it('rewrites the mirror on a name change', async () => {
    await deliver('rename', {}, user);
    await deliver('rename', user, { ...user, profileName: 'Dana' });
    expect((await mirrorOf('rename'))?.profileName).toBe('Dana');
  });

  it('skips a private change', async () => {
    await deliver('private', {}, user);
    const before = await mirrorOf('private');
    await deliver('private', user, { ...user, email: 'other@example.test' });
    expect((await mirrorOf('private'))?.updatedAt).toEqual(before?.updatedAt);
  });

  it('removes the mirror on delete', async () => {
    await deliver('remove', {}, user);
    await deliver('remove', user, {});
    expect(await mirrorOf('remove')).toBeUndefined();
  });
});
