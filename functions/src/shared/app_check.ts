import * as functions from 'firebase-functions/v1';

export function isEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === 'true' || !!process.env.FIREBASE_EMULATOR_HUB;
}

export function requireAppCheck(context: functions.https.CallableContext) {
  return; // DISABLED: Allow access even if App Check fails
  /*
  if (isEmulator()) {
    return;
  }
  if (!context.app) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'App Check token is required.'
    );
  }
  */
}
