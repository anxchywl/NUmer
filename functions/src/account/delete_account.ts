import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { requireAppCheck } from '../shared/app_check';
import { normalizeEmail, sha256Hex } from '../auth/codes';
import { deletionMarkerRef } from '../shared/user_writes';

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

async function markForDeletion(uid: string, email: unknown) {
  const markerRef = deletionMarkerRef(uid);
  await db.runTransaction(async (txn) => {
    const marker = await txn.get(markerRef);
    if (!marker.exists) {
      txn.create(markerRef, {
        uid,
        emailHash: typeof email === 'string' ? sha256Hex(normalizeEmail(email)) : null,
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + markerTtlMs),
      });
      return;
    }
    if (marker.data()?.status === 'done') return;
    txn.update(markerRef, { retryRequestedAt: admin.firestore.FieldValue.serverTimestamp() });
  });
}

// the purge may already have removed the auth user, which is the end state anyway
async function disableUser(uid: string) {
  try {
    await admin.auth().updateUser(uid, { disabled: true });
    await admin.auth().revokeRefreshTokens(uid);
  } catch (err) {
    if ((err as { code?: unknown }).code !== 'auth/user-not-found') throw err;
  }
}

// the marker comes first, so a failure after it still ends in a purge instead of a locked account
export const deleteAccountCallable = functions.https.onCall(async (_data, context) => {
  requireAppCheck(context, 'deleteAccountCallable');
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const { uid, token } = context.auth;
  requireRecentAuth(token.auth_time);

  await markForDeletion(uid, token.email);
  await disableUser(uid);

  return { success: true };
});
