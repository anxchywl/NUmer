// needs npm run build and GOOGLE_APPLICATION_CREDENTIALS
const { readFileSync } = require('node:fs');
const { parseArgs } = require('node:util');
const admin = require('firebase-admin');
const { parseAnnouncement } = require('../lib/feed/announcement_input');

(async function main() {
  const { values } = parseArgs({
    options: {
      file: { type: 'string' },
      retract: { type: 'string' },
      'dry-run': { type: 'boolean', default: false },
    },
  });
  if (!values.file === !values.retract) {
    console.error('Usage: node scripts/publish_announcement.js (--file <json> | --retract <id>) [--dry-run]');
    process.exit(1);
  }
  const input = values.file && parseAnnouncement(JSON.parse(readFileSync(values.file, 'utf8')), Date.now());
  console.log(input ? JSON.stringify(input, null, 2) : `retract: ${values.retract}`);

  if (values['dry-run']) {
    console.log('Dry run, nothing changed.');
    return;
  }
  admin.initializeApp();
  const announcements = admin.firestore().collection('announcements');
  const { FieldValue, Timestamp } = admin.firestore;
  if (!input) {
    await announcements.doc(values.retract).update({
      retracted: true,
      retractedAt: FieldValue.serverTimestamp(),
      retractedBy: 'owner-script',
    });
    console.log(values.retract);
    return;
  }
  const { expiresAt, ...fields } = input;
  const ref = await announcements.add({
    ...fields,
    ...(expiresAt !== undefined && { expiresAt: Timestamp.fromMillis(expiresAt) }),
    publishedAt: FieldValue.serverTimestamp(),
    authorUid: 'owner-script',
    retracted: false,
  });
  console.log(ref.id);
})();
