// reads every membership document, add --dry-run to count without writing

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

admin.initializeApp({ projectId });
const db = admin.firestore();
db.settings({ projectId });

const BATCH_SIZE = 400;
const dryRun = process.argv.includes('--dry-run');

function isGroupMember(ref) {
  const parent = ref.parent.parent;
  return parent !== null && parent.parent.id === 'groups' && parent.parent.parent === null;
}

async function readMemberships() {
  const snap = await db.collectionGroup('members').get();
  const index = new Map();
  for (const doc of snap.docs) {
    if (!isGroupMember(doc.ref)) continue;
    const groupIds = index.get(doc.id) || [];
    groupIds.push(doc.ref.parent.parent.id);
    index.set(doc.id, groupIds);
  }
  return index;
}

async function writeIndex(entries) {
  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const [uid, groupIds] of entries.slice(i, i + BATCH_SIZE)) {
      batch.set(db.collection('groupIndex').doc(uid), {
        groupIds,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

(async function main() {
  const entries = [...(await readMemberships())];
  if (!dryRun) await writeIndex(entries);
  const memberships = entries.reduce((total, [, groupIds]) => total + groupIds.length, 0);
  console.log(`users=${entries.length} memberships=${memberships}`);
  process.exit(0);
})();
