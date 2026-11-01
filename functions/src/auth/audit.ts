import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions/v1';
import { db } from '../shared/admin';

const auditLifeMs = 90 * 24 * 3600 * 1000;

export interface AuditFields {
  uid?: string;
  emailHash?: string;
  ipHash?: string;
  result?: string;
}

export async function audit(action: string, fields: AuditFields, now: number): Promise<void> {
  await db.collection('authAudit').add({
    action,
    ...fields,
    at: admin.firestore.Timestamp.fromMillis(now),
    expiresAt: admin.firestore.Timestamp.fromMillis(now + auditLifeMs),
  });
}

function resultOf(error: unknown): string {
  if (error instanceof functions.https.HttpsError) {
    return (error.details as { reason?: string } | undefined)?.reason ?? error.code;
  }
  return 'error';
}

// the audit row is written for every outcome, then the error goes on to the caller unchanged
export async function audited<T>(
  action: string,
  fields: AuditFields,
  now: number,
  run: () => Promise<T>,
): Promise<T> {
  try {
    const value = await run();
    await audit(action, { ...fields, result: fields.result ?? 'ok' }, now);
    return value;
  } catch (error) {
    await audit(action, { ...fields, result: resultOf(error) }, now);
    throw error;
  }
}
