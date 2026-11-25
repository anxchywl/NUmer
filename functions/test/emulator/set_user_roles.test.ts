import functionsTest from 'firebase-functions-test';
import { auth, db } from '../../src/shared/admin';
import { setUserRoles } from '../../src/roles/set_user_roles';

const testEnv = functionsTest();
const call = testEnv.wrap(setUserRoles);

function as(uid: string, roles: string[]) {
  return { auth: { uid, token: { numer_roles: roles } as any } };
}

const admin = as('roles-admin', ['numer:admin']);
const target = 'roles-target';

async function auditCount() {
  const snap = await db.collection('roleAudit').get();
  return snap.size;
}

describe('setUserRoles', () => {
  beforeAll(async () => {
    await auth.createUser({ uid: 'roles-admin' });
    await auth.setCustomUserClaims('roles-admin', { numer_roles: ['numer:admin'] });
    await auth.createUser({ uid: target });
    await auth.setCustomUserClaims(target, { beta: true });
  });

  afterAll(async () => {
    await auth.deleteUsers(['roles-admin', 'roles-demoted', target]);
    testEnv.cleanup();
  });

  it('denies a caller without numer:admin', async () => {
    await expect(
      call({ uid: target, roles: ['muto:admin'] }, as('roles-editor', ['numer:editor'])),
    ).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(call({ uid: target, roles: [] }, {})).rejects.toMatchObject({
      code: 'unauthenticated',
    });
  });

  it('denies an administrator whose role was removed after the token was issued', async () => {
    await auth.createUser({ uid: 'roles-demoted' });

    await expect(
      call({ uid: target, roles: ['muto:admin'] }, as('roles-demoted', ['numer:admin'])),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects an invalid uid', async () => {
    await expect(call({ uid: 'a/b', roles: [] }, admin)).rejects.toMatchObject({
      code: 'invalid-argument',
    });
  });

  it('sets roles, keeps other claims and writes one audit document', async () => {
    const count = await auditCount();

    await expect(call({ uid: target, roles: ['muto:admin'] }, admin)).resolves.toEqual({
      roles: ['muto:admin'],
    });

    const user = await auth.getUser(target);
    expect(user.customClaims).toEqual({ beta: true, numer_roles: ['muto:admin'] });
    expect(await auditCount()).toBe(count + 1);
    const audit = await db.collection('roleAudit').where('target', '==', target).get();
    expect(audit.docs[0].data()).toMatchObject({
      actor: 'roles-admin',
      before: [],
      after: ['muto:admin'],
    });
  });

  it('revokes refresh tokens when a role is removed', async () => {
    // the emulator leaves tokensValidAfterTime unset until the first revocation
    await auth.revokeRefreshTokens(target);
    const before = Date.parse((await auth.getUser(target)).tokensValidAfterTime!);
    // the timestamp has a resolution of one second
    await new Promise((resolve) => setTimeout(resolve, 1100));
    await call({ uid: target, roles: ['muto:admin', 'numer:editor'] }, admin);
    expect(Date.parse((await auth.getUser(target)).tokensValidAfterTime!)).toBe(before);
    const count = await auditCount();

    await call({ uid: target, roles: ['numer:editor'] }, admin);

    const after = Date.parse((await auth.getUser(target)).tokensValidAfterTime!);
    expect(after).toBeGreaterThan(before);
    expect(await auditCount()).toBe(count + 1);
  });

  it('does not let an administrator drop their own numer:admin', async () => {
    await expect(
      call({ uid: 'roles-admin', roles: ['numer:editor'] }, admin),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
