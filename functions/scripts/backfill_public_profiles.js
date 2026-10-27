// reads every user document and needs npm run build first, add --dry-run to count without writing

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
const { syncPublicProfile } = require('../lib/profiles/public_profile');
const db = admin.firestore();
db.settings({ projectId });

const PAGE_SIZE = 300;
const CONCURRENCY = 20;
const dryRun = process.argv.includes('--dry-run');

async function writeProfiles(docs) {
  for (let i = 0; i < docs.length; i += CONCURRENCY) {
    await Promise.all(docs.slice(i, i + CONCURRENCY).map((doc) => syncPublicProfile(doc.id)));
  }
}

(async function main() {
  const query = db.collection('users')
    .orderBy(admin.firestore.FieldPath.documentId())
    .select()
    .limit(PAGE_SIZE);
  let page = await query.get();
  let users = 0;

  while (!page.empty) {
    if (!dryRun) await writeProfiles(page.docs);
    users += page.size;
    page = await query.startAfter(page.docs[page.size - 1]).get();
  }

  console.log(`users=${users}`);
  process.exit(0);
})();
