import { Contribution, dayKeyOf, derivePayload, UserFields } from '../../src/aggregates/derive';

const now = new Date('2026-11-25T10:00:00Z');
const user: UserFields = { profileName: 'Ann', avatarIndex: 2, avatarColorValue: 7, timezoneOffsetMinutes: 0 };

function contribution(sessionId: string, day: string, seconds: number, courseId = 'math'): Contribution {
  return { sessionId, courseId, day, seconds };
}

function derive(contributions: Contribution[], hidden: string[] = [], fields: UserFields = user) {
  return derivePayload({ userId: 'u1', user: fields, hiddenCourseIds: new Set(hidden), contributions, now });
}

describe('derivePayload', () => {
  it('sums today, the week since monday and the calendar month', () => {
    const payload = derive([
      contribution('s1', '2026-11-25', 100),
      contribution('s2', '2026-11-23', 200),
      contribution('s3', '2026-11-10', 400),
      contribution('s4', '2026-10-30', 800),
    ]);
    expect(payload.totals).toEqual({ today: 100, last7Days: 300, lastMonth: 700 });
  });

  it('excludes hidden courses everywhere', () => {
    const payload = derive([
      contribution('s1', '2026-11-25', 100),
      contribution('s2', '2026-11-25', 1600, 'art'),
    ], ['art']);
    expect(payload.totals).toEqual({ today: 100, last7Days: 100, lastMonth: 100 });
    expect(payload.dailyBreakdown.find(e => e.date === '2026-11-25')?.seconds).toBe(100);
  });

  it('lists 35 zero filled days ending today', () => {
    const payload = derive([contribution('s1', '2026-11-01', 50), contribution('s2', '2026-11-01', 25)]);
    expect(payload.dailyBreakdown).toHaveLength(35);
    expect(payload.dailyBreakdown[0].date).toBe('2026-10-22');
    expect(payload.dailyBreakdown[34].date).toBe('2026-11-25');
    expect(payload.dailyBreakdown.filter(e => e.seconds > 0)).toEqual([{ date: '2026-11-01', seconds: 75 }]);
  });

  it('reports the latest visible study day', () => {
    expect(derive([]).lastStudyDate).toBe('');
    const payload = derive([
      contribution('s1', '2026-11-20', 10),
      contribution('s2', '2026-11-24', 10, 'art'),
      contribution('s3', '2026-11-12', 10),
    ], ['art']);
    expect(payload.lastStudyDate).toBe('2026-11-20');
  });

  it('moves a session across midnight with the timezone offset', () => {
    const startMs = Date.parse('2026-11-24T22:00:00Z');
    const east = { ...user, timezoneOffsetMinutes: 180 };
    const local = derive([contribution('s1', dayKeyOf(startMs, 180), 60)], [], east);
    expect(local.totals.today).toBe(60);
    expect(local.lastStudyDate).toBe('2026-11-25');
    const utc = derive([contribution('s1', dayKeyOf(startMs, 0), 60)]);
    expect(utc.totals.today).toBe(0);
    expect(utc.lastStudyDate).toBe('2026-11-24');
  });

  it('keeps the legacy profile defaults', () => {
    const payload = derive([], [], { timezoneOffsetMinutes: '300' });
    expect(payload).toMatchObject({
      userId: 'u1',
      name: '',
      avatarIndex: null,
      avatarColorValue: 0xFF6366F1,
      timezoneOffsetMinutes: 0,
    });
  });
});
