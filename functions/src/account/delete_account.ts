import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { requireAppCheck } from '../shared/app_check';
import { normalizeEmail, sha256Hex } from '../auth/codes';

const recentAuthSeconds = 300;
const markerTtlMs = 30 * 24 * 3600 * 1000;

function requireRecentAuth(authTime: number) {
  if (process.env.DELETE_REQUIRES_RECENT_AUTH !== 'on') return;
  if (Date.now() / 1000 - authTime < recentAuthSeconds) return;
  throw new functions.https.HttpsError(
    'failed-precondition',
    'Sign in again to delete your account.',
    { reason: 'recent-login-required' },
  );
}

// the purge runs in onUserDeletionRequested, because a disabled user cannot call again
export const deleteAccountCallable = functions.https.onCall(async (_data, context) => {
  requireAppCheck(context, 'deleteAccountCallable');
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { uid, token } = context.auth;
  requireRecentAuth(token.auth_time);

  await admin.auth().updateUser(uid, { disabled: true });
  await admin.auth().revokeRefreshTokens(uid);

  const markerRef = db.collection('deletedUsers').doc(uid);
  await db.runTransaction(async (txn) => {
    const marker = await txn.get(markerRef);
    if (!marker.exists) {
      txn.create(markerRef, {
        uid,
        emailHash: typeof token.email === 'string' ? sha256Hex(normalizeEmail(token.email)) : null,
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + markerTtlMs),
      });
      return;
    }
    if (marker.data()?.status === 'done') return;
    txn.update(markerRef, { retryRequestedAt: admin.firestore.FieldValue.serverTimestamp() });
  });

  return { success: true };
});
