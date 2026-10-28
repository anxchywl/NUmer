import { db } from '../../src/shared/admin';
import { enqueueMail, processMailQueued } from '../../src/mail/queue';
import { MailDeliveryError, MailMessage, MailSender } from '../../src/mail/types';

class FakeSender implements MailSender {
  readonly attempts: MailMessage[] = [];

  constructor(private readonly failures: number[] = []) {}

  async send(message: MailMessage): Promise<void> {
    this.attempts.push(message);
    const status = this.failures.shift();
    if (status !== undefined) {
      throw new MailDeliveryError(status);
    }
  }
}

const noWait = async () => {};
const queue = db.collection('mailQueue');

async function queued(to: string | null) {
  await enqueueMail(to, 'verify', 'en', { code: '481920' });
  const { docs } = await queue.get();
  return docs[0];
}

async function deliver(to: string | null, sender: FakeSender) {
  const snapshot = await queued(to);
  await processMailQueued(snapshot, () => sender, noWait);
  return snapshot.ref.get();
}

function expectPurged(after: FirebaseFirestore.DocumentSnapshot) {
  expect(after.data()).not.toHaveProperty('to');
  expect(after.data()).not.toHaveProperty('vars');
  expect(after.data()).toHaveProperty('failedAt');
}

describe('mail queue', () => {
  beforeEach(async () => {
    await db.recursiveDelete(queue);
  });

  afterAll(async () => {
    await db.terminate();
  });

  it('stores an entry that expires after an hour', async () => {
    const entry = (await queued('student@example.org')).data();

    expect(entry.expiresAt.toMillis() - entry.createdAt.toMillis()).toBe(60 * 60 * 1000);
  });

  it('sends a queued document and deletes it', async () => {
    const sender = new FakeSender();

    const after = await deliver('student@example.org', sender);

    expect(sender.attempts).toHaveLength(1);
    expect(sender.attempts[0].to).toBe('student@example.org');
    expect(sender.attempts[0].text).toContain('481920');
    expect(after.exists).toBe(false);
  });

  it('deletes a dummy entry without sending', async () => {
    const sender = new FakeSender();

    const after = await deliver(null, sender);

    expect(sender.attempts).toHaveLength(0);
    expect(after.exists).toBe(false);
  });

  it.each([0, 429, 503])('retries once after status %i', async (status) => {
    const sender = new FakeSender([status]);

    const after = await deliver('student@example.org', sender);

    expect(sender.attempts).toHaveLength(2);
    expect(after.exists).toBe(false);
  });

  it('keeps no address or code after two failures', async () => {
    const sender = new FakeSender([500, 500]);

    const after = await deliver('student@example.org', sender);

    expect(sender.attempts).toHaveLength(2);
    expectPurged(after);
  });

  it('does not retry after status 422', async () => {
    const sender = new FakeSender([422]);

    const after = await deliver('student@example.org', sender);

    expect(sender.attempts).toHaveLength(1);
    expectPurged(after);
  });

  it('purges the entry when the sender cannot be configured', async () => {
    const snapshot = await queued('student@example.org');
    const failure = new Error('MAIL_FROM and MAIL_API_KEY are required');
    const createSender = () => {
      throw failure;
    };

    await expect(processMailQueued(snapshot, createSender, noWait)).rejects.toBe(failure);

    expectPurged(await snapshot.ref.get());
  });

  it('purges the entry when it cannot be rendered', async () => {
    const sender = new FakeSender();
    await queue.add({ to: 'student@example.org', template: 'unknown', locale: 'en', vars: { code: '481920' } });
    const [snapshot] = (await queue.get()).docs;

    await expect(processMailQueued(snapshot, () => sender, noWait)).rejects.toThrow(TypeError);

    expect(sender.attempts).toHaveLength(0);
    expectPurged(await snapshot.ref.get());
  });
});
