# ⚡ Quick Start - 5 دقائق للتشغيل!

## 🎯 الهدف
تشغيل نظام الإشعارات التلقائية لمشروع MyBus في أقل من 5 دقائق!

---

## 📝 الخطوات (5 دقائق فقط!)

### 1️⃣ تحميل Service Account (دقيقة واحدة)

```
1. افتح: https://console.firebase.google.com/project/mybus-5a992/settings/serviceaccounts/adminsdk
2. اضغط "Generate New Private Key"
3. احفظ الملف باسم: serviceAccountKey.json
4. ضعه في: C:\Users\musta\Desktop\pro\mybus\backend\serviceAccountKey.json
```

✅ **تم!**

---

### 2️⃣ تثبيت Node.js (إذا لم يكن مثبتاً) (دقيقتين)

- حمّل من: https://nodejs.org (LTS version)
- ثبّت عادي (Next, Next, Finish)
- تحقق بالأمر:
```bash
node --version
npm --version
```

✅ **تم!**

---

### 3️⃣ تثبيت Dependencies (30 ثانية)

```bash
cd C:\Users\musta\Desktop\pro\mybus\backend
npm install
```

انتظر... ✅ **تم!**

---

### 4️⃣ تشغيل السيرفر محلياً (10 ثوانٍ)

```bash
npm start
```

يجب أن تشوف:
```
🚀 MyBus Notification Service Started!
📡 Listening to Firestore changes...
```

✅ **السيرفر شغال!** 🎉

---

### 5️⃣ اختبار (30 ثانية)

1. افتح التطبيق على الموبايل
2. سجل دخول كولي أمر
3. أضف رحلة جديدة للطالب
4. شوف Console - يجب أن تظهر:
```
🆕 رحلة جديدة: trip_12345
   الطالب: أحمد محمد
   ✅ إشعار مرسل لولي الأمر
```

5. شوف الموبايل - الإشعار ظهر! 📱

✅ **يشتغل!** 🎉🎉🎉

---

## 🚀 النشر على Railway (دقيقة واحدة)

الآن خلي السيرفر يشتغل 24/7:

### الطريقة الأسهل:

1. **اذهب إلى:** https://railway.app
2. **سجل دخول** بحساب GitHub
3. **اضغط:** New Project → Deploy from GitHub
4. **اختر:** Repository بتاع Backend
5. **Railway** هيعمل كل حاجة تلقائياً!

✅ **تم! السيرفر شغال على الإنترنت 24/7** 🌍

---

## 🎯 Checklist سريع

قبل ما تبدأ، تأكد من:

- ✅ Firebase project موجود ومُهيأ
- ✅ FCM Token بيتحفظ في Firestore (في collection "users")
- ✅ Firebase Messaging مفعّل في التطبيق
- ✅ Permissions للإشعارات مطلوبة

---

## 📱 Flutter Quick Setup

في `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // ✅ هذا السطر مهم!
  await FirebaseMessaging.instance.requestPermission();
  
  runApp(MyApp());
}
```

بعد Login:

```dart
Future<void> afterLogin(String userId) async {
  final token = await FirebaseMessaging.instance.getToken();
  
  await FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .update({'fcmToken': token});
}
```

✅ **تم!**

---

## ❓ مش شغال؟

### مشكلة 1: "serviceAccountKey.json not found"
**الحل:** تأكد من إن الملف موجود في مجلد backend

### مشكلة 2: الإشعار مش واصل
**الحل:** 
```bash
# شوف الـ Logs
npm start

# يجب أن تظهر: ✅ إشعار مرسل لولي الأمر
```

إذا ظهرت هذه الرسالة لكن الإشعار مش واصل:
- تأكد من `fcmToken` موجود في Firestore
- تأكد من Firebase Messaging مفعّل في التطبيق

### مشكلة 3: "Cannot find module"
**الحل:**
```bash
npm install
```

---

## 🎉 مبروك!

دلوقتي عندك:
- ✅ Backend شغال ومراقب Firestore
- ✅ إشعارات تلقائية للرحلات
- ✅ إشعارات للغيابات والشكاوى
- ✅ كل حاجة شغالة 24/7!

---

## 📚 مصادر إضافية

- **الدليل الكامل:** README.md
- **إعداد Flutter:** FLUTTER_DEPENDENCIES.md
- **دليل النشر:** SETUP_GUIDE.md

---

**وقت التشغيل الفعلي: 5 دقائق** ⏱️

**صعوبة: سهل جداً** 😊

**التكلفة: مجاني تماماً** 💰

---

Made with ❤️ for MyBus
