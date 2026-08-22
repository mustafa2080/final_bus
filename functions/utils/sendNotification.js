// ============================================
// 🔔 دالة موحدة لبناء وإرسال إشعارات FCM (نسخة Cloud Functions)
// ============================================
// نفس منطق backend/utils/sendNotification.js بالظبط (كان شغال كـ Windows
// service)، منقولة هنا عشان processFcmQueue في functions/index.js تستخدمها.
// الهدف: كل الإشعارات تمر من هنا عشان:
// - نفس الأيقونة الموحدة في كل مكان (status bar icon صحيح)
// - نفس الشكل (title/body/data/channel)
// - نسخة in-app في collection "notifications" تتحفظ تلقائيًا
// - data-only message (من غير notification key) عشان Android
//   ميعرضش الإشعار تلقائيًا، والتطبيق (Kotlin service) هو
//   المتحكم الوحيد في العرض، فمفيش تكرار.
// ============================================

// قنوات الإشعارات الموحدة (لازم تتطابق مع القنوات المسجلة في
// android/app/src/main/kotlin/.../MyFirebaseMessagingService.kt)
const CHANNELS = {
  GENERAL: 'mybus_notifications',
  STUDENT: 'student_notifications',
  COMPLAINTS: 'complaints_channel',
  TRIPS: 'mybus_notifications',
};

/**
 * إرسال إشعار FCM موحّد + حفظ نسخة in-app في Firestore.
 *
 * @param {object} admin - firebase-admin instance
 * @param {object} db - Firestore instance
 * @param {object} params
 * @param {string} params.recipientId
 * @param {string} [params.fcmToken]
 * @param {string} params.title
 * @param {string} params.body
 * @param {string} [params.type='general']
 * @param {string} [params.channelId]
 * @param {object} [params.data={}]
 * @param {'high'|'normal'} [params.priority='high']
 * @param {string} [params.color='#1E88E5']
 * @param {string} [params.deduplicationKey] - لو موصول من fcm_queue (الفلاتر
 *   كتبته وحفظت نسخة in-app بنفس الـ ID فورًا وقت الإرسال)، بنستخدمه كـ doc ID
 *   هنا كمان عشان الكتابة تبقى idempotent، مش تكرار.
 * @returns {Promise<{sent: boolean, messageId?: string, reason?: string}>}
 */
async function sendFcmNotification(admin, db, params) {
  const {
    recipientId,
    fcmToken,
    title,
    body,
    type = 'general',
    channelId = CHANNELS.GENERAL,
    data = {},
    priority = 'high',
    color = '#1E88E5',
    deduplicationKey,
  } = params;

  const stringData = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) continue;
    stringData[key] = typeof value === 'string' ? value : JSON.stringify(value);
  }

  const saveInApp = async () => {
    try {
      const payload = {
        title,
        body,
        recipientId,
        type,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        data: stringData,
      };
      if (deduplicationKey) {
        await db.collection('notifications').doc(deduplicationKey).set(
          { id: deduplicationKey, ...payload },
          { merge: true }
        );
      } else {
        await db.collection('notifications').add(payload);
      }
    } catch (e) {
      console.error('   ⚠️ فشل حفظ نسخة in-app:', e.message);
    }
  };

  if (!fcmToken) {
    await saveInApp();
    return { sent: false, reason: 'no_fcm_token' };
  }

  // Data-only message (بدون notification key) — لمنع تكرار العرض، لأن
  // الـ Kotlin service (MyFirebaseMessagingService) هو المسؤول الوحيد
  // عن عرض الإشعار في كل الحالات (foreground/background/killed).
  const message = {
    token: fcmToken,
    data: {
      title,
      body,
      type,
      channelId,
      color,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
      ...stringData,
    },
    android: {
      priority: priority === 'high' ? 'high' : 'normal',
    },
    apns: {
      headers: {
        'apns-priority': priority === 'high' ? '10' : '5',
      },
      payload: {
        aps: {
          'content-available': 1,
          sound: 'default',
        },
      },
    },
  };

  try {
    const messageId = await admin.messaging().send(message);
    await saveInApp();
    return { sent: true, messageId };
  } catch (error) {
    console.error('   ❌ فشل إرسال FCM:', error.message);
    await saveInApp();
    return { sent: false, reason: error.message };
  }
}

module.exports = { CHANNELS, sendFcmNotification };
