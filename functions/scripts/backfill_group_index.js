// reads every membership document and needs npm run build first, add --dry-run to count without writing

const admin = require('firebase-admin');

if (process.env.FORCE_BACKFILL !== '1') {
  console.error('Backfill disabled. Set FORCE_BACKFILL=1 to run.');
  process.exit(1);
}

const projectId = process.env.GCLOUD_PROJECT;
if (!projectId) {
  console.error('Set GCLOUD_PROJECT to the target project id.');
  process.exit(1);
}

const emulator = process.env.FIRESTORE_EMULATOR_HOST;
console.log(emulator ? `target=emulator ${emulator}` : `target=project ${projectId}`);

// the built module initialises the default app on require
const { collectMemberships, syncGroupIndex } = require('../lib/groups/membership_index');
admin.firestore().settings({ projectId });

const CONCURRENCY = 20;
const dryRun = process.argv.includes('--dry-run');

async function writeIndex(entries) {
  for (let i = 0; i < entries.length; i += CONCURRENCY) {
    const chunk = entries.slice(i, i + CONCURRENCY);
    await Promise.all(chunk.map(([uid, groupIds]) => syncGroupIndex(uid, groupIds)));
  }
}

(async function main() {
  const entries = [...(await collectMemberships())];
  if (!dryRun) await writeIndex(entries);
  const joined = entries.filter(([, groupIds]) => groupIds.length > 0);
  const memberships = joined.reduce((total, [, groupIds]) => total + groupIds.length, 0);
  console.log(`users=${joined.length} memberships=${memberships}`);
  process.exit(0);
})();
