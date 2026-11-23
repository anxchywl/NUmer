import * as functions from 'firebase-functions/v1';
import { DocumentData, DocumentReference, Firestore, Timestamp } from 'firebase-admin/firestore';
import { AccountEventData, nextAttemptAt, serializeEvent, signEvent } from './event_signature';

const modules = ['clavis', 'events', 'muto'] as const;
const loopbackHosts = ['127.0.0.1', 'localhost'];
const timeoutMs = 10_000;
const retryWindowMs = 72 * 3600 * 1000;
const dueLimit = 20;

export type ModuleName = (typeof modules)[number];

export interface EventTarget {
  module: ModuleName;
  url: string;
}

type Status = 'delivered' | 'pending' | 'failed';

interface Delivery {
  status: Status;
  attempts: number;
  lastAttemptAt: Timestamp;
  lastHttpStatus: number;
}

interface Attempt {
  module: ModuleName;
  httpStatus: number;
}

export function secretName(module: ModuleName): string {
  return `ACCOUNT_EVENTS_SECRET_${module.toUpperCase()}`;
}

function isModuleName(value: unknown): value is ModuleName {
  return modules.includes(value as ModuleName);
}

function isAllowedUrl(url: string, allowLoopbackHttp: boolean): boolean {
  const { protocol, hostname } = new URL(url);
  if (protocol === 'https:') return true;
  return allowLoopbackHttp && protocol === 'http:' && loopbackHosts.includes(hostname);
}

export function loadTargets(raw: string | undefined, options: { allowLoopbackHttp: boolean }): EventTarget[] {
  if (!raw) return [];
  const entries: unknown = JSON.parse(raw);
  if (!Array.isArray(entries)) throw new Error('account event targets must be a JSON array');
  const seen = new Set<ModuleName>();
  return entries.map((entry) => {
    const { module, url } = (entry ?? {}) as { module?: unknown; url?: unknown };
    if (!isModuleName(module)) throw new Error('unknown account event module');
    if (seen.has(module)) throw new Error(`duplicate account event module ${module}`);
    seen.add(module);
    if (typeof url !== 'string' || !isAllowedUrl(url, options.allowLoopbackHttp)) {
      throw new Error(`account event url for ${module} must use https`);
    }
    return { module, url };
  });
}

// fetch rejects with TypeError on a network failure and AbortError on the timeout
function isTransportFailure(error: unknown): boolean {
  return ['TypeError', 'AbortError'].includes((error as Error).name);
}

// status 0 means no answer, and a redirect is not followed so it never counts as success
async function post(target: EventTarget, body: string, fetchImpl: typeof fetch): Promise<number> {
  const secret = process.env[secretName(target.module)];
  if (!secret) return 0;
  // the send time, since the run's clock can be minutes old and handlers reject a stale signature
  const signature = signEvent(secret, Math.floor(Date.now() / 1000), body);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(target.url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Numer-Signature': signature },
      body,
      redirect: 'manual',
      signal: controller.signal,
    });
    await response.body?.cancel();
    return response.status;
  } catch (error) {
    if (!isTransportFailure(error)) throw error;
    return 0;
  } finally {
    clearTimeout(timer);
  }
}

function isSuccess(httpStatus: number): boolean {
  return httpStatus >= 200 && httpStatus < 300;
}

// a concurrent run may have settled the target already, and a settled target never reopens
function mergeAttempt(stored: Delivery | undefined, httpStatus: number, expired: boolean, now: Date): Delivery {
  if (stored?.status === 'delivered') return stored;
  const failed = expired || stored?.status === 'failed';
  return {
    status: isSuccess(httpStatus) ? 'delivered' : failed ? 'failed' : 'pending',
    attempts: (stored?.attempts ?? 0) + 1,
    lastAttemptAt: Timestamp.fromDate(now),
    lastHttpStatus: httpStatus,
  };
}

