import functionsTest from 'firebase-functions-test';
import * as functions from 'firebase-functions/v1';
import { DocumentData, DocumentReference, Timestamp } from 'firebase-admin/firestore';
import { db } from '../../src/shared/admin';
import { derivePayload } from '../../src/aggregates/derive';
import { createAggregateHandlers, HandlerConfig } from '../../src/aggregates/handlers';

jest.mock('firebase-functions/v1', () => ({
  ...jest.requireActual('firebase-functions/v1'),
  logger: { info: jest.fn(), error: jest.fn() },
}));

const fft = functionsTest({ projectId: 'demo-numer' });
const DAY_MS = 24 * 3600 * 1000;
const COURSES = ['c0', 'c1', 'c2', 'c3', 'c4'];

type Kind = 'create' | 'seconds' | 'moveDay' | 'course' | 'softDelete' | 'undelete' | 'notes' | 'hardDelete' | 'toggleHidden';
const KINDS: Kind[] = ['create', 'seconds', 'moveDay', 'course', 'softDelete', 'undelete', 'notes', 'hardDelete', 'toggleHidden'];

function mulberry32(seed: number) {
  let a = seed;
  return () => {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function triggers(config: HandlerConfig) {
  const handlers = createAggregateHandlers(config);
  return {
    session: fft.wrap(functions.firestore.document('users/{userId}/sessions/{sessionId}').onWrite(handlers.onSession)),
    course: fft.wrap(functions.firestore.document('users/{userId}/courses/{courseId}').onWrite(handlers.onCourse)),
  };
}

const legacy = triggers({ mode: 'off', shadowPercent: 0 });
const incremental = triggers({ mode: 'on', shadowPercent: 0 });

let lastEventMs = 0;
function nextTimestamp(): string {
  lastEventMs = Math.max(lastEventMs + 1, Date.now());
  return new Date(lastEventMs).toISOString();
}

let runId = 0;
function uniqueUser(name: string): string {
  runId += 1;
  return `${name}-${Date.now()}-${runId}`;
}

async function seedUser(uid: string, groupCount: number, sessions: Record<string, DocumentData>, tz = 300) {
  const batch = db.batch();
  const user = db.collection('users').doc(uid);
  batch.set(user, { profileName: 'Ann', avatarIndex: 3, avatarColorValue: 4281558681, timezoneOffsetMinutes: tz });
  for (let g = 1; g <= groupCount; g++) {
    batch.set(user.collection('groupMemberships').doc(`${uid}-g${g}`), { role: 'member' });
  }
  COURSES.forEach((id, i) => batch.set(user.collection('courses').doc(id), { name: id, hiddenFromLeaderboard: i === 4 }));
  for (const [id, data] of Object.entries(sessions)) {
    batch.set(user.collection('sessions').doc(id), data);
  }
  await batch.commit();
}

function randomSession(rng: () => number, nowMs: number, spanDays: number): DocumentData {
  const data: DocumentData = {
    courseId: COURSES[Math.floor(rng() * COURSES.length)],
    seconds: rng() < 0.1 ? 0 : 60 + Math.floor(rng() * 7200),
    startUtc: Timestamp.fromMillis(nowMs - Math.floor(rng() * spanDays * DAY_MS)),
  };
  if (rng() < 0.1) data.deleted = true;
  return data;
}

function seedSessions(seed: number): Record<string, DocumentData> {
  const rng = mulberry32(seed);
  const nowMs = Date.now();
  const sessions: Record<string, DocumentData> = {};
  for (let i = 0; i < 60; i++) sessions[`s${i}`] = randomSession(rng, nowMs, 40);
  return sessions;
}

async function writeDoc(ref: DocumentReference, data: DocumentData | null) {
  const before = await ref.get();
  if (data) {
    await ref.set(data);
  } else {
    await ref.delete();
  }
  const after = await ref.get();
  return fft.makeChange(before, after);
}

type Trigger = ReturnType<typeof triggers>['session'];

async function sessionEvent(trigger: Trigger, uid: string, sessionId: string, data: DocumentData | null, timestamp = nextTimestamp()) {
  const change = await writeDoc(db.doc(`users/${uid}/sessions/${sessionId}`), data);
  await trigger(change, { params: { userId: uid, sessionId }, timestamp });
  return { change, timestamp };
}

async function courseEvent(trigger: Trigger, uid: string, courseId: string, data: DocumentData) {
  const change = await writeDoc(db.doc(`users/${uid}/courses/${courseId}`), data);
  await trigger(change, { params: { userId: uid, courseId }, timestamp: nextTimestamp() });
}

function aggregatePaths(uid: string, groupCount: number): string[] {
  const paths = [`users/${uid}/aggregates/statistics`];
  for (let g = 1; g <= groupCount; g++) paths.push(`groups/${uid}-g${g}/aggregates/${uid}`);
  return paths;
}

async function publicDocs(uid: string, groupCount: number) {
  const snaps = await Promise.all(aggregatePaths(uid, groupCount).map(p => db.doc(p).get()));
  return snaps.map(s => {
    const data = s.data();
    if (!data) return null;
    const { updatedAt, userId, ...rest } = data;
    expect(updatedAt).toBeDefined();
    expect(userId).toBe(uid);
    return rest;
  });
}

async function updateTimes(paths: string[]) {
  const snaps = await Promise.all(paths.map(p => db.doc(p).get()));
  return snaps.map(s => s.updateTime?.toMillis() ?? null);
}

function eventLogs(spy: jest.Mock, uid: string) {
  return spy.mock.calls
    .filter(([message, fields]) => message === 'aggregate_event' && fields.uid === uid)
    .map(([, fields]) => fields as { reads: number; wrote: boolean });
}

class Scenario {
  private readonly rng: () => number;
  private readonly sessions: Record<string, DocumentData>;
  private readonly hidden: Record<string, boolean> = { c0: false, c1: false, c2: false, c3: false, c4: true };
  private created = 0;

  constructor(seed: number, sessions: Record<string, DocumentData>) {
    this.rng = mulberry32(seed);
    this.sessions = { ...sessions };
  }

  private pickSession(): string {
    const ids = Object.keys(this.sessions);
    return ids[Math.floor(this.rng() * ids.length)];
  }

  next(kind: Kind): { collection: 'sessions' | 'courses'; id: string; data: DocumentData | null } {
    if (kind === 'toggleHidden') {
      const id = COURSES[Math.floor(this.rng() * COURSES.length)];
      this.hidden[id] = !this.hidden[id];
      return { collection: 'courses', id, data: { name: id, hiddenFromLeaderboard: this.hidden[id] } };
    }
    if (kind === 'create') {
      const id = `new${this.created++}`;
      this.sessions[id] = randomSession(this.rng, Date.now(), 34);
      return { collection: 'sessions', id, data: this.sessions[id] };
    }
    const id = this.pickSession();
    if (kind === 'hardDelete') {
      delete this.sessions[id];
      return { collection: 'sessions', id, data: null };
    }
    const data = { ...this.sessions[id] };
    if (kind === 'seconds') data.seconds = this.rng() < 0.2 ? 0 : 60 + Math.floor(this.rng() * 7200);
    if (kind === 'moveDay') {
      const shift = (1 + Math.floor(this.rng() * 10)) * DAY_MS * (this.rng() < 0.5 ? -1 : 1);
      data.startUtc = Timestamp.fromMillis(Math.min(Date.now(), (data.startUtc as Timestamp).toMillis() + shift));
    }
    if (kind === 'course') data.courseId = COURSES[Math.floor(this.rng() * COURSES.length)];
    if (kind === 'softDelete') data.deleted = true;
    if (kind === 'undelete') data.deleted = false;
    if (kind === 'notes') {
      data.notes = `note ${Math.floor(this.rng() * 1000)}`;
      data.updatedAt = Timestamp.now();
    }
    this.sessions[id] = data;
    return { collection: 'sessions', id, data };
  }

  kind(index: number): Kind {
    if (index < KINDS.length) return KINDS[index];
    return KINDS[Math.floor(this.rng() * KINDS.length)];
  }
}

async function runEvents(
  scenario: Scenario,
  count: number,
  users: { uid: string; trigger: ReturnType<typeof triggers> }[],
  afterEach: (index: number) => Promise<void>,
) {
  for (let i = 0; i < count; i++) {
    const event = scenario.next(scenario.kind(i));
    for (const { uid, trigger } of users) {
      if (event.collection === 'sessions') {
        await sessionEvent(trigger.session, uid, event.id, event.data);
      } else {
        await courseEvent(trigger.course, uid, event.id, event.data as DocumentData);
      }
    }
    await afterEach(i);
  }
}

describe('incremental aggregates', () => {
  const info = functions.logger.info as jest.Mock;
  const error = functions.logger.error as jest.Mock;

  beforeEach(() => {
    info.mockClear();
    error.mockClear();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  afterAll(() => {
    fft.cleanup();
  });

  it('writes the same documents as the legacy path after each of 40 events', async () => {
    const sessions = seedSessions(42);
    const legacyUid = uniqueUser('legacy');
    const incrementalUid = uniqueUser('incremental');
    await seedUser(legacyUid, 2, sessions);
    await seedUser(incrementalUid, 2, sessions);

    const scenario = new Scenario(7, sessions);
    await runEvents(scenario, 40, [
      { uid: legacyUid, trigger: legacy },
      { uid: incrementalUid, trigger: incremental },
    ], async index => {
      const expected = await publicDocs(legacyUid, 2);
      expect(expected.every(d => d !== null)).toBe(true);
      expect({ index, docs: await publicDocs(incrementalUid, 2) }).toEqual({ index, docs: expected });
    });

    const reads = eventLogs(info, incrementalUid).map(l => l.reads);
    expect(reads.length).toBeGreaterThanOrEqual(40);
    expect(Math.max(...reads.slice(1))).toBeLessThanOrEqual(6);
  }, 180000);

  it('changes nothing when an event is delivered twice', async () => {
    const uid = uniqueUser('twice');
    await seedUser(uid, 1, seedSessions(1));
    await sessionEvent(incremental.session, uid, 's1', { courseId: 'c0', seconds: 600, startUtc: Timestamp.now() });

    const { change, timestamp } = await sessionEvent(
      incremental.session, uid, 's1', { courseId: 'c0', seconds: 900, startUtc: Timestamp.now() });
    const paths = [...aggregatePaths(uid, 1), `users/${uid}/aggState/v1`];
    const before = await updateTimes(paths);
    await incremental.session(change, { params: { userId: uid, sessionId: 's1' }, timestamp });

    expect(await updateTimes(paths)).toEqual(before);
    expect(eventLogs(info, uid).pop()?.wrote).toBe(false);
  });

  it('ignores an older event delivered after a newer one', async () => {
    const uid = uniqueUser('order');
    await seedUser(uid, 1, {});
    const start = Timestamp.now();
    await sessionEvent(incremental.session, uid, 'seed', { courseId: 'c0', seconds: 60, startUtc: start });

    const ref = db.doc(`users/${uid}/sessions/s1`);
    const older = await writeDoc(ref, { courseId: 'c0', seconds: 100, startUtc: start });
    const olderTime = nextTimestamp();
    const newer = await writeDoc(ref, { courseId: 'c0', seconds: 200, startUtc: start });
    const newerTime = nextTimestamp();
    await incremental.session(newer, { params: { userId: uid, sessionId: 's1' }, timestamp: newerTime });

    const paths = [...aggregatePaths(uid, 1), `users/${uid}/aggState/v1`];
    const before = await updateTimes(paths);
    await incremental.session(older, { params: { userId: uid, sessionId: 's1' }, timestamp: olderTime });

    expect(await updateTimes(paths)).toEqual(before);
    const stats = await db.doc(`users/${uid}/aggregates/statistics`).get();
    expect(stats.data()?.totals.today).toBe(260);
  });

  it('writes nothing for a notes-only edit', async () => {
    const uid = uniqueUser('notes');
    await seedUser(uid, 2, seedSessions(3));
    const session = { courseId: 'c1', seconds: 300, startUtc: Timestamp.now() };
    await sessionEvent(incremental.session, uid, 's1', session);

    const paths = [...aggregatePaths(uid, 2), `users/${uid}/aggState/v1`];
    const before = await updateTimes(paths);
    await sessionEvent(incremental.session, uid, 's1', { ...session, notes: 'chapter 2', updatedAt: Timestamp.now() });

    expect(await updateTimes(paths)).toEqual(before);
    expect(eventLogs(info, uid).pop()?.wrote).toBe(false);
  });

  it('writes the aggregate for a newly joined group on the next event', async () => {
    const uid = uniqueUser('join');
    await seedUser(uid, 1, seedSessions(4));
    const session = { courseId: 'c1', seconds: 300, startUtc: Timestamp.now() };
    await sessionEvent(incremental.session, uid, 's1', session);
    await db.doc(`users/${uid}/groupMemberships/${uid}-g2`).set({ role: 'member' });

    await sessionEvent(incremental.session, uid, 's1', { ...session, notes: 'joined' });

    const docs = await publicDocs(uid, 2);
    expect(docs[2]).not.toBeNull();
    expect(docs[2]).toEqual(docs[0]);
  });

  it('rebuilds after a timezone change and matches the legacy result', async () => {
    const sessions = seedSessions(5);
    const legacyUid = uniqueUser('tz-legacy');
    const incrementalUid = uniqueUser('tz-incremental');
    await seedUser(legacyUid, 1, sessions);
    await seedUser(incrementalUid, 1, sessions);
    const users = [
      { uid: legacyUid, trigger: legacy },
      { uid: incrementalUid, trigger: incremental },
    ];
    const session = { courseId: 'c2', seconds: 1200, startUtc: Timestamp.fromMillis(Date.now() - 3 * 3600 * 1000) };
    for (const { uid, trigger } of users) await sessionEvent(trigger.session, uid, 'tz1', session);

    for (const { uid, trigger } of users) {
      await db.doc(`users/${uid}`).update({ timezoneOffsetMinutes: -420 });
      await sessionEvent(trigger.session, uid, 'tz1', { ...session, notes: 'moved' });
    }

    expect(await publicDocs(incrementalUid, 1)).toEqual(await publicDocs(legacyUid, 1));
    expect((await db.doc(`users/${incrementalUid}/aggState/v1`).get()).data()?.tz).toBe(-420);
  });

  it('reads at most 5 documents per event after the first', async () => {
    const uid = uniqueUser('reads');
    await seedUser(uid, 1, seedSessions(6));
    await sessionEvent(incremental.session, uid, 's1', { courseId: 'c0', seconds: 300, startUtc: Timestamp.now() });
    await sessionEvent(incremental.session, uid, 's1', { courseId: 'c0', seconds: 400, startUtc: Timestamp.now() });
    await sessionEvent(incremental.session, uid, 's2', null);

    const reads = eventLogs(info, uid).map(l => l.reads);
    expect(reads[0]).toBeGreaterThan(50);
    expect(reads.slice(1)).toEqual([5, 5]);
  });

  it('logs a shadow mismatch only when the derived payload differs', async () => {
    const wrongUid = uniqueUser('shadow-wrong');
    await seedUser(wrongUid, 1, seedSessions(8));
    const wrong = triggers({
      mode: 'off',
      shadowPercent: 100,
      derive: input => ({ ...derivePayload(input), name: 'wrong' }),
    });
    await sessionEvent(wrong.session, wrongUid, 's1', { courseId: 'c0', seconds: 300, startUtc: Timestamp.now() });
    expect(error).toHaveBeenCalledWith('aggregate_shadow_mismatch', { uid: wrongUid, sessionId: 's1', keys: ['name'] });

    error.mockClear();
    const sessions = seedSessions(9);
    const uid = uniqueUser('shadow');
    await seedUser(uid, 2, sessions);
    const shadowed = triggers({ mode: 'off', shadowPercent: 100 });
    await runEvents(new Scenario(11, sessions), 40, [{ uid, trigger: shadowed }], async () => undefined);

    expect(eventLogs(info, uid).length).toBeGreaterThanOrEqual(40);
    expect(error).not.toHaveBeenCalled();
  }, 180000);
});
