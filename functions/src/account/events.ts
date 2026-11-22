import * as functions from 'firebase-functions/v1';
import { db } from '../shared/admin';
import { deliverPending, loadTargets, retryDueEvents, secretName } from './event_delivery';

// read at load time because a deploy fails on a declared secret that does not exist yet
const targets = loadTargets(process.env.ACCOUNT_EVENT_TARGETS, {
  allowLoopbackHttp: process.env.FUNCTIONS_EMULATOR === 'true',
});
const secrets = targets.map(({ module }) => secretName(module));

export const onAccountEventCreated = functions
  .runWith({ secrets, timeoutSeconds: 120 })
  .firestore.document('accountEvents/{id}')
  .onCreate((snapshot) => deliverPending(snapshot.ref, targets, new Date()));

export const retryAccountEvents = functions
  .runWith({ secrets, timeoutSeconds: 540 })
  .pubsub.schedule('every 15 minutes')
  .onRun(() => retryDueEvents(db, new Date(), targets));
