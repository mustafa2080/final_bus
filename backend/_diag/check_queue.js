const admin = require('firebase-admin');
const path = require('path');
admin.initializeApp({
  credential: admin.credential.cert(require(path.join(__dirname, '..', 'serviceAccountKey.json')))
});
const db = admin.firestore();

db.collection('fcm_queue').orderBy('createdAt', 'desc').limit(10).get()
  .then(snap => {
    console.log('COUNT:', snap.size);
    snap.forEach(doc => {
      const d = doc.data();
      console.log('---');
      console.log('id:', doc.id);
      console.log('status:', d.status);
      console.log('recipientId:', d.recipientId);
      console.log('title:', d.title);
      console.log('createdAt:', d.createdAt ? d.createdAt.toDate() : null);
      console.log('error:', d.error || null);
    });
    process.exit(0);
  })
  .catch(e => {
    console.error('ERROR:', e.message);
    process.exit(1);
  });
