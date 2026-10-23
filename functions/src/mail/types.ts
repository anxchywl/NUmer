export type MailTemplate = 'verify' | 'reset' | 'passwordChanged';
export type MailLocale = 'en' | 'ru' | 'kk';

export interface MailVars {
  code?: string;
}

export interface MailMessage {
  to: string;
  subject: string;
  html: string;
  text: string;
}

export interface MailSender {
  send(message: MailMessage): Promise<void>;
}

export class MailDeliveryError extends Error {
  constructor(public status: number) {
    super('mail delivery failed');
    this.name = 'MailDeliveryError';
  }
}
