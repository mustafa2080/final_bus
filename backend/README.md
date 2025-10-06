# 🚀 MyBus Notification Backend

Backend service للتعامل مع الإشعارات في تطبيق MyBus بشكل تلقائي.

## ✨ المميزات

- ✅ **إشعارات فورية** عند ركوب/نزول الطالب
- ✅ **إشعارات تلقائية** عند بداية/نهاية الرحلة
- ✅ **تنبيهات** لطلبات الغياب والشكاوى
- ✅ **مراقبة مستمرة** لقاعدة البيانات
- ✅ **حفظ الإشعارات** في Firestore

## 📋 المتطلبات

- Node.js v18 أو أحدث
- حساب Firebase مع Service Account
- FCM Tokens للمستخدمين في قاعدة البيانات

## 🛠️ التثبيت

### 1️⃣ تثبيت Dependencies

```bash
cd backend
npm install
```

### 2️⃣ الحصول على Service Account Key

1. افتح Firebase Console: https://console.firebase.google.com/project/mybus-5a992/settings/serviceaccounts/adminsdk
2. اضغط على **Generate New Private Key**
3. احفظ الملف باسم `serviceAccountKey.json` في مجلد `backend`

### 3️⃣ تشغيل السيرفر محلياً

```bash
npm start
```

أو للتطوير:
```bash
npm run dev
```

## 🚀 النشر على Railway

### الطريقة 1: من GitHub (موصى بها)

1. **رفع الكود على GitHub:**
```bash
cd backend
git init
git add .
git commit -m "Initial backend setup"
git branch -M main
git remote add origin YOUR_GITHUB_REPO_URL
git push -u origin main
```

2. **إنشاء مشروع على Railway:**
   - اذهب إلى: https://railway.app
   - سجل دخول بحساب GitHub
   - اضغط **New Project** → **Deploy from GitHub repo**
   - اختر الريبو بتاعك
   - Railway هيكتشف `package.json` تلقائياً

3. **إضافة المتغيرات:**
   - في Dashboard → Variables
   - أضف `FIREBASE_DATABASE_URL`
   - أضف محتوى `serviceAccountKey.json` كمتغير

### الطريقة 2: من CLI

```bash
npm i -g @railway/cli
railway login
railway init
railway up
```

## 🌐 نشر على خدمات أخرى

### Render.com
1. اذهب إلى: https://render.com
2. New → Web Service
3. Connect Repository
4. Environment: Node
5. Build Command: `npm install`
6. Start Command: `npm start`

### Heroku
```bash
heroku create mybus-notifications
git push heroku main
```

## 📊 مراقبة السيرفر

السيرفر يطبع logs في Console:
```
🚀 MyBus Notification Service Started!
📡 Listening to Firestore changes...

🆕 رحلة جديدة: trip_12345
   الطالب: أحمد محمد
   الإجراء: boardBusToSchool
   ✅ إشعار مرسل لولي الأمر: ...
   ✅ الإشعار محفوظ في Firestore

💚 Service is running... 05/10/2025, 10:30:00
```

## 🔧 التخصيص

### إضافة إشعار جديد

في `index.js`، أضف listener جديد:

```javascript
const newCollectionRef = db.collection('your_collection');
newCollectionRef.onSnapshot(async (snapshot) => {
  // Your logic here
});
```

### تعديل نص الإشعارات

عدّل في القسم:
```javascript
switch (trip.action) {
  case 'boardBusToSchool':
    notificationTitle = 'عنوان مخصص';
    // ...
}
```

## 📱 إعداد التطبيق (Flutter)

تأكد من:
1. ✅ المستخدمين عندهم `fcmToken` في Firestore
2. ✅ Firebase Messaging مفعّل في التطبيق
3. ✅ Notification Channel معمول صح

## 🐛 Troubleshooting

### الإشعارات مش واصلة؟
- تأكد من `fcmToken` موجود في `users` collection
- تأكد من الـ Token محدّث
- شوف الـ Logs في السيرفر

### خطأ في التوصيل بـ Firestore؟
- تأكد من `serviceAccountKey.json` موجود
- تأكد من الـ permissions صح
- شوف Firebase Console → Service Accounts

### السيرفر بيتوقف؟
- على Railway: تأكد من الـ plan (Free plan بيتوقف بعد فترة)
- استخدم Keep-alive service: https://uptimerobot.com

## 💰 التكلفة

- **Railway Free Plan:** 
  - 500 ساعة شهرياً مجاناً
  - $5 بعد كده
  
- **Render Free Plan:**
  - مجاني تماماً
  - السيرفر بينام بعد 15 دقيقة خمول

## 📞 الدعم

لو عندك مشكلة، افتح Issue على GitHub!

---

Made with ❤️ for MyBus School Transportation System
