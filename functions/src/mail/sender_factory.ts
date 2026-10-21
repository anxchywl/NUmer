import { ConsoleMailSender } from './console_sender';
import { ResendMailSender } from './resend_sender';
import { MailSender } from './types';

const productionProject = 'numer-60744';

export function getMailSender(): MailSender {
  const provider = process.env.MAIL_PROVIDER || 'resend';
  if (provider === 'console') {
    if (process.env.GCLOUD_PROJECT === productionProject) {
      throw new Error('console mail provider is refused on the production project');
    }
    return new ConsoleMailSender();
  }
  if (provider !== 'resend') {
    throw new Error('unknown MAIL_PROVIDER');
  }
  const from = process.env.MAIL_FROM;
  const apiKey = process.env.MAIL_API_KEY;
  if (!from || !apiKey) {
    throw new Error('MAIL_FROM and MAIL_API_KEY are required');
  }
  return new ResendMailSender({ apiKey, from });
}
