import * as functions from 'firebase-functions/v1';
import { updateUserAggregates } from './update_user_aggregates';

export const onStudySessionWrite = functions.firestore
  .document('users/{userId}/sessions/{sessionId}')
  .onWrite(async (change, context) => {
    const { userId } = context.params;
    console.log(`[onStudySessionWrite] userId=${userId}`);
    await updateUserAggregates(userId);
  });

export const onCourseWrite = functions.firestore
  .document('users/{userId}/courses/{courseId}')
  .onWrite(async (change, context) => {
    const { userId } = context.params;

    // Check if hiddenFromLeaderboard changed
    const before = change.before.data();
    const after = change.after.data();

    // If it's a delete or create, we might need to update.
    // If update, check if hidden status changed.
    const hiddenBefore = before?.hiddenFromLeaderboard === true;
    const hiddenAfter = after?.hiddenFromLeaderboard === true;

    if (hiddenBefore !== hiddenAfter || !before || !after) {
      console.log(`[onCourseWrite] userId=${userId} courseId=${context.params.courseId} hidden=${hiddenAfter}`);
      await updateUserAggregates(userId);
    }
  });
