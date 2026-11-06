describe('exports', () => {
  it('keeps the deployed function names', () => {
    expect(Object.keys(require('../../src/index')).sort()).toEqual([
      'confirmPasswordReset',
      'deleteAccountCallable',
      'deleteGroupCallable',
      'joinPrivateGroup',
      'onCourseWrite',
      'onGroupMemberDelete',
      'onGroupMemberWrite',
      'onMailQueued',
      'onStudySessionWrite',
      'onUserDeletionRequested',
      'onUserProfileWrite',
      'requestPasswordResetCode',
      'sendEmailVerificationCode',
      'sendNudge',
      'setUserRoles',
      'sweepDeletedUsers',
      'verifyEmailCode',
      'verifyPasswordResetCode',
    ]);
  });
});
