import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { updateIfExists } from '../shared/user_writes';

export const onGroupMemberDelete = functions.firestore
  .document('groups/{groupId}/members/{memberId}')
  .onDelete(async (_snap, context) => {
    const { groupId, memberId } = context.params;
    const userRef = db.collection('users').doc(memberId);

    await Promise.all([
      userRef.collection('groupMemberships').doc(groupId).delete(),
      updateIfExists(userRef, { groupIds: admin.firestore.FieldValue.arrayRemove(groupId) }),
      db.collection('groups').doc(groupId).collection('aggregates').doc(memberId).delete(),
    ]);
  });
