import * as functions from 'firebase-functions/v1';

export const ALLOWED_ROLES: readonly string[] = [
  'clavis:operator',
  'events:admin',
  'gradus:operator',
  'muto:admin',
  'numer:admin',
  'numer:editor',
];

const MAX_CLAIMS_BYTES = 1000;

export function normalizeRoles(input: unknown): string[] {
  if (!Array.isArray(input) || !input.every((role) => ALLOWED_ROLES.includes(role))) {
    throw new functions.https.HttpsError('invalid-argument', 'Unknown role.');
  }
  return [...new Set<string>(input)].sort();
}

export function rolesOf(claims: Record<string, unknown> | undefined): string[] {
  const roles = claims?.numer_roles;
  if (!Array.isArray(roles)) return [];
  return roles.filter((role): role is string => typeof role === 'string');
}

export function hasRole(token: Record<string, unknown> | undefined, role: string): boolean {
  return rolesOf(token).includes(role);
}

export function mergeRoles(
  claims: Record<string, unknown> | undefined,
  roles: string[],
): Record<string, unknown> {
  const merged = { ...claims, numer_roles: roles };
  if (Buffer.byteLength(JSON.stringify(merged), 'utf8') > MAX_CLAIMS_BYTES) {
    throw new functions.https.HttpsError('failed-precondition', 'Custom claims are too large.');
  }
  return merged;
}
