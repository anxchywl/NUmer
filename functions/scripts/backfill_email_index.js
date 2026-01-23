/**
 * Backfill email index and emailVerified flag for existing users.
 *
 * WARNING: Reads all auth users + user docs. Run only when you understand cost.
 *
 * Usage (from functions/): FORCE_BACKFILL=1 node scripts/backfill_email_index.js
 */

const admin = require('firebase-admin');

if (!process.env.FORCE_BACKFILL) {
  console.error('Backfill disabled. Set FORCE_BACKFILL=1 to run.');
  process.exit(1);
}

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

const BATCH_SIZE = 300;

function normalizeEmail(email) {
  return (email || '').trim().toLowerCase();
}

async function processBatch(nextPageToken) {
  const listResult = await auth.listUsers(BATCH_SIZE, nextPageToken);
  console.log(`Fetched ${listResult.users.length} users`);

  const batch = db.batch();
  let writes = 0;

  for (const user of listResult.users) {
    const email = normalizeEmail(user.email);
    if (!email) continue;

    // email_index/{emailLower} -> { uid, email, updatedAt }
    const idxRef = db.collection('email_index').doc(email);
    batch.set(
      idxRef,
      {
        uid: user.uid,
        email,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    writes++;

    // users/{uid}.emailVerified = user.emailVerified (merge)
    const userRef = db.collection('users').doc(user.uid);
    batch.set(
      userRef,
      { emailVerified: user.emailVerified ?? false, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
    writes++;
  }

  if (writes > 0) {
    await batch.commit();
    console.log(`Committed ${writes} writes`);
  } else {
    console.log('No writes in this batch');
  }

  if (listResult.pageToken) {
    await processBatch(listResult.pageToken);
  }
}

(async function main() {
  console.log('Starting backfill_email_index...');
  await processBatch();
  console.log('Done.');
  process.exit(0);
})();
