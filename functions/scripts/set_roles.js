// needs npm run build and GOOGLE_APPLICATION_CREDENTIALS
const { parseArgs } = require('node:util');
const admin = require('firebase-admin');
const { mergeRoles, normalizeRoles, rolesOf } = require('../lib/roles/roles');

(async function main() {
  const { values } = parseArgs({
    options: {
      uid: { type: 'string' },
      roles: { type: 'string' },
      'dry-run': { type: 'boolean', default: false },
    },
  });
  if (!values.uid || values.roles === undefined) {
    console.error('Usage: node scripts/set_roles.js --uid <uid> --roles <comma list> [--dry-run]');
    process.exit(1);
  }
  const roles = normalizeRoles(values.roles === '' ? [] : values.roles.split(','));

  admin.initializeApp();
  const auth = admin.auth();
  const { customClaims } = await auth.getUser(values.uid);
  const before = rolesOf(customClaims);
  const claims = mergeRoles(customClaims, roles);
  console.log('before:', JSON.stringify(before));
  console.log('after: ', JSON.stringify(roles));

  if (values['dry-run']) {
    console.log('Dry run, nothing changed.');
    return;
  }
  await auth.setCustomUserClaims(values.uid, claims);
  if (before.some((role) => !roles.includes(role))) {
    await auth.revokeRefreshTokens(values.uid);
  }
  console.log('Roles set.');
})();
