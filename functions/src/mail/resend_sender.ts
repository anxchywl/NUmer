import { MailDeliveryError, MailMessage, MailSender } from './types';

const endpoint = 'https://api.resend.com/emails';
const timeoutMs = 10_000;

interface ResendOptions {
  apiKey: string;
  from: string;
  fetchImpl?: typeof fetch;
}

// fetch rejects with TypeError on a network failure and AbortError on the timeout
function isTransportFailure(error: unknown): boolean {
  return error instanceof TypeError || (error as Error).name === 'AbortError';
}

export class ResendMailSender implements MailSender {
  private readonly apiKey: string;
  private readonly from: string;
  private readonly fetchImpl: typeof fetch;

  constructor({ apiKey, from, fetchImpl = fetch }: ResendOptions) {
    this.apiKey = apiKey;
    this.from = from;
    this.fetchImpl = fetchImpl;
  }

  async send(message: MailMessage): Promise<void> {
    const response = await this.post(message);
    if (!response.ok) {
      throw new MailDeliveryError(response.status);
    }
  }

  private async post({ to, subject, html, text }: MailMessage): Promise<Response> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      return await this.fetchImpl(endpoint, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ from: this.from, to: [to], subject, html, text }),
        signal: controller.signal,
      });
    } catch (error) {
      if (!isTransportFailure(error)) {
        throw error;
      }
      throw new MailDeliveryError(0);
    } finally {
      clearTimeout(timer);
    }
  }
}
