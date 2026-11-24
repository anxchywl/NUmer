import * as functions from 'firebase-functions/v1';
import type { LocalizedText } from './types';

const languages = ['en', 'ru', 'kk'] as const;

function invalid(name: string) {
  return new functions.https.HttpsError('invalid-argument', `${name} is invalid.`);
}

export function parseLocalized(value: unknown, name: string, maxLength: number): LocalizedText {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw invalid(name);
  const input = value as Record<string, unknown>;
  if (!Object.keys(input).every((key) => (languages as readonly string[]).includes(key))) {
    throw invalid(name);
  }
  const result: LocalizedText = { en: '' };
  for (const language of languages) {
    const raw = input[language];
    if (raw === undefined && language !== 'en') continue;
    const text = typeof raw === 'string' ? raw.trim() : '';
    if (text === '' || text.length > maxLength) throw invalid(name);
    result[language] = text;
  }
  return result;
}

// campus local time is utc+05:00 all year
export function eventStartsAt(date: string, time: string): number {
  return Date.parse(`${date}T${time}:00+05:00`);
}
