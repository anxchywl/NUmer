import { hasRole, mergeRoles, normalizeRoles } from '../../src/roles/roles';

describe('normalizeRoles', () => {
  it('sorts and de-duplicates', () => {
    expect(normalizeRoles(['numer:editor', 'muto:admin', 'numer:editor'])).toEqual([
      'muto:admin',
      'numer:editor',
    ]);
  });

  it.each([[['numer:root']], [[1]], ['muto:admin'], [undefined]])('rejects %p', (input) => {
    expect(() => normalizeRoles(input)).toThrow('Unknown role.');
  });
});

describe('hasRole', () => {
  it('reads the claim', () => {
    expect(hasRole({ numer_roles: ['muto:admin'] }, 'muto:admin')).toBe(true);
  });

  it.each([undefined, {}, { numer_roles: 'muto:admin' }])('grants nothing for %p', (token) => {
    expect(hasRole(token, 'muto:admin')).toBe(false);
  });
});

describe('mergeRoles', () => {
  it('replaces only the roles claim', () => {
    expect(mergeRoles({ beta: true, numer_roles: ['muto:admin'] }, [])).toEqual({
      beta: true,
      numer_roles: [],
    });
  });

  it('rejects claims above 1000 bytes', () => {
    expect(() => mergeRoles({ note: 'я'.repeat(500) }, [])).toThrow('Custom claims are too large.');
  });
});
