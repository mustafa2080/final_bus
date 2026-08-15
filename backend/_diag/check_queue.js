const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.join(__dirname, '..', 'serviceAccountKey.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function main() {
  console.log('=== fcm_queue status counts (last 100) ===');
  const queueSnap = await db.collection('fcm_queue')
    .orderBy('createdAt', 'desc')
    .limit(100)
    .get();

  const counts = {};
  const samples = [];
  queueSnap.forEach(doc => {
    const d = doc.data();
    counts[d.status] = (counts[d.status] || 0) + 1;
    if (samples.length < 15) {
      samples.push({
        id: doc.id,
        status: d.status,
        recipientId: d.recipientId,
        title: d.title,
        error: d.error,
        createdAt: d.createdAt ? d.createdAt.toDate().toISOString() : null,
        sentAt: d.sentAt ? d.sentAt.toDate().toISOString() : null,
      });
    }
  });
  console.log('Counts:', counts);
  console.log('Total fetched:', queueSnap.size);
  console.log('\nSample docs (most recent first):');
  console.log(JSON.stringify(samples, null, 2));
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
