import { Timestamp } from 'firebase-admin/firestore';
import { applyToLedger, contributionOf, Ledger, payloadHash, pruneLedger } from '../../src/aggregates/ledger';

const windowStart = '2026-10-22';
const session = {
  courseId: 'math',
  seconds: 600,
  startUtc: Timestamp.fromDate(new Date('2026-11-20T08:00:00Z')),
};

function apply(ledger: Ledger, data: Record<string, unknown> | undefined, t: number) {
  return applyToLedger(ledger, 's1', contributionOf(data, 0, windowStart), t);
}

const created = apply({}, session, 1000).ledger;

describe('contributionOf', () => {
  it('ignores sessions that do not count', () => {
    expect(contributionOf(undefined, 0, windowStart)).toBeNull();
    expect(contributionOf({ ...session, deleted: true }, 0, windowStart)).toBeNull();
    expect(contributionOf({ ...session, seconds: 0 }, 0, windowStart)).toBeNull();
    expect(contributionOf({ ...session, startUtc: undefined }, 0, windowStart)).toBeNull();
    const old = { ...session, startUtc: Timestamp.fromDate(new Date('2026-10-21T23:59:59Z')) };
    expect(contributionOf(old, 0, windowStart)).toBeNull();
  });

  it('uses the local day', () => {
    const late = { ...session, startUtc: Timestamp.fromDate(new Date('2026-11-20T22:00:00Z')) };
    expect(contributionOf(late, 180, windowStart)).toEqual({ c: 'math', d: '2026-11-21', s: 600 });
  });
});

describe('applyToLedger', () => {
  it('adds an entry on create', () => {
    expect(created).toEqual({ s1: { c: 'math', d: '2026-11-20', s: 600, t: 1000 } });
  });

  it('replaces the entry when seconds change', () => {
    const result = apply(created, { ...session, seconds: 900 }, 2000);
    expect(result.changed).toBe(true);
    expect(result.ledger.s1).toEqual({ c: 'math', d: '2026-11-20', s: 900, t: 2000 });
  });

  it('replaces the entry when the start moves to another day', () => {
    const moved = { ...session, startUtc: Timestamp.fromDate(new Date('2026-11-18T08:00:00Z')) };
    const result = apply(created, moved, 2000);
    expect(result.changed).toBe(true);
    expect(result.ledger.s1.d).toBe('2026-11-18');
  });

  it('replaces the entry when the course changes', () => {
    const result = apply(created, { ...session, courseId: 'art' }, 2000);
    expect(result.changed).toBe(true);
    expect(result.ledger.s1.c).toBe('art');
  });

  it('removes the entry on a soft delete or zero seconds', () => {
    for (const data of [{ ...session, deleted: true }, { ...session, seconds: 0 }]) {
      const result = apply(created, data, 2000);
      expect(result.changed).toBe(true);
      expect(result.ledger).toEqual({});
    }
  });

  it('adds the entry again on un-delete', () => {
    const removed = apply(created, { ...session, deleted: true }, 2000).ledger;
    const result = apply(removed, { ...session, deleted: false }, 3000);
    expect(result.changed).toBe(true);
    expect(result.ledger.s1).toEqual({ c: 'math', d: '2026-11-20', s: 600, t: 3000 });
  });

  it('removes the entry on a hard delete', () => {
    const result = apply(created, undefined, 2000);
    expect(result.changed).toBe(true);
    expect(result.ledger).toEqual({});
  });

  it('reports no change for a notes or updatedAt edit', () => {
    const result = apply(created, { ...session, notes: 'read ch 3', updatedAt: Timestamp.now() }, 2000);
    expect(result.changed).toBe(false);
    expect(result.ledger).toBe(created);
  });

  it('reports no change when the same event arrives twice', () => {
    const first = apply(created, { ...session, seconds: 900 }, 2000);
    const second = apply(first.ledger, { ...session, seconds: 900 }, 2000);
    expect(second.changed).toBe(false);
    expect(second.ledger).toEqual(first.ledger);
  });

  it('ignores an older event after a newer one', () => {
    const newer = apply(created, { ...session, seconds: 900 }, 3000).ledger;
    const result = apply(newer, { ...session, seconds: 300 }, 2000);
    expect(result.changed).toBe(false);
    expect(result.ledger.s1.s).toBe(900);
  });
});

describe('pruneLedger', () => {
  it('drops entries before the window', () => {
    const ledger: Ledger = {
      a: { c: 'math', d: '2026-10-21', s: 1, t: 1 },
      b: { c: 'math', d: '2026-10-22', s: 1, t: 1 },
    };
    expect(Object.keys(pruneLedger(ledger, windowStart))).toEqual(['b']);
  });
});

describe('payloadHash', () => {
  it('does not depend on key order', () => {
    expect(payloadHash({ a: 1, b: { c: [1, 2], d: null } })).toBe(payloadHash({ b: { d: null, c: [1, 2] }, a: 1 }));
    expect(payloadHash({ a: 1 })).not.toBe(payloadHash({ a: 2 }));
  });
});

describe('state size', () => {
  it('stays under 100 KB for 1000 entries with client style ids', () => {
    const ledger: Ledger = {};
    for (let i = 0; i < 1000; i++) {
      const courseId = `${1700000000000 + i}`;
      ledger[`${1764000000000000 + i * 1000000}_${courseId}`] = { c: courseId, d: '2026-11-20', s: 3600, t: 1764000000000 };
    }
    const state = { v: 1, tz: 300, hidden: ['1700000000001'], ledger, rebuiltAt: 1764000000000, payloadHash: 'f'.repeat(64) };
    expect(Buffer.byteLength(JSON.stringify(state))).toBeLessThan(100 * 1024);
  });
});
