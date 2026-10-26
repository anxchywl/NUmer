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

const { FieldValue } = firebase.firestore;

describe('firestore rules stage 1', () => {
  let env: RulesTestEnvironment;

  const as = (uid: string, token: Record<string, unknown> = {}): Db =>
    env.authenticatedContext(uid, token).firestore() as unknown as Db;
  const anon = (): Db => env.unauthenticatedContext().firestore() as unknown as Db;

  beforeAll(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-numer-stage1',
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
      const seed: [string, Record<string, unknown>][] = [
        ['groups/PUB', { name: 'Pub', description: 'd', visibility: 'public', createdBy: 'creator', memberCount: 3 }],
        ['groups/PUB/members/creator', { role: 'admin' }],
        ['groups/PUB/members/adm', { role: 'admin' }],
        ['groups/PUB/members/mem', { role: 'member' }],
        ['groups/PRIV', { name: 'Priv', description: 'd', visibility: 'private', createdBy: 'creator', memberCount: 1 }],
        ['groups/PRIV/members/creator', { role: 'admin' }],
        ['groups/OLD', { name: 'Old', description: 'd', visibility: 'public', createdBy: 'creator' }],
        ['groups/OLD/members/creator', { role: 'admin' }],
        ['groups/OLD/members/adm', { role: 'admin' }],
        ['users/creator', { groupIds: ['PUB', 'PRIV', 'OLD'] }],
        ['users/adm', { groupIds: ['PUB', 'OLD'] }],
        ['users/mem', { groupIds: ['PUB'] }],
        ['users/mem/groupMemberships/PUB', { role: 'member' }],
        ['users/victim', { groupIds: ['VG'], emailVerified: true }],
        ['users/victim/sessions/s1', { uid: 'victim', seconds: 60 }],
        ['users/victim/courses/c1', { name: 'secret course' }],
        ['users/victim/aggregates/statistics', { totalSeconds: 60 }],
        ['users/creator/sessions/s1', { uid: 'creator', seconds: 60 }],
        ['users/creator/courses/c1', { name: 'course' }],
        ['users/creator/aggregates/statistics', { totalSeconds: 60 }],
        ['groupIndex/creator', { groupIds: ['PUB', 'PRIV', 'OLD'] }],
        ['groupIndex/adm', { groupIds: ['PUB', 'OLD'] }],
        ['groupIndex/mem', { groupIds: ['PUB'] }],
        ['groupIndex/victim', { groupIds: ['VG'] }],
        ['publicProfiles/victim', { displayName: 'Victim' }],
        ['publicProfiles/creator', { displayName: 'Creator' }],
        ['email_index/victim@x.com', { uid: 'victim', email: 'victim@x.com' }],
        ['nudges/n1', { receiverId: 'mem', status: 'pending', title: 't', body: 'b' }],
        ['config/app', { minVersion: '1.0.0' }],
        ['feed/current', { items: [] }],
      ];
      for (const [path, data] of seed) {
        await db.doc(path).set(data);
      }
    });
  });

  describe('denied', () => {
    it('a non-member creates an admin member document in a public group', async () => {
      await assertFails(
        as('att').doc('groups/PUB/members/att').set({ role: 'admin', joinedAt: FieldValue.serverTimestamp() }),
      );
    });

    it('a member promotes their own member document to admin', async () => {
      await assertFails(as('mem').doc('groups/PUB/members/mem').update({ role: 'admin' }));
    });

    it('an admin changes createdBy of a group', async () => {
      await assertFails(as('adm').doc('groups/PUB').update({ createdBy: 'adm' }));
    });

    it('an unauthenticated client gets a user document', async () => {
      await assertFails(anon().doc('users/victim').get());
    });

    it('an unauthenticated client lists users', async () => {
      await assertFails(anon().collection('users').get());
    });

    it('a signed-in user lists email_index', async () => {
      await assertFails(as('att', { email: 'att@x.com' }).collection('email_index').get());
    });

    it('a signed-in user writes the email_index entry of another email', async () => {
      await assertFails(
        as('att', { email: 'att@x.com' }).doc('email_index/victim@x.com').set({ uid: 'att', email: 'victim@x.com' }),
      );
    });

    describe('with groupIds forged on the attacker user document', () => {
      beforeEach(async () => {
        await assertSucceeds(as('att').doc('users/att').set({ groupIds: ['VG'] }, { merge: true }));
      });

      it('reads the victim sessions', async () => {
        await assertFails(as('att').doc('users/victim/sessions/s1').get());
      });

      it('reads the victim courses', async () => {
        await assertFails(as('att').doc('users/victim/courses/c1').get());
      });

      it('reads the victim aggregates', async () => {
        await assertFails(as('att').doc('users/victim/aggregates/statistics').get());
      });
    });

    it('an unauthenticated client reads user aggregates', async () => {
      await assertFails(anon().doc('users/victim/aggregates/statistics').get());
    });

    it('the owner writes a session longer than seven days', async () => {
      await assertFails(as('victim').doc('users/victim/sessions/long').set({ uid: 'victim', seconds: 10000000 }));
    });

    it('an admin who is not the creator deletes the creator member document', async () => {
      await assertFails(as('adm').doc('groups/PUB/members/creator').delete());
    });

    it('a user joins a private group by creating their own member document', async () => {
      await assertFails(
        as('att').doc('groups/PRIV/members/att').set({ role: 'member', joinedAt: FieldValue.serverTimestamp() }),
      );
    });

    it('a signed-in user without a shared group reads a public profile', async () => {
      await assertFails(as('att').doc('publicProfiles/victim').get());
    });

    it('a client writes server-maintained documents', async () => {
      const db = as('att');
      await assertFails(db.doc('publicProfiles/att').set({ displayName: 'x' }));
      await assertFails(db.doc('groupIndex/att').set({ groupIds: ['VG'] }));
      await assertFails(db.doc('config/app').set({ minVersion: '0' }));
      await assertFails(db.doc('feed/current').set({ items: [] }));
      await assertFails(db.doc('authCodes/x').set({ code: '1' }));
    });

    it('a receiver sets a nudge status other than delivered', async () => {
      await assertFails(as('mem').doc('nudges/n1').update({ status: 'read' }));
    });

    it('a non-receiver reads a nudge', async () => {
      await assertFails(as('att').doc('nudges/n1').get());
    });

    it('a signed-in user lists users', async () => {
      await assertFails(as('att').collection('users').get());
    });
  });

  describe('allowed', () => {
    const createGroup = async (uid: string, groupId: string, visibility: 'public' | 'private') => {
      const db = as(uid);
      const groupRef = db.doc(`groups/${groupId}`);
      const joinedAt = FieldValue.serverTimestamp();
      const batch = db.batch();
      batch.set(groupRef, {
        name: 'New',
        description: 'desc',
        visibility,
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        memberCount: 1,
      });
      if (visibility === 'private') {
        batch.set(groupRef.collection('secrets').doc('settings'), { joinCode: 'ABC123' });
      }
      batch.set(groupRef.collection('members').doc(uid), { role: 'admin', joinedAt });
      batch.set(db.doc(`users/${uid}/groupMemberships/${groupId}`), { role: 'admin', joinedAt });
      batch.set(db.doc(`users/${uid}`), { groupIds: FieldValue.arrayUnion(groupId) }, { merge: true });
      await batch.commit();
    };

    it('creates a public group as one batch', async () => {
      await assertSucceeds(createGroup('newbie', 'NEWPUB', 'public'));
    });

    it('creates a private group as one batch', async () => {
      await assertSucceeds(createGroup('newbie', 'NEWPRIV', 'private'));
    });

    it('joins a public group as one transaction and leaves it', async () => {
      const db = as('joiner');
      const groupRef = db.doc('groups/PUB');
      const memberRef = db.doc('groups/PUB/members/joiner');
      const membershipRef = db.doc('users/joiner/groupMemberships/PUB');
      const userRef = db.doc('users/joiner');

      await assertSucceeds(
        db.runTransaction(async (txn) => {
          const groupSnap = await txn.get(groupRef);
          await txn.get(membershipRef);
          txn.set(memberRef, { role: 'member', joinedAt: FieldValue.serverTimestamp() });
          txn.set(membershipRef, { role: 'member', joinedAt: FieldValue.serverTimestamp() });
          txn.set(userRef, { groupIds: FieldValue.arrayUnion('PUB') }, { merge: true });
          txn.update(groupRef, {
            memberCount: (groupSnap.data()?.memberCount ?? 0) + 1,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }),
      );

      await assertSucceeds(
        db.runTransaction(async (txn) => {
          const groupSnap = await txn.get(groupRef);
          await txn.get(memberRef);
          txn.delete(memberRef);
          txn.delete(membershipRef);
          txn.delete(db.doc('groups/PUB/aggregates/joiner'));
          txn.set(userRef, { groupIds: FieldValue.arrayRemove('PUB') }, { merge: true });
          const current = groupSnap.data()?.memberCount ?? 1;
          txn.update(groupRef, {
            memberCount: current <= 1 ? 0 : current - 1,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }),
      );
    });

    it('the creator promotes a member to admin and demotes them', async () => {
      const db = as('creator');
      const changeRole = (role: string) =>
        db.runTransaction(async (txn) => {
          await txn.get(db.doc('groups/PUB'));
          await txn.get(db.doc('groups/PUB/members/mem'));
          txn.update(db.doc('groups/PUB/members/mem'), { role });
          txn.update(db.doc('users/mem/groupMemberships/PUB'), { role });
        });
      await assertSucceeds(changeRole('admin'));
      await assertSucceeds(changeRole('member'));
    });

    it('an admin edits name and description', async () => {
      await assertSucceeds(
        as('adm').doc('groups/PUB').update({
          name: 'Renamed',
          description: 'new',
          updatedAt: FieldValue.serverTimestamp(),
        }),
      );
    });

    it('an admin edits the name of a group without memberCount', async () => {
      await assertSucceeds(
        as('adm').doc('groups/OLD').update({ name: 'Renamed', updatedAt: FieldValue.serverTimestamp() }),
      );
    });

    it('an admin removes a member with the count update', async () => {
      const db = as('adm');
      const groupRef = db.doc('groups/PUB');
      const memberRef = db.doc('groups/PUB/members/mem');
      await assertSucceeds(
        db.runTransaction(async (txn) => {
          const groupSnap = await txn.get(groupRef);
          await txn.get(memberRef);
          txn.delete(memberRef);
          txn.delete(db.doc('users/mem/groupMemberships/PUB'));
          txn.delete(db.doc('groups/PUB/aggregates/mem'));
          const current = groupSnap.data()?.memberCount ?? 1;
          txn.update(groupRef, {
            memberCount: current <= 1 ? 0 : current - 1,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }),
      );
    });

    it('writes the sign-up email index entry before verification', async () => {
      const db = as('newu', { email: 'Mixed@Case.com', email_verified: false });
      await assertSucceeds(
        db.doc('email_index/mixed@case.com').set(
          { uid: 'newu', email: 'mixed@case.com', updatedAt: FieldValue.serverTimestamp() },
          { merge: true },
        ),
      );
    });

    it('the owner writes their user document', async () => {
      await assertSucceeds(
        as('self').doc('users/self').set(
          {
            groupIds: ['G'],
            activeSession: { courseId: 'c1', kind: 'timer', startedAt: 1 },
            isStudying: true,
            lastActive: FieldValue.serverTimestamp(),
          },
          { merge: true },
        ),
      );
    });

    it('a signed-in user gets another user document', async () => {
      await assertSucceeds(as('att').doc('users/victim').get());
    });

    it('a co-member reads sessions, courses, aggregates and public profile', async () => {
      const db = as('mem');
      await assertSucceeds(db.doc('users/creator/sessions/s1').get());
      await assertSucceeds(db.doc('users/creator/courses/c1').get());
      await assertSucceeds(db.doc('users/creator/aggregates/statistics').get());
      await assertSucceeds(db.doc('publicProfiles/creator').get());
    });

    it('the owner creates a session and soft-deletes it', async () => {
      const db = as('self');
      const ref = db.doc('users/self/sessions/1700000000000000_c1');
      await assertSucceeds(
        ref.set(
          {
            uid: 'self',
            courseId: 'c1',
            startUtc: firebase.firestore.Timestamp.fromMillis(1700000000000),
            endUtc: firebase.firestore.Timestamp.fromMillis(1700003600000),
            seconds: 3600,
            kind: 'timer',
            notes: null,
            createdAt: firebase.firestore.Timestamp.fromMillis(1700003600000),
            deleted: false,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        ),
      );
      await assertSucceeds(ref.update({ deleted: true, updatedAt: FieldValue.serverTimestamp() }));
    });

    it('the receiver lists pending nudges and marks one delivered', async () => {
      const db = as('mem');
      await assertSucceeds(
        db.collection('nudges').where('receiverId', '==', 'mem').where('status', '==', 'pending').get(),
      );
      await assertSucceeds(db.doc('nudges/n1').update({ status: 'delivered' }));
    });

    it('a signed-in user gets config and feed', async () => {
      const db = as('att');
      await assertSucceeds(db.doc('config/app').get());
      await assertSucceeds(db.doc('feed/current').get());
    });
  });
});
