import * as functions from 'firebase-functions/v1';
import { db } from '../../src/shared/admin';
import { Deps } from '../../src/auth/context';
import { MailDeliveryError, MailMessage, MailSender } from '../../src/mail/types';

process.env.AUTH_CODE_SECRET = 'test-secret';

export const secret = 'test-secret';
export const testIp = '203.0.113.7';
// aligned to the 900 and 3600 second windows so a test never crosses a window boundary
export const startTime = 1_800_000_000_000;

export class FakeSender implements MailSender {
  readonly sent: MailMessage[] = [];

  constructor(private readonly failure?: number) {}

  async send(message: MailMessage): Promise<void> {
    if (this.failure !== undefined) {
      throw new MailDeliveryError(this.failure);
    }
    this.sent.push(message);
  }
}

export function fakeDeps(sender = new FakeSender()) {
  const clock = { time: startTime };
  const deps: Deps = { mail: sender, now: () => clock.time };
  return { sender, clock, deps };
}

export function signedIn(uid: string, email?: string, verified = false, ip = testIp) {
  return {
    auth: { uid, token: { email, email_verified: verified } },
    rawRequest: { ip },
  } as unknown as functions.https.CallableContext;
}

export function anonymous(ip = testIp) {
  return { rawRequest: { ip } } as unknown as functions.https.CallableContext;
}

export function sentCode(message: MailMessage): string {
  const match = message.text.match(/\b\d{6}\b/);
  if (!match) {
    throw new Error('no code in the message');
  }
  return match[0];
}

export const authCollections = ['authCodes', 'authRateLimits', 'authAudit', 'mailQueue'];

export async function clearAuthCollections() {
  await Promise.all(authCollections.map((name) => db.recursiveDelete(db.collection(name))));
}

function strings(value: unknown): string[] {
  if (typeof value === 'string') {
    return [value];
  }
  if (value && typeof value === 'object') {
    return Object.values(value).flatMap(strings);
  }
  return [];
}

export async function storedStrings(names: string[]): Promise<string[]> {
  const snaps = await Promise.all(names.map((name) => db.collection(name).get()));
  return snaps.flatMap((snap) => snap.docs.flatMap((doc) => [doc.id, ...strings(doc.data())]));
}

export function reason(details: Record<string, unknown>) {
  return { details: expect.objectContaining(details) };
}
