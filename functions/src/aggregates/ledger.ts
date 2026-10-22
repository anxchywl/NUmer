import { createHash } from 'crypto';
import { DocumentData, Timestamp } from 'firebase-admin/firestore';
import { Contribution, dayKeyOf } from './derive';

export interface LedgerValue {
  c: string;
  d: string;
  s: number;
}

export interface LedgerEntry extends LedgerValue {
  t: number;
}

export type Ledger = Record<string, LedgerEntry>;

export function contributionOf(
  data: DocumentData | undefined,
  timezoneOffsetMinutes: number,
  windowStartDay: string,
): LedgerValue | null {
  if (!data) return null;
  const ts = data.startUtc;
  const seconds = (data.seconds as number) || 0;
  const deleted = (data.deleted as boolean) || false;
  if (!(ts instanceof Timestamp) || deleted || seconds <= 0) return null;

  const d = dayKeyOf(ts.toMillis(), timezoneOffsetMinutes);
  if (d < windowStartDay) return null;
  return { c: (data.courseId as string) || '', d, s: seconds };
}

export function applyToLedger(
  ledger: Ledger,
  sessionId: string,
  contribution: LedgerValue | null,
  eventTimeMs: number,
): { ledger: Ledger; changed: boolean } {
  const stored = ledger[sessionId];
  if (stored && stored.t > eventTimeMs) return { ledger, changed: false };
  if (!contribution) {
    if (!stored) return { ledger, changed: false };
    const next = { ...ledger };
    delete next[sessionId];
    return { ledger: next, changed: true };
  }
  if (stored && stored.c === contribution.c && stored.d === contribution.d && stored.s === contribution.s) {
    return { ledger, changed: false };
  }
  return { ledger: { ...ledger, [sessionId]: { ...contribution, t: eventTimeMs } }, changed: true };
}

export function pruneLedger(ledger: Ledger, windowStartDay: string): Ledger {
  const next: Ledger = {};
  for (const [sessionId, entry] of Object.entries(ledger)) {
    if (entry.d >= windowStartDay) next[sessionId] = entry;
  }
  return next;
}

export function contributionsOf(ledger: Ledger): Contribution[] {
  return Object.entries(ledger).map(([sessionId, entry]) => ({
    sessionId,
    courseId: entry.c,
    day: entry.d,
    seconds: entry.s,
  }));
}

export function stableStringify(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    const keys = Object.keys(record).filter(k => record[k] !== undefined).sort();
    return `{${keys.map(k => `${JSON.stringify(k)}:${stableStringify(record[k])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

export function payloadHash(payload: unknown): string {
  return createHash('sha256').update(stableStringify(payload)).digest('hex');
}
