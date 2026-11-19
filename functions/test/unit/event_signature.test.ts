import { Timestamp } from 'firebase-admin/firestore';
import { loadTargets, secretName } from '../../src/account/event_delivery';
import { nextAttemptAt, serializeEvent, signEvent } from '../../src/account/event_signature';

// the same vector is pinned in backend/numer_identity/tests/test_account_events.py
const secret = 'test-account-event-secret';
const timestamp = 1767225600;
const body =
  '{"id":"deleted_user-1","type":"account.deleted","issuer":"https://securetoken.google.com/demo-numer","subject":"user-1","occurredAt":"2026-01-01T00:00:00.000Z"}';
const header = 't=1767225600,v1=877c5684343268c547921c79e56c3c4e5c6e1e48a2e73e12c5f61614ab08b5db';

describe('account event signature', () => {
  it('signs the timestamp and the raw body', () => {
    expect(signEvent(secret, timestamp, body)).toBe(header);
  });

  it('serializes the event into the signed body', () => {
    const serialized = serializeEvent('deleted_user-1', {
      subject: 'user-1',
      occurredAt: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
      issuer: 'https://securetoken.google.com/demo-numer',
      type: 'account.deleted',
    });

    expect(serialized).toBe(body);
  });

  it.each([
    [1, 15],
    [2, 30],
    [3, 60],
    [4, 120],
    [5, 240],
    [6, 360],
    [20, 360],
  ])('waits after attempt %i for %i minutes', (attempts, minutes) => {
    const now = new Date('2026-01-01T00:00:00Z');

    expect(nextAttemptAt(attempts, now).getTime() - now.getTime()).toBe(minutes * 60 * 1000);
  });
});

describe('account event targets', () => {
  const strict = { allowLoopbackHttp: false };
  const loopback = { allowLoopbackHttp: true };
  const one = (module: string, url: string) => JSON.stringify([{ module, url }]);

  it.each([undefined, '', '[]'])('has no targets for %p', (raw) => {
    expect(loadTargets(raw, strict)).toEqual([]);
  });

  it('accepts https', () => {
    expect(loadTargets(one('muto', 'https://muto.test/hook'), strict)).toEqual([
      { module: 'muto', url: 'https://muto.test/hook' },
    ]);
  });

  it.each(['http://muto.test/hook', 'http://127.0.0.1:9000/hook', 'ftp://muto.test'])('rejects %s', (url) => {
    expect(() => loadTargets(one('muto', url), strict)).toThrow('must use https');
  });

  it.each(['http://127.0.0.1:9000/hook', 'http://localhost:9000/hook'])('accepts %s with the option', (url) => {
    expect(loadTargets(one('clavis', url), loopback)).toHaveLength(1);
  });

  it('rejects plain http to another host even with the option', () => {
    expect(() => loadTargets(one('muto', 'http://muto.test'), loopback)).toThrow('must use https');
  });

  it('rejects a module outside the three', () => {
    expect(() => loadTargets(one('gradus', 'https://gradus.test'), strict)).toThrow('unknown');
  });

  it('rejects a duplicate module', () => {
    const entry = { module: 'events', url: 'https://events.test' };

    expect(() => loadTargets(JSON.stringify([entry, entry]), strict)).toThrow('duplicate');
  });

  it('rejects a value that is not a list', () => {
    expect(() => loadTargets('{}', strict)).toThrow('JSON array');
  });

  it('names one secret per module', () => {
    expect(secretName('clavis')).toBe('ACCOUNT_EVENTS_SECRET_CLAVIS');
  });
});
