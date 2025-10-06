import 'package:flutter/material.dart';
import '../../services/notification_test_service.dart';
import '../../services/simple_fcm_service.dart';

/// شاشة اختبار الإشعارات المحسنة
class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final NotificationTestService _testService = NotificationTestService();
  final SimpleFCMService _fcmService = SimpleFCMService();
  
  bool _isLoading = false;
  String _statusMessage = '';
  Map<String, dynamic>? _statistics;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _testService.getTestStatistics();
      setState(() {
        _statistics = stats;
        _statusMessage = stats['serviceHealthy'] ? 'الخدمة تعمل بشكل صحيح' : 'يوجد مشكلة في الخدمة';
      });
    } catch (e) {
      setState(() => _statusMessage = 'خطأ في تحميل الإحصائيات: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runTest(String testName, Future<void> Function() testFunction) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري تشغيل اختبار: $testName...';
    });

    try {
      await testFunction();
      setState(() => _statusMessage = 'تم تشغيل اختبار $testName بنجاح ✅');
      
      // تحديث الإحصائيات
      await _loadStatistics();
    } catch (e) {
      setState(() => _statusMessage = 'فشل اختبار $testName: $e ❌');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبار الإشعارات'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة الحالة
            _buildStatusCard(),
            
            const SizedBox(height: 20),
            
            // بطاقة الإحصائيات
            _buildStatisticsCard(),
            
            const SizedBox(height: 20),
            
            // أزرار الاختبارات
            _buildTestButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _statistics?['serviceHealthy'] == true 
                      ? Icons.check_circle 
                      : Icons.error,
                  color: _statistics?['serviceHealthy'] == true 
                      ? Colors.green 
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'حالة الخدمة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: _statusMessage.contains('✅') 
                      ? Colors.green 
                      : _statusMessage.contains('❌') 
                          ? Colors.red 
                          : Colors.blue,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصائيات الخدمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatItem('حالة الخدمة', _statistics!['serviceHealthy'] ? 'سليمة' : 'بها مشاكل'),
            _buildStatItem('تهيئة FCM', _statistics!['fcmInitialized'] ? 'مكتملة' : 'غير مكتملة'),
            _buildStatItem('توفر Token', _statistics!['hasToken'] ? 'متوفر' : 'غير متوفر'),
            _buildStatItem('آخر فحص', _formatTimestamp(_statistics!['testTimestamp'])),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTestButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اختبارات الإشعارات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // اختبار شامل
        _buildTestButton(
          'تشغيل جميع الاختبارات',
          Icons.play_arrow,
          Colors.blue,
          () => _runTest('جميع الاختبارات', _testService.runAllTests),
        ),
        
        const SizedBox(height: 12),
        
        // اختبارات فردية
        _buildTestButton(
          'اختبار تحديث حالة الطالب',
          Icons.person,
          Colors.green,
          () => _runTest('تحديث حالة الطالب', _testService.testStudentStatusNotification),
        ),
        
        _buildTestButton(
          'اختبار الاستبيان الجديد',
          Icons.poll,
          Colors.orange,
          () => _runTest('الاستبيان الجديد', _testService.testNewSurveyNotification),
        ),
        
        _buildTestButton(
          'اختبار إكمال الاستبيان',
          Icons.check_circle,
          Colors.purple,
          () => _runTest('إكمال الاستبيان', _testService.testSurveyCompletionNotification),
        ),
        
        _buildTestButton(
          'اختبار تذكير الاستبيان',
          Icons.alarm,
          Colors.amber,
          () => _runTest('تذكير الاستبيان', _testService.testSurveyReminderNotification),
        ),
        
        _buildTestButton(
          'اختبار إشعار الطوارئ',
          Icons.warning,
          Colors.red,
          () => _runTest('إشعار الطوارئ', _testService.testEmergencyNotification),
        ),
        
        const SizedBox(height: 20),
        
        // اختبارات متقدمة
        const Text(
          'اختبارات متقدمة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        _buildTestButton(
          'اختبار إشعار لأولياء الأمور',
          Icons.group,
          Colors.teal,
          () => _runTest('إشعار أولياء الأمور', () => _testService.testSendToUserType('parent')),
        ),
        
        _buildTestButton(
          'اختبار إشعار للمشرفين',
          Icons.supervisor_account,
          Colors.indigo,
          () => _runTest('إشعار المشرفين', () => _testService.testSendToUserType('supervisor')),
        ),
        
        _buildTestButton(
          'اختبار إشعار للإدارة',
          Icons.admin_panel_settings,
          Colors.deepPurple,
          () => _runTest('إشعار الإدارة', () => _testService.testSendToUserType('admin')),
        ),
        
        const SizedBox(height: 20),
        
        // أزرار التشخيص والاختبار
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runDiagnosis,
                icon: const Icon(Icons.medical_services),
                label: const Text('تشخيص المشاكل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendTestNotification,
                icon: const Icon(Icons.send),
                label: const Text('إشعار اختبار'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // زر تحديث الإحصائيات
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _loadStatistics,
          icon: const Icon(Icons.refresh),
          label: const Text('تحديث الإحصائيات'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[600],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTestButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return timestamp;
    }
  }

  /// تشخيص مشاكل الإشعارات
  Future<void> _runDiagnosis() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري تشخيص مشاكل الإشعارات...';
    });

    try {
      final diagnosis = await _fcmService.diagnosePushNotifications();
      
      // عرض نتائج التشخيص
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('نتائج التشخيص'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDiagnosisItem('الخدمة مهيأة', diagnosis['serviceInitialized']),
                  _buildDiagnosisItem('يوجد Token', diagnosis['hasToken']),
                  _buildDiagnosisItem('حالة الأذونات', diagnosis['authorizationStatus']),
                  _buildDiagnosisItem('التنبيهات', diagnosis['alert']),
                  _buildDiagnosisItem('الصوت', diagnosis['sound']),
                  _buildDiagnosisItem('إشعارات النظام', diagnosis['systemNotificationsEnabled']),
                  _buildDiagnosisItem('اختبار الإشعار المحلي', diagnosis['localNotificationTest']),
                  if (diagnosis['error'] != null)
                    _buildDiagnosisItem('خطأ', diagnosis['error'], isError: true),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }

      setState(() => _statusMessage = 'تم إجراء التشخيص بنجاح ✅');
    } catch (e) {
      setState(() => _statusMessage = 'فشل في التشخيص: $e ❌');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDiagnosisItem(String label, dynamic value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'غير متوفر',
              style: TextStyle(
                color: isError ? Colors.red : 
                       value == true || value == 'success' ? Colors.green : 
                       Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// إرسال إشعار اختبار
  Future<void> _sendTestNotification() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'جاري إرسال إشعار اختبار...';
    });

    try {
      await _fcmService.sendTestNotification();
      setState(() => _statusMessage = 'تم إرسال إشعار الاختبار بنجاح ✅');
    } catch (e) {
      setState(() => _statusMessage = 'فشل في إرسال إشعار الاختبار: $e ❌');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
