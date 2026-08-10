// سكريبت لمسح كل بيانات الطلبة من Firestore
// الاستخدام: node delete_all_students.js

const admin = require('firebase-admin');
const serviceAccount = require('./mybus-5a992-firebase-adminsdk-fbsvc-faa489a772.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const COLLECTION_NAME = 'students';
const BATCH_SIZE = 400; // Firestore batch limit is 500

async function deleteCollection(collectionPath, batchSize) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.limit(batchSize);

  let totalDeleted = 0;

  await new Promise((resolve, reject) => {
    deleteQueryBatch(query, batchSize, resolve, reject, (count) => {
      totalDeleted += count;
    });
  });

  return totalDeleted;
}

async function deleteQueryBatch(query, batchSize, resolve, reject, onCount) {
  try {
    const snapshot = await query.get();

    if (snapshot.size === 0) {
      resolve();
      return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    onCount(snapshot.size);
    console.log(`تم حذف ${snapshot.size} مستند...`);

    // استمر في الحذف حتى ينتهي الـ collection
    process.nextTick(() => {
      deleteQueryBatch(query, batchSize, resolve, reject, onCount);
    });
  } catch (err) {
    reject(err);
  }
}

async function main() {
  console.log(`جاري حذف كل المستندات من collection: "${COLLECTION_NAME}" ...`);
  const total = await deleteCollection(COLLECTION_NAME, BATCH_SIZE);
  console.log(`تم الانتهاء. إجمالي المستندات المحذوفة: ${total ?? 'غير محدد'}`);
  process.exit(0);
}

main().catch((err) => {
  console.error('حصل خطأ أثناء الحذف:', err);
  process.exit(1);
});
