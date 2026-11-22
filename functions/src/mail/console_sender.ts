import * as functions from 'firebase-functions/v1';
import { MailMessage, MailSender } from './types';

export class ConsoleMailSender implements MailSender {
  async send({ subject }: MailMessage): Promise<void> {
    functions.logger.info('mail_not_sent', { to: '<redacted>', subject });
  }
}
