import { auth, db } from '../../src/shared/admin';
import { handleSendEmailVerificationCode, handleVerifyEmailCode } from '../../src/auth/email_verification';
import { handleRequestPasswordResetCode, handleVerifyPasswordResetCode } from '../../src/auth/password_reset';
import { hit, windowRef } from '../../src/auth/rate_limits';
import { ipHash } from '../../src/auth/context';
import { sha256Hex } from '../../src/auth/codes';
import { anonymous, clearAuthCollections, fakeDeps, reason, secret, signedIn, startTime, testIp } from './auth_helpers';

const uid = 'limits-user';
const email = 'limits.user@example.org';
const emailHash = sha256Hex(email);
const testIpHash = ipHash(secret, testIp);
const rateLimited = { code: 'resource-exhausted', ...reason({ reason: 'rate-limited' }) };

async function fill(key: string, windowSeconds: number, count: number) {
  await windowRef(key, windowSeconds, startTime).set({ count });
}

describe('auth rate limits', () => {
  beforeEach(async () => {
    await clearAuthCollections();
    await auth.deleteUsers([uid]);
    await auth.createUser({ uid, email, emailVerified: false });
  });

  afterAll(async () => {
    await auth.deleteUsers([uid]);
    await db.terminate();
  });

  it('counts up to the limit, then refuses until the window ends', async () => {
    const check = { key: 'test:unit:a', limit: 2, windowSeconds: 900 };
    const now = startTime + 100_000;

    await expect(hit(check, now)).resolves.toEqual({ allowed: true, retryAfterSeconds: 0 });
    await expect(hit(check, now)).resolves.toEqual({ allowed: true, retryAfterSeconds: 0 });
    await expect(hit(check, now)).resolves.toEqual({ allowed: false, retryAfterSeconds: 800 });
    await expect(hit(check, startTime + 900_000)).resolves.toMatchObject({ allowed: true });
    const data = (await windowRef(check.key, 900, now).get()).data()!;
    expect(data.count).toBe(2);
    expect(data.expiresAt.toMillis()).toBe(startTime + 900_000 + 3600_000);
  });

  it('keeps windows of different lengths apart', async () => {
    expect(windowRef('k', 900, 0).id).not.toBe(windowRef('k', 86400, 0).id);
  });

  it('refuses a fourth reset send per email in 15 minutes', async () => {
    const { clock, deps } = fakeDeps();
    for (let i = 0; i < 3; i++) {
      await handleRequestPasswordResetCode({ email }, anonymous(), deps);
      clock.time += 61_000;
    }

    await expect(handleRequestPasswordResetCode({ email }, anonymous(), deps)).rejects.toMatchObject(rateLimited);
  });

  it('refuses sends per email after 10 a day', async () => {
    const { deps } = fakeDeps();
    await fill(`send:email:${emailHash}`, 86400, 10);

    await expect(handleRequestPasswordResetCode({ email }, anonymous(), deps)).rejects.toMatchObject(rateLimited);
  });

  it('refuses verification sends per uid after 5 an hour and removes the new code', async () => {
    const { sender, deps } = fakeDeps();
    await fill(`send:uid:${uid}`, 3600, 5);

    await expect(handleSendEmailVerificationCode({}, signedIn(uid, email), deps)).rejects.toMatchObject(rateLimited);
    expect(sender.sent).toHaveLength(0);
    expect((await db.doc(`authCodes/verify_${uid}`).get()).exists).toBe(false);
  });

  it('refuses sends per ip after 10 an hour and skips the ip limit without an ip', async () => {
    const { deps } = fakeDeps();
    await fill(`send:ip:${testIpHash}`, 3600, 10);
    await fill(`send:ip:${ipHash(secret, '')}`, 3600, 10);

    await expect(handleRequestPasswordResetCode({ email }, anonymous(), deps)).rejects.toMatchObject(rateLimited);
    await expect(handleRequestPasswordResetCode({ email }, anonymous(''), deps)).resolves.toMatchObject({
      status: 'accepted',
    });
  });

  it('refuses email code checks per uid after 20 in 15 minutes', async () => {
    const { deps } = fakeDeps();
    await fill(`verify:uid:${uid}`, 900, 20);

    await expect(handleVerifyEmailCode({ code: '123456' }, signedIn(uid, email), deps)).rejects.toMatchObject(
      rateLimited,
    );
  });

  it('refuses reset code checks per email after 20 in 15 minutes', async () => {
    const { deps } = fakeDeps();
    await fill(`verify:email:${emailHash}`, 900, 20);

    await expect(handleVerifyPasswordResetCode({ email, code: '123456' }, anonymous(''), deps)).rejects.toMatchObject(
      rateLimited,
    );
  });

  it('refuses code checks per ip after 30 an hour', async () => {
    const { deps } = fakeDeps();
    await fill(`verify:ip:${testIpHash}`, 3600, 30);

    await expect(handleVerifyPasswordResetCode({ email, code: '123456' }, anonymous(), deps)).rejects.toMatchObject(
      rateLimited,
    );
    await expect(handleVerifyEmailCode({ code: '123456' }, signedIn(uid, email), deps)).rejects.toMatchObject(
      rateLimited,
    );
  });

  it('refuses verification sends after 2000 a day and still accepts resets', async () => {
    const { sender, deps } = fakeDeps();
    await fill('send:global:verify', 86400, 2000);

    await expect(handleSendEmailVerificationCode({}, signedIn(uid, email), deps)).rejects.toMatchObject(rateLimited);
    await expect(handleRequestPasswordResetCode({ email }, anonymous(), deps)).resolves.toMatchObject({
      status: 'accepted',
    });
    expect(sender.sent).toHaveLength(0);
  });

  it('refuses reset sends after 2000 a day and still sends verification codes', async () => {
    const { sender, deps } = fakeDeps();
    await fill('send:global:reset', 86400, 2000);

    await expect(handleRequestPasswordResetCode({ email }, anonymous(), deps)).rejects.toMatchObject(rateLimited);
    await expect(handleSendEmailVerificationCode({}, signedIn(uid, email), deps)).resolves.toMatchObject({
      status: 'sent',
    });
    expect(sender.sent).toHaveLength(1);
  });

  it('refuses verification sends per ip after 10 an hour', async () => {
    const { sender, deps } = fakeDeps();
    await fill(`send:ip:${testIpHash}`, 3600, 10);

    await expect(handleSendEmailVerificationCode({}, signedIn(uid, email), deps)).rejects.toMatchObject(rateLimited);
    await expect(handleSendEmailVerificationCode({}, signedIn(uid, email, false, ''), deps)).resolves.toMatchObject({
      status: 'sent',
    });
    expect(sender.sent).toHaveLength(1);
  });
});
