import { sanitizeDisplayName } from '../../src/nudges/sanitize';

describe('sanitizeDisplayName', () => {
  it('removes urls and collapses whitespace', () => {
    expect(sanitizeDisplayName('  Ann https://x.test/a   www.y.test  Lee ')).toBe('Ann Lee');
  });

  it('cuts to 40 characters', () => {
    expect(sanitizeDisplayName('a'.repeat(200))).toBe('a'.repeat(40));
  });

  it('gives an empty string for a non-string', () => {
    expect(sanitizeDisplayName({ name: 'Ann' })).toBe('');
  });
});
