import { DocumentData } from 'firebase-admin/firestore';

export interface UserFields {
  profileName?: unknown;
  avatarIndex?: unknown;
  avatarColorValue?: unknown;
  timezoneOffsetMinutes?: unknown;
}

export interface Contribution {
  sessionId: string;
  courseId: string;
  day: string;
  seconds: number;
}

export interface DeriveInput {
  userId: string;
  user: UserFields;
  hiddenCourseIds: ReadonlySet<string>;
  contributions: Contribution[];
  now: Date;
}

export interface AggregatePayload {
  userId: string;
  name: string;
  avatarIndex: unknown;
  avatarColorValue: unknown;
  timezoneOffsetMinutes: number;
  totals: { today: number; last7Days: number; lastMonth: number };
  dailyBreakdown: { date: string; seconds: number }[];
  lastStudyDate: string;
}

export function userFieldsOf(data: DocumentData | undefined): UserFields {
  const profile = data || {};
  return {
    profileName: profile.profileName,
    avatarIndex: profile.avatarIndex,
    avatarColorValue: profile.avatarColorValue,
    timezoneOffsetMinutes: profile.timezoneOffsetMinutes,
  };
}

export function timezoneOf(user: UserFields): number {
  return Number.isFinite(user.timezoneOffsetMinutes) ? Number(user.timezoneOffsetMinutes) : 0;
}

export function dayKeyOf(utcMs: number, timezoneOffsetMinutes: number): string {
  return new Date(utcMs + timezoneOffsetMinutes * 60 * 1000).toISOString().slice(0, 10);
}

export function localDays(timezoneOffsetMinutes: number, now: Date) {
  const offsetMs = timezoneOffsetMinutes * 60 * 1000;
  const shiftedNow = new Date(now.getTime() + offsetMs);

  const todayStartLocal = new Date(Date.UTC(
    shiftedNow.getUTCFullYear(),
    shiftedNow.getUTCMonth(),
    shiftedNow.getUTCDate(),
    0, 0, 0, 0
  ));

  const weekday = shiftedNow.getUTCDay();
  const daysFromMonday = (weekday + 6) % 7;
  const mondayStartLocal = new Date(Date.UTC(
    shiftedNow.getUTCFullYear(),
    shiftedNow.getUTCMonth(),
    shiftedNow.getUTCDate() - daysFromMonday,
    0, 0, 0, 0
  ));

  const monthStartLocal = new Date(Date.UTC(
    shiftedNow.getUTCFullYear(),
    shiftedNow.getUTCMonth(),
    1,
    0, 0, 0, 0
  ));

  const breakdownStartLocal = new Date(todayStartLocal.getTime() - 34 * 24 * 3600 * 1000);

  return {
    shiftedNow,
    breakdownStartLocal,
    breakdownQueryStart: new Date(breakdownStartLocal.getTime() - offsetMs),
    todayKey: todayStartLocal.toISOString().slice(0, 10),
    mondayKey: mondayStartLocal.toISOString().slice(0, 10),
    monthKey: monthStartLocal.toISOString().slice(0, 10),
    windowStartDay: breakdownStartLocal.toISOString().slice(0, 10),
  };
}

export function windowStartDay(timezoneOffsetMinutes: number, now: Date): string {
  return localDays(timezoneOffsetMinutes, now).windowStartDay;
}

export function derivePayload(input: DeriveInput): AggregatePayload {
  const { user } = input;
  const timezoneOffsetMinutes = timezoneOf(user);
  const days = localDays(timezoneOffsetMinutes, input.now);

  let totalToday = 0, total7 = 0, totalMonth = 0;
  const dailyMap = new Map<string, number>();
  let lastStudyDate = '';

  // a local day key compares like the legacy utc instant against the local period start
  for (const contribution of input.contributions) {
    if (input.hiddenCourseIds.has(contribution.courseId)) continue;
    const { day, seconds } = contribution;
    dailyMap.set(day, (dailyMap.get(day) || 0) + seconds);

    if (day > lastStudyDate) {
      lastStudyDate = day;
    }

    if (day >= days.monthKey) {
      totalMonth += seconds;
    }
    if (day >= days.mondayKey) {
      total7 += seconds;
    }
    if (day >= days.todayKey) {
      totalToday += seconds;
    }
  }

  const dailyBreakdown: { date: string; seconds: number }[] = [];
  for (let d = new Date(days.breakdownStartLocal); d <= days.shiftedNow; d.setDate(d.getDate() + 1)) {
    const key = d.toISOString().slice(0, 10);
    dailyBreakdown.push({ date: key, seconds: dailyMap.get(key) || 0 });
  }

  return {
    userId: input.userId,
    name: (user.profileName as string) || '',
    avatarIndex: user.avatarIndex ?? null,
    avatarColorValue: user.avatarColorValue ?? 0xFF6366F1,
    timezoneOffsetMinutes,
    totals: {
      today: totalToday,
      last7Days: total7,
      lastMonth: totalMonth,
    },
    dailyBreakdown,
    lastStudyDate,
  };
}
