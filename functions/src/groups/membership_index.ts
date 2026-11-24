import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';

export const onGroupMemberWrite = functions.firestore
  .document('groups/{groupId}/members/{memberId}')
  .onWrite(async (change, context) => {
    if (change.before.exists && change.after.exists) return;

    const { groupId, memberId } = context.params;
    const memberRef = db.collection('groups').doc(groupId).collection('members').doc(memberId);
    const indexRef = db.collection('groupIndex').doc(memberId);

    // events arrive late or twice, and the transaction stops a change landing between read and write
    await db.runTransaction(async (txn) => {
      const member = await txn.get(memberRef);
      const { arrayUnion, arrayRemove, serverTimestamp } = admin.firestore.FieldValue;
      txn.set(indexRef, {
        groupIds: member.exists ? arrayUnion(groupId) : arrayRemove(groupId),
        updatedAt: serverTimestamp(),
      }, { merge: true });
    });
  });
