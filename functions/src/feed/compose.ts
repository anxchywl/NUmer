import * as admin from 'firebase-admin';
import type { DocumentData, Firestore, QueryDocumentSnapshot } from 'firebase-admin/firestore';
import { eventStartsAt } from './localized';
import type { EventSourceItem, FeedItem } from './types';

const maxItems = 30;
const maxPinned = 2;
const maxAnnouncements = 100;
const fetchTimeoutMs = 10_000;
const eventFields = ['token', 'title', 'date', 'time', 'location'] as const;

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

async function announcementItems(db: Firestore, now: number): Promise<FeedItem[]> {
  const snap = await db
    .collection('announcements')
    .orderBy('publishedAt', 'desc')
    .limit(maxAnnouncements)
    .get();
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

function eventItems(events: EventSourceItem[], previous: FeedItem[], now: number): FeedItem[] {
  const firstSeen = new Map(previous.map((item) => [item.id, item.publishedAt]));
  return events.flatMap((event): FeedItem[] => {
    const startsAt = eventStartsAt(event.date, event.time);
    if (event.is_ended || Number.isNaN(startsAt) || startsAt < now) return [];
    const id = `event_${event.token}`;
    return [{
      id,
      kind: 'event',
      title: { en: event.title },
      startsAt: admin.firestore.Timestamp.fromMillis(startsAt),
      place: event.location,
      publishedAt: firstSeen.get(id) ?? admin.firestore.Timestamp.fromMillis(now),
      pinned: false,
    }];
  });
}

function rank(items: FeedItem[]): FeedItem[] {
  const newest = [...items].sort((a, b) => b.publishedAt.toMillis() - a.publishedAt.toMillis());
  const top = newest.filter((item) => item.pinned).slice(0, maxPinned);
  const rest = newest.filter((item) => !top.includes(item)).map((item) => ({ ...item, pinned: false }));
  return [...top, ...rest].slice(0, maxItems);
}

export async function composeFeed(deps: ComposeDeps): Promise<FeedItem[]> {
  const feed = deps.db.collection('feed').doc('current');
  // the slow fetch goes first so a concurrent run cannot overwrite newer announcements with old ones
  const events = await sourceEvents(deps);
  const now = deps.now();
  const [current, announcements] = await Promise.all([feed.get(), announcementItems(deps.db, now)]);
  const previous: FeedItem[] = current.data()?.items ?? [];
  const upcoming = events
    ? eventItems(events, previous, now)
    : previous.filter((item) => item.kind === 'event' && item.startsAt!.toMillis() >= now);

  const items = rank([...announcements, ...upcoming]);
  await feed.set({
    items,
    composedAt: admin.firestore.FieldValue.serverTimestamp(),
    eventsOk: events !== null,
  });
  return items;
}
