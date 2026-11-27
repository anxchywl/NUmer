import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { db } from '../shared/admin';

export interface PublicProfile {
  profileName: string;
  major: string | null;
  profileGoal: string | null;
  profileContact: string | null;
  avatarIndex: number | null;
  avatarColorValue: number | null;
  avatarImageBase64: string | null;
  isStudying: boolean;
  activeSession: {
    courseId: unknown;
    kind: unknown;
    startUtc: unknown;
    expectedEndUtc: unknown;
  } | null;
  allowNudges: boolean;
  fcmEnabled: boolean;
}

// keeps the mirror clear of the firestore document size limit
const maxAvatarLength = 700000;

function stringOrNull(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === 'number' ? value : null;
}

function isPlainMap(value: unknown): value is Record<string, unknown> {
  if (typeof value !== 'object' || value === null) return false;
  const proto = Object.getPrototypeOf(value);
  return proto === null || Object.getPrototypeOf(proto) === null;
}

function toPublicSession(value: unknown): PublicProfile['activeSession'] {
  if (!isPlainMap(value)) return null;
  return {
    courseId: value.courseId ?? null,
    kind: value.kind ?? null,
    startUtc: value.startUtc ?? null,
    expectedEndUtc: value.expectedEndUtc ?? null,
  };
}

function toPublicImage(value: unknown): string | null {
  const image = stringOrNull(value);
  if (image === null || image.length > maxAvatarLength) return null;
  return image;
}

export function toPublicProfile(data: FirebaseFirestore.DocumentData | undefined): PublicProfile | null {
  if (data === undefined) return null;
  return {
    profileName: stringOrNull(data.profileName ?? data.displayName) ?? '',
    major: stringOrNull(data.major),
    profileGoal: stringOrNull(data.profileGoal),
    profileContact: stringOrNull(data.profileContact),
    avatarIndex: numberOrNull(data.profileAvatarIndex ?? data.avatarIndex),
    avatarColorValue: numberOrNull(data.avatarColorValue ?? data.profileAvatarColorValue),
    avatarImageBase64: toPublicImage(data.profileAvatarImageBase64 ?? data.avatarImageBase64),
    isStudying: data.isStudying === true,
    activeSession: toPublicSession(data.activeSession),
    allowNudges: data.allowNudges !== false,
    fcmEnabled: data.fcmEnabled === true,
  };
}

function valuesEqual(a: unknown, b: unknown): boolean {
  if (Object.is(a, b)) return true;
  if (a instanceof admin.firestore.Timestamp) {
    return b instanceof admin.firestore.Timestamp && a.isEqual(b);
  }
  if (typeof a !== 'object' || typeof b !== 'object' || a === null || b === null) return false;
  if (Object.getPrototypeOf(a) !== Object.getPrototypeOf(b)) return false;

  const left = a as Record<string, unknown>;
  const right = b as Record<string, unknown>;
  const keys = Object.keys(left);
  if (keys.length !== Object.keys(right).length) return false;
  return keys.every((key) => key in right && valuesEqual(left[key], right[key]));
}

export function publicProfilesEqual(a: PublicProfile | null, b: PublicProfile | null): boolean {
  return valuesEqual(a, b);
}

function storedProfile(data: FirebaseFirestore.DocumentData | undefined): PublicProfile | null {
  if (data === undefined) return null;
  const { updatedAt, ...profile } = data;
  return profile as PublicProfile;
}

// reads current state so late, repeated or failed events cannot leave the mirror stale
export async function syncPublicProfile(userId: string): Promise<void> {
  const userRef = db.collection('users').doc(userId);
  const mirrorRef = db.collection('publicProfiles').doc(userId);

  await db.runTransaction(async (txn) => {
    const [user, mirror] = await txn.getAll(userRef, mirrorRef);
    const profile = toPublicProfile(user.data());
    if (profile === null) {
      txn.delete(mirrorRef);
      return;
    }
    if (publicProfilesEqual(storedProfile(mirror.data()), profile)) return;

    txn.set(mirrorRef, { ...profile, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  });
}

export const onUserProfileWrite = functions
  .runWith({ failurePolicy: true })
  .firestore.document('users/{userId}')
  .onWrite((_change, context) => syncPublicProfile(context.params.userId));
