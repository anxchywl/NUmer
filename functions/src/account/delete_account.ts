import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { requireAppCheck } from '../shared/app_check';
import {
  deleteGroupCascade,
  deleteUserCollections,
  removeUserMemberships,
} from '../groups/cleanup';

export const deleteAccountCallable = functions.https.onCall(async (_data, context) => {
  requireAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const userId = context.auth.uid;

  const ownedGroupsSnap = await db
    .collection('groups')
    .where('createdBy', '==', userId)
    .get();
  const ownedGroupIds = new Set(ownedGroupsSnap.docs.map((doc) => doc.id));

  await removeUserMemberships(userId, ownedGroupIds);

  for (const groupDoc of ownedGroupsSnap.docs) {
    await deleteGroupCascade(groupDoc.ref);
  }

  const userRef = db.collection('users').doc(userId);
  await deleteUserCollections(userId, [
    'courses',
    'studyTimes',
    'courseGoals',
    'courseProgress',
    'sessions',
    'studySessions',
    'goals',
    'reflections',
    'preferences',
    'groupMemberships',
    'meta',
    'aggregates',
    'aiLogs',
    'stats',
  ]);

  await db.recursiveDelete(userRef);
  await admin.auth().deleteUser(userId);

  return { success: true };
});
