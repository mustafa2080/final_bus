import 'package:flutter/material.dart';
import '../../services/master_notification_service.dart';
import '../../widgets/premium_notification_widget.dart';

/// 🧪 شاشة اختبار الإشعارات الاحترافية
class PremiumNotificationTestScreen extends StatefulWidget {
  const PremiumNotificationTestScreen({super.key});

  @override
  State<PremiumNotificationTestScreen> createState() => _PremiumNotificationTestScreenState();
}

class _PremiumNotificationTestScreenState extends State<PremiumNotificationTestScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _cardController;
  
  final MasterNotificationService _notificationService = MasterNotificationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _initializeService();
    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    setState(() => _isLoading = true);
    await _notificationService.initialize();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade900,
              Colors.blue.shade700,
              Colors.blue.shade500,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAnimatedHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTestControls(),
                      Expanded(
                        child: _buildNotificationDisplay(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء الرأس المتحرك
  Widget _buildAnimatedHeader() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _headerController,
        curve: Curves.elasticOut,
      )),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                const Text(
                  'اختبار الإشعارات المطور',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'جار تهيئة خدمة الإشعارات...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade300,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'خدمة الإشعارات جاهزة',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// بناء أزرار التحكم في الاختبار
  Widget _buildTestControls() {
    return FadeTransition(
      opacity: _cardController,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🚀 اختبار أنواع الإشعارات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildTestGrid(),
          ],
        ),
      ),
    );
  }

  /// بناء شبكة أزرار الاختبار
  Widget _buildTestGrid() {
    final tests = [
      {
        'title': 'تسكين طالب',
        'icon': Icons.person_add,
        'color': Colors.green,
        'action': () => _testStudentAssignment(),
      },
      {
        'title': 'ركوب الباص',
        'icon': Icons.directions_bus,
        'color': Colors.orange,
        'action': () => _testBusBoarding(),
      },
      {
        'title': 'نزول من الباص',
        'icon': Icons.home,
        'color': Colors.blue,
        'action': () => _testBusAlighting(),
      },
      {
        'title': 'طلب غياب',
        'icon': Icons.event_busy,
        'color': Colors.purple,
        'action': () => _testAbsenceRequest(),
      },
      {
        'title': 'موافقة غياب',
        'icon': Icons.check_circle,
        'color': Colors.teal,
        'action': () => _testAbsenceApproved(),
      },
      {
        'title': 'شكوى جديدة',
        'icon': Icons.report_problem,
        'color': Colors.indigo,
        'action': () => _testComplaint(),
      },
      {
        'title': 'رد على شكوى',
        'icon': Icons.reply,
        'color': Colors.cyan,
        'action': () => _testComplaintReply(),
      },
      {
        'title': 'حالة طوارئ',
        'icon': Icons.warning,
        'color': Colors.red,
        'action': () => _testEmergency(),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: tests.length,
      itemBuilder: (context, index) {
        final test = tests[index];
        return _buildTestButton(
          title: test['title'] as String,
          icon: test['icon'] as IconData,
          color: test['color'] as Color,
          onTap: test['action'] as VoidCallback,
        );
      },
    );
  }

  /// بناء زر اختبار واحد
  Widget _buildTestButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                color.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// بناء عرض الإشعارات
  Widget _buildNotificationDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list,
                color: Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'إشعاراتك الحالية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _notificationService.getUserNotifications(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PremiumNotificationWidget(
                onNotificationTap: (notification) {
                  _showNotificationDetails(notification);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // 🧪 طرق الاختبار
  // ===============================

  /// اختبار إشعار تسكين طالب
  Future<void> _testStudentAssignment() async {
    await _notificationService.sendStudentAssignmentNotification(
      studentId: 'test_student_001',
      studentName: 'أحمد محمد',
      busId: 'باص 001',
      parentId: 'current_user',
      supervisorId: 'supervisor_001',
      excludeAdminId: 'current_admin',
    );
    _showSuccessMessage('تم إرسال إشعار تسكين الطالب بنجاح');
  }

  /// اختبار إشعار ركوب الباص
  Future<void> _testBusBoarding() async {
    await _notificationService.sendBusBoardingNotification(
      studentId: 'test_student_002',
      studentName: 'فاطمة علي',
      busId: 'باص 002',
      parentId: 'current_user',
      location: 'محطة المدرسة',
    );
    _showSuccessMessage('تم إرسال إشعار ركوب الباص بنجاح');
  }

  /// اختبار إشعار نزول من الباص
  Future<void> _testBusAlighting() async {
    await _notificationService.sendBusAlightingNotification(
      studentId: 'test_student_003',
      studentName: 'محمد حسن',
      busId: 'باص 003',
      parentId: 'current_user',
      location: 'منزل الطالب',
    );
    _showSuccessMessage('تم إرسال إشعار وصول الطالب بنجاح');
  }

  /// اختبار إشعار طلب غياب
  Future<void> _testAbsenceRequest() async {
    await _notificationService.sendAbsenceRequestNotification(
      studentId: 'test_student_004',
      studentName: 'زينب أحمد',
      parentId: 'current_user',
      reason: 'مرض',
      date: DateTime.now().add(const Duration(days: 1)),
      supervisorId: 'supervisor_001',
    );
    _showSuccessMessage('تم إرسال طلب الغياب بنجاح');
  }

  /// اختبار إشعار موافقة غياب
  Future<void> _testAbsenceApproved() async {
    await _notificationService.sendAbsenceApprovedNotification(
      studentId: 'test_student_005',
      studentName: 'عبدالله محمود',
      parentId: 'current_user',
      date: DateTime.now().add(const Duration(days: 2)),
    );
    _showSuccessMessage('تم إرسال موافقة الغياب بنجاح');
  }

  /// اختبار إشعار شكوى
  Future<void> _testComplaint() async {
    await _notificationService.sendComplaintNotification(
      complaintId: 'complaint_001',
      parentName: 'أم أحمد',
      subject: 'تأخير الباص',
      description: 'الباص يتأخر كل يوم عن موعده',
    );
    _showSuccessMessage('تم إرسال الشكوى بنجاح');
  }

  /// اختبار إشعار رد على شكوى
  Future<void> _testComplaintReply() async {
    await _notificationService.sendComplaintReplyNotification(
      complaintId: 'complaint_002',
      parentId: 'current_user',
      subject: 'تأخير الباص',
      reply: 'سيتم حل هذه المشكلة في أقرب وقت',
    );
    _showSuccessMessage('تم إرسال الرد على الشكوى بنجاح');
  }

  /// اختبار إشعار طوارئ
  Future<void> _testEmergency() async {
    await _notificationService.sendEmergencyNotification(
      title: 'حالة طوارئ',
      message: 'تعطل في الباص رقم 001 - يرجى التواصل فوراً',
      busId: 'باص 001',
      studentId: 'emergency_student',
    );
    _showSuccessMessage('تم إرسال إنذار الطوارئ بنجاح');
  }

  /// عرض رسالة نجاح
  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  /// عرض تفاصيل الإشعار
  void _showNotificationDetails(Map<String, dynamic> notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade600,
                        Colors.indigo.shade700,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'تفاصيل الإشعار',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailItem('العنوان', notification['title'] ?? '-'),
                        _buildDetailItem('المحتوى', notification['body'] ?? '-'),
                        _buildDetailItem('النوع', notification['type'] ?? '-'),
                        _buildDetailItem('حالة القراءة', notification['isRead'] == true ? 'مقروء' : 'غير مقروء'),
                        if (notification['createdAt'] != null)
                          _buildDetailItem('وقت الإرسال', _formatDetailTime(notification['createdAt'].toDate())),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// بناء عنصر تفصيل
  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// تنسيق الوقت للتفاصيل
  String _formatDetailTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
