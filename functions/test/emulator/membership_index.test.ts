import functionsTest from 'firebase-functions-test';
import { db } from '../../src/shared/admin';
import { onGroupMemberWrite } from '../../src/groups/membership_index';

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

describe('onGroupMemberWrite', () => {
  afterAll(() => test.cleanup());

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

  it('leaves the id out when a create event arrives after the delete', async () => {
    await deliver('g1', 'late', {}, { role: 'member' });
    expect((await indexOf('late'))?.groupIds).toEqual([]);
  });
});
