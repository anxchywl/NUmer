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

describe('firestore rules feed', () => {
  let env: RulesTestEnvironment;

  const as = (uid: string, token: Record<string, unknown> = {}): Db =>
    env.authenticatedContext(uid, token).firestore() as unknown as Db;
  const anon = (): Db => env.unauthenticatedContext().firestore() as unknown as Db;
  const editor = () => as('ed', { numer_roles: ['numer:editor'] });

  beforeAll(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-numer-feed',
      firestore: { rules: fs.readFileSync('../firestore/firestore.rules', 'utf8') },
    });
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('feed/current').set({ items: [] });
      await db.doc('announcements/x').set({ title: { en: 't' } });
      await db.doc('feedState/events').set({ seen: {} });
    });
  });

  afterAll(async () => {
    await env.cleanup();
  });

  it('lets a signed-in user get the feed', async () => {
    await assertSucceeds(as('u').doc('feed/current').get());
  });

  it('denies a signed-out user the feed', async () => {
    await assertFails(anon().doc('feed/current').get());
  });

  it('denies listing and writing the feed', async () => {
    for (const db of [as('u'), editor()]) {
      await assertFails(db.collection('feed').get());
      await assertFails(db.doc('feed/current').set({ items: [] }));
      await assertFails(db.doc('feed/current').delete());
    }
  });

  it('denies every client any access to the feed state', async () => {
    for (const db of [as('u'), editor()]) {
      await assertFails(db.doc('feedState/events').get());
      await assertFails(db.collection('feedState').get());
      await assertFails(db.doc('feedState/events').set({ seen: {} }));
    }
  });

  it('denies every client any access to announcements, editors included', async () => {
    for (const db of [as('u'), editor()]) {
      await assertFails(db.doc('announcements/x').get());
      await assertFails(db.collection('announcements').get());
      await assertFails(db.doc('announcements/x').update({ retracted: true }));
      await assertFails(db.collection('announcements').add({ title: { en: 't' } }));
    }
  });
});
