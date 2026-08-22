const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();
const { CHANNELS, sendFcmNotification } = require('./utils/sendNotification');

// إعداد Express server
const app = express();
const server = http.createServer(app);

// إعداد Socket.IO مع CORS
const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : '*',
    methods: ['GET', 'POST'],
    credentials: true
  }
});

app.use(cors());
app.use(express.json());

// تهيئة Firebase Admin SDK
const serviceAccount = process.env.SERVICE_ACCOUNT_KEY 
  ? JSON.parse(process.env.SERVICE_ACCOUNT_KEY)
  : require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: process.env.FIREBASE_DATABASE_URL
});

const db = admin.firestore();
const messaging = admin.messaging();

console.log('🚀 MyBus Notification Service Started!');
console.log('📡 Listening to Firestore changes...\n');

// ============================================
// 🔥 API Endpoints
// ============================================

// ✅ Endpoint لحذف FCM Token عند Logout
app.post('/api/logout', async (req, res) => {
  try {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ 
        success: false, 
        message: 'userId is required' 
      });
    }
    
    console.log(`\n🚪 ===========================================`);
    console.log(`🚪 طلب Logout من المستخدم: ${userId}`);
    console.log(`===========================================\n`);
    
    // حذف FCM Token من Firestore
    await db.collection('users').doc(userId).update({
      fcmToken: admin.firestore.FieldValue.delete(),
      lastLogout: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ تم حذف FCM Token بنجاح`);
    console.log(`👤 المستخدم: ${userId}`);
    console.log(`⏰ الوقت: ${new Date().toLocaleString('ar-EG')}\n`);
    
    res.json({ 
      success: true, 
      message: 'FCM Token deleted successfully' 
    });
    
  } catch (error) {
    console.error('❌ خطأ في حذف FCM Token:', error.message);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
});

// ✅ Endpoint لتحديث FCM Token عند Login
app.post('/api/updateToken', async (req, res) => {
  try {
    const { userId, fcmToken } = req.body;
    
    if (!userId || !fcmToken) {
      return res.status(400).json({ 
        success: false, 
        message: 'userId and fcmToken are required' 
      });
    }
    
    console.log(`\n🔑 ===========================================`);
    console.log(`🔑 تحديث FCM Token للمستخدم: ${userId}`);
    console.log(`📱 Token: ${fcmToken.substring(0, 30)}...`);
    console.log(`===========================================\n`);
    
    // تحديث FCM Token في Firestore
    await db.collection('users').doc(userId).update({
      fcmToken: fcmToken,
      lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ تم تحديث FCM Token بنجاح`);
    console.log(`⏰ الوقت: ${new Date().toLocaleString('ar-EG')}\n`);
    
    res.json({ 
      success: true, 
      message: 'FCM Token updated successfully' 
    });
    
  } catch (error) {
    console.error('❌ خطأ في تحديث FCM Token:', error.message);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    notifications: {
      sent: notificationsSent,
      failed: notificationsFailed
    }
  });
});

// ============================================
// 🗺️ Socket.IO - Live Bus Tracking
// ============================================

// تخزين مؤقت لمواقع الباصات النشطة
const activeBuses = new Map();
// Map structure: busId => { location, timestamp, supervisorId, socketId, students }

// تخزين اشتراكات أولياء الأمور
const parentSubscriptions = new Map();
// Map structure: socketId => { userId, busIds: Set() }

console.log('\n🔌 ===========================================');
console.log('🔌 Socket.IO Server Initializing...');
console.log('===========================================\n');

