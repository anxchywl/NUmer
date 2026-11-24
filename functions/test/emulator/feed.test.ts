import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import { auth, db } from '../../src/shared/admin';
import { publishAnnouncement, retractAnnouncement } from '../../src/feed/announcements';
import { composeFeed, ComposeDeps } from '../../src/feed/compose';
import type { EventSourceItem, FeedItem } from '../../src/feed/types';

const testEnv = functionsTest();
const publish = testEnv.wrap(publishAnnouncement);
const retract = testEnv.wrap(retractAnnouncement);

const { Timestamp } = admin.firestore;
const now = Date.UTC(2026, 11, 1, 12, 0);
const eventsUrl = 'https://events.test/api/events';
const feed = db.collection('feed').doc('current');
const announcements = db.collection('announcements');

function as(uid: string, roles: string[]) {
  return { auth: { uid, token: { numer_roles: roles } as any } };
}

const editor = as('feed-editor', ['numer:editor']);

function deps(events: EventSourceItem[] = [], overrides: Partial<ComposeDeps> = {}): ComposeDeps {
  return { db, now: () => now, eventsUrl, fetchEvents: async () => events, ...overrides };
}

function event(token: string, overrides: Partial<EventSourceItem> = {}): EventSourceItem {
  return {
    token,
    title: `Event ${token}`,
    date: '2026-12-12',
    time: '18:00',
    location: 'Atrium',
    is_ended: false,
    ...overrides,
  };
}

// a higher age means an older announcement
async function seed(id: string, age: number, data: Record<string, unknown> = {}) {
  await announcements.doc(id).set({
    title: { en: id },
    pinned: false,
    retracted: false,
    publishedAt: Timestamp.fromMillis(now - age * 60_000),
    ...data,
  });
}

const ids = (items: FeedItem[]) => items.map((item) => item.id);

beforeEach(async () => {
  await db.recursiveDelete(announcements);
  await feed.delete();
});

describe('composeFeed', () => {
  it('puts the newest two pinned announcements first', async () => {
    await seed('plain1', 1);
    await seed('pin1', 2, { pinned: true });
    await seed('plain2', 3);
    await seed('pin2', 4, { pinned: true });
    await seed('plain3', 5);
    await seed('pin3', 6, { pinned: true });
    await seed('plain4', 7);
    await seed('plain5', 8);

    const items = await composeFeed(deps());

    expect(ids(items)).toEqual(['pin1', 'pin2', 'plain1', 'plain2', 'plain3', 'pin3', 'plain4', 'plain5']);
    expect(items.map((item) => item.pinned)).toEqual([true, true, false, false, false, false, false, false]);
    const stored = (await feed.get()).data()!;
    expect(ids(stored.items)).toEqual(ids(items));
    expect(stored.composedAt).toBeInstanceOf(Timestamp);
  });

  it('keeps 30 items', async () => {
    for (let i = 0; i < 40; i++) await seed(`a${i}`, i);

    const items = await composeFeed(deps());

    expect(items).toHaveLength(30);
    expect(ids(items)).toContain('a29');
    expect(ids(items)).not.toContain('a30');
  });

  it('drops expired and retracted announcements', async () => {
    await seed('live', 1, { expiresAt: Timestamp.fromMillis(now + 60_000), link: 'https://events.test/a' });
    await seed('expired', 2, { expiresAt: Timestamp.fromMillis(now - 1) });
    await seed('retracted', 3, { retracted: true });

    const items = await composeFeed(deps());

    expect(ids(items)).toEqual(['live']);
    expect(items[0]).toMatchObject({ kind: 'announcement', link: 'https://events.test/a' });
  });

  it('drops ended, past and unreadable events', async () => {
    const items = await composeFeed(
      deps([
        event('future'),
        event('ended', { is_ended: true }),
        event('past', { date: '2026-11-30' }),
        event('broken', { date: 'soon' }),
      ]),
    );

    expect(ids(items)).toEqual(['event_future']);
    expect((await feed.get()).data()!.items[0]).toEqual({
      id: 'event_future',
      kind: 'event',
      title: { en: 'Event future' },
      startsAt: Timestamp.fromMillis(Date.UTC(2026, 11, 12, 13, 0)),
      place: 'Atrium',
      publishedAt: Timestamp.fromMillis(now),
      pinned: false,
    });
  });

  it('keeps the first seen time of an event', async () => {
    await composeFeed(deps([event('old')]));

    const items = await composeFeed(deps([event('old'), event('new')], { now: () => now + 60_000 }));

    expect(ids(items)).toEqual(['event_new', 'event_old']);
    expect(items.map((item) => item.publishedAt.toMillis())).toEqual([now + 60_000, now]);
  });

  it('keeps previous events and refreshes announcements when the source fails', async () => {
    await composeFeed(deps([event('soon', { date: '2026-12-02' }), event('later')]));
    await seed('fresh', 0);

    const items = await composeFeed(
      deps([], {
        now: () => Date.UTC(2026, 11, 3),
        fetchEvents: async () => {
          throw new Error('unreachable');
        },
      }),
    );

    expect(ids(items).sort()).toEqual(['event_later', 'fresh']);
    expect((await feed.get()).data()!.eventsOk).toBe(false);
  });

  it('holds announcements only without an events url', async () => {
    await composeFeed(deps([event('before')]));
    await seed('only', 1);
    const fetchEvents = jest.fn();

    const items = await composeFeed(deps([], { eventsUrl: '', fetchEvents }));

    expect(ids(items)).toEqual(['only']);
    expect(fetchEvents).not.toHaveBeenCalled();
    expect((await feed.get()).data()!.eventsOk).toBe(true);
  });

  it('stays under 100 kb with the longest cyrillic texts', async () => {
    const text = (length: number) => ({ en: 'ж'.repeat(length), ru: 'ж'.repeat(length), kk: 'ж'.repeat(length) });
    for (let i = 0; i < 30; i++) {
      await seed(`${'a'.repeat(18)}${String(i).padStart(2, '0')}`, i, { title: text(100), body: text(400) });
    }

    const items = await composeFeed(deps());

    expect(items).toHaveLength(30);
    const bytes = Buffer.byteLength(JSON.stringify(items));
    process.stdout.write(`feed of 30 longest items: ${bytes} bytes\n`);
    expect(bytes).toBeLessThan(100 * 1024);
  });
});

