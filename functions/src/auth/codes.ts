import * as crypto from 'crypto';

export type CodePurpose = 'verify' | 'reset';

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const maxEmailLength = 254;

export function generateCode(randomInt: (min: number, max: number) => number = crypto.randomInt): string {
  return String(randomInt(0, 1_000_000)).padStart(6, '0');
}

export function newCodeId(): string {
  return crypto.randomBytes(16).toString('hex');
}

function hmacHex(secret: string, parts: string[]): string {
  return crypto.createHmac('sha256', secret).update(JSON.stringify(parts)).digest('hex');
}

export function hashCode(secret: string, purpose: CodePurpose, subject: string, code: string, codeId: string): string {
  return hmacHex(secret, [purpose, subject, code, codeId]);
}

export function generateTicket(): string {
  return crypto.randomBytes(32).toString('base64url');
}

export function hashTicket(secret: string, docId: string, ticket: string): string {
  return hmacHex(secret, ['ticket', docId, ticket]);
}

export function safeEqualHex(a: string, b: string): boolean {
  const left = Buffer.from(a, 'hex');
  const right = Buffer.from(b, 'hex');
  return a.length === b.length && left.length === right.length && crypto.timingSafeEqual(left, right);
}

export function sha256Hex(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function isValidEmail(email: string): boolean {
  return email.length <= maxEmailLength && emailPattern.test(email);
}

export function isSixDigits(value: unknown): value is string {
  return typeof value === 'string' && /^\d{6}$/.test(value);
}
