# 📦 Dependencies المطلوبة للإشعارات في Flutter

## أضف هذه في pubspec.yaml:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.6
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.5
  
  # Local Notifications
  flutter_local_notifications: ^16.3.0
  
  # Permissions (اختياري)
  permission_handler: ^11.0.1

dev_dependencies:
  flutter_test:
    sdk: flutter
```

---

## 🔧 إعدادات Android

### 1️⃣ android/app/build.gradle

تأكد من:
```gradle
android {
    compileSdkVersion 34  // أو أعلى
    
    defaultConfig {
        minSdkVersion 21     // على الأقل 21
        targetSdkVersion 34
    }
}

dependencies {
    // Firebase
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

### 2️⃣ android/app/src/main/AndroidManifest.xml

أضف:
```xml
<manifest>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    
    <application>
        <!-- FCM Service -->
        <service
            android:name="com.google.firebase.messaging.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        
        <!-- Default notification channel (اختياري) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="mybus_notifications" />
            
        <!-- Default notification icon (اختياري) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
    </application>
</manifest>
```

### 3️⃣ إضافة أيقونة الإشعارات

ضع ملف `ic_notification.png` في:
```
android/app/src/main/res/drawable/ic_notification.png
```

أو استخدم Android Asset Studio:
https://romannurik.github.io/AndroidAssetStudio/icons-notification.html

---

## 🍎 إعدادات iOS

### 1️⃣ ios/Runner/Info.plist

أضف:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>fetch</string>
</array>

<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

### 2️⃣ Enable Push Notifications

في Xcode:
1. افتح `ios/Runner.xcworkspace`
2. اختر Target "Runner"
3. روح Signing & Capabilities
4. اضغط "+ Capability"
5. اختر "Push Notifications"
6. اختار "Background Modes" وفعّل "Remote notifications"

### 3️⃣ iOS Certificates

تأكد من:
- Apple Push Notification service (APNs) مفعّل
- Upload APNs Certificate في Firebase Console

---

## ✅ اختبار الإعدادات

### 1. تثبيت Dependencies:
```bash
flutter pub get
cd ios && pod install && cd ..  # للـ iOS فقط
```

### 2. تشغيل التطبيق:
```bash
flutter run
```

### 3. التحقق من FCM Token:

في Console يجب أن تظهر:
```
🔔 Initializing Notification Service...
✅ Permission status: AuthorizationStatus.authorized
✅ Notification Service initialized successfully!
✅ FCM Token: eXaMpLe_ToKeN_HeRe...
✅ FCM Token saved successfully for user: user123
```

### 4. اختبار الإشعار:

أ) من Firebase Console:
- Cloud Messaging → Send test message
- أدخل FCM Token
- ابعت الإشعار

ب) من Backend (بعد النشر):
- أضف رحلة جديدة من التطبيق
- شوف Logs في Railway
- الإشعار يجب أن يظهر!

---

## 🐛 Troubleshooting

### ❌ "MissingPluginException"
```bash
flutter clean
flutter pub get
flutter run
```

### ❌ الإشعارات مش بتظهر على Android
- تأكد من `minSdkVersion >= 21`
- تأكد من Notification Channel معمول
- شوف Logcat: `adb logcat | grep FCM`

### ❌ iOS: "not receiving notifications"
- تأكد من APNs Certificate موجود في Firebase
- تأكد من Push Notifications مفعّل في Xcode
- جرب على جهاز حقيقي (مش Simulator)

### ❌ Token = null
- تأكد من `google-services.json` موجود (Android)
- تأكد من `GoogleService-Info.plist` موجود (iOS)
- تأكد من Firebase project مهيأ صح

---

## 📱 اختبار على Production

1. **Build APK/IPA:**
```bash
flutter build apk --release
flutter build ios --release
```

2. **تثبيت على جهاز:**
```bash
flutter install --release
```

3. **اختبار:**
- سجل دخول
- أضف رحلة
- اقفل التطبيق
- الإشعار يجب أن يظهر! 🎉

---

## 🎯 Checklist نهائي

قبل النشر، تأكد من:

### Backend:
- ✅ Backend منشور على Railway وشغال
- ✅ Service Account Key صحيح
- ✅ Firestore Rules تسمح بالقراءة والكتابة
- ✅ Logs بتظهر صح في Railway

### Flutter App:
- ✅ Firebase initialized في main.dart
- ✅ NotificationService.initialize() بيتنادي
- ✅ FCM Token بيتحفظ بعد Login
- ✅ Permissions مطلوبة
- ✅ Notification channels معمولة (Android)
- ✅ Background handler موجود

### Firestore:
- ✅ Collection "users" فيه field "fcmToken"
- ✅ Collection "trips" بيضاف فيه رحلات جديدة
- ✅ Collection "notifications" بيتعمل تلقائياً

### Testing:
- ✅ الإشعارات بتظهر والتطبيق مفتوح
- ✅ الإشعارات بتظهر والتطبيق في الخلفية
- ✅ الإشعارات بتظهر والتطبيق مقفول
- ✅ النقر على الإشعار بيفتح التطبيق

---

## 🚀 Ready to Go!

لو كل الخطوات دي تمام، يبقى نظام الإشعارات جاهز تماماً! 🎉

**الإشعارات هتشتغل:**
- ✅ عند ركوب الطالب الباص
- ✅ عند نزول الطالب من الباص
- ✅ عند وصول المدرسة
- ✅ عند وصول المنزل
- ✅ عند طلب غياب جديد
- ✅ عند الرد على الغياب
- ✅ عند شكوى جديدة

**كل ده تلقائي وبدون أي تدخل منك!** 🤖💚
