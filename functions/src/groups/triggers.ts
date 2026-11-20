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

export const deleteGroup = functions.firestore
  .document('groups/{groupId}')
  .onDelete(async (snap, context) => {
    // This is a backup cleanup trigger, but we'll also implement a callable for direct deletion
    // to ensure we can handle the recursive delete properly and return success/failure to client.
    // Actually, let's just make it a Callable function that the client calls.
  });