io.on('connection', (socket) => {
  console.log(`\n✅ عميل جديد متصل: ${socket.id}`);
  console.log(`📊 إجمالي الاتصالات النشطة: ${io.engine.clientsCount}`);
  
  // ====================================
  // 🚌 السوبرفايزر: بدء تتبع الباص
  // ====================================
  socket.on('supervisor:startTracking', async (data) => {
    try {
      const { busId, supervisorId, latitude, longitude } = data;
      
      console.log(`\n🚌 ===========================================`);
      console.log(`🚌 بدء تتبع باص جديد`);
      console.log(`🆔 Bus ID: ${busId}`);
      console.log(`👤 Supervisor ID: ${supervisorId}`);
      console.log(`📍 الموقع الأولي: [${latitude}, ${longitude}]`);
      console.log(`===========================================\n`);
      
      // جلب بيانات الباص من Firestore
      const busDoc = await db.collection('buses').doc(busId).get();
      
      if (!busDoc.exists) {
        console.log(`❌ الباص غير موجود: ${busId}`);
        socket.emit('error', { message: 'Bus not found' });
        return;
      }
      
      const busData = busDoc.data();
      
      // جلب الطلاب المسجلين في هذا الباص
      const studentsSnapshot = await db.collection('students')
        .where('busId', '==', busId)
        .get();
      
      const studentsList = [];
      studentsSnapshot.forEach(doc => {
        studentsList.push({
          id: doc.id,
          name: doc.data().name,
          parentId: doc.data().parentId
        });
      });
      
      console.log(`👥 عدد الطلاب في الباص: ${studentsList.length}`);
      
      // حفظ بيانات الباص النشط
      activeBuses.set(busId, {
        busId,
        supervisorId,
        socketId: socket.id,
        location: { latitude, longitude },
        timestamp: Date.now(),
        busNumber: busData.busNumber || busId,
        driverName: busData.driverName || 'غير محدد',
        students: studentsList,
        isTracking: true
      });
      
      // تحديث حالة الباص في Firestore
      await db.collection('buses').doc(busId).update({
        isTracking: true,
        lastLocation: {
          latitude,
          longitude,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        },
        currentSupervisorId: supervisorId
      });
      
      // انضمام السوبرفايزر لغرفة الباص
      socket.join(`bus:${busId}`);
      
      console.log(`✅ السوبرفايزر انضم لغرفة: bus:${busId}`);
      console.log(`📊 الباصات النشطة: ${activeBuses.size}`);
      
      // إرسال تأكيد للسوبرفايزر
      socket.emit('supervisor:trackingStarted', {
        success: true,
        busId,
        studentsCount: studentsList.length,
        message: 'تم بدء التتبع بنجاح'
      });
      
      // إشعار جميع أولياء الأمور المشتركين
      io.to(`bus:${busId}:parents`).emit('bus:trackingStarted', {
        busId,
        busNumber: busData.busNumber,
        location: { latitude, longitude },
        timestamp: Date.now()
      });
      
    } catch (error) {
      console.error(`❌ خطأ في بدء التتبع:`, error.message);
      socket.emit('error', { message: error.message });
    }
  });
  
  // ====================================
  // 📍 السوبرفايزر: تحديث الموقع
  // ====================================
  socket.on('supervisor:updateLocation', async (data) => {
    try {
      const { busId, latitude, longitude, speed, heading } = data;
      
      const busInfo = activeBuses.get(busId);
      
      if (!busInfo) {
        console.log(`⚠️ محاولة تحديث موقع باص غير نشط: ${busId}`);
        return;
      }
      
      // التحقق من أن المرسل هو السوبرفايزر الصحيح
      if (busInfo.socketId !== socket.id) {
        console.log(`⚠️ محاولة غير مصرح بها لتحديث موقع الباص`);
        return;
      }
      
      const now = Date.now();
      const timeDiff = (now - busInfo.timestamp) / 1000; // بالثواني
      
      console.log(`📍 تحديث موقع الباص ${busInfo.busNumber}`);
      console.log(`   الموقع: [${latitude.toFixed(6)}, ${longitude.toFixed(6)}]`);
      console.log(`   السرعة: ${speed || 0} km/h`);
      console.log(`   الوقت منذ آخر تحديث: ${timeDiff.toFixed(1)}s`);
      
      // تحديث البيانات المؤقتة
      busInfo.location = { latitude, longitude };
      busInfo.timestamp = now;
      if (speed !== undefined) busInfo.speed = speed;
      if (heading !== undefined) busInfo.heading = heading;
      
      activeBuses.set(busId, busInfo);
      
      // بث الموقع الجديد لجميع أولياء الأمور المشتركين
      const updateData = {
        busId,
        location: { latitude, longitude },
        speed: speed || 0,
        heading: heading || 0,
        timestamp: now,
        busNumber: busInfo.busNumber
      };
      
      io.to(`bus:${busId}:parents`).emit('bus:locationUpdate', updateData);
      
      // تحديث Firestore كل دقيقة (لتوفير التكلفة)
      if (timeDiff >= 60) {
        await db.collection('buses').doc(busId).update({
          lastLocation: {
            latitude,
            longitude,
            speed: speed || 0,
            heading: heading || 0,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          }
        });
      }
      
    } catch (error) {
      console.error(`❌ خطأ في تحديث الموقع:`, error.message);
    }
  });
  
  // ====================================
  // 🛑 السوبرفايزر: إيقاف التتبع
  // ====================================
  socket.on('supervisor:stopTracking', async (data) => {
    try {
      const { busId } = data;
      
      console.log(`\n🛑 ===========================================`);
      console.log(`🛑 إيقاف تتبع الباص: ${busId}`);
      console.log(`===========================================\n`);
      
      const busInfo = activeBuses.get(busId);
      
      if (busInfo) {
        // تحديث Firestore
        await db.collection('buses').doc(busId).update({
          isTracking: false,
          trackingStoppedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // حذف من الباصات النشطة
        activeBuses.delete(busId);
        
        // إشعار أولياء الأمور
        io.to(`bus:${busId}:parents`).emit('bus:trackingStopped', {
          busId,
          busNumber: busInfo.busNumber,
          timestamp: Date.now()
        });
        
        // مغادرة الغرفة
        socket.leave(`bus:${busId}`);
        
        console.log(`✅ تم إيقاف التتبع بنجاح`);
        console.log(`📊 الباصات النشطة: ${activeBuses.size}`);
        
        socket.emit('supervisor:trackingStopped', {
          success: true,
          message: 'تم إيقاف التتبع'
        });
      }
      
    } catch (error) {
      console.error(`❌ خطأ في إيقاف التتبع:`, error.message);
      socket.emit('error', { message: error.message });
    }
  });
  
  // ====================================
  // 👨‍👩‍👧 ولي الأمر: الاشتراك في تتبع باص
  // ====================================
  socket.on('parent:subscribeToBus', async (data) => {
    try {
      const { userId, busId } = data;
      
      console.log(`\n👨‍👩‍👧 ===========================================`);
      console.log(`👨‍👩‍👧 ولي أمر يشترك في تتبع الباص`);
      console.log(`👤 User ID: ${userId}`);
      console.log(`🚌 Bus ID: ${busId}`);
      console.log(`===========================================\n`);
      
      // التحقق من أن ولي الأمر له طالب في هذا الباص
      const studentsSnapshot = await db.collection('students')
        .where('parentId', '==', userId)
        .where('busId', '==', busId)
        .get();
      
      if (studentsSnapshot.empty) {
        console.log(`⚠️ ولي الأمر ليس لديه طالب في هذا الباص`);
        socket.emit('error', { message: 'You have no student in this bus' });
        return;
      }
      
      // حفظ الاشتراك
      let subscription = parentSubscriptions.get(socket.id);
      if (!subscription) {
        subscription = { userId, busIds: new Set() };
      }
      subscription.busIds.add(busId);
      parentSubscriptions.set(socket.id, subscription);
      
      // الانضمام لغرفة أولياء الأمور
      socket.join(`bus:${busId}:parents`);
      
      console.log(`✅ ولي الأمر انضم لغرفة: bus:${busId}:parents`);
      console.log(`📊 اشتراكات ولي الأمر: ${subscription.busIds.size} باص`);
      
      // إرسال الموقع الحالي إذا كان الباص نشط
      const busInfo = activeBuses.get(busId);
      if (busInfo) {
        console.log(`📍 إرسال الموقع الحالي للباص`);
        socket.emit('bus:currentLocation', {
          busId,
          busNumber: busInfo.busNumber,
          location: busInfo.location,
          speed: busInfo.speed || 0,
          heading: busInfo.heading || 0,
          timestamp: busInfo.timestamp,
          isTracking: true
        });
      } else {
        // إرسال آخر موقع معروف من Firestore
        const busDoc = await db.collection('buses').doc(busId).get();
        if (busDoc.exists) {
          const busData = busDoc.data();
          socket.emit('bus:currentLocation', {
            busId,
            busNumber: busData.busNumber,
            location: busData.lastLocation || null,
            isTracking: false,
            message: 'الباص غير نشط حالياً'
          });
        }
      }
      
      socket.emit('parent:subscribed', {
        success: true,
        busId,
        message: 'تم الاشتراك في تتبع الباص'
      });
      
    } catch (error) {
      console.error(`❌ خطأ في الاشتراك:`, error.message);
      socket.emit('error', { message: error.message });
    }
  });
  
  // ====================================
  // 🔕 ولي الأمر: إلغاء الاشتراك
  // ====================================
  socket.on('parent:unsubscribeFromBus', (data) => {
    try {
      const { busId } = data;
      
      console.log(`\n🔕 ولي أمر يلغي اشتراكه من الباص: ${busId}`);
      
      const subscription = parentSubscriptions.get(socket.id);
      if (subscription) {
        subscription.busIds.delete(busId);
        if (subscription.busIds.size === 0) {
          parentSubscriptions.delete(socket.id);
        }
      }
      
      socket.leave(`bus:${busId}:parents`);
      
      console.log(`✅ تم إلغاء الاشتراك`);
      
      socket.emit('parent:unsubscribed', {
        success: true,
        busId
      });
      
    } catch (error) {
      console.error(`❌ خطأ في إلغاء الاشتراك:`, error.message);
    }
  });
  
  // ====================================
  // 📊 طلب قائمة الباصات النشطة
  // ====================================
  socket.on('getActiveBuses', () => {
    const buses = [];
    activeBuses.forEach((busInfo) => {
      buses.push({
        busId: busInfo.busId,
        busNumber: busInfo.busNumber,
        location: busInfo.location,
        studentsCount: busInfo.students.length,
        isTracking: busInfo.isTracking,
        timestamp: busInfo.timestamp
      });
    });
    
    socket.emit('activeBuses', buses);
    console.log(`📊 تم إرسال قائمة ${buses.length} باص نشط`);
  });
  
  // ====================================
  // 🔌 قطع الاتصال
  // ====================================
  socket.on('disconnect', async () => {
    console.log(`\n❌ عميل قطع الاتصال: ${socket.id}`);
    
    // التحقق إذا كان سوبرفايزر
    let disconnectedBus = null;
    activeBuses.forEach((busInfo, busId) => {
      if (busInfo.socketId === socket.id) {
        disconnectedBus = { busId, busInfo };
      }
    });
    
    if (disconnectedBus) {
      const { busId, busInfo } = disconnectedBus;
      console.log(`⚠️ سوبرفايزر انقطع - إيقاف تتبع الباص: ${busId}`);
      
      // تحديث Firestore
      await db.collection('buses').doc(busId).update({
        isTracking: false,
        disconnectedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // حذف من الباصات النشطة
      activeBuses.delete(busId);
      
      // إشعار أولياء الأمور
      io.to(`bus:${busId}:parents`).emit('bus:trackingStopped', {
        busId,
        busNumber: busInfo.busNumber,
        reason: 'supervisor_disconnected',
        timestamp: Date.now()
      });
    }
    
    // حذف اشتراكات ولي الأمر
    parentSubscriptions.delete(socket.id);
    
    console.log(`📊 الاتصالات النشطة: ${io.engine.clientsCount}`);
    console.log(`📊 الباصات النشطة: ${activeBuses.size}\n`);
  });
});

// Start Express + Socket.IO server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`\n🎉 ===========================================`);
  console.log(`🌐 API Server running on port ${PORT}`);
  console.log(`🔌 Socket.IO Server ready`);
  console.log(`📍 Endpoints:`);
  console.log(`   POST http://localhost:${PORT}/api/logout`);
  console.log(`   POST http://localhost:${PORT}/api/updateToken`);
  console.log(`   GET  http://localhost:${PORT}/health`);
  console.log(`🔌 Socket.IO:`);
  console.log(`   ws://localhost:${PORT}`);
  console.log(`===========================================\n`);
});

// عداد للإشعارات المرسلة
let notificationsSent = 0;
let notificationsFailed = 0;

// ============================================
// 🔥 الأهم: مراقبة fcm_queue لإرسال الإشعارات الحقيقية
// ============================================
// ملحوظة (17/8/2026): تبين إن Railway وCloud Functions مش شغالين أصلاً في
// هذا الإعداد - المصدر الوحيد اللي بيبعت push حقيقي هو تشغيل هذا الملف
// يدويًا (node index.js) من التيرمينال. المشكلة اللي سببت التكرار قبل
// كده مش كانت Cloud Function متوازية، لكن احتمال تشغيل أكتر من نسخة من
// هذا الملف في نفس الوقت بالغلط (نافذة تيرمينال قديمة منسية + نافذة
// جديدة). عشان كده أضفنا حماية transaction تحت (claimQueueItem) بتضمن
// إن كل عنصر في fcm_queue يتعالج مرة واحدة بس مهما كان عدد النسخ الشغالة
// بالتوازي - بدل ما نعتمد على الانضباط اليدوي في تشغيل نسخة واحدة بس.
const fcmQueueRef = db.collection('fcm_queue');

console.log('👀 بدء مراقبة fcm_queue...');

/// يحاول "يحجز" معالجة عنصر الـ queue عن طريق إنشاء مستند في
/// notification_deliveries بمفتاح deduplicationKey داخل transaction.
/// لو المستند موجود بالفعل (نسخة تانية من هذا الملف سبقتنا وحجزته)،
/// الـ transaction بترجع false ومنعالجش العنصر تاني - كده مهما كان
/// عدد نسخ node index.js الشغالة بالتوازي، كل حدث بيتبعت مرة واحدة بس.
async function claimQueueItem(deduplicationKey, queueId, recipientId) {
  if (!deduplicationKey) return true; // مفيش مفتاح؟ نكمل عادي (توافق قديم)
  const deliveryRef = db.collection('notification_deliveries').doc(deduplicationKey);
  try {
    return await db.runTransaction(async (transaction) => {
      const delivery = await transaction.get(deliveryRef);
      if (delivery.exists) return false;
      transaction.set(deliveryRef, {
        queueId,
        recipientId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 2 * 60 * 1000),
      });
      return true;
    });
  } catch (error) {
    console.error('❌ خطأ في حجز عنصر fcm_queue:', error.message);
    return true; // فشل الحجز نفسه (مش تكرار) - كمل بدل ما نضيع إشعار
  }
}

fcmQueueRef.onSnapshot(async (snapshot) => {
  if (snapshot.empty) {
    console.log('📭 fcm_queue فارغة - لا توجد إشعارات في الانتظار');
  }
  
  snapshot.docChanges().forEach(async (change) => {
    if (change.type === 'added') {
      const queueItem = change.doc.data();
      const queueId = change.doc.id;
      
      console.log('\n🔔 ===========================================');
      console.log('📥 إشعار جديد في fcm_queue!');
      console.log('🆔 Queue ID:', queueId);
      console.log('👤 المستلم:', queueItem.recipientId);
      console.log('📝 العنوان:', queueItem.title);
      console.log('💬 المحتوى:', queueItem.body);
      console.log('📊 Status:', queueItem.status);
      console.log('===========================================\n');
      
      // تحقق من أن الإشعار pending وليس مرسل
      if (queueItem.status !== 'pending') {
        console.log(`⏭️  تخطي الإشعار - الحالة: ${queueItem.status}`);
        return;
      }

      // حجز العنصر قبل أي معالجة - بيمنع أي نسخة تانية شغالة بالتوازي
      // من إرسال نفس الإشعار تاني (شوف الشرح فوق claimQueueItem)
      const claimed = await claimQueueItem(
        queueItem.deduplicationKey,
        queueId,
        queueItem.recipientId
      );
      if (!claimed) {
        console.log(`⏭️ إشعار مكرر تم تجاهله (نسخة تانية شغالة سبقتنا): ${queueId}`);
        await db.collection('fcm_queue').doc(queueId).update({
          status: 'skipped_duplicate',
          skippedAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});
        return;
      }
      
      try {
        // تحديث الحالة إلى processing
        console.log('⚙️  تغيير الحالة إلى processing...');
        await db.collection('fcm_queue').doc(queueId).update({
          status: 'processing',
          processedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // جلب FCM Token للمستخدم المستهدف
        console.log('🔍 البحث عن المستخدم في Firestore...');
        const userDoc = await db.collection('users').doc(queueItem.recipientId).get();
        
        if (!userDoc.exists) {
          console.log(`❌ المستخدم غير موجود: ${queueItem.recipientId}`);
          await db.collection('fcm_queue').doc(queueId).update({
            status: 'failed',
            error: 'User not found',
            failedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          notificationsFailed++;
          return;
        }
        
        const userData = userDoc.data();
        console.log('✅ المستخدم موجود:', userData.email || userData.name || queueItem.recipientId);
        
        const fcmToken = userData.fcmToken;
        
        // ملحوظة: الحفظ في notifications (in-app) بيحصل جوه sendFcmNotification
        // نفسها، سواء التوكن موجود أو لأ - فمفيش داعي نكرره هنا زي قبل كده.
        // بنمرر deduplicationKey (لو موجودة في الـ queue item) عشان الكتابة هنا
        // تتطابق مع النسخة اللي الفلاتر كتبتها فورًا وقت الإرسال - مفيش تكرار.
        const result = await sendFcmNotification(admin, db, {
          recipientId: queueItem.recipientId,
          fcmToken,
          title: queueItem.title || 'إشعار جديد',
          body: queueItem.body || '',
          type: queueItem.data?.type || 'general',
          channelId: queueItem.data?.channelId || CHANNELS.GENERAL,
          data: queueItem.data || {},
          priority: queueItem.priority === 'high' ? 'high' : 'normal',
          deduplicationKey: queueItem.deduplicationKey,
        });

        if (result.sent) {
          console.log('✅ ✅ ✅ إشعار مرسل بنجاح! ✅ ✅ ✅');
          console.log('📨 Message ID:', result.messageId);
          await db.collection('fcm_queue').doc(queueId).update({
            status: 'sent',
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            messageId: result.messageId
          });
          notificationsSent++;
        } else {
          console.log(`⚠️ لم يتم إرسال push (${result.reason}) - لكن تم حفظ نسخة in-app`);
          await db.collection('fcm_queue').doc(queueId).update({
            status: 'failed',
            error: result.reason,
            failedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          notificationsFailed++;
        }

        console.log(`\n📊 إحصائيات: ${notificationsSent} مرسل | ${notificationsFailed} فشل\n`);
        
      } catch (error) {
        console.error('❌ ❌ ❌ خطأ في إرسال الإشعار:');
        console.error('📛 Error:', error.message);
        console.error('📛 Code:', error.code);
        
        // تحديث الحالة إلى failed
        await db.collection('fcm_queue').doc(queueId).update({
          status: 'failed',
          error: error.message,
          errorCode: error.code,
          failedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        notificationsFailed++;
      }
    }
  });
}, (error) => {
  console.error('❌ ❌ ❌ خطأ كبير في مراقبة fcm_queue:', error);
  console.error('تأكد من صلاحيات Firestore Rules!');
});

// ============================================
// 1️⃣ مراقبة الرحلات (Trips) - تم إلغاؤها عن قصد
// ============================================
// ⚠️ هذا الـ listener اتشال لأنه كان بيسبب إشعارات مكررة.
// التطبيق (Flutter) بيبعت إشعار "ركب الباص/وصل المدرسة" مباشرة
// عن طريق fcm_queue من خلال SimpleFCMService، ومفيش أي مكان في
// التطبيق بينادي addTrip() أصلاً - فالـ listener ده كان شغال
// بدون فايدة أو كان هيسبب تكرار لو حد رجّع استخدام addTrip() تاني.
// لو حبينا نرجعه مستقبلاً، لازم يبعت عن طريق fcm_queue بدل
// ما يبني ويبعت رسالة FCM لوحده.

// ============================================
// 2️⃣ مراقبة طلبات الغياب (Absences)
// ============================================
const absencesRef = db.collection('absences');

console.log('👀 بدء مراقبة absences...');

absencesRef.onSnapshot(async (snapshot) => {
  snapshot.docChanges().forEach(async (change) => {
    if (change.type === 'added') {
      const absence = change.doc.data();
      const absenceId = change.doc.id;
      
      console.log(`\n📝 طلب غياب جديد: ${absenceId}`);
      
      try {
        // إرسال إشعار للإدمن والمشرف
        const admins = await db.collection('users')
          .where('userType', 'in', ['admin', 'supervisor'])
          .get();
        
        for (const adminDoc of admins.docs) {
          const adminUser = adminDoc.data();
          
          const result = await sendFcmNotification(admin, db, {
            recipientId: adminDoc.id,
            fcmToken: adminUser.fcmToken,
            title: '📝 طلب غياب جديد',
            body: `طلب غياب جديد من ${absence.studentName || 'طالب'}`,
            type: 'absenceRequested',
            channelId: CHANNELS.GENERAL,
            data: {
              absenceId,
              studentId: absence.studentId || '',
            },
          });

          if (result.sent) {
            console.log(`   ✅ إشعار غياب مرسل للمسؤول: ${adminDoc.id}`);
          } else {
            console.log(`   ⚠️ لم يتم إرسال push للمسؤول ${adminDoc.id} (${result.reason})`);
          }
        }
        
      } catch (error) {
        console.error(`   ❌ خطأ في إرسال إشعار الغياب:`, error.message);
      }
    }
    
    // مراقبة تحديثات حالة الغياب (موافقة/رفض)
    if (change.type === 'modified') {
      const absence = change.doc.data();
      const oldAbsence = change.oldIndex >= 0 ? snapshot.docs[change.oldIndex].data() : null;
      
      // إذا تغيرت الحالة
      if (oldAbsence && absence.status !== oldAbsence.status && absence.status !== 'pending') {
        console.log(`\n📝 تحديث حالة الغياب: ${change.doc.id} → ${absence.status}`);
        
        try {
          // إرسال إشعار لولي الأمر
          const parentDoc = await db.collection('users').doc(absence.parentId).get();
          
          if (parentDoc.exists) {
            const parent = parentDoc.data();
            const isApproved = absence.status === 'approved';

            const result = await sendFcmNotification(admin, db, {
              recipientId: absence.parentId,
              fcmToken: parent.fcmToken,
              title: isApproved ? '✅ تمت الموافقة على الغياب' : '❌ تم رفض الغياب',
              body: `طلب غياب ${absence.studentName || 'طالبك'} تم ${isApproved ? 'قبوله' : 'رفضه'}`,
              type: isApproved ? 'absenceApproved' : 'absenceRejected',
              channelId: CHANNELS.GENERAL,
              data: {
                absenceId: change.doc.id,
                studentId: absence.studentId || '',
              },
            });

            if (result.sent) {
              console.log(`   ✅ إشعار تحديث غياب مرسل لولي الأمر`);
            } else {
              console.log(`   ⚠️ لم يتم إرسال push لولي الأمر (${result.reason})`);
            }
          }
        } catch (error) {
          console.error(`   ❌ خطأ في إرسال إشعار تحديث الغياب:`, error.message);
        }
      }
    }
  });
}, (error) => {
  console.error('❌ خطأ في مراقبة الغيابات:', error);
});

// ============================================
// 3️⃣ مراقبة الشكاوى (Complaints) - محسّنة
// ============================================
const complaintsRef = db.collection('complaints');

console.log('👀 بدء مراقبة complaints (محسّنة مع مراقبة الردود)...\n');

complaintsRef.onSnapshot(async (snapshot) => {
  snapshot.docChanges().forEach(async (change) => {
    // ====== 1️⃣ شكوى جديدة من ولي الأمر ======
    if (change.type === 'added') {
      const complaint = change.doc.data();
      const complaintId = change.doc.id;
      
      console.log(`\n📢 =====================================`);
      console.log(`📢 شكوى جديدة من ولي الأمر!`);
      console.log(`🆔 Complaint ID: ${complaintId}`);
      console.log(`👤 ولي الأمر: ${complaint.parentName || 'غير معروف'}`);
      console.log(`📝 العنوان: ${complaint.title || 'بدون عنوان'}`);
      console.log(`💬 الوصف: ${(complaint.description || '').substring(0, 100)}...`);
      console.log(`📊 الحالة: ${complaint.status || 'pending'}`);
      console.log(`⚠️ الأولوية: ${complaint.priority || 'normal'}`);
      console.log(`=====================================\n`);
      
      try {
        // إرسال إشعار لجميع الإدمن
        console.log('🔍 البحث عن المسؤولين (Admins)...');
        const admins = await db.collection('users')
          .where('userType', '==', 'admin')
          .where('isActive', '==', true)
          .get();
        
        console.log(`✅ وجدنا ${admins.size} مسؤول`);
        
        let sentCount = 0;
        let failedCount = 0;
        
        for (const adminDoc of admins.docs) {
          const adminUser = adminDoc.data();
          
          console.log(`   📤 محاولة إرسال للإدمن: ${adminUser.name || adminUser.email || adminDoc.id}`);

          const result = await sendFcmNotification(admin, db, {
            recipientId: adminDoc.id,
            fcmToken: adminUser.fcmToken,
            title: '🚨 شكوى جديدة من ولي أمر',
            body: `${complaint.parentName || 'ولي أمر'}: ${complaint.title || 'شكوى جديدة'}`,
            type: 'complaintSubmitted',
            channelId: CHANNELS.COMPLAINTS,
            color: '#FF6B6B',
            data: {
              complaintId,
              parentId: complaint.parentId || '',
              parentName: complaint.parentName || '',
              complaintTitle: complaint.title || '',
              description: complaint.description || '',
              priority: complaint.priority || 'normal',
              navigationRoute: '/admin/complaints',
              navigationParams: JSON.stringify({ complaintId, openDetails: true }),
            },
          });

          if (result.sent) {
            console.log(`   ✅ إشعار شكوى مرسل للإدمن بنجاح! Message ID: ${result.messageId}`);
            sentCount++;
          } else {
            console.log(`   ⚠️ لم يتم إرسال push (${result.reason})`);
            failedCount++;
          }
        }
        
        console.log(`\n📊 إحصائيات إرسال إشعار الشكوى:`);
        console.log(`   ✅ مرسل: ${sentCount}`);
        console.log(`   ❌ فشل: ${failedCount}`);
        console.log(`   📱 إجمالي المسؤولين: ${admins.size}\n`);
        
      } catch (error) {
        console.error(`\n❌ خطأ كبير في إرسال إشعار الشكوى:`);
        console.error(`   Error: ${error.message}`);
        console.error(`   Stack: ${error.stack}\n`);
      }
    }
    
    // ====== 2️⃣ رد الإدمن على الشكوى ======
    if (change.type === 'modified') {
      const newComplaint = change.doc.data();
      const complaintId = change.doc.id;
      
      // الحصول على البيانات القديمة
      const oldDoc = snapshot.docChanges().find(c => c.doc.id === complaintId && c.oldIndex >= 0);
      
      if (!oldDoc) return;
      
      const oldComplaint = oldDoc.doc.data();
      
      // التحقق من وجود رد جديد من الإدمن
      const hasNewResponse = newComplaint.adminResponse && 
                            (!oldComplaint.adminResponse || 
                             oldComplaint.adminResponse !== newComplaint.adminResponse);
      
      const statusChanged = newComplaint.status !== oldComplaint.status;
      
      if (hasNewResponse || statusChanged) {
        console.log(`\n💬 =====================================`);
        console.log(`💬 رد جديد من الإدمن على شكوى!`);
        console.log(`🆔 Complaint ID: ${complaintId}`);
        console.log(`👤 ولي الأمر: ${newComplaint.parentName || 'غير معروف'}`);
        console.log(`📝 عنوان الشكوى: ${newComplaint.title || 'بدون عنوان'}`);
        
        if (hasNewResponse) {
          console.log(`💭 الرد: ${(newComplaint.adminResponse || '').substring(0, 100)}...`);
        }
        
        if (statusChanged) {
          console.log(`📊 الحالة: ${oldComplaint.status || 'pending'} → ${newComplaint.status}`);
        }
        
        console.log(`=====================================\n`);
        
        try {
          const parentId = newComplaint.parentId;
          
          if (!parentId) {
            console.log(`   ⚠️ معرف ولي الأمر غير موجود`);
            return;
          }
          
          console.log(`🔍 البحث عن ولي الأمر: ${parentId}`);
          const parentDoc = await db.collection('users').doc(parentId).get();
          
          if (!parentDoc.exists) {
            console.log(`   ⚠️ ولي الأمر غير موجود في قاعدة البيانات`);
            return;
          }
          
          const parent = parentDoc.data();
          console.log(`✅ ولي الأمر موجود: ${parent.name || parent.email}`);
          
          // تحديد نص الإشعار
          let notificationTitle = '';
          let notificationBody = '';
          
          if (hasNewResponse) {
            notificationTitle = '✅ رد على شكواك';
            notificationBody = `تم الرد على شكوى "${newComplaint.title}". ${(newComplaint.adminResponse || '').substring(0, 50)}...`;
          } else if (statusChanged) {
            switch (newComplaint.status) {
              case 'inProgress':
              case 'in_progress':
                notificationTitle = '⏳ شكواك قيد المعالجة';
                notificationBody = `شكوى "${newComplaint.title}" قيد المعالجة الآن`;
                break;
              case 'resolved':
                notificationTitle = '✅ تم حل شكواك';
                notificationBody = `شكوى "${newComplaint.title}" تم حلها بنجاح`;
                break;
              case 'closed':
                notificationTitle = '🔒 تم إغلاق شكواك';
                notificationBody = `شكوى "${newComplaint.title}" تم إغلاقها`;
                break;
              default:
                notificationTitle = '📝 تحديث على شكواك';
                notificationBody = `تحديث جديد على شكوى "${newComplaint.title}"`;
            }
          }
          
          console.log(`📤 إرسال إشعار موحّد...`);
          console.log(`   📌 العنوان: ${notificationTitle}`);
          console.log(`   💬 المحتوى: ${notificationBody}`);

          const result = await sendFcmNotification(admin, db, {
            recipientId: parentId,
            fcmToken: parent.fcmToken,
            title: notificationTitle,
            body: notificationBody,
            type: 'complaintResponded',
            channelId: CHANNELS.COMPLAINTS,
            color: '#4CAF50',
            data: {
              complaintId,
              complaintTitle: newComplaint.title || '',
              description: newComplaint.description || '',
              response: newComplaint.adminResponse || '',
              status: newComplaint.status || '',
              navigationRoute: '/parent/complaints',
              navigationParams: JSON.stringify({ complaintId, openDetails: true }),
            },
          });

          if (result.sent) {
            console.log(`\n✅ ✅ ✅ إشعار رد الشكوى مرسل بنجاح! Message ID: ${result.messageId} ✅ ✅ ✅`);
          } else {
            console.log(`   ⚠️ لم يتم إرسال push (${result.reason}) - تم حفظ نسخة in-app`);
          }
          
        } catch (error) {
          console.error(`\n❌ خطأ في إرسال إشعار رد الشكوى:`);
          console.error(`   Error: ${error.message}`);
          console.error(`   Code: ${error.code}`);
          console.error(`   Stack: ${error.stack}\n`);
        }
      }
    }
  });
}, (error) => {
  console.error('❌ ❌ ❌ خطأ كبير في مراقبة الشكاوى:', error);
  console.error('تأكد من صلاحيات Firestore Rules!');
});

// ============================================
// 4️⃣ مراقبة تحديثات الطلاب (Students Updates) - محسّنة
// ============================================
const studentsRef = db.collection('students');

console.log('👀 بدء مراقبة students (تغيير الحالة وتحديث البيانات)...\n');

// حفظ البيانات القديمة للمقارنة
const studentOldData = new Map();

studentsRef.onSnapshot(async (snapshot) => {
  snapshot.docChanges().forEach(async (change) => {
    const studentId = change.doc.id;
    const newData = change.doc.data();
    
    // مراقبة التعديلات فقط
    if (change.type === 'modified') {
      // استخدام البيانات القديمة المحفوظة للمقارنة
      const oldData = studentOldData.get(studentId);
      
      if (!oldData) {
        // حفظ البيانات الحالية كبيانات قديمة للمرة القادمة
        studentOldData.set(studentId, { ...newData });
        return;
      }
      
      console.log(`\n📝 =====================================`);
      console.log(`📝 تعديل على بيانات الطالب: ${newData.name || 'غير معروف'}`);
      console.log(`🆔 Student ID: ${studentId}`);
      console.log(`=====================================\n`);
      
      try {
        // ====== 1️⃣ تتبع تغيير الحالة ======
        const oldStatus = oldData.currentStatus;
        const newStatus = newData.currentStatus;
        
        if (oldStatus && newStatus && oldStatus !== newStatus) {
          console.log(`🔄 تغيير الحالة: ${oldStatus} → ${newStatus}`);
          await handleStatusChange(studentId, newData, oldStatus, newStatus);
        }
        
        // ====== 2️⃣ تتبع تغيير البيانات الأخرى (من الإدمن) ======
        const changedFields = {};
        const importantFields = [
          'name', 'schoolName', 'grade', 
          'parentName', 'parentPhone', 'address', 'notes'
        ];
        
        let hasDataChanges = false;
        
        for (const field of importantFields) {
          const oldValue = oldData[field];
          const newValue = newData[field];
          
          if (oldValue !== newValue && oldValue !== undefined && newValue !== undefined) {
            hasDataChanges = true;
            changedFields[field] = {
              old: oldValue,
              new: newValue
            };
            console.log(`   📌 ${field}: "${oldValue}" → "${newValue}"`);
          }
        }
        
        // إذا كان هناك تغييرات في البيانات، أرسل إشعار
        if (hasDataChanges) {
          console.log(`\n📢 تم تغيير ${Object.keys(changedFields).length} حقل(حقول)!`);
          await handleDataUpdate(studentId, newData, changedFields);
        } else {
          console.log(`   ℹ️ لا توجد تغييرات مهمة في البيانات`);
        }
        
        // تحديث البيانات القديمة المحفوظة
        studentOldData.set(studentId, { ...newData });
        
      } catch (error) {
        console.error(`   ❌ خطأ في معالجة التعديل:`, error.message);
      }
    }
    
    // إذا كان إضافة جديدة، احفظ البيانات
    if (change.type === 'added') {
      studentOldData.set(studentId, { ...newData });
    }
    
    // إذا تم حذف الطالب، احذف بياناته القديمة
    if (change.type === 'removed') {
      studentOldData.delete(studentId);
    }
  });
}, (error) => {
  console.error('❌ خطأ في مراقبة الطلاب:', error);
});

// ====== دالة معالجة تغيير الحالة ======
// ⚠️ ملحوظة مهمة: التطبيق نفسه (SimpleFCMService في Flutter) بيبعت
// إشعار push فعلي عند تغيير حالة الطالب من QR Scanner مباشرة عن طريق
// fcm_queue. الدالة دي هنا بترصد نفس التغيير من ناحية الباك إند
// (Firestore listener) كـ fallback/log بس، وبتحفظ نسخة in-app فقط
// من غير ما تبعت push تاني، عشان منمنعش تكرار الإشعار على ولي الأمر.
// لو حبينا يوم ما التطبيق يبقى مش هو مصدر الإشعار (مثلاً تحديث من
// لوحة تحكم الأدمن مباشرة)، وقتها نستخدم sendFcmNotification هنا.
async function handleStatusChange(studentId, studentData, oldStatus, newStatus) {
  try {
    const parentId = studentData.parentId;
    
    if (!parentId) {
      console.log(`   ⚠️ ولي الأمر غير مسجل للطالب`);
      return;
    }
    
    const parentDoc = await db.collection('users').doc(parentId).get();
    
    if (!parentDoc.exists) {
      console.log(`   ⚠️ ولي الأمر غير موجود: ${parentId}`);
      return;
    }

    const notificationTitle = getStatusChangeTitle(studentData.name, newStatus);
    const notificationBody = getStatusChangeBody(studentData.name, newStatus);

    // حفظ نسخة in-app فقط (بدون push) لمنع التكرار مع إشعار
    // fcm_queue اللي التطبيق بعته أصلاً لنفس الحدث
    await db.collection('notifications').add({
      id: db.collection('notifications').doc().id,
      title: notificationTitle,
      body: notificationBody,
      recipientId: parentId,
      studentId: studentId,
      studentName: studentData.name,
      type: 'studentStatusChanged',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      data: {
        oldStatus: oldStatus,
        newStatus: newStatus
      }
    });
    
  } catch (error) {
    console.error(`   ❌ خطأ في إرسال إشعار تغيير الحالة:`, error.message);
  }
}

// ====== دالة معالجة تحديث البيانات ======
async function handleDataUpdate(studentId, studentData, changedFields) {
  try {
    const parentId = studentData.parentId;
    
    if (!parentId) {
      console.log(`   ⚠️ ولي الأمر غير مسجل للطالب`);
      return;
    }
    
    console.log(`🔍 البحث عن ولي الأمر: ${parentId}`);
    const parentDoc = await db.collection('users').doc(parentId).get();
    
    if (!parentDoc.exists) {
      console.log(`   ⚠️ ولي الأمر غير موجود: ${parentId}`);
      return;
    }
    
    const parent = parentDoc.data();
    console.log(`✅ ولي الأمر موجود: ${parent.name || parent.email}`);
    
    const changesText = formatChangedFields(changedFields);
    const notificationTitle = '📝 تم تحديث بيانات الطالب';
    const notificationBody = `تم تحديث بيانات ${studentData.name} من قبل الإدارة\n\n${changesText}`;

    const result = await sendFcmNotification(admin, db, {
      recipientId: parentId,
      fcmToken: parent.fcmToken,
      title: notificationTitle,
      body: notificationBody,
      type: 'student_data_update',
      channelId: CHANNELS.STUDENT,
      color: '#2196F3',
      data: {
        studentId,
        studentName: studentData.name,
        changedFields: JSON.stringify(changedFields),
        navigationRoute: '/parent/students',
        navigationParams: JSON.stringify({ studentId, openDetails: true }),
      },
    });

    if (result.sent) {
      console.log(`   ✅ إشعار تحديث بيانات مرسل بنجاح! Message ID: ${result.messageId}`);
    } else {
      console.log(`   ⚠️ لم يتم إرسال push (${result.reason}) - تم حفظ نسخة in-app`);
    }
    
    console.log(`💾 تم حفظ الإشعار في Firestore\n`);
    
  } catch (error) {
    console.error(`\n❌ خطأ في إرسال إشعار تحديث البيانات:`);
    console.error(`   Error: ${error.message}`);
    console.error(`   Code: ${error.code}`);
    console.error(`   Stack: ${error.stack}\n`);
  }
}

// ====== دوال مساعدة لنصوص الإشعارات ======
function getStatusChangeTitle(studentName, newStatus) {
  let emoji = '';
  let statusText = '';
  
  switch (newStatus) {
    case 'home':
    case 'atHome':
      emoji = '🏠';
      statusText = 'في المنزل';
      break;
    case 'onBus':
    case 'inBus':
      emoji = '🚌';
      statusText = 'في الباص';
      break;
    case 'school':
    case 'atSchool':
      emoji = '🏫';
      statusText = 'في المدرسة';
      break;
    default:
      emoji = '📍';
      statusText = newStatus;
  }
  
  return `${emoji} ${studentName} ${statusText}`;
}

function getStatusChangeBody(studentName, newStatus) {
  let statusText = '';
  
  switch (newStatus) {
    case 'home':
    case 'atHome':
      statusText = 'في المنزل';
      break;
    case 'onBus':
    case 'inBus':
      statusText = 'في الباص';
      break;
    case 'school':
    case 'atSchool':
      statusText = 'في المدرسة';
      break;
    default:
      statusText = newStatus;
  }
  
  return `تم تحديث حالة ${studentName} إلى: ${statusText}`;
}

// ====== دالة تنسيق الحقول المتغيرة ======
function formatChangedFields(changedFields) {
  const fieldNames = {
    'name': 'اسم الطالب',
    'schoolName': 'اسم المدرسة',
    'grade': 'الصف الدراسي',
    'parentName': 'اسم ولي الأمر',
    'parentPhone': 'رقم هاتف ولي الأمر',
    'address': 'العنوان',
    'notes': 'ملاحظات'
  };
  
  const changes = [];
  
  for (const [field, values] of Object.entries(changedFields)) {
    const fieldName = fieldNames[field] || field;
    const oldValue = values.old || 'غير محدد';
    const newValue = values.new || 'غير محدد';
    
    changes.push(`• ${fieldName}: من "${oldValue}" إلى "${newValue}"`);
  }
  
  return changes.join('\n');
}

// ============================================
// تنظيف الإشعارات القديمة من fcm_queue كل ساعة
// ============================================
setInterval(async () => {
  try {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    
    const oldNotifications = await db.collection('fcm_queue')
      .where('status', 'in', ['sent', 'failed'])
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(oneDayAgo))
      .get();
    
    if (!oldNotifications.empty) {
      const batch = db.batch();
      oldNotifications.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      
      await batch.commit();
      console.log(`\n🧹 تم تنظيف ${oldNotifications.size} إشعار قديم من fcm_queue`);
    }
  } catch (error) {
    console.error('❌ خطأ في تنظيف الإشعارات القديمة:', error);
  }
}, 60 * 60 * 1000); // كل ساعة

// ============================================
// معالجة الأخطاء والإغلاق
// ============================================
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down gracefully...');
  console.log(`📊 Final Stats: ${notificationsSent} sent | ${notificationsFailed} failed`);
  process.exit(0);
});

process.on('unhandledRejection', (error) => {
  console.error('❌ Unhandled rejection:', error);
});

// Keep the process alive
setInterval(() => {
  const now = new Date();
  console.log(`💚 Service is running... ${now.toLocaleString('ar-EG', { timeZone: 'Africa/Cairo' })}`);
  console.log(`   📊 Stats: ${notificationsSent} sent | ${notificationsFailed} failed`);
}, 60000); // كل دقيقة

console.log('\n🎉 🎉 🎉 جميع المراقبات نشطة وجاهزة! 🎉 🎉 🎉');
console.log('==================================================');
console.log('🔥 1. fcm_queue - الأهم: إرسال الإشعارات من Flutter');
console.log('🚌 2. trips - رحلات الطلاب (ركوب/نزول)');
console.log('📝 3. absences - طلبات الغياب');
console.log('🚨 4. complaints - الشكاوى (محسّنة!):');
console.log('   ✅ شكوى جديدة → إشعار للإدمن 📢');
console.log('   ✅ رد الإدمن → إشعار لولي الأمر 📨');
console.log('👥 5. students - تحديثات الطلاب (محسّنة! 🆕):');
console.log('   ✅ تغيير حالة الطالب → إشعار لولي الأمر 📍');
console.log('   ✅ تحديث بيانات الطالب من الإدمن → إشعار لولي الأمر 📝');
console.log('==================================================');
console.log('\n💡 💡 💡 جرب الآن:');
console.log('1. أرسل شكوى من تطبيق ولي الأمر → سيصل للإدمن 📢');
console.log('2. رد على الشكوى من تطبيق الإدمن → سيصل لولي الأمر 📨');
console.log('3. غيّر حالة طالب من التطبيق → سيصل لولي الأمر 📍');
console.log('4. عدّل بيانات طالب من صفحة الإدمن → سيصل لولي الأمر 📝 (جديد!)'); 
console.log('==================================================\n');
