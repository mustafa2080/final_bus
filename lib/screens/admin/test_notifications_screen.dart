import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/simple_fcm_service.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class TestNotificationsScreen extends StatefulWidget {
  const TestNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<TestNotificationsScreen> createState() => _TestNotificationsScreenState();
}

class _TestNotificationsScreenState extends State<TestNotificationsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _selectedUserType = 'parent';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = 'اختبار الإشعارات';
    _bodyController.text = 'هذا إشعار تجريبي لاختبار النظام';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار الإشعارات'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // معلومات FCM
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'معلومات FCM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer<SimpleFCMService>(
                      builder: (context, fcmService, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الحالة: ${fcmService.isInitialized ? "✅ مهيأة" : "❌ غير مهيأة"}'),
                            const SizedBox(height: 4),
                            Text('Token: ${fcmService.currentToken?.substring(0, 20) ?? "غير متوفر"}...'),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // إعدادات الإشعار
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إعدادات الإشعار',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // نوع المستخدم
                    DropdownButtonFormField<String>(
                      value: _selectedUserType,
                      decoration: const InputDecoration(
                        labelText: 'نوع المستخدم المستهدف',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('أدمن')),
                        DropdownMenuItem(value: 'supervisor', child: Text('مشرف')),
                        DropdownMenuItem(value: 'parent', child: Text('ولي أمر')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedUserType = value!;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // عنوان الإشعار
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الإشعار',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // محتوى الإشعار
                    TextField(
                      controller: _bodyController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'محتوى الإشعار',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // أزرار الاختبار
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendTestNotification,
                    icon: const Icon(Icons.send),
                    label: const Text('إرسال إشعار تجريبي'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendLocalTestNotification,
                    icon: const Icon(Icons.notifications),
                    label: const Text('إشعار محلي'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // إشعارات الطوارئ
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendEmergencyNotification,
              icon: const Icon(Icons.warning),
              label: const Text('إرسال إشعار طوارئ لجميع المستخدمين'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // معلومات إضافية
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملاحظات مهمة:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• تأكد من أن التطبيق في الخلفية أو مغلق لاختبار الإشعارات الخارجية'),
                    const Text('• الإشعارات المحلية تظهر فوراً'),
                    const Text('• الإشعارات الخارجية تحتاج Cloud Functions'),
                    const Text('• تحقق من إعدادات الإشعارات في الجهاز'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      _showSnackBar('يرجى ملء جميع الحقول', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fcmService = Provider.of<SimpleFCMService>(context, listen: false);
      
      await fcmService.sendNotificationToUserType(
        userType: _selectedUserType,
        title: _titleController.text,
        body: _bodyController.text,
        data: {
          'type': 'test_notification',
          'source': 'admin_test',
          'timestamp': DateTime.now().toIso8601String(),
        },
        channelId: 'mybus_notifications',
      );

      _showSnackBar('تم إرسال الإشعار بنجاح', Colors.green);
    } catch (e) {
      _showSnackBar('خطأ في إرسال الإشعار: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendLocalTestNotification() async {
    try {
      final fcmService = Provider.of<SimpleFCMService>(context, listen: false);
      
      // إرسال إشعار محلي مباشر للمستخدم الحالي
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await fcmService.sendNotificationToUser(
          userId: currentUser.uid,
          title: _titleController.text,
          body: _bodyController.text,
          data: {
            'type': 'local_test',
            'source': 'admin_test',
          },
          channelId: 'mybus_notifications',
        );
      }

      _showSnackBar('تم إرسال الإشعار المحلي', Colors.green);
    } catch (e) {
      _showSnackBar('خطأ في الإشعار المحلي: $e', Colors.red);
    }
  }

  Future<void> _sendEmergencyNotification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fcmService = Provider.of<SimpleFCMService>(context, listen: false);
      
      // إرسال إشعار طوارئ لجميع أنواع المستخدمين
      await Future.wait([
        fcmService.sendNotificationToUserType(
          userType: 'admin',
          title: '🚨 تنبيه طوارئ',
          body: 'هذا إشعار طوارئ تجريبي من نظام الاختبار',
          data: {
            'type': 'emergency',
            'source': 'admin_test',
            'priority': 'high',
          },
          channelId: 'emergency_notifications',
        ),
        fcmService.sendNotificationToUserType(
          userType: 'supervisor',
          title: '🚨 تنبيه طوارئ',
          body: 'هذا إشعار طوارئ تجريبي من نظام الاختبار',
          data: {
            'type': 'emergency',
            'source': 'admin_test',
            'priority': 'high',
          },
          channelId: 'emergency_notifications',
        ),
        fcmService.sendNotificationToUserType(
          userType: 'parent',
          title: '🚨 تنبيه طوارئ',
          body: 'هذا إشعار طوارئ تجريبي من نظام الاختبار',
          data: {
            'type': 'emergency',
            'source': 'admin_test',
            'priority': 'high',
          },
          channelId: 'emergency_notifications',
        ),
      ]);

      _showSnackBar('تم إرسال إشعارات الطوارئ لجميع المستخدمين', Colors.green);
    } catch (e) {
      _showSnackBar('خطأ في إرسال إشعارات الطوارئ: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}