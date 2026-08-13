/**
 * MyBus - Cloud Functions
 * بديل الـ Node backend القديم: بيراقب fcm_queue تلقائياً (Firestore Trigger)
 * وبيبعت push notifications حقيقية عبر FCM - من غير الحاجة لتشغيل سيرفر منفصل.
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// إعدادات عامة: منطقة قريبة من مصر + حدود تكلفة معقولة
setGlobalOptions({
  region: 'europe-west1',
  maxInstances: 10,
});

/**
 * 🔥 الدالة الأساسية: بترسل push notification حقيقية
 * تتفعل تلقائياً كل ما مستند جديد يتضاف في fcm_queue (من التطبيق مباشرة)
 */
exports.processFcmQueue = onDocumentCreated('fcm_queue/{queueId}', async (event) => {
  const queueId = event.params.queueId;
  const queueItem = event.data?.data();

  if (!queueItem) {
    logger.warn(`⚠️ لا يوجد بيانات في المستند: ${queueId}`);
    return;
  }

  logger.info('📥 إشعار جديد في fcm_queue', {
    queueId,
    recipientId: queueItem.recipientId,
    title: queueItem.title,
  });

  if (queueItem.status !== 'pending') {
    logger.info(`⏭️ تخطي - الحالة ليست pending: ${queueItem.status}`);
    return;
  }

  const queueRef = db.collection('fcm_queue').doc(queueId);

  try {
    await queueRef.update({
      status: 'processing',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // جلب بيانات المستخدم المستلم
    const userDoc = await db.collection('users').doc(queueItem.recipientId).get();

    if (!userDoc.exists) {
      await queueRef.update({
        status: 'failed',
        error: 'User not found',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.warn(`❌ المستخدم غير موجود: ${queueItem.recipientId}`);
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      await queueRef.update({
        status: 'failed',
        error: 'FCM token not found',
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.warn(`❌ لا يوجد FCM token للمستخدم: ${queueItem.recipientId}`);
      return;
    }

    const message = {
      token: fcmToken,
      notification: {
        title: queueItem.title || 'إشعار جديد',
        body: queueItem.body || '',
      },
      data: {
        ...(queueItem.data || {}),
        recipientId: queueItem.recipientId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: queueItem.priority === 'high' ? 'high' : 'normal',
        notification: {
          channelId: queueItem.data?.channelId || 'mybus_notifications',
          sound: 'default',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
          defaultLightSettings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            contentAvailable: true,
          },
        },
      },
      webpush: {
        notification: {
          title: queueItem.title,
          body: queueItem.body,
          icon: '/icons/icon-192x192.png',
          badge: '/icons/badge-72x72.png',
        },
        fcmOptions: {
          link: '/',
        },
      },
    };

    const response = await messaging.send(message);

    await queueRef.update({
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      messageId: response,
    });

    logger.info(`✅ إشعار مرسل بنجاح: ${queueId}`, { messageId: response });
  } catch (error) {
    logger.error(`❌ خطأ في إرسال الإشعار: ${queueId}`, {
      error: error.message,
      code: error.code,
    });

    // لو التوكن أصبح غير صالح (المستخدم عمل logout أو حذف التطبيق)
    // نمسحه من بيانات المستخدم عشان محاولات لاحقة متفشلش لنفس السبب
    const invalidTokenCodes = [
      'messaging/invalid-registration-token',
      'messaging/registration-token-not-registered',
    ];

    if (invalidTokenCodes.includes(error.code)) {
      try {
        await db.collection('users').doc(queueItem.recipientId).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        logger.info(`🗑️ تم حذف FCM token غير صالح للمستخدم: ${queueItem.recipientId}`);
      } catch (cleanupError) {
        logger.error('❌ فشل حذف التوكن غير الصالح', cleanupError);
      }
    }

    await queueRef.update({
      status: 'failed',
      error: error.message,
      errorCode: error.code || null,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * 🧹 تنظيف دوري: بيحذف عناصر fcm_queue القديمة (sent/failed) كل يوم
 * بديل الـ setInterval اللي كان في الـ Node backend
 */
const { onSchedule } = require('firebase-functions/v2/scheduler');

exports.cleanupFcmQueue = onSchedule('every 24 hours', async () => {
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const snapshot = await db.collection('fcm_queue')
    .where('status', 'in', ['sent', 'failed'])
    .where('createdAt', '<', admin.firestore.Timestamp.fromDate(oneDayAgo))
    .get();

  if (snapshot.empty) {
    logger.info('🧹 لا يوجد عناصر قديمة للحذف');
    return;
  }

  const batch = db.batch();
  snapshot.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();

  logger.info(`🧹 تم حذف ${snapshot.size} عنصر قديم من fcm_queue`);
});
