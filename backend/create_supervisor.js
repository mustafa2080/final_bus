/**
 * سكريبت إضافة حساب مشرف (Supervisor) مباشرة في Firebase
 * الاستخدام: node create_supervisor.js
 * أو مع بيانات مخصصة:
 * node create_supervisor.js "email@example.com" "password123" "اسم المشرف" "01000000000"
 */

const admin = require('firebase-admin');
const serviceAccount = require('./mybus-5a992-firebase-adminsdk-fbsvc-faa489a772.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db = admin.firestore();

// بيانات المشرف - تقدر تغيرها من هنا أو تمررها كـ arguments
const email = process.argv[2] || 'supervisor@mybus.com';
const password = process.argv[3] || 'supervisor123456';
const name = process.argv[4] || 'أحمد المشرف';
const phone = process.argv[5] || '0507654321';

async function createSupervisor() {
  try {
    console.log(`🔄 جاري إنشاء حساب المشرف: ${email} ...`);

    let userRecord;

    // تحقق هل اليوزر موجود بالفعل في Auth
    try {
      userRecord = await auth.getUserByEmail(email);
      console.log(`⚠️ اليوزر موجود بالفعل في Firebase Auth (uid: ${userRecord.uid})، هيتم فقط تحديث/إضافة بياناته في Firestore.`);
    } catch (err) {
      if (err.code === 'auth/user-not-found') {
        // إنشاء يوزر جديد في Firebase Auth
        userRecord = await auth.createUser({
          email,
          password,
          displayName: name,
        });
        console.log(`✅ تم إنشاء اليوزر في Firebase Auth (uid: ${userRecord.uid})`);
      } else {
        throw err;
      }
    }

    // إنشاء/تحديث الـ document في Firestore بنفس شكل UserModel
    const now = admin.firestore.Timestamp.now();
    const userDoc = {
      id: userRecord.uid,
      email,
      name,
      phone,
      userType: 'supervisor',
      createdAt: now,
      updatedAt: now,
      isActive: true,
    };

    await db.collection('users').doc(userRecord.uid).set(userDoc, { merge: true });

    console.log('✅ تم حفظ بيانات المشرف في Firestore بنجاح');
    console.log('----------------------------------------');
    console.log(`📧 البريد الإلكتروني: ${email}`);
    console.log(`🔑 كلمة المرور: ${password}`);
    console.log(`👤 الاسم: ${name}`);
    console.log(`📱 الهاتف: ${phone}`);
    console.log(`🆔 UID: ${userRecord.uid}`);
    console.log('----------------------------------------');
    process.exit(0);
  } catch (error) {
    console.error('❌ حدث خطأ أثناء إنشاء حساب المشرف:', error);
    process.exit(1);
  }
}

createSupervisor();