function eventUpdate(event: DocumentData, targets: EventTarget[], attempts: Attempt[], now: Date) {
  const expired = now.getTime() - (event.occurredAt as Timestamp).toMillis() >= retryWindowMs;
  const deliveries: Partial<Record<ModuleName, Delivery>> = { ...event.deliveries };
  const newlyFailed: ModuleName[] = [];
  for (const { module, httpStatus } of attempts) {
    const stored = deliveries[module];
    const merged = mergeAttempt(stored, httpStatus, expired, now);
    if (merged.status === 'failed' && stored?.status !== 'failed') newlyFailed.push(module);
    deliveries[module] = merged;
  }
  // kept apart from delivered so that these deletions can still be found and sent
  if (targets.length === 0) {
    return { newlyFailed, changes: event.status === 'pending' ? { status: 'unrouted' } : {} };
  }
  const records = targets.map(({ module }) => deliveries[module]);
  if (records.every((record) => record?.status === 'delivered')) {
    return { newlyFailed, changes: { deliveries, status: 'delivered' } };
  }
  if (event.status !== 'pending') return { newlyFailed, changes: { deliveries } };
  if (expired) return { newlyFailed, changes: { deliveries, status: 'failed' } };
  const due = records
    .filter((record) => record?.status === 'pending')
    .map((record) => nextAttemptAt(record!.attempts, now).getTime());
  const next = due.length > 0 ? Math.min(...due) : nextAttemptAt(1, now).getTime();
  return { newlyFailed, changes: { deliveries, status: 'pending', nextAttemptAt: Timestamp.fromMillis(next) } };
}

async function recordAttempts(eventRef: DocumentReference, targets: EventTarget[], attempts: Attempt[], now: Date) {
  const update = await eventRef.firestore.runTransaction(async (transaction) => {
    const event = (await transaction.get(eventRef)).data();
    if (!event) return undefined;
    const result = eventUpdate(event, targets, attempts, now);
    transaction.update(eventRef, result.changes);
    return result;
  });
  if (update?.changes.status === 'unrouted') {
    functions.logger.warn('account_event_unrouted', { id: eventRef.id });
  }
  for (const module of update?.newlyFailed ?? []) {
    functions.logger.error('account_event_delivery_failed', { id: eventRef.id, module });
  }
}

export async function deliverPending(
  eventRef: DocumentReference,
  targets: EventTarget[],
  now: Date,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const event = (await eventRef.get()).data();
  if (event?.status !== 'pending') return;
  // written before any post so that an interrupted run is picked up by the retry
  if (!event.nextAttemptAt) {
    await eventRef.update({ nextAttemptAt: Timestamp.fromDate(nextAttemptAt(1, now)) });
  }
  const body = serializeEvent(eventRef.id, event as AccountEventData);
  const open = targets.filter(({ module }) => {
    const status = event.deliveries?.[module]?.status;
    return status !== 'delivered' && status !== 'failed';
  });
  const results = await Promise.allSettled(
    open.map(async (target) => ({
      module: target.module,
      httpStatus: await post(target, body, fetchImpl),
    })),
  );
  const attempts = results.flatMap((result) => (result.status === 'fulfilled' ? [result.value] : []));
  await recordAttempts(eventRef, targets, attempts, now);
  const rejected = results.find((result): result is PromiseRejectedResult => result.status === 'rejected');
  if (rejected) throw rejected.reason;
}

export async function retryDueEvents(
  db: Firestore,
  now: Date,
  targets: EventTarget[],
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const pending = db.collection('accountEvents').where('status', '==', 'pending');
  // a query never matches a missing field, so unscheduled events are filtered here
  const [all, due] = await Promise.all([
    pending.select('nextAttemptAt').get(),
    pending.where('nextAttemptAt', '<=', Timestamp.fromDate(now)).limit(dueLimit).get(),
  ]);
  const unscheduled = all.docs.filter((event) => !event.get('nextAttemptAt'));
  for (const event of [...unscheduled, ...due.docs].slice(0, dueLimit)) {
    await deliverPending(event.ref, targets, now, fetchImpl);
  }
}
