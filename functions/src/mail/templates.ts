import { MailLocale, MailTemplate, MailVars } from './types';

interface Copy {
  subject: string;
  intro: string;
  footer: string;
  validity?: string;
}

const copy: Record<MailLocale, Record<MailTemplate, Copy>> = {
  en: {
    verify: {
      subject: 'Your NUmer verification code',
      intro: 'Enter this code in the app to verify your email.',
      validity: 'The code is valid for 10 minutes.',
      footer: 'If you did not create a NUmer account, ignore this email.',
    },
    reset: {
      subject: 'Your NUmer password reset code',
      intro: 'Enter this code in the app to set a new password.',
      validity: 'The code is valid for 10 minutes.',
      footer: 'If you did not ask to reset your password, ignore this email. Your password stays the same.',
    },
    passwordChanged: {
      subject: 'Your NUmer password was changed',
      intro: 'The password of your NUmer account was just changed. All devices were signed out.',
      footer: 'If this was not you, reset your password in the app now.',
    },
  },
  ru: {
    verify: {
      subject: 'Код подтверждения NUmer',
      intro: 'Введите этот код в приложении, чтобы подтвердить почту.',
      validity: 'Код действует 10 минут.',
      footer: 'Если вы не создавали аккаунт NUmer, проигнорируйте это письмо.',
    },
    reset: {
      subject: 'Код для сброса пароля NUmer',
      intro: 'Введите этот код в приложении, чтобы задать новый пароль.',
      validity: 'Код действует 10 минут.',
      footer: 'Если вы не запрашивали сброс пароля, проигнорируйте это письмо. Пароль останется прежним.',
    },
    passwordChanged: {
      subject: 'Пароль NUmer изменён',
      intro: 'Пароль вашего аккаунта NUmer только что изменён. Выполнен выход на всех устройствах.',
      footer: 'Если это были не вы, сразу сбросьте пароль в приложении.',
    },
  },
  kk: {
    verify: {
      subject: 'NUmer растау коды',
      intro: 'Поштаңызды растау үшін осы кодты қолданбаға енгізіңіз.',
      validity: 'Код 10 минут жарамды.',
      footer: 'NUmer аккаунтын ашпаған болсаңыз, бұл хатты елемеңіз.',
    },
    reset: {
      subject: 'NUmer құпиясөзін қалпына келтіру коды',
      intro: 'Жаңа құпиясөз орнату үшін осы кодты қолданбаға енгізіңіз.',
      validity: 'Код 10 минут жарамды.',
      footer: 'Құпиясөзді қалпына келтіруді сұрамаған болсаңыз, бұл хатты елемеңіз. Құпиясөзіңіз өзгермейді.',
    },
    passwordChanged: {
      subject: 'NUmer құпиясөзі өзгертілді',
      intro: 'NUmer аккаунтыңыздың құпиясөзі жаңа ғана өзгертілді. Барлық құрылғылардан шығу орындалды.',
      footer: 'Бұл сіз болмасаңыз, қолданбада құпиясөзді дереу қалпына келтіріңіз.',
    },
  },
};

const fontStack = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif";
const brandStyle = 'font-size: 20px; font-weight: 700; color: #448AFF;';
const introStyle = 'font-size: 16px; color: #202124;';
const codeStyle =
  'font-size: 32px; font-weight: 700; letter-spacing: 6px; ' +
  'font-family: ui-monospace, Menlo, Consolas, monospace; color: #202124;';
const noteStyle = 'font-size: 13px; color: #5F6368;';
// text colours are fixed dark, so the background is fixed light for dark mode clients
const backgroundStyle = 'background-color: #FFFFFF;';

function isMailLocale(locale: string): locale is MailLocale {
  return Object.prototype.hasOwnProperty.call(copy, locale);
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function row(style: string, value: string): string {
  return `<tr><td style="padding: 8px 16px; ${style}">${escapeHtml(value)}</td></tr>`;
}

function renderHtml(locale: MailLocale, { intro, validity, footer }: Copy, code?: string): string {
  const rows = [
    row(brandStyle, 'NUmer'),
    row(introStyle, intro),
    ...(code === undefined ? [] : [row(codeStyle, code)]),
    ...(validity === undefined ? [] : [row(noteStyle, validity)]),
    row(noteStyle, footer),
  ];
  return [
    '<!DOCTYPE html>',
    `<html lang="${escapeHtml(locale)}">`,
    '<head><meta charset="utf-8"><meta name="color-scheme" content="light"></head>',
    `<body style="margin: 0; ${backgroundStyle} font-family: ${fontStack};">`,
    '<table role="presentation" align="center" cellpadding="0" cellspacing="0" ' +
      `style="width: 100%; max-width: 480px; margin: 0 auto; text-align: center; ${backgroundStyle}">`,
    ...rows,
    '</table>',
    '</body>',
    '</html>',
  ].join('\n');
}

export function renderEmail(template: MailTemplate, locale: string, vars: MailVars) {
  const resolved = isMailLocale(locale) ? locale : 'en';
  const content = copy[resolved][template];
  const { subject, intro, validity, footer } = content;
  const code = validity === undefined ? undefined : vars.code ?? '';
  const paragraphs = [intro, code, validity, footer].filter((line) => line !== undefined);
  return {
    subject,
    html: renderHtml(resolved, content, code),
    text: paragraphs.join('\n\n'),
  };
}
