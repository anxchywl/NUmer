import * as functions from 'firebase-functions/v1';
import { parseLocalized } from './localized';
import type { LocalizedText } from './types';

const maxTitle = 100;
const maxBody = 400;
const maxLink = 500;
const maxLifetimeMs = 365 * 24 * 60 * 60 * 1000;

export type AnnouncementInput = {
  title: LocalizedText;
  body?: LocalizedText;
  pinned: boolean;
  expiresAt?: number;
  link?: string;
};

function invalid(name: string) {
  return new functions.https.HttpsError('invalid-argument', `${name} is invalid.`);
}

function parsePinned(value: unknown): boolean {
  if (value === undefined || value === null) return false;
  if (typeof value !== 'boolean') throw invalid('pinned');
  return value;
}

function parseExpiresAt(value: unknown, now: number): number {
  if (!Number.isInteger(value)) throw invalid('expiresAt');
  const millis = value as number;
  if (millis <= now || millis > now + maxLifetimeMs) throw invalid('expiresAt');
  return millis;
}

function parseLink(value: unknown): string {
  if (typeof value !== 'string' || value.length > maxLink || !/^https:\/\/[^\s/?#]\S*$/.test(value)) {
    throw invalid('link');
  }
  return value;
}

// shared with the owner script, so this module must not import shared/admin
export function parseAnnouncement(data: unknown, now: number): AnnouncementInput {
  const input = (data ?? {}) as Record<string, unknown>;
  const result: AnnouncementInput = {
    title: parseLocalized(input.title, 'title', maxTitle),
    pinned: parsePinned(input.pinned),
  };
  if (input.body != null) result.body = parseLocalized(input.body, 'body', maxBody);
  if (input.expiresAt != null) result.expiresAt = parseExpiresAt(input.expiresAt, now);
  if (input.link != null) result.link = parseLink(input.link);
  return result;
}
