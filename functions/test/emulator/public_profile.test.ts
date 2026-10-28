import functionsTest from 'firebase-functions-test';
import { Timestamp } from 'firebase-admin/firestore';
import { db } from '../../src/shared/admin';
import { onUserProfileWrite, syncPublicProfile } from '../../src/profiles/public_profile';

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

async function write(uid: string, before: Record<string, unknown>, after: Record<string, unknown>) {
  await db.doc(`users/${uid}`).set(after);
  await deliver(uid, before, after);
}

async function mirrorOf(uid: string) {
  return (await db.doc(`publicProfiles/${uid}`).get()).data();
}

const user = { profileName: 'Aru', email: 'aru@example.test' };

describe('onUserProfileWrite', () => {
  afterAll(() => test.cleanup());

  it('writes the mirror on create', async () => {
    await write('create', {}, user);
    const mirror = await mirrorOf('create');
    expect(mirror?.profileName).toBe('Aru');
    expect(mirror?.updatedAt).toBeDefined();
    expect(mirror).not.toHaveProperty('email');
  });

  it('rewrites the mirror on a name change', async () => {
    await write('rename', {}, user);
    await write('rename', user, { ...user, profileName: 'Dana' });
    expect((await mirrorOf('rename'))?.profileName).toBe('Dana');
  });

  it('skips a private change', async () => {
    const studying = {
      ...user,
      isStudying: true,
      activeSession: { courseId: 'c1', startUtc: Timestamp.fromMillis(1000) },
    };
    await write('private', {}, studying);
    const before = await mirrorOf('private');
    await write('private', studying, { ...studying, email: 'other@example.test' });
    expect((await mirrorOf('private'))?.updatedAt).toEqual(before?.updatedAt);
  });

  it('keeps the current state when an older event arrives last', async () => {
    const started = { ...user, isStudying: true };
    const ended = { ...user, isStudying: false };
    await write('order', started, ended);
    await deliver('order', ended, started);
    expect((await mirrorOf('order'))?.isStudying).toBe(false);
  });

  it('repairs a stale mirror on a private change', async () => {
    await db.doc('publicProfiles/stale').set({ profileName: 'Old' });
    await write('stale', user, { ...user, email: 'other@example.test' });
    expect((await mirrorOf('stale'))?.profileName).toBe('Aru');
  });

  it('removes the mirror on delete', async () => {
    await write('remove', {}, user);
    await db.doc('users/remove').delete();
    await deliver('remove', user, {});
    expect(await mirrorOf('remove')).toBeUndefined();
  });

  it('does not mirror a deleted user from a late event', async () => {
    await deliver('gone', {}, user);
    expect(await mirrorOf('gone')).toBeUndefined();
  });

  it('asks for failed events to be retried', () => {
    expect(onUserProfileWrite.__endpoint.eventTrigger?.retry).toBe(true);
  });

  it('fills a missing mirror without an event', async () => {
    await db.doc('users/filled').set(user);
    await syncPublicProfile('filled');
    expect((await mirrorOf('filled'))?.profileName).toBe('Aru');
  });
});
