import { eventStartsAt, parseLocalized } from '../../src/feed/localized';

const rejected = expect.objectContaining({ code: 'invalid-argument' });
const parse = (value: unknown) => () => parseLocalized(value, 'title', 10);

describe('parseLocalized', () => {
  it('accepts english alone and all three languages, trimmed', () => {
    expect(parse({ en: ' News ' })()).toEqual({ en: 'News' });
    expect(parse({ en: 'News', ru: 'Новости', kk: 'Жаңалық' })()).toEqual({
      en: 'News',
      ru: 'Новости',
      kk: 'Жаңалық',
    });
  });

  it('rejects a missing english text, an extra key and an over-long string', () => {
    expect(parse({ ru: 'Новости' })).toThrow(rejected);
    expect(parse({ en: '  ' })).toThrow(rejected);
    expect(parse({ en: 'News', de: 'Neu' })).toThrow(rejected);
    expect(parse({ en: 'x'.repeat(11) })).toThrow(rejected);
    expect(parse({ en: 'News', ru: 5 })).toThrow(rejected);
    expect(parse('News')).toThrow(rejected);
  });
});

describe('eventStartsAt', () => {
  it('reads campus time as utc+05:00', () => {
    expect(eventStartsAt('2026-12-12', '18:00')).toBe(Date.UTC(2026, 11, 12, 13, 0));
  });

  it('returns NaN for an unreadable date', () => {
    expect(eventStartsAt('soon', '18:00')).toBeNaN();
  });
});
