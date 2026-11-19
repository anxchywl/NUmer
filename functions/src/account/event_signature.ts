import { createHmac } from 'crypto';
import type { Timestamp } from 'firebase-admin/firestore';

const minuteMs = 60 * 1000;
const backoffMinutes = [15, 30, 60, 120, 240, 360];

export interface AccountEventData {
  type: string;
  issuer: string;
  subject: string;
  occurredAt: Timestamp;
}

export function signEvent(secret: string, timestampSeconds: number, rawBody: string): string {
  const digest = createHmac('sha256', secret).update(`${timestampSeconds}.${rawBody}`).digest('hex');
  return `t=${timestampSeconds},v1=${digest}`;
}

// attempts counts the attempt just made
export function nextAttemptAt(attempts: number, now: Date): Date {
  const minutes = backoffMinutes[Math.min(attempts, backoffMinutes.length) - 1];
  return new Date(now.getTime() + minutes * minuteMs);
}

export function serializeEvent(id: string, data: AccountEventData): string {
  const { type, issuer, subject, occurredAt } = data;
  return JSON.stringify({ id, type, issuer, subject, occurredAt: occurredAt.toDate().toISOString() });
}
