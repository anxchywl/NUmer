/**
 * Backfill aggregates for existing studySessions.
 *
 * WARNING: This script can perform many reads/writes. Run only when you
 * understand the cost implications. To run locally against production
 * credentials provide a service account or run in a safe context.
 *
 * Usage:
 *   FORCE_BACKFILL=1 node scripts/backfill.js
 */

const admin = require('firebase-admin');

if (!process.env.FORCE_BACKFILL) {
  console.error('Backfill disabled. Set FORCE_BACKFILL=1 to run.');
  process.exit(1);
}

admin.initializeApp();
const db = admin.firestore();

function startOfDay(d) {
  // Return start of day in UTC
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), 0, 0, 0));
}

(async function main() {
  console.log('Starting backfill...');
  const groupsSnap = await db.collection('groups').get();
  const now = new Date();
  const todayStart = startOfDay(now);
  const last7Start = new Date(todayStart.getTime() - 6 * 24 * 3600 * 1000);
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);

  for (const groupDoc of groupsSnap.docs) {
    const groupId = groupDoc.id;
    console.log('Processing group', groupId);
    const membersSnap = await groupDoc.ref.collection('members').get();
    const memberIds = membersSnap.docs.map(d => d.id);
    for (const userId of memberIds) {
      console.log('  Aggregating for user', userId);
      const sessionsSnap = await db.collection('users').doc(userId)
        .collection('sessions')
        .where('startUtc', '>=', admin.firestore.Timestamp.fromDate(monthStart))
        .get();

      let totalToday = 0, total7 = 0, totalMonth = 0;
      const dailyMap = new Map();

      sessionsSnap.docs.forEach(sdoc => {
        const sd = sdoc.data();
        const ts = sd.startUtc;
        const seconds = (sd.seconds || 0);
        const deleted = (sd.deleted || false);
        if (!ts || deleted || seconds <= 0) return;
        const dt = ts.toDate();
        const dayKey = dt.toISOString().slice(0,10);
        dailyMap.set(dayKey, (dailyMap.get(dayKey) || 0) + seconds);
        if (dt >= monthStart) totalMonth += seconds;
        if (dt >= last7Start) total7 += seconds;
        if (dt >= todayStart) totalToday += seconds;
      });

      const dailyBreakdown = [];
      for (let d = new Date(monthStart); d <= now; d.setDate(d.getDate() + 1)) {
        const key = new Date(d).toISOString().slice(0,10);
        dailyBreakdown.push({ date: key, seconds: dailyMap.get(key) || 0 });
      }

      const profileSnap = await db.collection('users').doc(userId).get();
      const profile = profileSnap.data() || {};
      const name = profile.profileName || '';
      const avatarIndex = profile.profileAvatarIndex || null;
      const avatarColorValue = profile.avatarColorValue || 0xFF6366F1;

      const aggregatePayload = {
        userId,
        name,
        avatarIndex,
        avatarColorValue,
        totals: {
          today: totalToday,
          last7Days: total7,
          lastMonth: totalMonth,
        },
        dailyBreakdown,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const ref = db.collection('groups').doc(groupId).collection('aggregates').doc(userId);
      await ref.set(aggregatePayload, { merge: true });
    }
  }

  console.log('Backfill complete.');
  process.exit(0);
})();
