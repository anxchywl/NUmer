import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';

const memberRef = (groupId: string, uid: string) =>
  db.collection('groups').doc(groupId).collection('members').doc(uid);

const indexRef = (uid: string) => db.collection('groupIndex').doc(uid);

// a retried event is harmless because the write depends only on what exists now
export const onGroupMemberWrite = functions
  .runWith({ failurePolicy: true })
  .firestore.document('groups/{groupId}/members/{memberId}')
  .onWrite(async (change, context) => {
    if (change.before.exists && change.after.exists) return;

    const { groupId, memberId } = context.params;

    // events arrive late or twice, and the transaction stops a change landing between read and write
    await db.runTransaction(async (txn) => {
      const member = await txn.get(memberRef(groupId, memberId));
      const { arrayUnion, arrayRemove, serverTimestamp } = admin.firestore.FieldValue;
      txn.set(indexRef(memberId), {
        groupIds: member.exists ? arrayUnion(groupId) : arrayRemove(groupId),
        updatedAt: serverTimestamp(),
      }, { merge: true });
    });
  });

function isGroupMember(ref: FirebaseFirestore.DocumentReference): boolean {
  const group = ref.parent.parent;
  return group !== null && group.parent.id === 'groups' && group.parent.parent === null;
}

// indexed users without a membership are listed too, so their stale ids get cleared
export async function collectMemberships(): Promise<Map<string, string[]>> {
  const memberships = new Map<string, string[]>();
  const members = await db.collectionGroup('members').get();
  for (const doc of members.docs) {
    if (!isGroupMember(doc.ref)) continue;
    const groupIds = memberships.get(doc.id) ?? [];
    groupIds.push(doc.ref.parent.parent!.id);
    memberships.set(doc.id, groupIds);
  }

  const indexed = await db.collection('groupIndex').select().get();
  for (const doc of indexed.docs) {
    if (!memberships.has(doc.id)) memberships.set(doc.id, []);
  }
  return memberships;
}

// candidates may be out of date, so only memberships that exist at write time are kept
export async function syncGroupIndex(uid: string, candidates: string[]): Promise<void> {
  await db.runTransaction(async (txn) => {
    const index = await txn.get(indexRef(uid));
    const indexed: string[] = index.data()?.groupIds ?? [];
    const groupIds = [...new Set([...indexed, ...candidates])];
    const members = await Promise.all(groupIds.map((groupId) => txn.get(memberRef(groupId, uid))));
    txn.set(indexRef(uid), {
      groupIds: groupIds.filter((_, i) => members[i].exists),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}
