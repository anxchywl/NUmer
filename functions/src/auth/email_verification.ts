import * as functions from 'firebase-functions/v1';
import { auth } from '../shared/admin';
import { getMailSender } from '../mail/sender_factory';
import { renderEmail } from '../mail/templates';
import { MailDeliveryError } from '../mail/types';
import { audited, AuditFields } from './audit';
import { checkCode, deleteChallenge, releaseCode, replaceChallenge } from './challenge';
import { isSixDigits, normalizeEmail, sha256Hex } from './codes';
import { authSecret, callableOptions, clientIp, Deps, fail, ipHash, normalizeLocale, rateLimited, tryAgain } from './context';
import { hitAll, sendLimits, verifyLimits } from './rate_limits';

interface SendInput {
  locale?: unknown;
}

interface VerifyInput {
  code?: unknown;
}

type CallableContext = functions.https.CallableContext;

// the user record, not the token, so a code is bound to the address the account has now
async function currentAccount(context: CallableContext, fields: AuditFields) {
  if (!context.auth) {
    throw fail('unauthenticated', 'unauthenticated');
  }
  const { uid } = context.auth;
  fields.uid = uid;
  const user = await auth.getUser(uid);
  if (!user.email) {
    throw fail('failed-precondition', 'no-email');
  }
  const emailHash = sha256Hex(normalizeEmail(user.email));
  fields.emailHash = emailHash;
  return { uid, email: user.email, emailHash, verified: user.emailVerified };
}

export async function handleSendEmailVerificationCode(
  data: SendInput | null | undefined,
  context: CallableContext,
  deps: Deps,
) {
  const now = deps.now();
  const secret = authSecret();
  const ip = clientIp(context);
  const fields: AuditFields = { ipHash: ipHash(secret, ip) };
  return audited('sendEmailVerificationCode', fields, now, async () => {
    const { uid, email, emailHash, verified } = await currentAccount(context, fields);
    if (verified) {
      fields.result = 'already-verified';
      return { status: 'already-verified', resendAvailableAt: now, expiresAt: now };
    }

    const docId = `verify_${uid}`;
    const locale = normalizeLocale(data?.locale);
    const challenge = await replaceChallenge(
      docId,
      { purpose: 'verify', uid, subject: uid, emailHash, locale },
      secret,
      now,
    );
    const { resendAvailableAt, expiresAt } = challenge;
    if (challenge.cooldown) {
      fields.result = 'cooldown';
      return { status: 'cooldown', resendAvailableAt, expiresAt };
    }

    const limit = await hitAll(sendLimits('verify', { uid, emailHash, ipHash: ip ? fields.ipHash : undefined }), now);
    if (!limit.allowed) {
      await deleteChallenge(docId, challenge.codeId);
      throw rateLimited(limit.retryAfterSeconds);
    }

    try {
      await deps.mail.send({ to: email, ...renderEmail('verify', locale, { code: challenge.code }) });
    } catch (error) {
      if (!(error instanceof MailDeliveryError)) {
        throw error;
      }
      functions.logger.error('verification_mail_failed', { status: error.status });
      await deleteChallenge(docId, challenge.codeId);
      throw fail('unavailable', 'delivery-failed');
    }
    fields.result = 'sent';
    return { status: 'sent', resendAvailableAt, expiresAt };
  });
}

export async function handleVerifyEmailCode(
  data: VerifyInput | null | undefined,
  context: CallableContext,
  deps: Deps,
) {
  const now = deps.now();
  const secret = authSecret();
  const ip = clientIp(context);
  const fields: AuditFields = { ipHash: ipHash(secret, ip) };
  return audited('verifyEmailCode', fields, now, async () => {
    const { uid, email, emailHash } = await currentAccount(context, fields);
    const code = data?.code;
    if (!isSixDigits(code)) {
      throw fail('invalid-argument', 'malformed-code');
    }

    const limit = await hitAll(verifyLimits({ uid, ipHash: ip ? fields.ipHash : undefined }), now);
    if (!limit.allowed) {
      throw rateLimited(limit.retryAfterSeconds);
    }

    const docId = `verify_${uid}`;
    const result = await checkCode(docId, 'verify', uid, emailHash, code, secret, now);
    if (result === 'none') {
      throw fail('not-found', 'no-active-code');
    }
    if (result === 'expired') {
      throw fail('deadline-exceeded', 'code-expired');
    }
    if (result === 'locked') {
      throw fail('resource-exhausted', 'too-many-attempts');
    }
    if ('invalid' in result) {
      throw fail('permission-denied', 'invalid-code', { attemptsLeft: result.invalid });
    }

    try {
      // writing the checked address too undoes an email change that raced this call
      await auth.updateUser(uid, { email, emailVerified: true });
    } catch (error) {
      functions.logger.error('verification_update_failed', { code: (error as { code?: string }).code });
      await releaseCode(docId, result.codeId);
      throw tryAgain();
    }
    return { verified: true };
  });
}

function verificationDeps(): Deps {
  return { mail: getMailSender(), now: Date.now };
}

const verificationOptions = callableOptions(['AUTH_CODE_SECRET', 'MAIL_API_KEY']);

export const sendEmailVerificationCode = functions
  .runWith(verificationOptions)
  .https.onCall((data, context) => handleSendEmailVerificationCode(data, context, verificationDeps()));

export const verifyEmailCode = functions
  .runWith(verificationOptions)
  .https.onCall((data, context) => handleVerifyEmailCode(data, context, verificationDeps()));
