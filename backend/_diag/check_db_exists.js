const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

(async () => {
  try {
    console.log('Project ID:', serviceAccount.project_id);

    const collections = ['users', 'notifications', 'fcm_queue', 'students'];
    for (const name of collections) {
      const snap = await db.collection(name).limit(3).get();
      console.log(`\n=== ${name} ===`);
      console.log('count (first 3 fetched):', snap.size);
      snap.forEach(doc => console.log(' -', doc.id));
    }

    process.exit(0);
  } catch (e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
