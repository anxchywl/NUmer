import * as functions from 'firebase-functions/v1';
import { db } from '../shared/admin';
import { composeFeed, ComposeDeps, fetchEventsOverHttp } from './compose';

function defaultDeps(): ComposeDeps {
  return {
    db,
    now: Date.now,
    eventsUrl: process.env.FEED_EVENTS_URL,
    fetchEvents: fetchEventsOverHttp,
  };
}

export const composeFeedScheduled = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(() => composeFeed(defaultDeps()));

export const onAnnouncementWrite = functions.firestore
  .document('announcements/{id}')
  .onWrite(() => composeFeed(defaultDeps()));
