import type { Timestamp } from 'firebase-admin/firestore';

export type LocalizedText = { en: string; ru?: string; kk?: string };

export type FeedItem = {
  id: string;
  kind: 'announcement' | 'event';
  title: LocalizedText;
  body?: LocalizedText;
  startsAt?: Timestamp;
  place?: string;
  publishedAt: Timestamp;
  pinned: boolean;
  link?: string;
};

export type EventSourceItem = {
  token: string;
  title: string;
  date: string;
  time: string;
  location: string;
  is_ended: boolean;
};
