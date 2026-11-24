import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { auth, db } from '../shared/admin';
import { requireAppCheck } from '../shared/app_check';
import { updateIfExists } from '../shared/user_writes';
import { assertId } from '../shared/validation';
import { hasRole } from '../roles/roles';
import { parseAnnouncement } from './announcement_input';

async function requireEditor(context: functions.https.CallableContext, name: string): Promise<string> {
  requireAppCheck(context, name);
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }
  const { uid, token } = context.auth;
  // a token issued before a demotion still carries the role, so the current claims decide too
  if (
    !hasRole(token, 'numer:editor') ||
    !hasRole((await auth.getUser(uid)).customClaims, 'numer:editor')
  ) {
    throw new functions.https.HttpsError('permission-denied', 'Only an editor can manage announcements.');
  }
  return uid;
}

export const publishAnnouncement = functions.https.onCall(async (data, context) => {
  const uid = await requireEditor(context, 'publishAnnouncement');
  const { expiresAt, ...input } = parseAnnouncement(data, Date.now());

  const ref = await db.collection('announcements').add({
    ...input,
    ...(expiresAt !== undefined && { expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt) }),
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
    authorUid: uid,
    retracted: false,
  });
  return { id: ref.id };
});

export const retractAnnouncement = functions.https.onCall(async (data, context) => {
  const uid = await requireEditor(context, 'retractAnnouncement');
  const id = assertId(data?.id, 'id');

  const found = await updateIfExists(db.collection('announcements').doc(id), {
    retracted: true,
    retractedAt: admin.firestore.FieldValue.serverTimestamp(),
    retractedBy: uid,
  });
  if (!found) {
    throw new functions.https.HttpsError('not-found', 'The announcement does not exist.');
  }
  return { id };
});
