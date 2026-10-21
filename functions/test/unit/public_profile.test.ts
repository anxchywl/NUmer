import { Timestamp } from 'firebase-admin/firestore';
import { publicProfilesEqual, toPublicProfile } from '../../src/profiles/public_profile';

function userDoc(overrides: Record<string, unknown> = {}) {
  return {
    profileName: 'Aru',
    displayName: 'Aru',
    major: 'Math',
    profileGoal: 'Graduate',
    profileContact: '@aru',
    profileAvatarIndex: 2,
    avatarIndex: 5,
    avatarColorValue: 100,
    profileAvatarColorValue: 200,
    profileAvatarImageBase64: 'abc',
    avatarImageBase64: 'def',
    isStudying: true,
    activeSession: {
      deviceId: 'device-1',
      updatedAt: Timestamp.fromMillis(1000),
      courseId: 'c1',
      kind: 'timer',
      startUtc: Timestamp.fromMillis(2000),
      expectedEndUtc: Timestamp.fromMillis(3000),
    },
    allowNudges: false,
    fcmEnabled: true,
    email: 'aru@example.test',
    emailVerified: true,
    lastActive: Timestamp.fromMillis(4000),
    ...overrides,
  };
}

describe('toPublicProfile', () => {
  it('keeps exactly the public keys', () => {
    expect(Object.keys(toPublicProfile(userDoc())!).sort()).toEqual([
      'activeSession',
      'allowNudges',
      'avatarColorValue',
      'avatarImageBase64',
      'avatarIndex',
      'fcmEnabled',
      'isStudying',
      'major',
      'profileContact',
      'profileGoal',
      'profileName',
    ]);
  });

  it('never carries email, emailVerified or deviceId', () => {
    const text = JSON.stringify(toPublicProfile(userDoc()));
    expect(text).not.toContain('email');
    expect(text).not.toContain('emailVerified');
    expect(text).not.toContain('deviceId');
    expect(text).not.toContain('aru@example.test');
    expect(text).not.toContain('device-1');
  });

  it('returns null without a document', () => {
    expect(toPublicProfile(undefined)).toBeNull();
  });

  it('allows nudges by default', () => {
    expect(toPublicProfile({})!.allowNudges).toBe(true);
  });

  it('prefers the profile avatar fields', () => {
    const profile = toPublicProfile(userDoc())!;
    expect(profile.avatarIndex).toBe(2);
    expect(profile.avatarColorValue).toBe(100);
    expect(profile.avatarImageBase64).toBe('abc');
  });

  it('falls back to the display name', () => {
    expect(toPublicProfile({ displayName: 'Aru' })!.profileName).toBe('Aru');
  });

  it('drops a name that is not a string', () => {
    expect(toPublicProfile(userDoc({ profileName: 7 }))!.profileName).toBe('');
  });

  it('drops an active session that is not a map', () => {
    expect(toPublicProfile(userDoc({ activeSession: ['c1'] }))!.activeSession).toBeNull();
    expect(toPublicProfile(userDoc({ activeSession: Timestamp.fromMillis(1) }))!.activeSession).toBeNull();
  });

  it('drops an oversized image', () => {
    const image = (length: number) => userDoc({ profileAvatarImageBase64: 'a'.repeat(length) });
    expect(toPublicProfile(image(700001))!.avatarImageBase64).toBeNull();
    expect(toPublicProfile(image(700000))!.avatarImageBase64).toHaveLength(700000);
  });
});

describe('publicProfilesEqual', () => {
  it('sees a changed session start', () => {
    const moved = userDoc({
      activeSession: { ...userDoc().activeSession, startUtc: Timestamp.fromMillis(2001) },
    });
    expect(publicProfilesEqual(toPublicProfile(userDoc()), toPublicProfile(moved))).toBe(false);
  });

  it('ignores private changes', () => {
    const changed = userDoc({
      email: 'other@example.test',
      lastActive: Timestamp.fromMillis(9000),
      activeSession: { ...userDoc().activeSession, deviceId: 'device-2' },
    });
    expect(publicProfilesEqual(toPublicProfile(userDoc()), toPublicProfile(changed))).toBe(true);
  });

  it('separates a missing document from a profile', () => {
    expect(publicProfilesEqual(null, toPublicProfile({}))).toBe(false);
  });
});
