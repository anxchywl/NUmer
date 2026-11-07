import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { timingSafeEqual } from 'crypto';
import { db } from '../shared/admin';
import { requireAppCheck } from '../shared/app_check';
import { assertId, assertString } from '../shared/validation';
import { deleteGroupCascade } from './cleanup';

const maxUserAttempts = 5;
const maxGroupAttempts = 50;
const attemptWindowMs = 3600 * 1000;
const attemptTtlMs = 2 * 24 * 3600 * 1000;

function attemptRefs(uid: string, groupId: string) {
  const attempts = db.collection('joinAttempts');
  const day = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  return {
    user: attempts.doc(`${uid}_${groupId}`),
    group: attempts.doc(`group_${groupId}_${day}`),
  };
}

type AttemptRefs = ReturnType<typeof attemptRefs>;

function isWindowOpen(data: FirebaseFirestore.DocumentData | undefined, now: number) {
  const start = data?.windowStart as admin.firestore.Timestamp | undefined;
  return !!start && now - start.toMillis() < attemptWindowMs;
}

// counted before the code is checked so parallel guesses cannot pass the limit
async function reserveAttempt(refs: AttemptRefs) {
  await db.runTransaction(async (txn) => {
    const [userSnap, groupSnap] = await txn.getAll(refs.user, refs.group);
    const now = Date.now();
    const userData = userSnap.data();
    const open = isWindowOpen(userData, now);
    const userCount = open ? userData?.count ?? 0 : 0;
    const groupCount = groupSnap.data()?.count ?? 0;
    if (userCount >= maxUserAttempts || groupCount >= maxGroupAttempts) {
      throw new functions.https.HttpsError('resource-exhausted', 'Too many attempts. Try again later.');
    }

    const expiresAt = admin.firestore.Timestamp.fromMillis(now + attemptTtlMs);
    txn.set(refs.user, {
      count: userCount + 1,
      windowStart: open ? userData?.windowStart : admin.firestore.Timestamp.fromMillis(now),
      expiresAt,
    });
    txn.set(refs.group, { count: groupCount + 1, expiresAt });
  });
}

// an emptied counter is deleted so the window starts at the first wrong code
async function releaseAttempt(refs: AttemptRefs) {
  await db.runTransaction(async (txn) => {
    const snaps = await txn.getAll(refs.user, refs.group);
    for (const snap of snaps) {
      const count = snap.data()?.count ?? 0;
      if (count > 1) {
        txn.update(snap.ref, { count: count - 1 });
      } else {
        txn.delete(snap.ref);
      }
    }
  });
}

function codesMatch(stored: unknown, given: string) {
  if (typeof stored !== 'string') return false;
  const expected = Buffer.from(stored, 'utf8');
  const actual = Buffer.from(given, 'utf8');
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

export const deleteGroupCallable = functions.https.onCall(async (data, context) => {
  requireAppCheck(context, 'deleteGroupCallable');
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const groupId = assertId(data?.groupId, 'groupId');

  const uid = context.auth.uid;
  const groupRef = db.collection('groups').doc(groupId);
  const groupSnap = await groupRef.get();

  if (!groupSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Group not found');
  }

  if (groupSnap.data()?.createdBy !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Only the group creator can delete this group');
  }

  await deleteGroupCascade(groupRef);

  return { success: true };
});

export const joinPrivateGroup = functions.https.onCall(async (data, context) => {
  requireAppCheck(context, 'joinPrivateGroup');
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  }

  const groupId = assertId(data?.groupId, 'groupId');
  const joinCode = assertString(data?.joinCode, 'joinCode', 64);

  // Validate join code format (alphanumeric only)
  if (!/^[a-zA-Z0-9]+$/.test(joinCode)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid join code format.');
  }

  const uid = context.auth.uid;
  const groupRef = db.collection('groups').doc(groupId);
  const attempts = attemptRefs(uid, groupId);

  await reserveAttempt(attempts);

  let accepted: boolean | undefined;
  try {
    accepted = await db.runTransaction(async (txn) => {
      const groupSnap = await txn.get(groupRef);
      if (!groupSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'Group not found');
      }

      const groupData = groupSnap.data();
      const visibility = groupData?.visibility || 'public';

      if (visibility !== 'private') {
        throw new functions.https.HttpsError('failed-precondition', 'This group is not private. You can join it directly.');
      }

      // Check if user is already a member
      const membershipRef = db.collection('users').doc(uid).collection('groupMemberships').doc(groupId);
      const membershipSnap = await txn.get(membershipRef);
      if (membershipSnap.exists) {
        return true; // already a member, nothing else to do
      }

      // Verify Join Code
      // We store secrets in a subcollection to prevent public read access via client SDKs
      // Assuming admin creates this doc when setting group to private
      const secretRef = groupRef.collection('secrets').doc('settings');
      const userRef = db.collection('users').doc(uid);
      const [secretSnap, userSnap] = await txn.getAll(secretRef, userRef);

      if (!secretSnap.exists) {
        // Fallback or error if secret config is missing.
        // If no code is set, maybe deny?
        throw new functions.https.HttpsError('internal', 'Group configuration error. No join code set.');
      }

      if (!codesMatch(secretSnap.data()?.joinCode, joinCode)) {
        return false;
      }

      // Code is correct, add member
      const memberRef = groupRef.collection('members').doc(uid);
      const now = admin.firestore.FieldValue.serverTimestamp();

      txn.set(memberRef, {
        role: 'member',
        joinedAt: now,
      });

      txn.set(membershipRef, {
        groupId,
        role: 'member',
        joinedAt: now,
      });

      if (userSnap.exists) {
        txn.update(userRef, { groupIds: admin.firestore.FieldValue.arrayUnion(groupId) });
      }

      const currentCount = (groupData?.memberCount || 0) as number;
      txn.update(groupRef, {
        memberCount: currentCount + 1,
        updatedAt: now,
      });
      return true;
    });
  } finally {
    // only a wrong code keeps its reserved attempt
    if (accepted !== false) {
      await releaseAttempt(attempts);
    }
  }

  if (!accepted) {
    throw new functions.https.HttpsError('permission-denied', 'Incorrect join code.');
  }

  return { success: true };
});
