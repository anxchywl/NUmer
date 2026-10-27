export function startOfDay(d: Date) {
  // Return start of day in UTC
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 0, 0, 0));
}

export type PeriodKey = 'today' | 'last7Days' | 'lastMonth';

export function resolvePeriodRange(period: PeriodKey, timezoneOffsetMinutes = 0) {
  const offsetMs = timezoneOffsetMinutes * 60 * 1000;
  const shiftedNow = new Date(Date.now() + offsetMs); // pretend server is in the caller's TZ

  const endOfTodayShifted = new Date(Date.UTC(
    shiftedNow.getUTCFullYear(),
    shiftedNow.getUTCMonth(),
    shiftedNow.getUTCDate(),
    23, 59, 59, 999,
  ));

  let startShifted: Date;
  let endShifted: Date = endOfTodayShifted;

  if (period === 'today') {
    startShifted = new Date(Date.UTC(
      shiftedNow.getUTCFullYear(),
      shiftedNow.getUTCMonth(),
      shiftedNow.getUTCDate(),
      0, 0, 0, 0,
    ));
  } else if (period === 'last7Days') {
    const weekday = shiftedNow.getUTCDay(); // Sunday = 0
    const daysFromMonday = (weekday + 6) % 7;
    const monday = new Date(Date.UTC(
      shiftedNow.getUTCFullYear(),
      shiftedNow.getUTCMonth(),
      shiftedNow.getUTCDate() - daysFromMonday,
      0, 0, 0, 0,
    ));
    const sunday = new Date(Date.UTC(
      monday.getUTCFullYear(),
      monday.getUTCMonth(),
      monday.getUTCDate() + 6,
      23, 59, 59, 999,
    ));
    startShifted = monday;
    endShifted = endOfTodayShifted < sunday ? endOfTodayShifted : sunday;
  } else {
    // lastMonth (current calendar month)
    startShifted = new Date(Date.UTC(
      shiftedNow.getUTCFullYear(),
      shiftedNow.getUTCMonth(),
      1,
      0, 0, 0, 0,
    ));
  }

  // Shift back to real UTC for the query
  return {
    start: new Date(startShifted.getTime() - offsetMs),
    end: new Date(endShifted.getTime() - offsetMs),
  };
}
