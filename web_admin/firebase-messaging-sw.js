// Firebase Messaging Service Worker - لوحة تحكم الأدمن (MyBus)
// ============================================
// المسؤول عن استقبال إشعارات FCM لما التاب يكون مقفول أو في الخلفية.
// لازم يكون في جذر المجلد اللي بيتقدم منه الموقع (نفس مكان index.html)
// عشان يقدر يسجل نفسه بـ scope صحيح (/).

importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// نفس إعدادات Firebase المستخدمة في firebase-config.js
firebase.initializeApp({
  apiKey: "AIzaSyCxUs93mPDENri0o6ARCDOm5p_m40D-y78",
  authDomain: "mybus-5a992.firebaseapp.com",
  projectId: "mybus-5a992",
  storageBucket: "mybus-5a992.firebasestorage.app",
  messagingSenderId: "804926032268",
  appId: "1:804926032268:web:6450c694a8bbc705982ea9"
});

const messaging = firebase.messaging();

// ============================================
// معالجة الرسائل في الخلفية (تاب مقفول / التطبيق مش فاتح)
// ============================================
// الباك إند بيبعت data-only messages (بدون notification key) عشان
// يمنع تكرار الإشعارات على الموبايل. على الويب، لازم إحنا نعرض
// الإشعار يدويًا هنا من الـ data payload.
messaging.onBackgroundMessage((payload) => {
  console.log('📩 [SW] رسالة خلفية مستلمة:', payload);

  const data = payload.data || {};
  const title = data.title || 'إشعار جديد';
  const body = data.body || '';

  const notificationOptions = {
    body: body,
    icon: '/favicon.ico',
    badge: '/favicon.ico',
    tag: data.type || 'general', // يمنع تكديس إشعارات من نفس النوع
    dir: 'rtl',
    lang: 'ar',
    data: data,
  };

  self.registration.showNotification(title, notificationOptions);
});

// عند الضغط على الإشعار: افتح لوحة التحكم (أو ركّز على تاب مفتوح)
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientsArr) => {
      const existingClient = clientsArr.find((c) => c.url.includes(self.registration.scope));
      if (existingClient) {
        return existingClient.focus();
      }
      return self.clients.openWindow('/');
    })
  );
});
