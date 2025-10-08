// ============================================
// 🔥 تطبيق حذف FCM Token عند Logout في Flutter
// ============================================
// 
// هذا الملف يوضح كيفية تطبيق حذف FCM Token عند تسجيل الخروج
// في تطبيق Flutter لمنع وصول الإشعارات للحسابات المغلقة

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ============================================
// 📡 Service للتواصل مع Backend API
// ============================================
class NotificationService {
  // 🔧 غير الـ URL حسب السيرفر بتاعك
  static const String BASE_URL = 'http://localhost:3000'; // للتجربة المحلية
  // static const String BASE_URL = 'https://your-server.com'; // للـ Production
  
  // ✅ دالة حذف FCM Token عند Logout
  static Future<bool> deleteTokenOnLogout(String userId) async {
    try {
      print('🚪 محاولة حذف FCM Token للمستخدم: $userId');
      
      final response = await http.post(
        Uri.parse('$BASE_URL/api/logout'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ تم حذف FCM Token: ${data['message']}');
        return data['success'] == true;
      } else {
        print('❌ فشل حذف FCM Token: ${response.statusCode}');
        print('   Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ خطأ في حذف FCM Token: $e');
      return false;
    }
  }
  
  // ✅ دالة تحديث FCM Token عند Login
  static Future<bool> updateTokenOnLogin(String userId, String fcmToken) async {
    try {
      print('🔑 محاولة تحديث FCM Token للمستخدم: $userId');
      print('📱 Token: ${fcmToken.substring(0, 30)}...');
      
      final response = await http.post(
        Uri.parse('$BASE_URL/api/updateToken'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userId': userId,
          'fcmToken': fcmToken,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ تم تحديث FCM Token: ${data['message']}');
        return data['success'] == true;
      } else {
        print('❌ فشل تحديث FCM Token: ${response.statusCode}');
        print('   Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ خطأ في تحديث FCM Token: $e');
      return false;
    }
  }
}

// ============================================
// 🔐 Auth Service مع إدارة FCM Token
// ============================================
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // ✅ Login مع تسجيل FCM Token
  Future<void> loginUser(String email, String password) async {
    try {
      print('🔐 محاولة تسجيل الدخول...');
      
      // 1️⃣ تسجيل الدخول في Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      String userId = userCredential.user!.uid;
      print('✅ تم تسجيل الدخول بنجاح!');
      print('👤 User ID: $userId');
      
      // 2️⃣ الحصول على FCM Token
      String? fcmToken = await _fcm.getToken();
      
      if (fcmToken != null) {
        print('📱 FCM Token: ${fcmToken.substring(0, 30)}...');
        
        // 3️⃣ تسجيل Token في Backend
        bool tokenUpdated = await NotificationService.updateTokenOnLogin(
          userId, 
          fcmToken
        );
        
        if (tokenUpdated) {
          print('✅ تم ربط FCM Token بالحساب بنجاح!');
        } else {
          print('⚠️ فشل ربط FCM Token - الإشعارات قد لا تعمل');
        }
      } else {
        print('⚠️ لم يتم الحصول على FCM Token');
      }
      
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      rethrow;
    }
  }
  
  // ✅ Logout مع حذف FCM Token
  Future<void> logoutUser() async {
    try {
      print('🚪 محاولة تسجيل الخروج...');
      
      // 1️⃣ الحصول على User ID قبل تسجيل الخروج
      String? userId = _auth.currentUser?.uid;
      
      if (userId != null) {
        print('👤 User ID: $userId');
        
        // 2️⃣ حذف FCM Token من Backend
        bool tokenDeleted = await NotificationService.deleteTokenOnLogout(userId);
        
        if (tokenDeleted) {
          print('✅ تم حذف FCM Token بنجاح!');
        } else {
          print('⚠️ فشل حذف FCM Token - قد تصل إشعارات بعد الخروج');
        }
        
        // 3️⃣ (اختياري) حذف Token من الجهاز
        await _fcm.deleteToken();
        print('📱 تم حذف Token من الجهاز');
        
      } else {
        print('⚠️ لا يوجد مستخدم مسجل دخول');
      }
      
      // 4️⃣ تسجيل الخروج من Firebase Auth
      await _auth.signOut();
      print('✅ تم تسجيل الخروج بنجاح!');
      
    } catch (e) {
      print('❌ خطأ في تسجيل الخروج: $e');
      rethrow;
    }
  }
}

// ============================================
// 🎨 مثال UI للـ Logout
// ============================================
class LogoutButton extends StatelessWidget {
  final AuthService _authService = AuthService();
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // إظهار تأكيد
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('تسجيل الخروج'),
            content: Text('هل أنت متأكد من تسجيل الخروج؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('تسجيل الخروج'),
              ),
            ],
          ),
        );
        
