import * as fs from 'fs';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

type Db = firebase.firestore.Firestore;

describe('firestore rules grades', () => {
  let env: RulesTestEnvironment;

  const as = (uid: string): Db => env.authenticatedContext(uid).firestore() as unknown as Db;
  const anon = (): Db => env.unauthenticatedContext().firestore() as unknown as Db;
  const paths = ['users/owner/courseGrades/1700000000000_1', 'users/owner/semesters/s1'];

  beforeAll(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-numer-grades',
      firestore: { rules: fs.readFileSync('../firestore/firestore.rules', 'utf8') },
    });
  });

  afterAll(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('groupIndex/owner').set({ groupIds: ['G'] });
      await db.doc('groupIndex/peer').set({ groupIds: ['G'] });
      await db.doc('users/owner/courses/1700000000000_1').set({ name: 'course' });
      await db.doc('users/owner/courseGrades/1700000000000_1').set({ semesterId: 's1' });
      await db.doc('users/owner/semesters/s1').set({ name: 'Fall', position: 0 });
    });
  });

  it('lets the owner read and write grades and semesters', async () => {
    const db = as('owner');
    for (const path of paths) {
      await assertSucceeds(db.doc(path).get());
      await assertSucceeds(db.doc(path).set({ updatedAt: 1 }, { merge: true }));
      await assertSucceeds(db.doc(path).delete());
    }
    await assertSucceeds(db.collection('users/owner/courseGrades').get());
    await assertSucceeds(db.collection('users/owner/semesters').get());
  });

  it('denies a group peer who can read the courses', async () => {
    const db = as('peer');
    await assertSucceeds(db.doc('users/owner/courses/1700000000000_1').get());
    for (const path of paths) {
      await assertFails(db.doc(path).get());
      await assertFails(db.doc(path).set({ updatedAt: 1 }));
      await assertFails(db.doc(path).delete());
    }
    await assertFails(db.collection('users/owner/courseGrades').get());
    await assertFails(db.collection('users/owner/semesters').get());
  });

  it('denies a signed-out client', async () => {
    for (const path of paths) {
      await assertFails(anon().doc(path).get());
      await assertFails(anon().doc(path).set({ updatedAt: 1 }));
    }
  });
});
