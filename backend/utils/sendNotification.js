// ============================================
// 🔔 دالة موحدة لبناء وإرسال إشعارات FCM
// ============================================
// الهدف: كل الإشعارات في التطبيق (رحلات، غياب، شكاوى، تحديث بيانات،
// تغيير حالة) تمر من هنا، عشان:
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
 * @param {string} params.recipientId - معرف المستخدم المستلم (لازم لحفظ in-app)
 * @param {string} [params.fcmToken] - FCM token (لو مش موجود، هيتحفظ in-app بس)
 * @param {string} params.title - عنوان الإشعار
 * @param {string} params.body - محتوى الإشعار
 * @param {string} [params.type='general'] - نوع الإشعار (يُستخدم للتنقل داخل التطبيق)
 * @param {string} [params.channelId] - قناة الإشعار (من CHANNELS)
 * @param {object} [params.data={}] - بيانات إضافية تتبعت مع الإشعار
 * @param {'high'|'normal'} [params.priority='high']
 * @param {string} [params.color='#1E88E5'] - لون الإشعار (اللون الأساسي للتطبيق)
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
  } = params;

  // تحويل كل قيم data لـ string (FCM data payload بيتطلب ده)
  const stringData = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === null || value === undefined) continue;
    stringData[key] = typeof value === 'string' ? value : JSON.stringify(value);
  }

  // حفظ نسخة in-app دائمًا (حتى لو الـ push فشل أو مفيش token)
  const saveInApp = async () => {
    try {
      await db.collection('notifications').add({
        title,
        body,
        recipientId,
        type,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        data: stringData,
      });
    } catch (e) {
      console.error('   ⚠️ فشل حفظ نسخة in-app:', e.message);
    }
  };

  if (!fcmToken) {
    await saveInApp();
    return { sent: false, reason: 'no_fcm_token' };
  }

  // ============================================
  // Data-only message (بدون notification key)
  // ============================================
  // ده مهم جدًا: لو بعتنا "notification" key، Android هيعرض
  // الإشعار تلقائيًا من نظام التشغيل، وفي نفس الوقت onMessageReceived
  // في الكود هيتنفذ ويعرض إشعار تاني يدوي = تكرار.
  // بإرسال data فقط، إحنا بنضمن إن التطبيق (Kotlin service) هو
  // الوحيد اللي بيقرر يعرض الإشعار إزاي، بأيقونة وقناة موحدة،
  // في كل الحالات (foreground / background / killed).
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
