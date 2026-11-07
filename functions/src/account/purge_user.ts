import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { normalizeEmail, sha256Hex } from '../auth/codes';
import { deleteGroupCascade, deleteQueryBatch, removeUserMemberships } from '../groups/cleanup';
import { deletionMarkerRef } from '../shared/user_writes';

const alreadyExistsCode = 6;
const nudgeBatchSize = 300;
const sweepDelayMs = 2 * 3600 * 1000;
const sweepLimit = 100;

const userRef = (uid: string) => db.collection('users').doc(uid);

function hasCode(err: unknown, code: unknown): boolean {
  return (err as { code?: unknown } | null)?.code === code;
}

// the ids stay on the marker so later passes can remove documents a racing trigger wrote back
async function removeGroups(uid: string) {
  const owned = await db.collection('groups').where('createdBy', '==', uid).get();
  const memberships = await userRef(uid).collection('groupMemberships').select().get();
  const groupIds = [...owned.docs, ...memberships.docs].map((doc) => doc.id);
  if (groupIds.length > 0) {
    await deletionMarkerRef(uid).update({ groupIds: admin.firestore.FieldValue.arrayUnion(...groupIds) });
  }
  await removeUserMemberships(uid, new Set(owned.docs.map((doc) => doc.id)));
  for (const group of owned.docs) {
    await deleteGroupCascade(group.ref);
  }
}

async function removeGroupLeftovers(uid: string) {
  const groupIds: string[] = (await deletionMarkerRef(uid).get()).get('groupIds') ?? [];
  const chunkSize = 200;
  for (let i = 0; i < groupIds.length; i += chunkSize) {
    const batch = db.batch();
    for (const groupId of groupIds.slice(i, i + chunkSize)) {
      const group = db.collection('groups').doc(groupId);
      batch.delete(group.collection('aggregates').doc(uid));
      batch.delete(group.collection('members').doc(uid));
    }
    await batch.commit();
  }
}

async function deleteNudges(uid: string) {
  const nudges = db.collection('nudges');
  await deleteQueryBatch(nudges.where('senderId', '==', uid), nudgeBatchSize);
  await deleteQueryBatch(nudges.where('receiverId', '==', uid), nudgeBatchSize);
}

async function emailOf(uid: string): Promise<string | undefined> {
  try {
    return (await admin.auth().getUser(uid)).email;
  } catch (err) {
    if (hasCode(err, 'auth/user-not-found')) return undefined;
    throw err;
  }
}

async function deleteAuthRecords(uid: string) {
  await deleteQueryBatch(db.collection('email_index').where('uid', '==', uid));
  const codes = db.collection('authCodes');
  await codes.doc(`verify_${uid}`).delete();
  const email = await emailOf(uid);
  if (email) {
    await codes.doc(`reset_${sha256Hex(normalizeEmail(email))}`).delete();
  }
}

async function deleteMirrors(uid: string) {
  await Promise.all([
    db.collection('publicProfiles').doc(uid).delete(),
    db.collection('groupIndex').doc(uid).delete(),
  ]);
}

async function deleteAuthUser(uid: string) {
  try {
    await admin.auth().deleteUser(uid);
  } catch (err) {
    if (!hasCode(err, 'auth/user-not-found')) throw err;
  }
}

async function recordEvent(uid: string) {
  try {
    await db.collection('accountEvents').doc(`deleted_${uid}`).create({
      type: 'account.deleted',
      issuer: `https://securetoken.google.com/${process.env.GCLOUD_PROJECT}`,
      subject: uid,
      occurredAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending',
    });
  } catch (err) {
    if (!hasCode(err, alreadyExistsCode)) throw err;
  }
}

// sweptAt starts as null so the sweep can query for it
async function markDone(uid: string) {
  await deletionMarkerRef(uid).update({
    status: 'done',
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    sweptAt: null,
  });
}

// the root document goes first so triggers see the user as gone and stop writing
const purgeSteps: [string, (uid: string) => Promise<unknown>][] = [
  ['groups', removeGroups],
  ['user_document', (uid) => userRef(uid).delete()],
  ['user_tree', (uid) => db.recursiveDelete(userRef(uid))],
  ['nudges', deleteNudges],
  ['auth_records', deleteAuthRecords],
  ['mirrors', deleteMirrors],
  ['user_tree_again', (uid) => db.recursiveDelete(userRef(uid))],
  ['group_leftovers', removeGroupLeftovers],
  ['auth_user', deleteAuthUser],
  ['event', recordEvent],
  ['done', markDone],
];

export async function purgeUser(uid: string): Promise<void> {
  for (const [step, run] of purgeSteps) {
    try {
      await run(uid);
    } catch (err) {
      functions.logger.error('user_purge_failed', { uid, step });
      throw err;
    }
  }
}

function retryRequested(change: functions.Change<functions.firestore.DocumentSnapshot>): boolean {
  if (!change.before.exists) return true;
  const before = change.before.get('retryRequestedAt') as admin.firestore.Timestamp | undefined;
  const after = change.after.get('retryRequestedAt') as admin.firestore.Timestamp | undefined;
  if (!after) return false;
  return !before || !before.isEqual(after);
}

export const onUserDeletionRequested = functions
  .runWith({ failurePolicy: true, timeoutSeconds: 540, memory: '512MB' })
  .firestore.document('deletedUsers/{uid}')
  .onWrite(async (change, context) => {
    if (!change.after.exists || change.after.get('status') !== 'pending') return;
    if (!retryRequested(change)) return;
    await purgeUser(context.params.uid);
  });

export async function sweepPurgedUsers(now = Date.now()): Promise<void> {
  const cutoff = admin.firestore.Timestamp.fromMillis(now - sweepDelayMs);
  const done = await db
    .collection('deletedUsers')
    .where('status', '==', 'done')
    .where('sweptAt', '==', null)
    .where('completedAt', '<', cutoff)
    .limit(sweepLimit)
    .get();
  for (const marker of done.docs) {
    await db.recursiveDelete(userRef(marker.id));
    await deleteMirrors(marker.id);
    await removeGroupLeftovers(marker.id);
    await marker.ref.update({ sweptAt: admin.firestore.FieldValue.serverTimestamp() });
  }
}

// another signed-in device can keep writing until its id token expires, up to an hour after the purge
export const sweepDeletedUsers = functions.pubsub
  .schedule('every 24 hours')
  .onRun(() => sweepPurgedUsers());
