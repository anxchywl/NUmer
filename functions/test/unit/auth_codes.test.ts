import * as crypto from 'crypto';
import {
  CodePurpose,
  generateCode,
  generateTicket,
  hashCode,
  hashTicket,
  isSixDigits,
  isValidEmail,
  normalizeEmail,
  safeEqualHex,
} from '../../src/auth/codes';

function seededRandomInt(seed: number) {
  let state = seed;
  return (min: number, max: number) => {
    state = (state * 1103515245 + 12345) % 2 ** 31;
    return min + (state % (max - min));
  };
}

const secret = 'test-secret';
type HashInputs = [CodePurpose, string, string, string];
const base: HashInputs = ['verify', 'uid-1', '123456', 'code-id-1'];
const changes: [string, HashInputs][] = [
  ['purpose', ['reset', 'uid-1', '123456', 'code-id-1']],
  ['subject', ['verify', 'uid-2', '123456', 'code-id-1']],
  ['code', ['verify', 'uid-1', '123457', 'code-id-1']],
  ['codeId', ['verify', 'uid-1', '123456', 'code-id-2']],
];

describe('auth codes', () => {
  it('generates six digit codes', () => {
    const codes = Array.from({ length: 1000 }, () => generateCode());

    expect(codes.every((code) => /^\d{6}$/.test(code))).toBe(true);
  });

  it('keeps a leading zero', () => {
    const randomInt = seededRandomInt(42);
    let found: string | undefined;
    for (let i = 0; i < 100_000 && found === undefined; i++) {
      const code = generateCode(randomInt);
      expect(code).toHaveLength(6);
      if (code.startsWith('0')) {
        found = code;
      }
    }

    expect(found).toMatch(/^0\d{5}$/);
  });

  it('hashes the same inputs equally', () => {
    expect(hashCode(secret, ...base)).toBe(hashCode(secret, ...base));
    expect(hashCode(secret, ...base)).toMatch(/^[0-9a-f]{64}$/);
  });

  it.each(changes)('changes the hash when %s changes', (_, changed) => {
    expect(hashCode(secret, ...changed)).not.toBe(hashCode(secret, ...base));
  });

  it('changes the hash with the secret', () => {
    expect(hashCode('other-secret', ...base)).not.toBe(hashCode(secret, ...base));
  });

  it('compares hex safely', () => {
    const hash = crypto.randomBytes(32).toString('hex');

    expect(safeEqualHex(hash, hash)).toBe(true);
    expect(safeEqualHex(hash, hash.slice(0, 62))).toBe(false);
    expect(safeEqualHex(hash, `${hash}00`)).toBe(false);
    expect(safeEqualHex(hash, hash.replace(/^./, hash[0] === 'a' ? 'b' : 'a'))).toBe(false);
  });

  it('makes 43 character tickets bound to the document', () => {
    const ticket = generateTicket();

    expect(ticket).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(hashTicket(secret, 'reset_a', ticket)).not.toBe(hashTicket(secret, 'reset_b', ticket));
  });

  it('normalizes and checks emails', () => {
    expect(normalizeEmail('  Student@Example.ORG ')).toBe('student@example.org');
    expect(isValidEmail('student@example.org')).toBe(true);
    expect(isValidEmail('student@example')).toBe(false);
    expect(isValidEmail('stu dent@example.org')).toBe(false);
    expect(isValidEmail(`${'a'.repeat(243)}@example.org`)).toBe(false);
  });

  it('accepts only six digit strings as codes', () => {
    expect(isSixDigits('012345')).toBe(true);
    expect(isSixDigits('12345')).toBe(false);
    expect(isSixDigits('1234567')).toBe(false);
    expect(isSixDigits('12345a')).toBe(false);
    expect(isSixDigits(123456)).toBe(false);
  });
});
