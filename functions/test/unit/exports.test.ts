describe('exports', () => {
  it('keeps the deployed function names', () => {
    expect(Object.keys(require('../../src/index')).sort()).toEqual([
      'confirmPasswordReset',
      'deleteAccountCallable',
      'deleteGroupCallable',
      'joinPrivateGroup',
      'onAccountEventCreated',
      'onCourseWrite',
      'onGroupMemberDelete',
      'onGroupMemberWrite',
      'onMailQueued',
      'onStudySessionWrite',
      'onUserDeletionRequested',
      'onUserProfileWrite',
      'requestPasswordResetCode',
      'retryAccountEvents',
      'sendEmailVerificationCode',
      'sendNudge',
      'setUserRoles',
      'sweepDeletedUsers',
      'verifyEmailCode',
      'verifyPasswordResetCode',
    ]);
  });
});
