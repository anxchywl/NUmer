import type * as functions from 'firebase-functions/v1';
import { parseEnforced, requireAppCheck } from '../../src/shared/app_check';

const unverified = {} as functions.https.CallableContext;
const verified = { app: { appId: 'app' } } as functions.https.CallableContext;

describe('parseEnforced', () => {
  it.each([undefined, '', ' , '])('is empty for %p', (value) => {
    expect(parseEnforced(value).size).toBe(0);
  });

  it('splits on commas and trims names', () => {
    expect([...parseEnforced(' sendNudge, joinPrivateGroup ,')]).toEqual([
      'sendNudge',
      'joinPrivateGroup',
    ]);
  });

  it('keeps the wildcard', () => {
    expect([...parseEnforced('*')]).toEqual(['*']);
  });
});

describe('requireAppCheck', () => {
  const rejection = expect.objectContaining({
    code: 'failed-precondition',
    message: 'This request could not be verified.',
    details: { reason: 'app-check' },
  });

  it('never throws when nothing is enforced', () => {
    expect(() => requireAppCheck(unverified, 'sendNudge', new Set())).not.toThrow();
  });

  it('rejects a listed callable without a token', () => {
    const enforced = new Set(['sendNudge']);
    expect(() => requireAppCheck(unverified, 'sendNudge', enforced)).toThrow(rejection);
  });

  it('accepts a listed callable with a token', () => {
    const enforced = new Set(['sendNudge']);
    expect(() => requireAppCheck(verified, 'sendNudge', enforced)).not.toThrow();
  });

  it('ignores a callable that is not listed', () => {
    const enforced = new Set(['sendNudge']);
    expect(() => requireAppCheck(unverified, 'joinPrivateGroup', enforced)).not.toThrow();
  });

  it('covers every name with the wildcard', () => {
    const enforced = new Set(['*']);
    expect(() => requireAppCheck(unverified, 'sendNudge', enforced)).toThrow(rejection);
    expect(() => requireAppCheck(unverified, 'joinPrivateGroup', enforced)).toThrow(rejection);
  });
});
