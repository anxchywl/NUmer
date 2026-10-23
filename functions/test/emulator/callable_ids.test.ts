import * as admin from 'firebase-admin';
import functionsTest from 'firebase-functions-test';
import { deleteGroupCallable, joinPrivateGroup } from '../../src/groups/callables';
import { sendNudge } from '../../src/nudges/send_nudge';

const test = functionsTest();
const context = { auth: { uid: 'ids-u' } };

const cases: [string, (value: unknown) => Promise<unknown>][] = [
  ['deleteGroupCallable groupId', (groupId) => test.wrap(deleteGroupCallable)({ groupId }, context)],
  ['joinPrivateGroup groupId', (groupId) => test.wrap(joinPrivateGroup)({ groupId, joinCode: 'CODE1' }, context)],
  ['joinPrivateGroup joinCode', (joinCode) => test.wrap(joinPrivateGroup)({ groupId: 'G', joinCode }, context)],
  ['sendNudge groupId', (groupId) => test.wrap(sendNudge)({ groupId, targetUserId: 'T' }, context)],
  ['sendNudge targetUserId', (targetUserId) => test.wrap(sendNudge)({ groupId: 'G', targetUserId }, context)],
];

describe('callable arguments', () => {
  afterAll(async () => {
    test.cleanup();
    await admin.app().delete();
  });

  describe.each(cases)('%s', (_label, call) => {
    it.each([['a path', 'G/members/x'], ['an object', {}]])('rejects %s', async (_kind, value) => {
      await expect(call(value)).rejects.toMatchObject({ code: 'invalid-argument' });
    });
  });
});
