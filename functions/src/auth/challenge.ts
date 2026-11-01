import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { db } from '../shared/admin';
import { MailLocale } from '../mail/types';
import { CodePurpose, generateCode, generateTicket, hashCode, hashTicket, newCodeId, safeEqualHex } from './codes';

const codeLifeMs = 600 * 1000;
const resendCooldownMs = 60 * 1000;
const ticketLifeMs = 600 * 1000;
const ttlGraceMs = 24 * 3600 * 1000;
const maxAttempts = 5;
const keyVersion = 1;

type Timestamp = admin.firestore.Timestamp;
const at = (millis: number) => admin.firestore.Timestamp.fromMillis(millis);

export interface ChallengeFields {
  purpose: CodePurpose;
  uid: string | null;
  subject: string;
  emailHash: string;
  locale: MailLocale;
}

export type ReplaceResult =
  | { cooldown: true; resendAvailableAt: number; expiresAt: number }
  | { cooldown: false; codeId: string; code: string; resendAvailableAt: number; expiresAt: number };

export type CheckResult =
  | 'none'
  | 'expired'
  | 'locked'
  | { invalid: number }
  | { ok: true; codeId: string; resetTicket?: string };

export interface TicketOwner {
  uid: string;
  locale: MailLocale;
}

const challenges = db.collection('authCodes');

function isConsumed(data: FirebaseFirestore.DocumentData): boolean {
  return data.consumedAt !== null && data.consumedAt !== undefined;
}

// a dummy row gets a random hash, so no code can ever match it
function codeHashFor(secret: string, fields: ChallengeFields, code: string, codeId: string): string {
  if (fields.uid === null) {
    return crypto.randomBytes(32).toString('hex');
  }
  return hashCode(secret, fields.purpose, fields.subject, code, codeId);
}

export async function replaceChallenge(
  docId: string,
  fields: ChallengeFields,
  secret: string,
  now: number,
): Promise<ReplaceResult> {
  const ref = challenges.doc(docId);
  const code = generateCode();
  const codeId = newCodeId();
  const codeHash = codeHashFor(secret, fields, code, codeId);
  return db.runTransaction(async (txn) => {
    const current = (await txn.get(ref)).data();
    const currentResend = current?.resendAvailableAt as Timestamp | undefined;
    if (current && !isConsumed(current) && currentResend && currentResend.toMillis() > now) {
      return {
        cooldown: true,
        resendAvailableAt: currentResend.toMillis(),
        expiresAt: (current.expiresAt as Timestamp).toMillis(),
      };
    }
    const expiresAt = now + codeLifeMs;
    const resendAvailableAt = now + resendCooldownMs;
    txn.set(ref, {
      purpose: fields.purpose,
      uid: fields.uid,
      emailHash: fields.emailHash,
      codeId,
      codeHash,
      keyVersion,
      attempts: 0,
      createdAt: at(now),
      expiresAt: at(expiresAt),
      resendAvailableAt: at(resendAvailableAt),
      consumedAt: null,
      ticketHash: null,
      ticketExpiresAt: null,
      ticketConsumedAt: null,
      locale: fields.locale,
      ttlAt: at(expiresAt + ttlGraceMs),
    });
    return { cooldown: false, codeId, code, resendAvailableAt, expiresAt };
  });
}

export async function deleteChallenge(docId: string, codeId: string): Promise<void> {
  const ref = challenges.doc(docId);
  await db.runTransaction(async (txn) => {
    const current = (await txn.get(ref)).data();
    if (current?.codeId === codeId) {
      txn.delete(ref);
    }
  });
}

export async function checkCode(
  docId: string,
  purpose: CodePurpose,
  subject: string,
  emailHash: string,
  code: string,
  secret: string,
  now: number,
): Promise<CheckResult> {
  const ref = challenges.doc(docId);
  return db.runTransaction<CheckResult>(async (txn) => {
    const data = (await txn.get(ref)).data();
    if (!data || isConsumed(data)) {
      return 'none';
    }
    const attempts = data.attempts as number;
    if (attempts >= maxAttempts) {
      return 'locked';
    }
    if ((data.expiresAt as Timestamp).toMillis() <= now) {
      return 'expired';
    }
    const expected = hashCode(secret, purpose, subject, code, data.codeId);
    const matches =
      data.uid !== null &&
      data.emailHash === emailHash &&
      data.keyVersion === keyVersion &&
      safeEqualHex(data.codeHash, expected);
    if (!matches) {
      txn.update(ref, { attempts: attempts + 1 });
      return { invalid: maxAttempts - attempts - 1 };
    }
    if (purpose !== 'reset') {
      txn.update(ref, { attempts: attempts + 1, consumedAt: at(now) });
      return { ok: true, codeId: data.codeId };
    }
    const resetTicket = generateTicket();
    txn.update(ref, {
      attempts: attempts + 1,
      consumedAt: at(now),
      ticketHash: hashTicket(secret, docId, resetTicket),
      ticketExpiresAt: at(now + ticketLifeMs),
    });
    return { ok: true, codeId: data.codeId, resetTicket };
  });
}

export async function releaseCode(docId: string, codeId: string): Promise<void> {
  const ref = challenges.doc(docId);
  await db.runTransaction(async (txn) => {
    const current = (await txn.get(ref)).data();
    if (current?.codeId === codeId) {
      txn.update(ref, { consumedAt: null });
    }
  });
}

export async function consumeTicket(
  docId: string,
  ticket: string,
  secret: string,
  now: number,
): Promise<TicketOwner | null> {
  const ref = challenges.doc(docId);
  return db.runTransaction(async (txn) => {
    const data = (await txn.get(ref)).data();
    if (!data || data.uid === null || typeof data.ticketHash !== 'string') {
      return null;
    }
    const expiresAt = data.ticketExpiresAt as Timestamp | null;
    const valid =
      safeEqualHex(data.ticketHash, hashTicket(secret, docId, ticket)) &&
      expiresAt !== null &&
      expiresAt.toMillis() > now &&
      data.ticketConsumedAt === null;
    if (!valid) {
      return null;
    }
    txn.update(ref, { ticketConsumedAt: at(now) });
    return { uid: data.uid, locale: data.locale };
  });
}

export async function releaseTicket(docId: string): Promise<void> {
  const ref = challenges.doc(docId);
  await db.runTransaction(async (txn) => {
    const current = (await txn.get(ref)).data();
    if (current && current.ticketConsumedAt !== null) {
      txn.update(ref, { ticketConsumedAt: null });
    }
  });
}
