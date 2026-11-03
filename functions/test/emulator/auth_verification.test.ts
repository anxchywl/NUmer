import { auth, db } from '../../src/shared/admin';
import { handleSendEmailVerificationCode, handleVerifyEmailCode } from '../../src/auth/email_verification';
import {
  clearAuthCollections,
  FakeSender,
  fakeDeps,
  reason,
  sentCode,
  signedIn,
  startTime,
  storedStrings,
} from './auth_helpers';

const uid = 'verify-user';
const email = 'Verify.User@Example.org';
const noEmailUid = 'verify-no-email';
const context = signedIn(uid, email);
const challenge = db.doc(`authCodes/verify_${uid}`);

function wrongCode(code: string) {
  return code === '000000' ? '000001' : '000000';
}

describe('email verification codes', () => {
  beforeEach(async () => {
    await clearAuthCollections();
    await auth.deleteUsers([uid]);
    await auth.createUser({ uid, email, password: 'initial-pass', emailVerified: false });
  });

  afterAll(async () => {
    await auth.deleteUsers([uid, noEmailUid]);
    await db.terminate();
  });

  it('sends a code that verifies the user and is stored nowhere in plain text', async () => {
    const { sender, deps } = fakeDeps();

    const sent = await handleSendEmailVerificationCode({ locale: 'ru' }, context, deps);
    const code = sentCode(sender.sent[0]);
    await expect(handleVerifyEmailCode({ code }, context, deps)).resolves.toEqual({ verified: true });

    expect(sent).toEqual({ status: 'sent', resendAvailableAt: startTime + 60_000, expiresAt: startTime + 600_000 });
    expect(sender.sent).toHaveLength(1);
    expect(sender.sent[0].to).toBe(email.toLowerCase());
    expect((await auth.getUser(uid)).emailVerified).toBe(true);
    const stored = await storedStrings(['authCodes', 'mailQueue', 'authAudit']);
    expect(stored.some((value) => value.includes(code))).toBe(false);
    expect(stored.some((value) => value.toLowerCase().includes(email.toLowerCase()))).toBe(false);
  });

  it('stores the documented fields with a ttl one day after expiry', async () => {
    const { deps } = fakeDeps();

    await handleSendEmailVerificationCode({ locale: 'xx' }, context, deps);
    const data = (await challenge.get()).data()!;

    expect(Object.keys(data).sort()).toEqual([
      'attempts', 'codeHash', 'codeId', 'consumedAt', 'createdAt', 'emailHash', 'expiresAt', 'keyVersion',
      'locale', 'purpose', 'resendAvailableAt', 'ticketConsumedAt', 'ticketExpiresAt', 'ticketHash', 'ttlAt', 'uid',
    ]);
    expect(data.locale).toBe('en');
    expect(data.ttlAt.toMillis() - data.expiresAt.toMillis()).toBe(24 * 3600 * 1000);
  });

  it('answers cooldown inside 60 seconds and sends nothing', async () => {
    const { sender, clock, deps } = fakeDeps();

    await handleSendEmailVerificationCode({}, context, deps);
    clock.time += 30_000;
    const second = await handleSendEmailVerificationCode({}, context, deps);

    expect(second).toEqual({ status: 'cooldown', resendAvailableAt: startTime + 60_000, expiresAt: startTime + 600_000 });
    expect(sender.sent).toHaveLength(1);
  });

  it('answers already-verified from the user record with the current time', async () => {
    const { sender, deps } = fakeDeps();
    await auth.updateUser(uid, { emailVerified: true });

    const result = await handleSendEmailVerificationCode({}, context, deps);

    expect(result).toEqual({ status: 'already-verified', resendAvailableAt: startTime, expiresAt: startTime });
    expect(sender.sent).toHaveLength(0);
  });

  it('sends to the address on the user record, not a stale token claim', async () => {
    const { sender, deps } = fakeDeps();

    await handleSendEmailVerificationCode({}, signedIn(uid, 'stale@example.org', true), deps);

    expect(sender.sent.map((message) => message.to)).toEqual([email.toLowerCase()]);
  });

  it('refuses a code after the account email changed', async () => {
    const { sender, deps } = fakeDeps();
    await handleSendEmailVerificationCode({}, context, deps);
    await auth.updateUser(uid, { email: 'victim@example.org' });

    await expect(handleVerifyEmailCode({ code: sentCode(sender.sent[0]) }, context, deps)).rejects.toMatchObject({
      code: 'permission-denied',
      ...reason({ reason: 'invalid-code' }),
    });
    expect((await auth.getUser(uid)).emailVerified).toBe(false);
  });

  it('rejects a caller without a session or without an email', async () => {
    const { deps } = fakeDeps();

    await expect(handleSendEmailVerificationCode({}, {} as never, deps)).rejects.toMatchObject({
      code: 'unauthenticated',
    });
    await auth.deleteUsers([noEmailUid]);
    await auth.createUser({ uid: noEmailUid });
    await expect(handleVerifyEmailCode({ code: '123456' }, signedIn(noEmailUid), deps)).rejects.toMatchObject({
      code: 'failed-precondition',
      ...reason({ reason: 'no-email' }),
    });
  });

  it.each([undefined, '12345', '1234567', 'abcdef', 123456])('rejects the malformed code %p', async (code) => {
    const { deps } = fakeDeps();

    await expect(handleVerifyEmailCode({ code }, context, deps)).rejects.toMatchObject({
      code: 'invalid-argument',
      ...reason({ reason: 'malformed-code' }),
    });
  });

  it('answers no-active-code without a send', async () => {
    const { deps } = fakeDeps();

    await expect(handleVerifyEmailCode({ code: '123456' }, context, deps)).rejects.toMatchObject({
      code: 'not-found',
      ...reason({ reason: 'no-active-code' }),
    });
  });

  it('counts down wrong codes and locks after the fifth', async () => {
    const { sender, deps } = fakeDeps();
    await handleSendEmailVerificationCode({}, context, deps);
    const code = sentCode(sender.sent[0]);

    for (const attemptsLeft of [4, 3, 2, 1, 0]) {
      await expect(handleVerifyEmailCode({ code: wrongCode(code) }, context, deps)).rejects.toMatchObject({
        code: 'permission-denied',
        ...reason({ reason: 'invalid-code', attemptsLeft }),
      });
    }

    await expect(handleVerifyEmailCode({ code }, context, deps)).rejects.toMatchObject({
      code: 'resource-exhausted',
      ...reason({ reason: 'too-many-attempts' }),
    });
    expect((await auth.getUser(uid)).emailVerified).toBe(false);
  });

  it('answers code-expired after expiresAt', async () => {
    const { sender, deps } = fakeDeps();
    await handleSendEmailVerificationCode({}, context, deps);
    await challenge.update({ expiresAt: new Date(startTime - 1) });

    await expect(handleVerifyEmailCode({ code: sentCode(sender.sent[0]) }, context, deps)).rejects.toMatchObject({
      code: 'deadline-exceeded',
      ...reason({ reason: 'code-expired' }),
    });
  });

  it('makes the old code invalid with a new send', async () => {
    const { sender, clock, deps } = fakeDeps();
    await handleSendEmailVerificationCode({}, context, deps);
    clock.time += 61_000;
    await handleSendEmailVerificationCode({}, context, deps);
    const [first, second] = sender.sent.map(sentCode);

    await expect(handleVerifyEmailCode({ code: first }, context, deps)).rejects.toMatchObject({
      code: 'permission-denied',
    });
    await expect(handleVerifyEmailCode({ code: second }, context, deps)).resolves.toEqual({ verified: true });
    expect(first).not.toBe(second);
  });

  it('verifies only the address the code was sent to when the email changes during the call', async () => {
    const { sender, deps } = fakeDeps();
    await handleSendEmailVerificationCode({}, context, deps);
    const update = auth.updateUser.bind(auth);
    const spy = jest.spyOn(auth, 'updateUser').mockImplementationOnce(async (target, properties) => {
      await update(target, { email: 'victim@example.org' });
      return update(target, properties);
    });

    await expect(handleVerifyEmailCode({ code: sentCode(sender.sent[0]) }, context, deps)).resolves.toEqual({
      verified: true,
    });
    spy.mockRestore();

    const user = await auth.getUser(uid);
    expect(user.email).toBe(email.toLowerCase());
    expect(user.emailVerified).toBe(true);
  });

  it('keeps attempts at five or less under six concurrent wrong guesses', async () => {
    const { sender, deps } = fakeDeps();
    await handleSendEmailVerificationCode({}, context, deps);
    const wrong = wrongCode(sentCode(sender.sent[0]));

    const results = await Promise.allSettled(
      Array.from({ length: 6 }, () => handleVerifyEmailCode({ code: wrong }, context, deps)),
    );

    expect(results.every((result) => result.status === 'rejected')).toBe(true);
    expect((await challenge.get()).data()!.attempts).toBeLessThanOrEqual(5);
  });

  it('returns rate-limited on the fourth send in 15 minutes', async () => {
    const { sender, clock, deps } = fakeDeps();
    for (let i = 0; i < 3; i++) {
      await expect(handleSendEmailVerificationCode({}, context, deps)).resolves.toMatchObject({ status: 'sent' });
      clock.time += 61_000;
    }

    await expect(handleSendEmailVerificationCode({}, context, deps)).rejects.toMatchObject({
      code: 'resource-exhausted',
      ...reason({ reason: 'rate-limited', retryAfterSeconds: 900 - 183 }),
    });
    expect(sender.sent).toHaveLength(3);
    expect((await challenge.get()).exists).toBe(false);
  });

  it('sends exactly one email for two concurrent sends', async () => {
    const { sender, deps } = fakeDeps();

    const results = await Promise.all([
      handleSendEmailVerificationCode({}, context, deps),
      handleSendEmailVerificationCode({}, context, deps),
    ]);

    expect(results.map((result) => result.status).sort()).toEqual(['cooldown', 'sent']);
    expect(sender.sent).toHaveLength(1);
  });

  it('returns delivery-failed and leaves no document when the mail fails', async () => {
    const { deps } = fakeDeps(new FakeSender(503));

    await expect(handleSendEmailVerificationCode({}, context, deps)).rejects.toMatchObject({
      code: 'unavailable',
      ...reason({ reason: 'delivery-failed' }),
    });
    expect((await challenge.get()).exists).toBe(false);
  });

  it('keeps the code usable when updateUser fails', async () => {
    const { sender, deps } = fakeDeps();
    await handleSendEmailVerificationCode({}, context, deps);
    const code = sentCode(sender.sent[0]);
    const failure = Object.assign(new Error('provider failed'), { code: 'auth/internal-error' });
    const spy = jest.spyOn(auth, 'updateUser').mockRejectedValueOnce(failure);

    await expect(handleVerifyEmailCode({ code }, context, deps)).rejects.toMatchObject({
      code: 'internal',
      message: 'Try again.',
    });
    spy.mockRestore();

    await expect(handleVerifyEmailCode({ code }, context, deps)).resolves.toEqual({ verified: true });
    expect((await auth.getUser(uid)).emailVerified).toBe(true);
  });

  it('writes no audit row for calls refused before any limit', async () => {
    const { deps } = fakeDeps();

    await expect(handleSendEmailVerificationCode({}, {} as never, deps)).rejects.toThrow();
    await expect(handleVerifyEmailCode({ code: '12' }, context, deps)).rejects.toThrow();

    expect((await db.collection('authAudit').get()).size).toBe(0);
  });

  it('writes one audit row per call without a code or an address', async () => {
    const { sender, deps } = fakeDeps();
    await handleSendEmailVerificationCode({}, context, deps);
    await expect(handleVerifyEmailCode({ code: wrongCode(sentCode(sender.sent[0])) }, context, deps)).rejects.toThrow();

    const rows = (await db.collection('authAudit').get()).docs.map((doc) => doc.data());
    expect(rows.map((row) => [row.action, row.result]).sort()).toEqual([
      ['sendEmailVerificationCode', 'sent'],
      ['verifyEmailCode', 'invalid-code'],
    ]);
    for (const row of rows) {
      expect(row.uid).toBe(uid);
      expect(row.ipHash).toMatch(/^[0-9a-f]{32}$/);
      expect(row.expiresAt.toMillis() - row.at.toMillis()).toBe(90 * 24 * 3600 * 1000);
      expect(JSON.stringify(row)).not.toContain(sentCode(sender.sent[0]));
    }
  });
});