        if (confirm == true) {
          // إظهار تحميل
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: CircularProgressIndicator(),
            ),
          );
          
          try {
            // تسجيل الخروج
            await _authService.logoutUser();
            
            // إغلاق شاشة التحميل
            Navigator.pop(context);
            
            // الانتقال لشاشة تسجيل الدخول
            Navigator.pushReplacementNamed(context, '/login');
            
            // رسالة نجاح
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم تسجيل الخروج بنجاح'),
                backgroundColor: Colors.green,
              ),
            );
            
          } catch (e) {
            // إغلاق شاشة التحميل
            Navigator.pop(context);
            
            // رسالة خطأ
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('حدث خطأ: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Text('تسجيل الخروج'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ============================================
// 📦 Dependencies المطلوبة في pubspec.yaml
// ============================================
/*
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  firebase_messaging: ^14.7.9
  
  # HTTP
  http: ^1.1.0
  
  # (اختياري) State Management
  provider: ^6.1.1
  # أو
  riverpod: ^2.4.9
*/

// ============================================
// 🔧 تعليمات التشغيل
// ============================================
/*

1️⃣ تثبيت Packages الجديدة في Backend:
   cd backend
   npm install

2️⃣ إعادة تشغيل Backend:
   npm run dev

3️⃣ في Flutter - تحديث BASE_URL في NotificationService:
   - للتجربة المحلية: http://localhost:3000
   - للـ Production: رابط السيرفر الحقيقي
   - إذا كنت تستخدم Android Emulator: http://10.0.2.2:3000

4️⃣ استخدام الـ Service في التطبيق:
   - في Login: استدعي loginUser()
   - في Logout: استدعي logoutUser()

5️⃣ اختبار:
   أ) سجل دخول من تطبيق ولي الأمر
   ب) ابعت إشعار من الإدمن - يجب أن يصل ✅
   ج) سجل خروج من تطبيق ولي الأمر
   د) ابعت إشعار مرة أخرى - يجب ألا يصل ❌
   
✅ الآن الإشعارات لن تصل للحسابات المغلقة!

*/

// ============================================
// 🐛 Troubleshooting
// ============================================
/*

❌ المشكلة: لا يزال الإشعار يصل بعد Logout
✅ الحل:
   1. تأكد أن Backend يعمل
   2. تأكد من BASE_URL صحيح
   3. راجع console logs في Backend
   4. تأكد من userId صحيح
   5. تحقق من Firestore - يجب أن fcmToken يكون null

❌ المشكلة: خطأ في الاتصال بـ Backend
✅ الحل:
   1. تأكد أن Backend يعمل: npm run dev
   2. تأكد من الـ PORT (default: 3000)
   3. للـ Android Emulator استخدم: http://10.0.2.2:3000
   4. تأكد من تفعيل CORS في Backend (موجود)

❌ المشكلة: الإشعارات لا تصل بعد Login
✅ الحل:
   1. تأكد من استدعاء updateTokenOnLogin()
   2. راجع console logs
   3. تحقق من Firestore - يجب أن fcmToken موجود
   4. تأكد من Firebase Messaging permissions

*/
