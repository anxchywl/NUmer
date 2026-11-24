import * as admin from 'firebase-admin';
import type {
  DocumentData,
  Firestore,
  QueryDocumentSnapshot,
  Timestamp,
  Transaction,
} from 'firebase-admin/firestore';
import { eventStartsAt } from './localized';
import type { EventSourceItem, FeedItem } from './types';

const maxItems = 30;
const maxPinned = 2;
const maxAnnouncements = 100;
const maxSeen = 300;
const maxFeedBytes = 96 * 1024;
const maxEventText = 100;
const eventToken = /^[A-Za-z0-9_-]{1,64}$/;
const fetchTimeoutMs = 10_000;
const eventFields = ['token', 'title', 'date', 'time', 'location'] as const;

type SeenEvent = { publishedAt: Timestamp; startsAt: Timestamp };
type EventState = { fetchedAt: number; seen: Record<string, SeenEvent> };

export type ComposeDeps = {
  db: Firestore;
  now: () => number;
  eventsUrl: string | undefined;
  fetchEvents: (url: string) => Promise<EventSourceItem[]>;
};

function toEventSourceItem(raw: unknown): EventSourceItem {
  const item = (raw ?? {}) as Record<string, unknown>;
  if (!eventFields.every((field) => typeof item[field] === 'string') || typeof item.is_ended !== 'boolean') {
    throw new Error('events source returned an invalid item');
  }
  const { token, title, date, time, location, is_ended } = item as EventSourceItem;
  return { token, title, date, time, location, is_ended };
}

export async function fetchEventsOverHttp(url: string): Promise<EventSourceItem[]> {
  const response = await fetch(`${url}?sort=time_asc&relevance=active&limit=${maxItems}`, {
    signal: AbortSignal.timeout(fetchTimeoutMs),
  });
  if (!response.ok) throw new Error(`events source answered ${response.status}`);
  const body: unknown = await response.json();
  if (!Array.isArray(body)) throw new Error('events source returned no list');
  return body.map(toEventSourceItem);
}

function announcementItem(doc: QueryDocumentSnapshot<DocumentData>): FeedItem {
  const { title, body, link, publishedAt, pinned } = doc.data();
  return {
    id: doc.id,
    kind: 'announcement',
    title,
    ...(body && { body }),
    ...(link && { link }),
    publishedAt,
    pinned: pinned === true,
  };
}

async function announcementItems(tx: Transaction, db: Firestore, now: number): Promise<FeedItem[]> {
  const query = db.collection('announcements').orderBy('publishedAt', 'desc').limit(maxAnnouncements);
  const snap = await tx.get(query);
  return snap.docs
    .filter((doc) => {
      const { retracted, expiresAt } = doc.data();
      return retracted !== true && (!expiresAt || expiresAt.toMillis() > now);
    })
    .map(announcementItem);
}

// null means the source failed, so the previous event items stay
async function sourceEvents(deps: ComposeDeps): Promise<EventSourceItem[] | null> {
  if (!deps.eventsUrl) return [];
  try {
    return await deps.fetchEvents(deps.eventsUrl);
  } catch {
    return null;
  }
}

function fitsFeed({ token, title, location }: EventSourceItem): boolean {
  return eventToken.test(token) && title.length <= maxEventText && location.length <= maxEventText;
}

function eventItems(events: EventSourceItem[], seen: EventState['seen'], now: number): FeedItem[] {
  return events.filter(fitsFeed).flatMap((event): FeedItem[] => {
    const startsAt = eventStartsAt(event.date, event.time);
    if (event.is_ended || Number.isNaN(startsAt) || startsAt < now) return [];
    const id = `event_${event.token}`;
    return [{
      id,
      kind: 'event',
      title: { en: event.title },
      startsAt: admin.firestore.Timestamp.fromMillis(startsAt),
      place: event.location,
      publishedAt: seen[id]?.publishedAt ?? admin.firestore.Timestamp.fromMillis(now),
      pinned: false,
    }];
  });
}

// an event cut from the feed or missing from one response must not return as new
function remember(seen: EventState['seen'], events: FeedItem[], now: number): EventState['seen'] {
  const next = { ...seen };
  for (const { id, publishedAt, startsAt } of events) next[id] = { publishedAt, startsAt: startsAt! };
  const upcoming = Object.entries(next)
    .filter(([, event]) => event.startsAt.toMillis() >= now)
    .sort(([, a], [, b]) => a.startsAt.toMillis() - b.startsAt.toMillis());
  return Object.fromEntries(upcoming.slice(0, maxSeen));
}

function rank(items: FeedItem[]): FeedItem[] {
  const newest = [...items].sort((a, b) => b.publishedAt.toMillis() - a.publishedAt.toMillis());
  const top = newest.filter((item) => item.pinned).slice(0, maxPinned);
  const rest = newest.filter((item) => !top.includes(item)).map((item) => ({ ...item, pinned: false }));
  return [...top, ...rest].slice(0, maxItems);
}

// the pinned items lead the list and are far below the limit, so only the oldest others go
function withinBudget(items: FeedItem[]): FeedItem[] {
  const kept = [...items];
  while (Buffer.byteLength(JSON.stringify(kept)) > maxFeedBytes) kept.pop();
  return kept;
}

async function writeFeed(
  tx: Transaction,
  db: Firestore,
  now: number,
  events: EventSourceItem[] | null,
  fetchedAt: number,
): Promise<FeedItem[]> {
  const feed = db.collection('feed').doc('current');
  const state = db.collection('feedState').doc('events');
  const stored = (await tx.get(state)).data() as EventState | undefined;
  const current = (await tx.get(feed)).data();
  const announcements = await announcementItems(tx, db, now);

  // a run that fetched later has already written, so this run's events are old
  const outdated = (stored?.fetchedAt ?? 0) > fetchedAt;
  const fresh = !outdated && events ? eventItems(events, stored?.seen ?? {}, now) : null;
  const previous: FeedItem[] = current?.items ?? [];
  const upcoming =
    fresh ?? previous.filter((item) => item.kind === 'event' && item.startsAt!.toMillis() >= now);

  const items = withinBudget(rank([...announcements, ...upcoming]));
  tx.set(feed, {
    items,
    composedAt: admin.firestore.FieldValue.serverTimestamp(),
    eventsOk: outdated ? current?.eventsOk ?? true : events !== null,
  });
  if (fresh) tx.set(state, { fetchedAt, seen: remember(stored?.seen ?? {}, fresh, now) });
  return items;
}

export async function composeFeed(deps: ComposeDeps): Promise<FeedItem[]> {
  const fetchedAt = deps.now();
  // the slow fetch stays outside the transaction
  const events = await sourceEvents(deps);
  return deps.db.runTransaction((tx) => writeFeed(tx, deps.db, deps.now(), events, fetchedAt));
}
