/// 📱 استخدام NotificationService في main.dart
/// 
/// أضف هذا الكود في ملف main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // ✅ تهيئة خدمة الإشعارات
  await NotificationService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyBus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}

/// ✅ استدعاء saveFCMToken بعد تسجيل الدخول
/// 
/// في ملف تسجيل الدخول (login_screen.dart):

Future<void> onLoginSuccess(String userId) async {
  // حفظ FCM Token
  await NotificationService.saveFCMToken(userId);
  
  // بدء الاستماع لتحديثات Token
  NotificationService.listenToTokenRefresh(userId);
  
  // الاشتراك في Topics (اختياري)
  final user = await getUserData(userId);
  if (user.userType == 'parent') {
    await NotificationService.subscribeToTopic('parents');
  } else if (user.userType == 'supervisor') {
    await NotificationService.subscribeToTopic('supervisors');
  }
  
  // الانتقال للصفحة الرئيسية
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const HomeScreen()),
  );
}

/// ✅ حذف Token عند تسجيل الخروج
/// 
/// في دالة Logout:

Future<void> onLogout(String userId) async {
  // حذف FCM Token
  await NotificationService.deleteFCMToken(userId);
  
  // تسجيل الخروج من Firebase Auth
  await FirebaseAuth.instance.signOut();
  
  // العودة لشاشة تسجيل الدخول
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
}
