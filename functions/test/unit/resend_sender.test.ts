import { ResendMailSender } from '../../src/mail/resend_sender';

const message = { to: 'student@example.org', subject: 'subject', html: '<p>html</p>', text: 'text' };

function senderWith(fetchImpl: typeof fetch) {
  return new ResendMailSender({ apiKey: 'test-key', from: 'NUmer <no-reply@example.org>', fetchImpl });
}

describe('ResendMailSender', () => {
  it('posts the message to resend', async () => {
    const calls: [unknown, RequestInit | undefined][] = [];
    const sender = senderWith(async (url, init) => {
      calls.push([url, init]);
      return new Response('{}', { status: 200 });
    });

    await sender.send(message);

    expect(calls).toHaveLength(1);
    const [url, init] = calls[0];
    expect(url).toBe('https://api.resend.com/emails');
    expect(init?.method).toBe('POST');
    expect(init?.headers).toEqual({
      Authorization: 'Bearer test-key',
      'Content-Type': 'application/json',
    });
    expect(JSON.parse(init?.body as string)).toEqual({
      from: 'NUmer <no-reply@example.org>',
      to: [message.to],
      subject: message.subject,
      html: message.html,
      text: message.text,
    });
  });

  it('reports a non-2xx status', async () => {
    const sender = senderWith(async () => new Response('{}', { status: 500 }));

    await expect(sender.send(message)).rejects.toMatchObject({ name: 'MailDeliveryError', status: 500 });
  });

  it('reports a network failure as status 0', async () => {
    const sender = senderWith(async () => {
      throw new TypeError('fetch failed');
    });

    await expect(sender.send(message)).rejects.toMatchObject({ name: 'MailDeliveryError', status: 0 });
  });

  it('aborts after 10 seconds with status 0', async () => {
    jest.useFakeTimers();
    const sender = senderWith(
      (_url, init) =>
        new Promise((_resolve, reject) => {
          init?.signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')));
        }),
    );

    const result = expect(sender.send(message)).rejects.toMatchObject({ status: 0 });
    await jest.advanceTimersByTimeAsync(10_000);
    await result;
    jest.useRealTimers();
  });
});
