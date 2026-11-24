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
const { toPublicProfile } = require('../lib/profiles/public_profile');
const db = admin.firestore();
db.settings({ projectId });

const PAGE_SIZE = 300;
// a commit is capped at 10 MiB and legacy avatars are large
const MAX_BATCH_IMAGE_LENGTH = 8000000;
const dryRun = process.argv.includes('--dry-run');

async function writeProfiles(docs) {
  let batch = db.batch();
  let imageLength = 0;
  for (const doc of docs) {
    const profile = toPublicProfile(doc.data());
    const length = profile.avatarImageBase64?.length ?? 0;
    if (imageLength + length > MAX_BATCH_IMAGE_LENGTH) {
      await batch.commit();
      batch = db.batch();
      imageLength = 0;
    }
    imageLength += length;
    batch.set(db.collection('publicProfiles').doc(doc.id), {
      ...profile,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

(async function main() {
  const query = db.collection('users')
    .orderBy(admin.firestore.FieldPath.documentId())
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
