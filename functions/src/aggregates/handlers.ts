import { createHash } from 'crypto';
import * as functions from 'firebase-functions/v1';
import { AggregatePayload, derivePayload } from './derive';
import { applyCourseEvent, applySessionEvent, EventOptions } from './incremental';
import { stableStringify } from './ledger';
import { updateUserAggregates } from './update_user_aggregates';

type DocumentChange = functions.Change<functions.firestore.DocumentSnapshot>;

export interface HandlerConfig {
  mode: 'on' | 'off';
  shadowPercent: number;
  derive?: typeof derivePayload;
}

export function stableHash(value: string): number {
  return createHash('sha256').update(value).digest().readUInt32BE(0);
}

function differingKeys(a: AggregatePayload, b: AggregatePayload): string[] {
  const left = a as unknown as Record<string, unknown>;
  const right = b as unknown as Record<string, unknown>;
  const keys = new Set([...Object.keys(left), ...Object.keys(right)]);
  return [...keys].filter(k => stableStringify(left[k]) !== stableStringify(right[k])).sort();
}

function reportShadow(
  legacy: AggregatePayload | null,
  shadow: AggregatePayload | null,
  fields: { uid: string; sessionId?: string; courseId?: string },
) {
  if (!legacy || !shadow) return;
  const keys = differingKeys(legacy, shadow);
  if (keys.length === 0) return;
  functions.logger.error('aggregate_shadow_mismatch', { ...fields, keys });
}

export function createAggregateHandlers({ mode, shadowPercent, derive = derivePayload }: HandlerConfig) {
  const publishing: EventOptions = { publish: true, derive };
  const shadowing: EventOptions = { publish: false, derive };
  const isShadowed = (userId: string) => stableHash(userId) % 100 < shadowPercent;

  const onSession = async (change: DocumentChange, context: functions.EventContext) => {
    const { userId, sessionId } = context.params;
    const eventTimeMs = Date.parse(context.timestamp);
    if (mode === 'on') {
      await applySessionEvent(userId, sessionId, change, eventTimeMs, publishing);
      return;
    }
    console.log(`[onStudySessionWrite] userId=${userId}`);
    const legacy = await updateUserAggregates(userId);
    if (!isShadowed(userId)) return;
    const shadow = await applySessionEvent(userId, sessionId, change, eventTimeMs, shadowing);
    reportShadow(legacy.payload, shadow.payload, { uid: userId, sessionId });
  };

  const onCourse = async (change: DocumentChange, context: functions.EventContext) => {
    const { userId, courseId } = context.params;
    if (mode === 'on') {
      await applyCourseEvent(userId, courseId, change, publishing);
      return;
    }
    const before = change.before.data();
    const after = change.after.data();
    const hiddenBefore = before?.hiddenFromLeaderboard === true;
    const hiddenAfter = after?.hiddenFromLeaderboard === true;
    if (hiddenBefore === hiddenAfter && before && after) return;

    console.log(`[onCourseWrite] userId=${userId} courseId=${courseId} hidden=${hiddenAfter}`);
    const legacy = await updateUserAggregates(userId);
    if (!isShadowed(userId)) return;
    const shadow = await applyCourseEvent(userId, courseId, change, shadowing);
    reportShadow(legacy.payload, shadow.payload, { uid: userId, courseId });
  };

  return { onSession, onCourse };
}
