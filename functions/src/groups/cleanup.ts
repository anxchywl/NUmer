import * as admin from 'firebase-admin';
import { db } from '../shared/admin';

export async function deleteQueryBatch(
  query: FirebaseFirestore.Query,
  batchSize = 250,
) {
  while (true) {
    const snapshot = await query.limit(batchSize).get();
    if (snapshot.empty) break;
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    if (snapshot.size < batchSize) break;
  }
}

export async function deleteUserCollections(userId: string, names: string[]) {
  const userRef = db.collection('users').doc(userId);
  await Promise.all(
    names.map((name) => deleteQueryBatch(userRef.collection(name))),
  );
}

export async function deleteGroupCascade(groupRef: FirebaseFirestore.DocumentReference) {
  const groupId = groupRef.id;
  const membersSnap = await groupRef.collection('members').get();
  const memberIds = membersSnap.docs.map((doc) => doc.id);

  await db.recursiveDelete(groupRef);

  const chunkSize = 400;
  for (let i = 0; i < memberIds.length; i += chunkSize) {
    const batch = db.batch();
    const slice = memberIds.slice(i, i + chunkSize);
    for (const memberId of slice) {
      const userRef = db.collection('users').doc(memberId);
      const membershipRef = userRef.collection('groupMemberships').doc(groupId);
      batch.delete(membershipRef);
      batch.set(
        userRef,
        { groupIds: admin.firestore.FieldValue.arrayRemove(groupId) },
        { merge: true },
      );
    }
    await batch.commit();
  }
}

export async function removeUserMemberships(userId: string, ownedGroupIds: Set<string>) {
  const membershipSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('groupMemberships')
    .get();

  const chunkSize = 400;
  for (let i = 0; i < membershipSnapshot.docs.length; i += chunkSize) {
    const slice = membershipSnapshot.docs.slice(i, i + chunkSize);
    const groupIds = slice.map((doc) => doc.id);
    const groupSnaps = await Promise.all(
      groupIds.map((groupId) => db.collection('groups').doc(groupId).get()),
    );

    const batch = db.batch();
    for (let j = 0; j < slice.length; j++) {
      const membership = slice[j];
      const groupId = membership.id;
      const groupSnap = groupSnaps[j];
      const groupRef = db.collection('groups').doc(groupId);

      batch.delete(groupRef.collection('members').doc(userId));
      batch.delete(groupRef.collection('aggregates').doc(userId));
      batch.delete(membership.ref);

      if (!ownedGroupIds.has(groupId) && groupSnap.exists) {
        batch.set(
          groupRef,
          {
            memberCount: admin.firestore.FieldValue.increment(-1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }
    await batch.commit();
  }
}
