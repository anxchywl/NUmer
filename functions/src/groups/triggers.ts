import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';

export const onGroupMemberDelete = functions.firestore
  .document('groups/{groupId}/members/{memberId}')
  .onDelete(async (_snap, context) => {
    const { groupId, memberId } = context.params;
    const userRef = db.collection('users').doc(memberId);
    const batch = db.batch();

    batch.delete(userRef.collection('groupMemberships').doc(groupId));
    batch.set(userRef, {
      groupIds: admin.firestore.FieldValue.arrayRemove(groupId),
    }, { merge: true });
    batch.delete(db.collection('groups').doc(groupId).collection('aggregates').doc(memberId));

    try {
      await batch.commit();
    } catch (err) {
      functions.logger.warn('Failed to clean up after member removal', err);
    }
  });
