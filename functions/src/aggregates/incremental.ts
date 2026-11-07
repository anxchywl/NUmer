import * as functions from 'firebase-functions/v1';
import { DocumentData } from 'firebase-admin/firestore';
import { db } from '../shared/admin';
import { AggregatePayload, derivePayload, timezoneOf, userFieldsOf, windowStartDay } from './derive';
import {
  applyToLedger,
  contributionOf,
  contributionsOf,
  Ledger,
  payloadHash,
  pruneLedger,
} from './ledger';
import { aggregateDocument, aggregateRefs, loadLegacyInputs } from './update_user_aggregates';
import { deletionMarkerRef } from '../shared/user_writes';

const STATE_VERSION = 1;
const REBUILD_AFTER_MS = 7 * 24 * 3600 * 1000;

type DocumentChange = functions.Change<functions.firestore.DocumentSnapshot>;

export interface AggState {
  v: number;
  tz: number;
  hidden: string[];
  ledger: Ledger;
  rebuiltAt: number;
  payloadHash: string;
}

export interface EventOptions {
  publish: boolean;
  derive: typeof derivePayload;
}

export interface EventResult {
  payload: AggregatePayload | null;
  reads: number;
  wrote: boolean;
}

type Mutation = (state: AggState, startDay: string) => { ledger: Ledger; hidden: string[]; changed: boolean };

function stateRef(userId: string) {
  return db.collection('users').doc(userId).collection('aggState').doc('v1');
}

function isValidState(state: DocumentData | undefined, tz: number, nowMs: number): state is AggState {
  return state !== undefined &&
    state.v === STATE_VERSION &&
    state.tz === tz &&
    typeof state.rebuiltAt === 'number' &&
    nowMs - state.rebuiltAt <= REBUILD_AFTER_MS;
}

async function prepareRebuild(userId: string): Promise<{ state: AggState; reads: number }> {
  const rebuiltAt = Date.now();
  const inputs = await loadLegacyInputs(userId, new Date(rebuiltAt));
  const ledger: Ledger = {};
  for (const c of inputs.contributions) {
    ledger[c.sessionId] = { c: c.courseId, d: c.day, s: c.seconds, t: rebuiltAt };
  }
  const state: AggState = {
    v: STATE_VERSION,
    tz: timezoneOf(inputs.user),
    hidden: [...inputs.hiddenCourseIds].sort(),
    ledger,
    rebuiltAt,
    payloadHash: '',
  };
  return { state, reads: inputs.reads };
}

async function runEvent(
  userId: string,
  logFields: Record<string, string>,
  options: EventOptions,
  requireState: boolean,
  mutate: Mutation,
): Promise<EventResult> {
  const userRef = db.collection('users').doc(userId);
  const [stateSnap, userSnap] = await Promise.all([stateRef(userId).get(), userRef.get()]);
  let reads = 2;
  let prepared: AggState | null = null;
  const proceed = userSnap.exists && (stateSnap.exists || !requireState);
  if (proceed && !isValidState(stateSnap.data(), timezoneOf(userFieldsOf(userSnap.data())), Date.now())) {
    const rebuild = await prepareRebuild(userId);
    prepared = rebuild.state;
    reads += rebuild.reads;
  }

  const outcome = !proceed ? { payload: null, wrote: false } : await db.runTransaction(async tx => {
    const [txState, txUser, marker, memberships] = await Promise.all([
      tx.get(stateRef(userId)),
      tx.get(userRef),
      tx.get(deletionMarkerRef(userId)),
      tx.get(userRef.collection('groupMemberships')),
    ]);
    reads += 3 + memberships.size;
    if (!txUser.exists || marker.exists || (requireState && !txState.exists)) return { payload: null, wrote: false };

    const user = userFieldsOf(txUser.data());
    const tz = timezoneOf(user);
    const now = new Date();
    const stored = txState.data();
    const valid = isValidState(stored, tz, now.getTime());
    const base = valid ? stored : prepared;
    if (!base || base.tz !== tz) {
      throw new Error('aggregate state became invalid during the event');
    }

    const startDay = windowStartDay(tz, now);
    const next = mutate(base, startDay);
    const ledger = pruneLedger(next.ledger, startDay);
    const changed = next.changed || Object.keys(ledger).length !== Object.keys(next.ledger).length;

    const groupIds = memberships.docs.map(d => d.id);
    const payload = options.derive({
      userId,
      user,
      hiddenCourseIds: new Set(next.hidden),
      contributions: contributionsOf(ledger),
      now,
    });
    const hash = payloadHash({ payload, groupIds: [...groupIds].sort() });
    const hashChanged = hash !== base.payloadHash;

    const publishing = hashChanged && options.publish;
    if (publishing) {
      const data = aggregateDocument(payload);
      for (const ref of aggregateRefs(userId, groupIds)) {
        tx.set(ref, data, { merge: true });
      }
    }
    const savingState = changed || hashChanged || !valid;
    if (savingState) {
      const state: AggState = {
        v: STATE_VERSION,
        tz,
        hidden: next.hidden,
        ledger,
        rebuiltAt: base.rebuiltAt,
        payloadHash: hash,
      };
      tx.set(stateRef(userId), state);
    }
    return { payload, wrote: publishing || savingState };
  });

  functions.logger.info('aggregate_event', { uid: userId, ...logFields, reads, wrote: outcome.wrote });
  return { ...outcome, reads };
}

export function applySessionEvent(
  userId: string,
  sessionId: string,
  change: DocumentChange,
  eventTimeMs: number,
  options: EventOptions,
): Promise<EventResult> {
  return runEvent(userId, { sessionId }, options, false, (state, startDay) => {
    // the rebuild read already saw every write older than itself, including deletes it holds no entry for
    if (eventTimeMs < state.rebuiltAt) return { ledger: state.ledger, hidden: state.hidden, changed: false };
    const contribution = contributionOf(change.after.data(), state.tz, startDay);
    const applied = applyToLedger(state.ledger, sessionId, contribution, eventTimeMs);
    return { ledger: applied.ledger, hidden: state.hidden, changed: applied.changed };
  });
}

export async function applyCourseEvent(
  userId: string,
  courseId: string,
  change: DocumentChange,
  options: EventOptions,
): Promise<EventResult> {
  const hiddenBefore = change.before.data()?.hiddenFromLeaderboard === true;
  const hiddenAfter = change.after.data()?.hiddenFromLeaderboard === true;
  if (hiddenBefore === hiddenAfter) {
    functions.logger.info('aggregate_event', { uid: userId, courseId, reads: 0, wrote: false });
    return { payload: null, reads: 0, wrote: false };
  }
  return runEvent(userId, { courseId }, options, true, state => {
    const hidden = state.hidden.filter(id => id !== courseId);
    if (hiddenAfter) hidden.push(courseId);
    hidden.sort();
    const changed = hidden.length !== state.hidden.length || hidden.some((id, i) => id !== state.hidden[i]);
    return { ledger: state.ledger, hidden, changed };
  });
}
