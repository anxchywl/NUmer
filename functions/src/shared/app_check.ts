import * as functions from 'firebase-functions/v1';

export function parseEnforced(value: string | undefined): Set<string> {
  const names = (value ?? '').split(',').map((name) => name.trim());
  return new Set(names.filter((name) => name !== ''));
}

const configured = parseEnforced(process.env.APPCHECK_ENFORCED);

export function requireAppCheck(
  context: functions.https.CallableContext,
  name: string,
  enforced: Set<string> = configured,
) {
  const isEnforced = enforced.has(name) || enforced.has('*');
  if (!isEnforced || context.app !== undefined) {
    return;
  }
  throw new functions.https.HttpsError(
    'failed-precondition',
    'This request could not be verified.',
    { reason: 'app-check' },
  );
}
