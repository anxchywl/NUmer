import functionsTest from 'firebase-functions-test';
import { db } from '../../src/shared/admin';
import {
  collectMemberships,
  onGroupMemberWrite,
  syncGroupIndex,
} from '../../src/groups/membership_index';

const test = functionsTest({ projectId: 'demo-numer' });
const wrapped = test.wrap(onGroupMemberWrite);

const memberPath = (groupId: string, uid: string) => `groups/${groupId}/members/${uid}`;

function snapshot(path: string, data: Record<string, unknown>) {
  return test.firestore.makeDocumentSnapshot(data, path);
}

async function deliver(groupId: string, uid: string, before: object, after: object) {
  const path = memberPath(groupId, uid);
  const change = test.makeChange(
    snapshot(path, before as Record<string, unknown>),
    snapshot(path, after as Record<string, unknown>),
  );
  await wrapped(change, { params: { groupId, memberId: uid } });
}

async function join(groupId: string, uid: string) {
  await db.doc(memberPath(groupId, uid)).set({ role: 'member' });
  await deliver(groupId, uid, {}, { role: 'member' });
}

async function leave(groupId: string, uid: string) {
  await db.doc(memberPath(groupId, uid)).delete();
  await deliver(groupId, uid, { role: 'member' }, {});
}

async function indexOf(uid: string) {
  return (await db.doc(`groupIndex/${uid}`).get()).data();
}

afterAll(() => test.cleanup());

describe('onGroupMemberWrite', () => {
  it('adds the group id on create', async () => {
    await join('g1', 'create');
    expect((await indexOf('create'))?.groupIds).toEqual(['g1']);
  });

  it('adds a second group id', async () => {
    await join('g1', 'second');
    await join('g2', 'second');
    expect((await indexOf('second'))?.groupIds).toEqual(['g1', 'g2']);
  });

  it('removes only the deleted group id', async () => {
    await join('g1', 'leaver');
    await join('g2', 'leaver');
    await leave('g1', 'leaver');
    expect((await indexOf('leaver'))?.groupIds).toEqual(['g2']);
  });

  it('leaves the index unchanged on update', async () => {
    await join('g1', 'update');
    const before = await indexOf('update');
    await deliver('g1', 'update', { role: 'member' }, { role: 'admin' });
    expect(await indexOf('update')).toEqual(before);
  });

  it('asks for failed events to be retried', () => {
    expect(onGroupMemberWrite.__endpoint.eventTrigger?.retry).toBe(true);
  });

  it('writes no index when a create event arrives after the delete', async () => {
    await deliver('g1', 'late', {}, { role: 'member' });
    expect(await indexOf('late')).toBeUndefined();
  });
});

describe('group index backfill', () => {
  const backfill = async (uid: string, collected: Map<string, string[]>) => {
    await syncGroupIndex(uid, collected.get(uid) ?? []);
  };

  it('keeps a leave that lands after the memberships were read', async () => {
    await join('g1', 'race-leave');
    await join('g2', 'race-leave');
    const collected = await collectMemberships();
    await leave('g1', 'race-leave');
    await backfill('race-leave', collected);
    expect((await indexOf('race-leave'))?.groupIds).toEqual(['g2']);
  });

  it('keeps a join that lands after the memberships were read', async () => {
    await join('g1', 'race-join');
    const collected = await collectMemberships();
    await join('g2', 'race-join');
    await backfill('race-join', collected);
    expect((await indexOf('race-join'))?.groupIds).toEqual(['g1', 'g2']);
  });

  it('does not restore a membership whose events are still pending', async () => {
    await db.doc(memberPath('g1', 'pending')).set({ role: 'member' });
    const collected = await collectMemberships();
    await db.doc(memberPath('g1', 'pending')).delete();
    await backfill('pending', collected);
    expect((await indexOf('pending'))?.groupIds).toEqual([]);
  });

  it('clears a user with no memberships left', async () => {
    await db.doc('groupIndex/emptied').set({ groupIds: ['g1'] });
    const collected = await collectMemberships();
    expect(collected.get('emptied')).toEqual([]);
    await backfill('emptied', collected);
    expect((await indexOf('emptied'))?.groupIds).toEqual([]);
  });

  it('fills a missing index and skips members outside groups', async () => {
    await db.doc(memberPath('g1', 'missing')).set({ role: 'member' });
    await db.doc('other/o1/members/missing').set({ role: 'member' });
    await db.doc('other/o1/groups/g9/members/missing').set({ role: 'member' });
    const collected = await collectMemberships();
    expect(collected.get('missing')).toEqual(['g1']);
    await backfill('missing', collected);
    expect((await indexOf('missing'))?.groupIds).toEqual(['g1']);
  });
});
