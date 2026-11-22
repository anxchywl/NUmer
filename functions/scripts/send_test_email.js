const { parseArgs } = require('util');

const usage = [
  'usage: node scripts/send_test_email.js --to <address>',
  '  --template <verify|reset|passwordChanged> --locale <en|ru|kk>',
  'run npm run build first',
  'environment: MAIL_API_KEY, MAIL_FROM, MAIL_PROVIDER (resend or console)',
].join('\n');

const { values } = parseArgs({
  options: {
    to: { type: 'string' },
    template: { type: 'string', default: 'verify' },
    locale: { type: 'string', default: 'en' },
  },
});
const { to, template, locale } = values;

if (!to || !['verify', 'reset', 'passwordChanged'].includes(template) || !['en', 'ru', 'kk'].includes(locale)) {
  console.error(usage);
  process.exit(1);
}

const { getMailSender } = require('../lib/mail/sender_factory');
const { renderEmail } = require('../lib/mail/templates');

(async function main() {
  await getMailSender().send({ to, ...renderEmail(template, locale, { code: '123456' }) });
  console.log('Done.');
})().catch((error) => {
  console.error(error.message, error.status === undefined ? '' : `(status ${error.status})`);
  process.exit(1);
});
