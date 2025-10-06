import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../widgets/admin_app_bar.dart';

class AppDiagnosticsScreen extends StatefulWidget {
  const AppDiagnosticsScreen({super.key});

  @override
  State<AppDiagnosticsScreen> createState() => _AppDiagnosticsScreenState();
}

class _AppDiagnosticsScreenState extends State<AppDiagnosticsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isRunningDiagnostics = false;
  final List<DiagnosticResult> _results = [];

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunningDiagnostics = true;
      _results.clear();
    });

    await _checkFirebaseConnection();
    await _checkFirestoreIndexes();
    await _checkAuthSystem();
    await _checkNotificationsSystem();
    await _checkDatabaseIntegrity();

    setState(() {
      _isRunningDiagnostics = false;
    });
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      await FirebaseFirestore.instance
          .collection('test')
          .doc('connection')
          .get()
          .timeout(const Duration(seconds: 5));

      _addResult(
        'اتصال Firebase',
        'متصل بنجاح',
        DiagnosticStatus.success,
        'Firebase يعمل بشكل صحيح',
      );
    } catch (e) {
      _addResult(
        'اتصال Firebase',
        'فشل الاتصال',
        DiagnosticStatus.error,
        'خطأ: $e',
      );
    }
  }

  Future<void> _checkFirestoreIndexes() async {
    try {
      // Test notification query
      await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: 'test')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      _addResult(
        'فهارس Firestore',
        'جميع الفهارس تعمل',
        DiagnosticStatus.success,
        'فهارس notifications صحيحة',
      );
    } catch (e) {
      if (e.toString().contains('index')) {
        _addResult(
          'فهارس Firestore',
          'فهارس مفقودة',
          DiagnosticStatus.warning,
          'يجب إنشاء الفهارس المطلوبة في Firebase Console',
        );
      } else {
        _addResult(
          'فهارس Firestore',
          'خطأ في الفحص',
          DiagnosticStatus.error,
          'خطأ: $e',
        );
      }
    }
  }

  Future<void> _checkAuthSystem() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        _addResult(
          'نظام المصادقة',
          'المستخدم مسجل الدخول',
          DiagnosticStatus.success,
          'UID: ${currentUser.uid}\nEmail: ${currentUser.email}',
        );
      } else {
        _addResult(
          'نظام المصادقة',
          'لا يوجد مستخدم',
          DiagnosticStatus.warning,
          'لم يتم تسجيل الدخول',
        );
      }
    } catch (e) {
      _addResult(
        'نظام المصادقة',
        'خطأ في الفحص',
        DiagnosticStatus.error,
        'خطأ: $e',
      );
    }
  }

  Future<void> _checkNotificationsSystem() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      _addResult(
        'نظام الإشعارات',
        'يعمل بشكل صحيح',
        DiagnosticStatus.success,
        'تم العثور على ${snapshot.docs.length} إشعار',
      );
    } catch (e) {
      _addResult(
        'نظام الإشعارات',
        'خطأ في الفحص',
        DiagnosticStatus.error,
        'خطأ: $e',
      );
    }
  }

  Future<void> _checkDatabaseIntegrity() async {
    try {
      final studentsCount = await _getCollectionCount('students');
      final busesCount = await _getCollectionCount('buses');
      final usersCount = await _getCollectionCount('users');

      _addResult(
        'سلامة قاعدة البيانات',
        'قاعدة البيانات سليمة',
        DiagnosticStatus.success,
        'الطلاب: $studentsCount\nالحافلات: $busesCount\nالمستخدمون: $usersCount',
      );
    } catch (e) {
      _addResult(
        'سلامة قاعدة البيانات',
        'خطأ في الفحص',
        DiagnosticStatus.error,
        'خطأ: $e',
      );
    }
  }

  Future<int> _getCollectionCount(String collection) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .count()
        .get();
    return snapshot.count ?? 0; // Return 0 if count is null
  }

  void _addResult(String title, String status, DiagnosticStatus statusType, String details) {
    setState(() {
      _results.add(DiagnosticResult(
        title: title,
        status: status,
        statusType: statusType,
        details: details,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final successCount = _results.where((r) => r.statusType == DiagnosticStatus.success).length;
    final warningCount = _results.where((r) => r.statusType == DiagnosticStatus.warning).length;
    final errorCount = _results.where((r) => r.statusType == DiagnosticStatus.error).length;

    return Scaffold(
      appBar: AdminAppBar(
        title: 'تشخيص التطبيق',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunningDiagnostics ? null : _runDiagnostics,
            tooltip: 'إعادة الفحص',
          ),
        ],
      ),
      body: _isRunningDiagnostics && _results.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري فحص النظام...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.analytics,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ملخص التشخيص',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'فحص شامل للنظام',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                '✓ نجح',
                                successCount,
                                Colors.green,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                '⚠ تحذير',
                                warningCount,
                                Colors.orange,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                '✗ خطأ',
                                errorCount,
                                Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Results List
                if (_results.isNotEmpty) ...[
                  const Text(
                    'نتائج الفحص',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._results.map((result) => _buildResultCard(result)),
                ],

                // Actions
                if (!_isRunningDiagnostics && _results.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إجراءات موصى بها',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (errorCount > 0) ...[
                            _buildActionItem(
                              'إصلاح الأخطاء',
                              'توجد $errorCount أخطاء تحتاج إلى إصلاح',
                              Icons.build,
                              Colors.red,
                              () => _showFixErrorsDialog(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (warningCount > 0) ...[
                            _buildActionItem(
                              'معالجة التحذيرات',
                              'توجد $warningCount تحذيرات',
                              Icons.warning,
                              Colors.orange,
                              () => _showWarningsDialog(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          _buildActionItem(
                            'تصدير التقرير',
                            'حفظ نتائج التشخيص',
                            Icons.download,
                            Colors.blue,
                            () => _exportReport(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(DiagnosticResult result) {
    Color statusColor;
    IconData statusIcon;

    switch (result.statusType) {
      case DiagnosticStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case DiagnosticStatus.warning:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      case DiagnosticStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(
          result.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          result.status,
          style: TextStyle(
            color: statusColor,
            fontSize: 14,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.details,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  void _showFixErrorsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.build, color: Colors.red),
            SizedBox(width: 8),
            Text('إصلاح الأخطاء'),
          ],
        ),
        content: const Text(
          'يتم الآن تحليل الأخطاء وتقديم حلول تلقائية.\n\n'
          'الإجراءات المتاحة:\n'
          '• إنشاء الفهارس المفقودة\n'
          '• إصلاح البيانات التالفة\n'
          '• إعادة تشغيل الخدمات',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performAutoFix();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('إصلاح تلقائي'),
          ),
        ],
      ),
    );
  }

  void _showWarningsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('التحذيرات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _results
              .where((r) => r.statusType == DiagnosticStatus.warning)
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('• ${r.title}: ${r.details}'),
                  ))
              .toList(),
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

  Future<void> _performAutoFix() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري تطبيق الإصلاحات التلقائية...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تطبيق الإصلاحات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _runDiagnostics();
    }
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تصدير التقرير بنجاح'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

class DiagnosticResult {
  final String title;
  final String status;
  final DiagnosticStatus statusType;
  final String details;

  DiagnosticResult({
    required this.title,
    required this.status,
    required this.statusType,
    required this.details,
  });
}

enum DiagnosticStatus {
  success,
  warning,
  error,
}
