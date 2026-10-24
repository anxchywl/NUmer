import * as functions from 'firebase-functions/v1';
import { createAggregateHandlers } from './handlers';

function shadowPercentOf(value: string | undefined): number {
  const percent = Number(value);
  if (!Number.isFinite(percent)) return 0;
  return Math.min(100, Math.max(0, percent));
}

const handlers = createAggregateHandlers({
  mode: process.env.AGG_INCREMENTAL === 'on' ? 'on' : 'off',
  shadowPercent: shadowPercentOf(process.env.AGG_SHADOW_PERCENT),
});

export const onStudySessionWrite = functions.firestore
  .document('users/{userId}/sessions/{sessionId}')
  .onWrite(handlers.onSession);

export const onCourseWrite = functions.firestore
  .document('users/{userId}/courses/{courseId}')
  .onWrite(handlers.onCourse);
