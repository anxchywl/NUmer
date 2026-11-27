import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';
import { getMailSender } from './sender_factory';
import { renderEmail } from './templates';
import { MailDeliveryError, MailLocale, MailMessage, MailSender, MailTemplate, MailVars } from './types';

const lifetimeMs = 60 * 60 * 1000;
const retryDelayMs = 1000;

// a null recipient is a dummy entry, so a caller does the same work with or without an account
export async function enqueueMail(
  to: string | null,
  template: MailTemplate,
  locale: MailLocale,
  vars: MailVars,
): Promise<void> {
  const now = Date.now();
  await db.collection('mailQueue').add({
    to,
    template,
    locale,
    vars,
    createdAt: admin.firestore.Timestamp.fromMillis(now),
    expiresAt: admin.firestore.Timestamp.fromMillis(now + lifetimeMs),
  });
}

function waitBeforeRetry(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, retryDelayMs));
}

function isRetryable({ status }: MailDeliveryError): boolean {
  return status === 0 || status === 429 || status >= 500;
}

async function sendWithRetry(sender: MailSender, message: MailMessage, wait: () => Promise<void>) {
  try {
    await sender.send(message);
  } catch (error) {
    if (!(error instanceof MailDeliveryError) || !isRetryable(error)) {
      throw error;
    }
    await wait();
    await sender.send(message);
  }
}

// neither the address nor a code may stay at rest
async function purgeFailed(snapshot: functions.firestore.QueryDocumentSnapshot): Promise<void> {
  await snapshot.ref.update({
    to: admin.firestore.FieldValue.delete(),
    vars: admin.firestore.FieldValue.delete(),
    failedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// the sender is built here so that a configuration error also purges the entry
export async function processMailQueued(
  snapshot: functions.firestore.QueryDocumentSnapshot,
  createSender: () => MailSender,
  wait: () => Promise<void> = waitBeforeRetry,
): Promise<void> {
  const { to, template, locale, vars } = snapshot.data();
  if (to === null) {
    await snapshot.ref.delete();
    return;
  }

  try {
    await sendWithRetry(createSender(), { to, ...renderEmail(template, locale, vars) }, wait);
  } catch (error) {
    const status = error instanceof MailDeliveryError ? error.status : undefined;
    functions.logger.error('mail_delivery_failed', { template, status });
    await purgeFailed(snapshot);
    if (status === undefined) {
      throw error;
    }
    return;
  }
  await snapshot.ref.delete();
}

export const onMailQueued = functions
  .runWith({ secrets: ['MAIL_API_KEY'] })
  .firestore.document('mailQueue/{id}')
  .onCreate((snapshot) => processMailQueued(snapshot, getMailSender));
