# 🚀 كيف تشغل Backend عشان الإشعارات تظهر بره؟

## المشكلة دلوقتي:
❌ **الإشعارات بتظهر جوا التطبيق بس**  
❌ **لو التطبيق مقفول، مفيش إشعارات**

## الحل:
✅ **تشغيل الـ Backend عشان يبعت الإشعارات خارج التطبيق**  
✅ **الإشعارات هتوصل حتى لو التطبيق مغلق تماماً**

---

## 📋 خطوات التشغيل (سهلة جداً):

### 1️⃣ تحميل Service Account Key من Firebase

1. افتح [Firebase Console](https://console.firebase.google.com)
2. اختر مشروعك **mybus-5a992**
3. اضغط على ⚙️ (Settings) → **Project settings**
4. روح لتاب **Service accounts**
5. اضغط على **Generate new private key**
6. اضغط **Generate key**
7. هينزل ملف JSON - **احفظه في مجلد `backend` باسم `serviceAccountKey.json`**

### 2️⃣ شغل الـ Backend

**طريقة سهلة:**
- دوس double-click على ملف **`start.bat`** في مجلد backend
- خلاص! الـ Backend شغال دلوقتي

**أو من Command Prompt:**
```cmd
cd C:\Users\musta\Desktop\pro\mybus\backend
start.bat
```

### 3️⃣ تأكد إنه شغال

لما يشتغل، هتشوف في الـ Console:
```
🚀 MyBus Notification Service Started!
📡 Listening to Firestore changes...
✅ جميع المراقبات نشطة:
   - fcm_queue (الأهم لإرسال الإشعارات)
   - trips (رحلات الطلاب)
   - absences (طلبات الغياب)
   - complaints (الشكاوى)

💚 Service is running... 5/10/2025, 10:30:00 م
```

### 4️⃣ جرب الإشعارات

دلوقتي لو غيرت بيانات طالب في التطبيق:
- ✅ **الإشعار هيظهر جوا التطبيق**
- ✅ **الإشعار هيظهر بره التطبيق** (في notification bar)
- ✅ **حتى لو التطبيق مغلق، الإشعار هيوصل**

---

## 🔍 كيف تشوف إنه بيشتغل؟

لما يجي إشعار جديد، هتشوف في الـ Console:
```
📤 معالجة إشعار جديد من القائمة: abc123
   المستلم: user_xyz
   العنوان: تم تحديث بيانات الطالب
   ✅ إشعار مرسل بنجاح: projects/.../messages/0:1234...
   ✅ تم تحديث حالة الإشعار في القائمة
```

---

## ⚠️ ملاحظات مهمة:

1. **الـ Backend لازم يفضل شغال طول الوقت**  
   لو قفلت الـ Console، الإشعارات مش هتوصل بره التطبيق

2. **للاستخدام الحقيقي:**  
   لازم ترفع الـ Backend على سيرفر (مثل Railway أو Heroku)  
   عشان يفضل شغال 24/7 بدون ما تقفل الكمبيوتر

3. **اختبار سريع:**
   - شغل الـ Backend
   - غير بيانات طالب من التطبيق
   - شوف الإشعار في notification bar (حتى لو التطبيق مغلق)

---

## 🐛 حل المشاكل:

### المشكلة: الـ Backend مش بيشتغل
**الحل:**
- تأكد إن Node.js مثبت
- تأكد إن ملف `serviceAccountKey.json` موجود في مجلد backend
- افتح مجلد backend في Command Prompt وشغل:
  ```cmd
  npm install
  node index.js
  ```

### المشكلة: الإشعارات لسه مش جاية بره التطبيق
**الحل:**
1. تأكد إن الـ Backend شغال (شوف الـ Console)
2. تأكد إن FCM Token محفوظ في Firestore (روح Firebase Console → Firestore → users → شوف أي user)
3. تأكد إن أذونات الإشعارات مفعلة في الجهاز/التطبيق

### المشكلة: خطأ "User not found" في Console
**الحل:**
- المستخدم مش موجود في Firestore
- أو FCM Token مش محفوظ
- خلي المستخدم يسجل دخول مرة تانية عشان يحفظ Token

---

## 🌐 للاستخدام الحقيقي (Production):

### استخدام Railway (مجاني لحد 500 ساعة/شهر):

1. اعمل حساب على https://railway.app
2. New Project → Deploy from GitHub
3. ربط Repository بتاعك
4. اختار مجلد `backend`
5. Add Environment Variables:
   - `SERVICE_ACCOUNT_KEY`: محتوى ملف serviceAccountKey.json كـ JSON
   - `FIREBASE_DATABASE_URL`: `https://mybus-5a992.firebaseio.com`
6. Deploy!

Railway هيديك رابط مثل: `https://mybus-backend.up.railway.app`  
والـ Backend هيفضل شغال 24/7 بدون ما تقفل الكمبيوتر

---

## ✅ الخلاصة:

| قبل تشغيل Backend | بعد تشغيل Backend |
|-------------------|-------------------|
| ❌ الإشعارات جوا التطبيق بس | ✅ الإشعارات جوا وبره التطبيق |
| ❌ لو التطبيق مغلق، مفيش إشعارات | ✅ الإشعارات تشتغل حتى لو مغلق |
| ❌ مش زي WhatsApp | ✅ تماماً زي WhatsApp |

---

## 📞 محتاج مساعدة؟

لو حصل أي مشكلة، ابعتلي screenshot من الـ Console والخطأ اللي ظاهر.
