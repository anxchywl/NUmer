import { renderEmail } from '../../src/mail/templates';
import { MailLocale, MailTemplate } from '../../src/mail/types';

const templates: MailTemplate[] = ['verify', 'reset', 'passwordChanged'];
const locales: MailLocale[] = ['en', 'ru', 'kk'];
const combinations = templates.flatMap((template) => locales.map((locale) => [template, locale] as const));
const validity: Record<MailLocale, string> = {
  en: 'The code is valid for 10 minutes.',
  ru: 'Код действует 10 минут.',
  kk: 'Код 10 минут жарамды.',
};
const code = '481920';

describe('renderEmail', () => {
  it.each(combinations)('renders %s in %s', (template, locale) => {
    const { subject, html, text } = renderEmail(template, locale, { code });
    const output = [subject, html, text].join('\n');

    expect(subject).not.toMatch(/\d/);
    expect(output).not.toMatch(/http|<img|<a |!(?!DOCTYPE)/);
    expect(html).toContain(`<html lang="${locale}">`);
    for (const part of [html, text]) {
      expect(part.includes(code)).toBe(template !== 'passwordChanged');
      expect(part.includes(validity[locale])).toBe(template !== 'passwordChanged');
    }
  });

  it('separates the plain text paragraphs with blank lines', () => {
    expect(renderEmail('verify', 'en', { code }).text).toBe(
      [
        'Enter this code in the app to verify your email.',
        code,
        validity.en,
        'If you did not create a NUmer account, ignore this email.',
      ].join('\n\n'),
    );
    expect(renderEmail('passwordChanged', 'en', {}).text.split('\n\n')).toHaveLength(2);
  });

  it('escapes the code in html', () => {
    const { html } = renderEmail('verify', 'en', { code: '<b>' });

    expect(html).toContain('&lt;b&gt;');
    expect(html).not.toContain('<b>');
  });

  it.each(['de', 'toString'])('falls back to en for the locale %s', (locale) => {
    expect(renderEmail('reset', locale, { code })).toEqual(renderEmail('reset', 'en', { code }));
  });
});
