import 'package:flutter/material.dart';
import '../services/simple_fcm_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final SimpleFCMService _fcmService = SimpleFCMService();
  String _statusMessage = 'جاهز للاختبار';
  bool _isLoading = false;
  Map<String, dynamic>? _diagnosis;

  @override
  void initState() {
    super.initState();
    _runDiagnosis();
  }

  Future<void> _runDiagnosis() async {
    setState(() => _isLoading = true);
    try {
      final diagnosis = await _fcmService.diagnosePushNotifications();
      setState(() {
        _diagnosis = diagnosis;
        _statusMessage = 'تم فحص النظام';
      });
    } catch (e) {
      setState(() => _statusMessage = 'خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري إرسال إشعار تجريبي...';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('لم تسجل الدخول');
      }

      await _fcmService.sendTestNotification();
      
      setState(() => _statusMessage = '✅ تم إرسال الإشعار بنجاح!');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال الإشعار! اغلق التطبيق لترى الإشعار خارجياً'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      setState(() => _statusMessage = '❌ فشل: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendToAllAdmins() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري إرسال لجميع المدراء...';
    });

    try {
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: '🧪 اختبار إشعار جماعي',
        body: 'هذا إشعار اختبار لجميع المدراء - ${DateTime.now().toString().substring(11, 19)}',
        channelId: 'mybus_notifications',
      );
      
      setState(() => _statusMessage = '✅ تم إرسال الإشعار لجميع المدراء!');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال الإشعار لجميع المدراء!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _statusMessage = '❌ فشل: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmergency() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري إرسال إشعار طوارئ...';
    });

    try {
      await _fcmService.sendEmergencyNotification(
        title: '🚨 تنبيه طوارئ!',
        body: 'هذا اختبار لإشعار الطوارئ - ${DateTime.now().toString().substring(11, 19)}',
        data: {
          'type': 'emergency_test',
          'priority': 'max',
        },
      );
      
      setState(() => _statusMessage = '✅ تم إرسال إشعار الطوارئ!');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال إشعار الطوارئ!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() => _statusMessage = '❌ فشل: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 اختبار الإشعارات'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline, size: 48, color: Colors.blue),
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Diagnosis Info
                  if (_diagnosis != null) ...[
                    const Text(
                      '📊 معلومات النظام',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('الخدمة مهيأة', _diagnosis!['serviceInitialized'] ?? false),
                            _buildInfoRow('يوجد Token', _diagnosis!['hasToken'] ?? false),
                            _buildInfoRow('طول Token', '${_diagnosis!['tokenLength'] ?? 0} حرف'),
                            _buildInfoRow('حالة الإذن', _diagnosis!['authorizationStatus'] ?? 'unknown'),
                            _buildInfoRow('المنصة', _diagnosis!['platform'] ?? 'unknown'),
                            _buildInfoRow('اختبار محلي', _diagnosis!['localNotificationTest'] ?? 'unknown'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Test Buttons
                  const Text(
                    '🎯 اختبارات الإشعارات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Test 1: Personal notification
                  ElevatedButton.icon(
                    onPressed: _sendTestNotification,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('إرسال إشعار تجريبي لي'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيرسل إشعار لك فقط. اغلق التطبيق بعد الإرسال لترى الإشعار خارجياً.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Test 2: Bulk notification
                  ElevatedButton.icon(
                    onPressed: _sendToAllAdmins,
                    icon: const Icon(Icons.group),
                    label: const Text('إرسال لجميع المدراء'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيرسل إشعار لجميع المستخدمين من نوع admin.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Test 3: Emergency
                  ElevatedButton.icon(
                    onPressed: _sendEmergency,
                    icon: const Icon(Icons.warning),
                    label: const Text('إرسال إشعار طوارئ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيرسل إشعار طوارئ لجميع المستخدمين (admins, supervisors, parents).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Diagnosis Button
                  OutlinedButton.icon(
                    onPressed: _runDiagnosis,
                    icon: const Icon(Icons.health_and_safety),
                    label: const Text('إعادة فحص النظام'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Instructions
                  Card(
                    color: Colors.amber.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '📝 تعليمات الاختبار',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('1. اضغط على زر "إرسال إشعار تجريبي"'),
                          Text('2. اغلق التطبيق تماماً (أو اضغط Home)'),
                          Text('3. انتظر 2-5 ثواني'),
                          Text('4. يجب أن ترى الإشعار في شريط الإشعارات'),
                          Text('5. يجب أن تسمع صوت وتشعر باهتزاز'),
                          SizedBox(height: 8),
                          Text(
                            '⚠️ ملاحظة: تأكد من تفعيل الإشعارات في إعدادات الجهاز',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Token Info
                  if (_fcmService.currentToken != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '🔑 FCM Token',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _fcmService.currentToken!,
                              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    Color color = Colors.black;
    IconData icon = Icons.info;
    
    if (value is bool) {
      color = value ? Colors.green : Colors.red;
      icon = value ? Icons.check_circle : Icons.cancel;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
