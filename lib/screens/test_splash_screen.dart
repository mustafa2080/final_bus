import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '../firebase_options.dart';
import '../services/persistent_auth_service.dart';
import '../services/theme_service.dart';

/// صفحة اختبار بسيطة لفحص مشكلة الـ splash screen
class TestSplashScreen extends StatefulWidget {
  const TestSplashScreen({super.key});

  @override
  State<TestSplashScreen> createState() => _TestSplashScreenState();
}

class _TestSplashScreenState extends State<TestSplashScreen> {
  String _status = 'جاري التهيئة...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    try {
      setState(() {
        _status = '1. فحص Firebase...';
      });
      
      await Future.delayed(Duration(milliseconds: 500));
      
      // فحص Firebase
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      
      setState(() {
        _status = '2. Firebase مهيأ بنجاح ✅';
      });
      
      await Future.delayed(Duration(milliseconds: 500));
      
      setState(() {
        _status = '3. فحص خدمة المصادقة...';
      });
      
      // فحص خدمة المصادقة
      final authService = PersistentAuthService();
      await authService.initialize();
      
      setState(() {
        _status = '4. خدمة المصادقة مهيأة بنجاح ✅';
      });
      
      await Future.delayed(Duration(milliseconds: 500));
      
      setState(() {
        _status = '5. جميع الاختبارات مكتملة ✅\nيمكنك الانتقال لشاشة تسجيل الدخول';
      });
      
      // انتقل لشاشة تسجيل الدخول بعد 3 ثوان
      await Future.delayed(Duration(seconds: 3));
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      
    } catch (e, stackTrace) {
      print('❌ Test error: $e');
      print('❌ Stack trace: $stackTrace');
      
      setState(() {
        _status = '❌ خطأ في الاختبار:\n$e\n\nسيتم الانتقال لشاشة تسجيل الدخول...';
        _hasError = true;
      });
      
      // انتقل لشاشة تسجيل الدخول بعد 5 ثوان في حالة الخطأ
      await Future.delayed(Duration(seconds: 5));
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // لوجو
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    size: 60,
                    color: Colors.blue.shade600,
                  ),
                ),
                
                SizedBox(height: 30),
                
                // عنوان التطبيق
                Text(
                  'كيدز باص - اختبار',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 50),
                
                // حالة الاختبار
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 40),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (!_hasError) ...[
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade600,
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: _hasError ? Colors.red : Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 30),
                
                // معلومات إضافية
                Text(
                  'اختبار مكونات التطبيق...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
