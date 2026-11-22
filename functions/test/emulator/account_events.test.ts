import { createServer, IncomingHttpHeaders, Server } from 'http';
import { AddressInfo } from 'net';
import * as functions from 'firebase-functions/v1';
import { Timestamp } from 'firebase-admin/firestore';
import { db } from '../../src/shared/admin';
import { deliverPending, EventTarget, ModuleName, retryDueEvents } from '../../src/account/event_delivery';
import { signEvent } from '../../src/account/event_signature';

jest.mock('firebase-functions/v1', () => ({
  ...jest.requireActual('firebase-functions/v1'),
  logger: { error: jest.fn() },
}));

const minuteMs = 60 * 1000;
const hourMs = 60 * minuteMs;
const events = db.collection('accountEvents');

interface Received {
  headers: IncomingHttpHeaders;
  body: string;
}

class FakeModule {
  status = 200;
  readonly received: Received[] = [];
  private server!: Server;

  async start(module: ModuleName): Promise<EventTarget> {
    this.server = createServer((request, response) => {
      const chunks: Buffer[] = [];
      request.on('data', (chunk) => chunks.push(chunk));
      request.on('end', () => {
        this.received.push({ headers: request.headers, body: Buffer.concat(chunks).toString() });
        response.writeHead(this.status, { location: '/moved' }).end();
      });
    });
    await new Promise<void>((resolve) => this.server.listen(0, '127.0.0.1', resolve));
    return { module, url: `http://127.0.0.1:${(this.server.address() as AddressInfo).port}/events` };
  }

  async stop(): Promise<void> {
    this.server.closeAllConnections();
    await new Promise((resolve) => this.server.close(resolve));
  }
}

async function createEvent(ageMs = 0, extra: Record<string, unknown> = {}) {
  const ref = events.doc('deleted_user-1');
  await ref.set({
    type: 'account.deleted',
    issuer: 'issuer',
    subject: 'user-1',
    occurredAt: Timestamp.fromMillis(Date.now() - ageMs),
    status: 'pending',
    ...extra,
  });
  return ref;
}

const later = (ms: number) => new Date(Date.now() + ms);
const read = async () => (await events.doc('deleted_user-1').get()).data()!;

describe('account event delivery', () => {
  const muto = new FakeModule();
  const clavis = new FakeModule();
  let mutoTarget: EventTarget;
  let clavisTarget: EventTarget;
  const logged = functions.logger.error as jest.Mock;

  beforeAll(async () => {
    process.env.ACCOUNT_EVENTS_SECRET_MUTO = 'muto-test-secret';
    process.env.ACCOUNT_EVENTS_SECRET_CLAVIS = 'clavis-test-secret';
    mutoTarget = await muto.start('muto');
    clavisTarget = await clavis.start('clavis');
  });

  beforeEach(async () => {
    await db.recursiveDelete(events);
    for (const module of [muto, clavis]) {
      module.status = 200;
      module.received.length = 0;
    }
    logged.mockClear();
  });

  afterAll(async () => {
    await muto.stop();
    await clavis.stop();
    await db.terminate();
  });

  it('posts a signed event and marks it delivered', async () => {
    const now = new Date();

    await deliverPending(await createEvent(), [mutoTarget], now);

    const [{ headers, body }] = muto.received;
    const seconds = Math.floor(now.getTime() / 1000);
    expect(headers['x-numer-signature']).toBe(signEvent('muto-test-secret', seconds, body));
    expect(headers['content-type']).toBe('application/json');
    expect(JSON.parse(body)).toMatchObject({ id: 'deleted_user-1', subject: 'user-1' });
    const event = await read();
    expect(event.status).toBe('delivered');
    expect(event.deliveries.muto).toMatchObject({ status: 'delivered', attempts: 1, lastHttpStatus: 200 });
  });

  it.each([302, 500])('retries after status %i until the module recovers', async (status) => {
    muto.status = status;
    const now = new Date();

    await deliverPending(await createEvent(), [mutoTarget], now);

    const pending = await read();
    expect(pending.status).toBe('pending');
    expect(pending.deliveries.muto).toMatchObject({ status: 'pending', attempts: 1, lastHttpStatus: status });
    expect(pending.nextAttemptAt.toMillis()).toBe(now.getTime() + 15 * minuteMs);
    muto.status = 200;
    await retryDueEvents(db, later(14 * minuteMs), [mutoTarget]);
    expect(muto.received).toHaveLength(1);

    await retryDueEvents(db, later(16 * minuteMs), [mutoTarget]);

    expect((await read()).status).toBe('delivered');
    expect((await read()).deliveries.muto.attempts).toBe(2);
  });

  it('records an unreachable module as status 0', async () => {
    const closed = new FakeModule();
    const target = await closed.start('muto');
    await closed.stop();

    await deliverPending(await createEvent(), [target], new Date());

    expect((await read()).deliveries.muto).toMatchObject({ status: 'pending', lastHttpStatus: 0 });
  });

  it('does not post without a secret', async () => {
    await deliverPending(await createEvent(), [{ ...mutoTarget, module: 'events' }], new Date());

    expect(muto.received).toHaveLength(0);
    expect((await read()).deliveries.events).toMatchObject({ status: 'pending', lastHttpStatus: 0 });
  });

  it('delivers an event whose first delivery never finished', async () => {
    await createEvent(0, { nextAttemptAt: Timestamp.fromDate(later(15 * minuteMs)) });

    await retryDueEvents(db, later(16 * minuteMs), [mutoTarget]);

    expect((await read()).status).toBe('delivered');
  });

  it('schedules the retry before it posts', async () => {
    const ref = await createEvent();
    const broken: typeof fetch = () => Promise.reject(new Error('interrupted'));

    await expect(deliverPending(ref, [mutoTarget], new Date(), broken)).rejects.toThrow('interrupted');

    expect((await read()).nextAttemptAt).toBeDefined();
    expect((await read()).status).toBe('pending');
  });

  it('gives up after 72 hours and logs the target once', async () => {
    muto.status = 500;
    const ref = await createEvent(73 * hourMs);

    await deliverPending(ref, [mutoTarget], new Date());
    await deliverPending(ref, [mutoTarget], new Date());

    const event = await read();
    expect(event.status).toBe('failed');
    expect(event.deliveries.muto.status).toBe('failed');
    expect(muto.received).toHaveLength(1);
    expect(logged.mock.calls).toEqual([
      ['account_event_delivery_failed', { id: 'deleted_user-1', module: 'muto' }],
    ]);
  });

  it('retries only the target that failed', async () => {
    clavis.status = 500;
    const targets = [mutoTarget, clavisTarget];
    await deliverPending(await createEvent(), targets, new Date());
    expect((await read()).deliveries.muto.status).toBe('delivered');
    expect((await read()).status).toBe('pending');
    clavis.status = 200;

    await retryDueEvents(db, later(16 * minuteMs), targets);

    expect(muto.received).toHaveLength(1);
    expect(clavis.received).toHaveLength(2);
    expect((await read()).status).toBe('delivered');
  });

  it('keeps a target delivered by a concurrent run', async () => {
    const ref = await createEvent();
    const overtaken: typeof fetch = async () => {
      await deliverPending(ref, [mutoTarget], new Date());
      return new Response(null, { status: 500 });
    };

    await deliverPending(ref, [mutoTarget], new Date(), overtaken);

    expect((await read()).status).toBe('delivered');
    expect((await read()).deliveries.muto.status).toBe('delivered');
  });

  it('is delivered at once without targets', async () => {
    await deliverPending(await createEvent(), [], new Date());

    expect((await read()).status).toBe('delivered');
  });
});
