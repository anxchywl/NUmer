import * as functions from 'firebase-functions/v1';
import { MailLocale, MailSender } from '../mail/types';
import { sha256Hex } from './codes';

export interface Deps {
  mail: MailSender;
  now: () => number;
}

const locales: MailLocale[] = ['en', 'ru', 'kk'];

export function fail(
  code: functions.https.FunctionsErrorCode,
  reason: string,
  extra: Record<string, number> = {},
): functions.https.HttpsError {
  return new functions.https.HttpsError(code, 'The request could not be completed.', { reason, ...extra });
}

export function rateLimited(retryAfterSeconds: number): functions.https.HttpsError {
  return fail('resource-exhausted', 'rate-limited', { retryAfterSeconds });
}

export function tryAgain(): functions.https.HttpsError {
  return new functions.https.HttpsError('internal', 'Try again.');
}

export function callableOptions(secrets: string[]) {
  return { enforceAppCheck: process.env.AUTH_ENFORCE_APPCHECK !== 'off', secrets };
}

export function authSecret(): string {
  const secret = process.env.AUTH_CODE_SECRET;
  if (!secret) {
    throw new Error('AUTH_CODE_SECRET is required');
  }
  return secret;
}

export function normalizeLocale(value: unknown): MailLocale {
  return locales.find((locale) => locale === value) ?? 'en';
}

export function clientIp(context: functions.https.CallableContext): string {
  return context.rawRequest?.ip || '';
}

export function ipHash(secret: string, ip: string): string {
  return sha256Hex(`${secret}:${ip}`).slice(0, 32);
}
