# 🚀 دليل التشغيل السريع للـ Backend

## ✅ خطوات التشغيل

### 1️⃣ تثبيت Dependencies
```bash
cd backend
npm install
```

### 2️⃣ إعداد Service Account Key
1. اذهب إلى Firebase Console
2. اختر مشروعك (mybus-5a992)
3. اذهب إلى Settings > Service Accounts
4. اضغط على "Generate new private key"
5. احفظ الملف كـ `serviceAccountKey.json` في مجلد `backend`

### 3️⃣ تشغيل الخدمة
```bash
npm start
```

أو للتطوير مع إعادة التشغيل التلقائي:
```bash
npm run dev
```

## 📋 ماذا يفعل الـ Backend؟

### 🔥 المراقبة الرئيسية (الأهم):
- **fcm_queue**: يراقب قائمة الإشعارات المنتظرة ويرسلها عبر FCM
  - عندما Flutter يضيف إشعار لـ `fcm_queue`
  - Backend يأخذه ويرسله عبر FCM الحقيقي
  - الإشعار يظهر **خارج التطبيق** حتى لو كان مغلق

### 📱 مراقبات إضافية:
- **trips**: رحلات الطلاب (ركوب/نزول)
- **absences**: طلبات الغياب (جديدة/موافقة/رفض)
- **complaints**: الشكاوى الجديدة

## 🔍 كيف تتأكد أنه يعمل؟

### 1. سترى في Console:
```
🚀 MyBus Notification Service Started!
📡 Listening to Firestore changes...
✅ جميع المراقبات نشطة:
   - fcm_queue (الأهم لإرسال الإشعارات)
   - trips (رحلات الطلاب)
   - absences (طلبات الغياب)
   - complaints (الشكاوى)
💚 Service is running...
```

### 2. عند إرسال إشعار، سترى:
```
📤 معالجة إشعار جديد من القائمة: abc123
   المستلم: user_xyz
   العنوان: إشعار جديد
   ✅ إشعار مرسل بنجاح: projects/.../messages/0:1234...
   ✅ تم تحديث حالة الإشعار في القائمة
```

## 🐛 حل المشاكل

### لا توجد إشعارات في Console؟
- تأكد أن التطبيق يضيف إلى `fcm_queue` collection
- تحقق من أن `serviceAccountKey.json` موجود وصحيح

### خطأ في الاتصال؟
- تأكد من اتصال الإنترنت
- تحقق من صحة Firebase Database URL في `.env`

### الإشعارات لا تظهر خارج التطبيق؟
- تأكد أن FCM Token محفوظ في Firestore للمستخدم
- تحقق من أذونات الإشعارات في الجهاز
- للويب: تحقق من أن `firebase-messaging-sw.js` موجود

## 🌐 للنشر على الإنترنت

### استخدام Railway (مجاني):
1. اذهب إلى https://railway.app
2. أنشئ حساب جديد
3. New Project > Deploy from GitHub
4. اختر repository الخاص بك
5. اختر مجلد `backend`
6. أضف Environment Variables:
   - `SERVICE_ACCOUNT_KEY`: محتوى ملف serviceAccountKey.json كـ JSON string
   - `FIREBASE_DATABASE_URL`: https://mybus-5a992.firebaseio.com
7. Deploy!

سيعطيك Railway رابط مثل: `https://your-app.up.railway.app`

---

## 📝 ملاحظات مهمة

1. **الـ Backend يجب أن يكون شغال دائماً** لإرسال الإشعارات خارج التطبيق
2. إذا أغلقت Terminal، الـ Backend سيتوقف والإشعارات لن تُرسل
3. للاستخدام الحقيقي، يجب نشره على خادم (Railway, Heroku, VPS)
4. الإشعارات تُحفظ في `fcm_queue` وتُحذف بعد 24 ساعة تلقائياً

## 🎯 الفرق بين قبل وبعد:

### ❌ قبل (بدون Backend):
- الإشعارات تظهر **داخل التطبيق فقط**
- لو التطبيق مغلق، لا توجد إشعارات

### ✅ بعد (مع Backend):
- الإشعارات تظهر **خارج التطبيق**
- تعمل حتى لو التطبيق مغلق تماماً
- تظهر في شريط الإشعارات مثل WhatsApp
