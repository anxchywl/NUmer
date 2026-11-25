import * as fs from 'fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';

describe('firestore rules', () => {
  let env: RulesTestEnvironment;

  beforeAll(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-numer',
      firestore: { rules: fs.readFileSync('../firestore/firestore.rules', 'utf8') },
    });
  });

  afterAll(async () => {
    await env.cleanup();
  });

  it('denies an unauthenticated write to a user document', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(db.doc('users/u1').set({ profileName: 'u1' }));
  });

  it('allows a user to write their own document', async () => {
    const db = env.authenticatedContext('u1').firestore();
    await assertSucceeds(db.doc('users/u1').set({ profileName: 'u1' }));
  });

  it('denies a client any access to the role audit log', async () => {
    const db = env.authenticatedContext('u1', { numer_roles: ['numer:admin'] }).firestore();
    await assertFails(db.doc('roleAudit/a1').get());
    await assertFails(db.doc('roleAudit/a1').set({ actor: 'u1' }));
  });
});
