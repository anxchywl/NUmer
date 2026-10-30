import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { sha256Hex } from './codes';

export interface LimitCheck {
  key: string;
  limit: number;
  windowSeconds: number;
}

export interface LimitResult {
  allowed: boolean;
  retryAfterSeconds: number;
}

function windowBounds(windowSeconds: number, now: number) {
  const nowSeconds = Math.floor(now / 1000);
  const start = Math.floor(nowSeconds / windowSeconds) * windowSeconds;
  return { nowSeconds, start, end: start + windowSeconds };
}

// the window length is hashed too, so a day and a 15 minute window starting at midnight stay apart
export function windowRef(key: string, windowSeconds: number, now: number) {
  const { start } = windowBounds(windowSeconds, now);
  return db.collection('authRateLimits').doc(`${sha256Hex(`${key}:${windowSeconds}`)}_${start}`);
}

export async function hit({ key, limit, windowSeconds }: LimitCheck, now: number): Promise<LimitResult> {
  const { nowSeconds, end } = windowBounds(windowSeconds, now);
  const ref = windowRef(key, windowSeconds, now);
  return db.runTransaction(async (txn) => {
    const count = (await txn.get(ref)).data()?.count ?? 0;
    if (count >= limit) {
      return { allowed: false, retryAfterSeconds: end - nowSeconds };
    }
    txn.set(ref, { count: count + 1, expiresAt: admin.firestore.Timestamp.fromMillis((end + 3600) * 1000) });
    return { allowed: true, retryAfterSeconds: 0 };
  });
}

export async function hitAll(checks: LimitCheck[], now: number): Promise<LimitResult> {
  for (const check of checks) {
    const result = await hit(check, now);
    if (!result.allowed) {
      return result;
    }
  }
  return { allowed: true, retryAfterSeconds: 0 };
}

// ipHash is left out when the caller has no ip, so such callers never share one bucket
interface Subjects {
  emailHash?: string;
  uid?: string;
  ipHash?: string;
}

function check(key: string | false, limit: number, windowSeconds: number): LimitCheck[] {
  return key ? [{ key, limit, windowSeconds }] : [];
}

export function sendLimits({ emailHash, uid, ipHash }: Subjects): LimitCheck[] {
  return [
    ...check(!!emailHash && `send:email:${emailHash}`, 3, 900),
    ...check(!!emailHash && `send:email:${emailHash}`, 10, 86400),
    ...check(!!uid && `send:uid:${uid}`, 5, 3600),
    ...check(!!ipHash && `send:ip:${ipHash}`, 10, 3600),
    ...check('send:global:all', 2000, 86400),
  ];
}

export function verifyLimits({ emailHash, uid, ipHash }: Subjects): LimitCheck[] {
  return [
    ...check(!!uid && `verify:uid:${uid}`, 20, 900),
    ...check(!!emailHash && `verify:email:${emailHash}`, 20, 900),
    ...check(!!ipHash && `verify:ip:${ipHash}`, 30, 3600),
  ];
}