describe('announcement callables', () => {
  const input = { title: { en: 'Hello' }, body: { en: 'World', ru: 'Мир' }, pinned: true };

  beforeAll(async () => {
    await auth.createUser({ uid: 'feed-editor' });
    await auth.setCustomUserClaims('feed-editor', { numer_roles: ['numer:editor'] });
    await auth.createUser({ uid: 'feed-demoted' });
  });

  afterAll(async () => {
    await auth.deleteUsers(['feed-editor', 'feed-demoted']);
    testEnv.cleanup();
  });

  describe.each([
    ['publishAnnouncement', publish, input],
    ['retractAnnouncement', retract, { id: 'target' }],
  ])('%s gate', (_, call, data) => {
    it('rejects everyone but a current editor', async () => {
      await seed('target', 1);

      await expect(call(data, {})).rejects.toMatchObject({ code: 'unauthenticated' });
      await expect(call(data, as('feed-editor', ['numer:admin']))).rejects.toMatchObject({
        code: 'permission-denied',
      });
      await expect(call(data, as('feed-demoted', ['numer:editor']))).rejects.toMatchObject({
        code: 'permission-denied',
      });
      expect((await announcements.get()).size).toBe(1);
      expect((await announcements.doc('target').get()).data()!.retracted).toBe(false);
    });
  });

  it('publishes an announcement', async () => {
    const expiresAt = Date.now() + 60_000;

    const { id } = await publish({ ...input, expiresAt, link: 'https://events.test/a' }, editor);

    const doc = (await announcements.doc(id).get()).data()!;
    expect(doc).toEqual({
      ...input,
      link: 'https://events.test/a',
      expiresAt: Timestamp.fromMillis(expiresAt),
      publishedAt: expect.any(Timestamp),
      authorUid: 'feed-editor',
      retracted: false,
    });
  });

  it('defaults to an unpinned announcement without optional fields', async () => {
    const { id } = await publish({ title: { en: 'Hello' } }, editor);

    const doc = (await announcements.doc(id).get()).data()!;
    expect(Object.keys(doc).sort()).toEqual(['authorUid', 'pinned', 'publishedAt', 'retracted', 'title']);
    expect(doc.pinned).toBe(false);
  });

  it.each([
    ['no data', null],
    ['no title', { pinned: true }],
    ['a long title', { title: { en: 'x'.repeat(101) } }],
    ['a long body', { ...input, body: { en: 'x'.repeat(401) } }],
    ['a pinned string', { ...input, pinned: 'yes' }],
    ['a past expiry', { ...input, expiresAt: Date.now() - 1000 }],
    ['a distant expiry', { ...input, expiresAt: Date.now() + 366 * 86_400_000 }],
    ['an expiry string', { ...input, expiresAt: '2027-01-01' }],
    ['an http link', { ...input, link: 'http://events.test/a' }],
    ['a link without a host', { ...input, link: 'https://' }],
    ['a long link', { ...input, link: `https://events.test/${'a'.repeat(500)}` }],
  ])('rejects %s', async (_, data) => {
    await expect(publish(data, editor)).rejects.toMatchObject({ code: 'invalid-argument' });
    expect((await announcements.get()).empty).toBe(true);
  });

  it('retracts an announcement', async () => {
    await seed('target', 1);

    await expect(retract({ id: 'target' }, editor)).resolves.toEqual({ id: 'target' });

    expect((await announcements.doc('target').get()).data()).toMatchObject({
      retracted: true,
      retractedBy: 'feed-editor',
      retractedAt: expect.any(Timestamp),
    });
  });

  it('answers not-found for an unknown id and rejects an invalid one', async () => {
    await expect(retract({ id: 'missing' }, editor)).rejects.toMatchObject({ code: 'not-found' });
    await expect(retract({ id: 'a/b' }, editor)).rejects.toMatchObject({ code: 'invalid-argument' });
  });
});
