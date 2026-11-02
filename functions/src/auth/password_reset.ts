import * as functions from 'firebase-functions/v1';
import { auth } from '../shared/admin';
import { enqueueMail } from '../mail/queue';
import { audited, AuditFields } from './audit';
import { checkCode, consumeTicket, releaseTicket, replaceChallenge } from './challenge';
import { isSixDigits, isValidEmail, normalizeEmail, sha256Hex } from './codes';
import {
  authSecret,
  callableOptions,
  clientIp,
  Deps,
  fail,
  ipHash,
  normalizeLocale,
  rateLimited,
  refuseReplayedAppCheck,
  tryAgain,
} from './context';
import { hitAll, LimitCheck, sendLimits, verifyLimits } from './rate_limits';

type ResetDeps = Pick<Deps, 'now'>;
type CallableContext = functions.https.CallableContext;

interface RequestInput {
  email?: unknown;
  locale?: unknown;
}

interface VerifyInput {
  email?: unknown;
  code?: unknown;
}

interface ConfirmInput {
  email?: unknown;
  resetTicket?: unknown;
  newPassword?: unknown;
}

const ticketPattern = /^[A-Za-z0-9_-]{43}$/;
const minPasswordLength = 8;
const maxPasswordLength = 128;

interface Caller {
  now: number;
  secret: string;
  ip: string;
  fields: AuditFields;
}

function caller(context: CallableContext, deps: ResetDeps): Caller {
  refuseReplayedAppCheck(context);
  const secret = authSecret();
  const ip = clientIp(context);
  return { now: deps.now(), secret, ip, fields: { ipHash: ipHash(secret, ip) } };
}

function parseEmail(value: unknown, reason: string, fields: AuditFields) {
  const email = typeof value === 'string' ? normalizeEmail(value) : '';
  if (!isValidEmail(email)) {
    throw fail('invalid-argument', reason);
  }
  const emailHash = sha256Hex(email);
  fields.emailHash = emailHash;
  return { email, emailHash, docId: `reset_${emailHash}` };
}

async function enforce(checks: LimitCheck[], now: number) {
  const limit = await hitAll(checks, now);
  if (!limit.allowed) {
    throw rateLimited(limit.retryAfterSeconds);
  }
}

function limitSubjects({ ip, fields }: Caller, emailHash: string) {
  return { emailHash, ipHash: ip ? fields.ipHash : undefined };
}

async function activeUid(email: string): Promise<string | null> {
  try {
    const user = await auth.getUserByEmail(email);
    return user.disabled ? null : user.uid;
  } catch (error) {
    if ((error as { code?: string }).code !== 'auth/user-not-found') {
      throw error;
    }
    return null;
  }
}

export async function handleRequestPasswordResetCode(
  data: RequestInput | null | undefined,
  context: CallableContext,
  deps: ResetDeps,
) {
  const call = caller(context, deps);
  const { now, secret, fields } = call;
  return audited('requestPasswordResetCode', fields, now, async () => {
    const { email, emailHash, docId } = parseEmail(data?.email, 'invalid-email', fields);
    const locale = normalizeLocale(data?.locale);
    await enforce(sendLimits('reset', limitSubjects(call, emailHash)), now);

    const uid = await activeUid(email);
    const challenge = await replaceChallenge(
      docId,
      { purpose: 'reset', uid, subject: emailHash, emailHash, locale },
      secret,
      now,
    );
    if (!challenge.cooldown) {
      if (uid === null) {
        await enqueueMail(null, 'reset', locale, {});
      } else {
        await enqueueMail(email, 'reset', locale, { code: challenge.code });
      }
    }
    fields.result = 'accepted';
    return { status: 'accepted', resendAvailableAt: challenge.resendAvailableAt };
  });
}

export async function handleVerifyPasswordResetCode(
  data: VerifyInput | null | undefined,
  context: CallableContext,
  deps: ResetDeps,
) {
  const call = caller(context, deps);
  const { now, secret, fields } = call;
  return audited('verifyPasswordResetCode', fields, now, async () => {
    const { emailHash, docId } = parseEmail(data?.email, 'malformed-input', fields);
    const code = data?.code;
    if (!isSixDigits(code)) {
      throw fail('invalid-argument', 'malformed-input');
    }
    await enforce(verifyLimits(limitSubjects(call, emailHash)), now);

    const result = await checkCode(docId, 'reset', emailHash, emailHash, code, secret, now);
    if (result === 'locked') {
      throw fail('resource-exhausted', 'too-many-attempts');
    }
    if (typeof result === 'string' || 'invalid' in result || result.resetTicket === undefined) {
      throw fail('permission-denied', 'invalid-or-expired-code');
    }
    return { resetTicket: result.resetTicket };
  });
}

// the account may have moved to another address since the code was sent
async function stillOwnsAddress(uid: string, emailHash: string): Promise<boolean> {
  try {
    const { email } = await auth.getUser(uid);
    return email !== undefined && sha256Hex(normalizeEmail(email)) === emailHash;
  } catch (error) {
    if ((error as { code?: string }).code !== 'auth/user-not-found') {
      throw error;
    }
    return false;
  }
}

function parsePassword(value: unknown): string {
  if (typeof value !== 'string') {
    throw fail('invalid-argument', 'malformed-input');
  }
  if (value.length < minPasswordLength || value.length > maxPasswordLength) {
    throw fail('invalid-argument', 'weak-password');
  }
  return value;
}

export async function handleConfirmPasswordReset(
  data: ConfirmInput | null | undefined,
  context: CallableContext,
  deps: ResetDeps,
) {
  const call = caller(context, deps);
  const { now, secret, fields } = call;
  return audited('confirmPasswordReset', fields, now, async () => {
    const { email, emailHash, docId } = parseEmail(data?.email, 'malformed-input', fields);
    const ticket = data?.resetTicket;
    if (typeof ticket !== 'string' || !ticketPattern.test(ticket)) {
      throw fail('invalid-argument', 'malformed-input');
    }
    const password = parsePassword(data?.newPassword);
    await enforce(verifyLimits(limitSubjects(call, emailHash)), now);

    const owner = await consumeTicket(docId, ticket, secret, now);
    if (owner === null || !(await stillOwnsAddress(owner.uid, emailHash))) {
      throw fail('permission-denied', 'invalid-or-expired-ticket');
    }
    fields.uid = owner.uid;

    // a retry after a failed revoke sets the same password again and revokes then
    try {
      await auth.updateUser(owner.uid, { password, emailVerified: true });
      await auth.revokeRefreshTokens(owner.uid);
    } catch (error) {
      functions.logger.error('password_update_failed', { code: (error as { code?: string }).code });
      await releaseTicket(docId);
      throw tryAgain();
    }
    await enqueueMail(email, 'passwordChanged', owner.locale, {});
    return { success: true };
  });
}

const resetOptions = { ...callableOptions(['AUTH_CODE_SECRET']), consumeAppCheckToken: true };

const resetDeps = (): ResetDeps => ({ now: Date.now });

export const requestPasswordResetCode = functions
  .runWith(resetOptions)
  .https.onCall((data, context) => handleRequestPasswordResetCode(data, context, resetDeps()));

export const verifyPasswordResetCode = functions
  .runWith(resetOptions)
  .https.onCall((data, context) => handleVerifyPasswordResetCode(data, context, resetDeps()));

export const confirmPasswordReset = functions
  .runWith(resetOptions)
  .https.onCall((data, context) => handleConfirmPasswordReset(data, context, resetDeps()));
