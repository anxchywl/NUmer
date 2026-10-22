import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { auth, db } from '../shared/admin';
import { requireAppCheck } from '../shared/app_check';
import { hasRole, mergeRoles, normalizeRoles, rolesOf } from './roles';

function assertUid(value: unknown): string {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) {
    throw new functions.https.HttpsError('invalid-argument', 'uid is invalid.');
  }
  return value;
}

export const setUserRoles = functions.https.onCall(async (data, context) => {
  requireAppCheck(context);
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }
  const actor = context.auth.uid;
  // a token issued before a demotion still carries the role, so the current claims decide too
  if (
    !hasRole(context.auth.token, 'numer:admin') ||
    !hasRole((await auth.getUser(actor)).customClaims, 'numer:admin')
  ) {
    throw new functions.https.HttpsError('permission-denied', 'Only an administrator can set roles.');
  }

  const uid = assertUid(data?.uid);
  const roles = normalizeRoles(data?.roles);
  if (uid === actor && !roles.includes('numer:admin')) {
    throw new functions.https.HttpsError('failed-precondition', 'You cannot remove your own administrator role.');
  }

  const { customClaims } = await auth.getUser(uid);
  const before = rolesOf(customClaims);
  await auth.setCustomUserClaims(uid, mergeRoles(customClaims, roles));
  // an issued token keeps a removed role until the user is forced to sign in again
  if (before.some((role) => !roles.includes(role))) {
    await auth.revokeRefreshTokens(uid);
  }
  await db.collection('roleAudit').add({
    actor,
    target: uid,
    before,
    after: roles,
    at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { roles };
});
