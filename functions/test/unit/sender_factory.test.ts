import { ConsoleMailSender } from '../../src/mail/console_sender';
import { ResendMailSender } from '../../src/mail/resend_sender';
import { getMailSender } from '../../src/mail/sender_factory';

describe('getMailSender', () => {
  const original = process.env;

  beforeEach(() => {
    process.env = { ...original, MAIL_FROM: 'no-reply@example.org', MAIL_API_KEY: 'test-key' };
    delete process.env.MAIL_PROVIDER;
    delete process.env.GCLOUD_PROJECT;
  });

  afterAll(() => {
    process.env = original;
  });

  it('defaults to resend', () => {
    expect(getMailSender()).toBeInstanceOf(ResendMailSender);
  });

  it('allows the console provider outside production', () => {
    process.env.MAIL_PROVIDER = 'console';
    process.env.GCLOUD_PROJECT = 'demo-numer';

    expect(getMailSender()).toBeInstanceOf(ConsoleMailSender);
  });

  it('refuses the console provider on the production project', () => {
    process.env.MAIL_PROVIDER = 'console';
    process.env.GCLOUD_PROJECT = 'numer-60744';

    expect(() => getMailSender()).toThrow('production');
  });

  it.each(['MAIL_FROM', 'MAIL_API_KEY'])('requires %s', (name) => {
    process.env[name] = '';

    expect(() => getMailSender()).toThrow('required');
  });

  it('rejects an unknown provider', () => {
    process.env.MAIL_PROVIDER = 'other';

    expect(() => getMailSender()).toThrow('unknown');
  });
});
