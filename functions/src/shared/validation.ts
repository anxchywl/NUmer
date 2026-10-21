import * as functions from 'firebase-functions/v1';

const idPattern = /^[A-Za-z0-9_-]{1,128}$/;

function invalid(name: string) {
  return new functions.https.HttpsError('invalid-argument', `${name} is invalid.`);
}

export function assertId(value: unknown, name: string): string {
  if (typeof value !== 'string' || !idPattern.test(value)) {
    throw invalid(name);
  }
  return value;
}

export function assertString(value: unknown, name: string, maxLength: number): string {
  if (typeof value !== 'string' || value.length === 0 || value.length > maxLength) {
    throw invalid(name);
  }
  return value;
}
