describe('exports', () => {
  it('keeps the deployed function names', () => {
    expect(Object.keys(require('../../src/index')).sort()).toEqual([
      'deleteAccountCallable',
      'deleteGroupCallable',
      'joinPrivateGroup',
      'onCourseWrite',
      'onGroupMemberDelete',
      'onGroupMemberWrite',
      'onMailQueued',
      'onStudySessionWrite',
      'onUserProfileWrite',
      'sendNudge',
    ]);
  });
});
