# 🚀 دليل النشر السريع - MyBus Backend

## الخطوات المطلوبة:

### 📥 الخطوة 1: تحميل Service Account Key

1. افتح Firebase Console:
   ```
   https://console.firebase.google.com/project/mybus-5a992/settings/serviceaccounts/adminsdk
   ```

2. اضغط على زر **"إنشاء مفتاح خاص جديد"** (Generate New Private Key)

3. سيتم تحميل ملف JSON - **احفظه باسم `serviceAccountKey.json`**

4. ضع الملف في مجلد `backend`:
   ```
   C:\Users\musta\Desktop\pro\mybus\backend\serviceAccountKey.json
   ```

---

### 💻 الخطوة 2: التجربة المحلية (اختياري)

```bash
cd C:\Users\musta\Desktop\pro\mybus\backend
npm install
npm start
```

إذا ظهرت رسالة:
```
🚀 MyBus Notification Service Started!
📡 Listening to Firestore changes...
```

معناها كل حاجة تمام! ✅

---

### ☁️ الخطوة 3: النشر على Railway (مجاني)

#### 3.1 إنشاء حساب:
- اذهب إلى: https://railway.app
- سجل دخول باستخدام GitHub

#### 3.2 رفع الكود على GitHub:

```bash
cd C:\Users\musta\Desktop\pro\mybus\backend
git init
git add .
git commit -m "MyBus Backend Setup"
```

**إنشاء Repository جديد على GitHub:**
1. اذهب إلى: https://github.com/new
2. اسم الريبو: `mybus-backend`
3. اضغط **Create repository**

**ارفع الكود:**
```bash
git remote add origin https://github.com/YOUR_USERNAME/mybus-backend.git
git branch -M main
git push -u origin main
```

#### 3.3 النشر على Railway:

1. في Railway، اضغط **New Project**
2. اختر **Deploy from GitHub repo**
3. اختر `mybus-backend`
4. Railway هيبدأ النشر تلقائياً! 🎉

#### 3.4 إضافة المتغيرات (Variables):

في Railway Dashboard:
1. اضغط على المشروع → **Variables**
2. أضف:
   ```
   FIREBASE_DATABASE_URL=https://mybus-5a992.firebaseio.com
   ```

3. **إضافة Service Account (طريقتين):**

   **الطريقة الأولى (الأسهل):**
   - خلي ملف `serviceAccountKey.json` موجود في الريبو
   - Railway هيقراه تلقائياً
   
   **الطريقة الثانية (الأكثر أماناً):**
   - افتح `serviceAccountKey.json`
   - انسخ كل المحتوى
   - في Railway Variables، أضف متغير اسمه `SERVICE_ACCOUNT_KEY`
   - الصق المحتوى كله
   
   ثم عدّل `index.js` ليقرأ من المتغير:
   ```javascript
   const serviceAccount = process.env.SERVICE_ACCOUNT_KEY 
     ? JSON.parse(process.env.SERVICE_ACCOUNT_KEY)
     : require('./serviceAccountKey.json');
   ```

4. اضغط **Deploy** أو **Restart**

---

### ✅ الخطوة 4: التحقق من عمل السيرفر

في Railway:
1. اضغط على المشروع
2. روح على **Deployments** → **View Logs**
3. لازم تشوف:
   ```
   🚀 MyBus Notification Service Started!
   📡 Listening to Firestore changes...
   ```

إذا شفت الرسالة دي، يبقى السيرفر شغال! 🎉

---

### 📱 الخطوة 5: تحديث التطبيق (Flutter)

تأكد من إن:

1. **FCM Token بيتحفظ في Firestore:**
   
   في `lib/services/` ضيف أو تأكد من:
   ```dart
   import 'package:firebase_messaging/firebase_messaging.dart';
   
   Future<void> saveFCMToken(String userId) async {
     final fcmToken = await FirebaseMessaging.instance.getToken();
     
     if (fcmToken != null) {
       await FirebaseFirestore.instance
         .collection('users')
         .doc(userId)
         .update({'fcmToken': fcmToken});
     }
   }
   ```

2. **Firebase Messaging مفعّل:**
   
   في `main.dart`:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     
     // طلب الإذن للإشعارات
     await FirebaseMessaging.instance.requestPermission(
       alert: true,
       badge: true,
       sound: true,
     );
     
     runApp(MyApp());
   }
   ```

3. **Notification Handler:**
   ```dart
   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     print('Got a message whilst in the foreground!');
     print('Message data: ${message.data}');
     
     if (message.notification != null) {
       // عرض الإشعار
       showNotification(message);
     }
   });
   ```

---

### 🧪 الخطوة 6: اختبار الإشعارات

1. **افتح التطبيق** وسجل دخول
2. **أضف رحلة جديدة** (trip) من التطبيق
3. **شوف Logs في Railway** - المفروض تشوف:
   ```
   🆕 رحلة جديدة: trip_12345
   الطالب: أحمد محمد
   ✅ إشعار مرسل لولي الأمر
   ```
4. **الإشعار يظهر في الموبايل** حتى لو التطبيق مقفول! 🎉

---

### 🐛 حل المشاكل الشائعة

#### ❌ "Cannot find module 'firebase-admin'"
```bash
cd backend
npm install
```

#### ❌ "serviceAccountKey.json not found"
- تأكد من إنك حملت الملف من Firebase Console
- تأكد من إن اسمه صح: `serviceAccountKey.json`

#### ❌ الإشعارات مش واصلة
1. تأكد من `fcmToken` موجود في `users` collection في Firestore
2. شوف Logs في Railway - لازم تلاقي "✅ إشعار مرسل"
3. تأكد من Firebase Cloud Messaging مفعّل في Firebase Console

#### ❌ Railway بيقول "Deployment Failed"
- شوف Build Logs
- تأكد من `package.json` موجود
- تأكد من `node_modules` مش موجود في git (في `.gitignore`)

---

### 💡 نصائح إضافية

1. **Keep-Alive (خلي السيرفر مايناماش):**
   - استخدم: https://uptimerobot.com (مجاني)
   - ضيف URL السيرفر بتاعك (من Railway)
   - هيعمل ping كل 5 دقائق

2. **مراقبة الأخطاء:**
   - شوف Logs في Railway بانتظام
   - ضيف Webhook للإشعارات لو حصلت مشكلة

3. **النسخ الاحتياطي:**
   - خلي الكود على GitHub دايماً محدث
   - ممكن تستخدم Render.com كـ backup

---

### 📊 المراقبة والصيانة

**Logs في Railway:**
```bash
# شوف آخر 100 سطر
railway logs

# متابعة live
railway logs --follow
```

**Restart السيرفر:**
```bash
railway restart
```

---

### 💰 خطة Railway المجانية

- ✅ **500 ساعة مجانية شهرياً**
- ✅ **كافية لمشروع صغير-متوسط**
- ✅ **لو نفدت الساعات:** إما ترقي أو استخدم Render.com

---

### 🎉 تم! 

دلوقتي عندك:
- ✅ Backend شغال 24/7
- ✅ إشعارات تلقائية للرحلات
- ✅ إشعارات للغيابات والشكاوى
- ✅ كل حاجة مجانية!

**لو عندك أي مشكلة، ارجع للـ README.md أو شوف الـ Logs!**

---

Made with ❤️ for MyBus School Transportation System
