import { auth, db } from '../../src/shared/admin';
import {
  handleConfirmPasswordReset,
  handleRequestPasswordResetCode,
  handleVerifyPasswordResetCode,
} from '../../src/auth/password_reset';
import { hashCode, sha256Hex } from '../../src/auth/codes';
import { anonymous, clearAuthCollections, fakeDeps, reason, secret, startTime, storedStrings } from './auth_helpers';

const uid = 'reset-user';
const email = 'reset.user@example.org';
const unknownEmail = 'nobody@example.org';
const oldPassword = 'old-password';
const newPassword = 'new-password-1';
const context = anonymous();

async function queuedCode(): Promise<string> {
  const { docs } = await db.collection('mailQueue').where('template', '==', 'reset').get();
  return docs[0].data().vars.code;
}

async function count(name: string) {
  return (await db.collection(name).get()).size;
}

async function ticketFor(deps: ReturnType<typeof fakeDeps>['deps']) {
  await handleRequestPasswordResetCode({ email, locale: 'kk' }, context, deps);
  const { resetTicket } = await handleVerifyPasswordResetCode({ email, code: await queuedCode() }, context, deps);
  return resetTicket;
}

function signIn(password: string, address = email) {
  const url =
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}` +
    '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator';
  return fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: address, password, returnSecureToken: true }),
  });
}

const invalidCode = { code: 'permission-denied', ...reason({ reason: 'invalid-or-expired-code' }) };
const invalidTicket = { code: 'permission-denied', ...reason({ reason: 'invalid-or-expired-ticket' }) };

describe('password reset codes', () => {
  beforeEach(async () => {
    await clearAuthCollections();
    await auth.deleteUsers([uid]);
    await auth.createUser({ uid, email, password: oldPassword, emailVerified: false });
  });

  afterAll(async () => {
    await auth.deleteUsers([uid]);
    await db.terminate();
  });

  it('answers and writes the same for an existing and an unknown email', async () => {
    const { deps } = fakeDeps();

    const known = await handleRequestPasswordResetCode({ email: ` ${email.toUpperCase()} `, locale: 'ru' }, context, deps);
    const knownCounts = [await count('authCodes'), await count('mailQueue')];
    const knownFields = Object.keys((await db.collection('authCodes').get()).docs[0].data()).sort();
    await clearAuthCollections();
    const unknown = await handleRequestPasswordResetCode({ email: unknownEmail, locale: 'ru' }, context, deps);
    const unknownCounts = [await count('authCodes'), await count('mailQueue')];
    const unknownFields = Object.keys((await db.collection('authCodes').get()).docs[0].data()).sort();

    expect(known).toEqual({ status: 'accepted', resendAvailableAt: startTime + 60_000 });
    expect(unknown).toEqual(known);
    expect(knownCounts).toEqual([1, 1]);
    expect(unknownCounts).toEqual([1, 1]);
    expect(unknownFields).toEqual(knownFields);
  });

  it('refuses a replayed app check token on all three callables', async () => {
    const { deps } = fakeDeps();
    const replayed = { ...context, app: { appId: 'app', token: {}, alreadyConsumed: true } } as typeof context;
    const refused = { code: 'failed-precondition', ...reason({ reason: 'app-check' }) };

    await expect(handleRequestPasswordResetCode({ email }, replayed, deps)).rejects.toMatchObject(refused);
    await expect(handleVerifyPasswordResetCode({ email, code: '123456' }, replayed, deps)).rejects.toMatchObject(refused);
    await expect(
      handleConfirmPasswordReset({ email, resetTicket: 'a'.repeat(43), newPassword }, replayed, deps),
    ).rejects.toMatchObject(refused);
    expect(await count('authCodes')).toBe(0);
  });

  it('rejects an invalid email', async () => {
    const { deps } = fakeDeps();

    for (const value of [undefined, 42, 'not-an-email', `${'a'.repeat(250)}@example.org`]) {
      await expect(handleRequestPasswordResetCode({ email: value }, context, deps)).rejects.toMatchObject({
        code: 'invalid-argument',
        ...reason({ reason: 'invalid-email' }),
      });
    }
  });

  it('skips the enqueue during the cooldown', async () => {
    const { clock, deps } = fakeDeps();

    await handleRequestPasswordResetCode({ email }, context, deps);
    clock.time += 10_000;
    const second = await handleRequestPasswordResetCode({ email }, context, deps);

    expect(second).toEqual({ status: 'accepted', resendAvailableAt: startTime + 60_000 });
    expect(await count('mailQueue')).toBe(1);
  });

  it('returns a ticket that works once and leaves no code or ticket in plain text', async () => {
    const { deps } = fakeDeps();
    await handleRequestPasswordResetCode({ email }, context, deps);
    const code = await queuedCode();
    const { resetTicket } = await handleVerifyPasswordResetCode({ email, code }, context, deps);
    await db.recursiveDelete(db.collection('mailQueue'));

    expect(resetTicket).toMatch(/^[A-Za-z0-9_-]{43}$/);
    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).resolves.toEqual({
      success: true,
    });
    await expect(
      handleConfirmPasswordReset({ email, resetTicket, newPassword: 'another-pass' }, context, deps),
    ).rejects.toMatchObject(invalidTicket);
    const stored = await storedStrings(['authCodes', 'authAudit']);
    expect(stored.some((value) => value.includes(code) || value.includes(resetTicket) || value.includes(email))).toBe(
      false,
    );
  });

  it('refuses a seven character password without consuming the ticket', async () => {
    const { deps } = fakeDeps();
    const resetTicket = await ticketFor(deps);

    await expect(
      handleConfirmPasswordReset({ email, resetTicket, newPassword: 'short12' }, context, deps),
    ).rejects.toMatchObject({ code: 'invalid-argument', ...reason({ reason: 'weak-password' }) });
    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).resolves.toEqual({
      success: true,
    });
  });

  it('rejects malformed confirm input', async () => {
    const { deps } = fakeDeps();
    const malformed = { code: 'invalid-argument', ...reason({ reason: 'malformed-input' }) };

    await expect(handleConfirmPasswordReset({ email, resetTicket: 'short', newPassword }, context, deps)).rejects.toMatchObject(malformed);
    await expect(handleConfirmPasswordReset({ email, newPassword }, context, deps)).rejects.toMatchObject(malformed);
    await expect(
      handleConfirmPasswordReset({ email, resetTicket: 'a'.repeat(43), newPassword: 12345678 }, context, deps),
    ).rejects.toMatchObject(malformed);
    await expect(handleVerifyPasswordResetCode({ email, code: '12a456' }, context, deps)).rejects.toMatchObject(malformed);
    await expect(handleVerifyPasswordResetCode({ email: 'x', code: '123456' }, context, deps)).rejects.toMatchObject(malformed);
  });

  it('sets the password, verifies the email, revokes sessions and queues a notice', async () => {
    const { deps } = fakeDeps();
    const before = (await auth.getUser(uid)).tokensValidAfterTime;
    await new Promise((resolve) => setTimeout(resolve, 1100));
    const resetTicket = await ticketFor(deps);

    await handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps);
    const user = await auth.getUser(uid);

    expect((await signIn(newPassword)).ok).toBe(true);
    expect((await signIn(oldPassword)).ok).toBe(false);
    expect(user.emailVerified).toBe(true);
    expect(Date.parse(user.tokensValidAfterTime!)).toBeGreaterThan(Date.parse(before ?? '0'));
    const notices = await db.collection('mailQueue').where('template', '==', 'passwordChanged').get();
    expect(notices.docs.map((doc) => doc.data())).toEqual([
      expect.objectContaining({ to: email, locale: 'kk', vars: {} }),
    ]);
  });

  it('keeps the ticket usable when updateUser fails', async () => {
    const { deps } = fakeDeps();
    const resetTicket = await ticketFor(deps);
    const failure = Object.assign(new Error('provider detail'), { code: 'auth/internal-error' });
    const spy = jest.spyOn(auth, 'updateUser').mockRejectedValueOnce(failure);

    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).rejects.toMatchObject({
      code: 'internal',
      message: 'Try again.',
    });
    spy.mockRestore();

    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).resolves.toEqual({
      success: true,
    });
  });

  it('keeps the ticket usable when revoking the sessions fails', async () => {
    const { deps } = fakeDeps();
    const resetTicket = await ticketFor(deps);
    const failure = Object.assign(new Error('provider detail'), { code: 'auth/internal-error' });
    const spy = jest.spyOn(auth, 'revokeRefreshTokens').mockRejectedValueOnce(failure);

    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).rejects.toMatchObject({
      code: 'internal',
      message: 'Try again.',
    });
    expect(spy).toHaveBeenCalledTimes(1);
    spy.mockRestore();
    const revoke = jest.spyOn(auth, 'revokeRefreshTokens');

    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).resolves.toEqual({
      success: true,
    });
    expect(revoke).toHaveBeenCalledWith(uid);
    revoke.mockRestore();
  });

  it('refuses a ticket after the account email changed', async () => {
    const { deps } = fakeDeps();
    const resetTicket = await ticketFor(deps);
    await auth.updateUser(uid, { email: 'moved@example.org' });

    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).rejects.toMatchObject(
      invalidTicket,
    );
    expect((await signIn(oldPassword, 'moved@example.org')).ok).toBe(true);
    expect((await auth.getUser(uid)).emailVerified).toBe(false);
  });

  it('refuses a ticket for a deleted account', async () => {
    const { deps } = fakeDeps();
    const resetTicket = await ticketFor(deps);
    await auth.deleteUsers([uid]);

    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).rejects.toMatchObject(
      invalidTicket,
    );
  });

  it('refuses an expired ticket', async () => {
    const { clock, deps } = fakeDeps();
    const resetTicket = await ticketFor(deps);
    clock.time += 600_000;

    await expect(handleConfirmPasswordReset({ email, resetTicket, newPassword }, context, deps)).rejects.toMatchObject(
      invalidTicket,
    );
  });

  it('never yields a ticket for a dummy row', async () => {
    const { deps } = fakeDeps();
    await handleRequestPasswordResetCode({ email: unknownEmail }, context, deps);
    const emailHash = sha256Hex(unknownEmail);
    const ref = db.doc(`authCodes/reset_${emailHash}`);
    const { codeId } = (await ref.get()).data()!;
    await ref.update({ codeHash: hashCode(secret, 'reset', emailHash, '123456', codeId) });

    await expect(
      handleVerifyPasswordResetCode({ email: unknownEmail, code: '123456' }, context, deps),
    ).rejects.toMatchObject(invalidCode);
    expect((await ref.get()).data()!.ticketHash).toBeNull();
  });

  it('answers invalid-or-expired-code for an unknown email, a wrong code and an expired code', async () => {
    const { clock, deps } = fakeDeps();

    await expect(
      handleVerifyPasswordResetCode({ email: unknownEmail, code: '654321' }, context, deps),
    ).rejects.toMatchObject(invalidCode);
    await handleRequestPasswordResetCode({ email }, context, deps);
    const code = await queuedCode();
    await expect(
      handleVerifyPasswordResetCode({ email, code: code === '000000' ? '000001' : '000000' }, context, deps),
    ).rejects.toMatchObject(invalidCode);
    clock.time += 600_000;
    await expect(handleVerifyPasswordResetCode({ email, code }, context, deps)).rejects.toMatchObject(invalidCode);
  });

  it('answers too-many-attempts after five wrong codes', async () => {
    const { deps } = fakeDeps();
    await handleRequestPasswordResetCode({ email }, context, deps);
    const code = await queuedCode();
    const wrong = code === '000000' ? '000001' : '000000';

    for (let i = 0; i < 5; i++) {
      await expect(handleVerifyPasswordResetCode({ email, code: wrong }, context, deps)).rejects.toMatchObject(invalidCode);
    }

    await expect(handleVerifyPasswordResetCode({ email, code }, context, deps)).rejects.toMatchObject({
      code: 'resource-exhausted',
      ...reason({ reason: 'too-many-attempts' }),
    });
  });
});
