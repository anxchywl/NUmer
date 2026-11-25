import { assertId } from '../../src/shared/validation';

describe('assertId', () => {
  it('accepts a safe id', () => {
    expect(assertId('abc_DEF-123', 'groupId')).toBe('abc_DEF-123');
  });

  it.each([
    ['an empty string', ''],
    ['a path', 'a/b'],
    ['an object', {}],
    ['a 129 character string', 'a'.repeat(129)],
  ])('rejects %s', (_label, value) => {
    expect(() => assertId(value, 'groupId')).toThrow('groupId is invalid.');
  });
});
