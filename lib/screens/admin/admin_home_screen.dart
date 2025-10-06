import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../../services/database_service.dart';
import '../../services/backup_service.dart';
import '../../models/student_model.dart';
import '../../models/absence_model.dart';
import '../../models/user_model.dart';
import '../../widgets/admin_bottom_navigation.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/responsive_widgets.dart';
import '../../utils/notification_test_helper.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final BackupService _backupService = BackupService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeBackupService();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  Future<void> _initializeBackupService() async {
    try {
      await _backupService.initialize();
      debugPrint('✅ تم تهيئة خدمة النسخ الاحتياطي بنجاح');
      if (!_backupService.isAutoBackupEnabled) {
        debugPrint('🔧 إنشاء نسخة احتياطية تجريبية...');
        final result = await _backupService.createSystemBackup();
        if (result['success'] == true) {
          debugPrint('✅ تم إنشاء النسخة التجريبية: ${result['backupId']}');
        }
      }
    } catch (e) {
      debugPrint('❌ خطأ في تهيئة خدمة النسخ الاحتياطي: $e');
    }
  }

  void _showNotificationTestDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.notifications_active, color: Color(0xFFFF6B6B)),
                SizedBox(width: 8),
                Text('اختبار الإشعارات'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('اختر نوع الاختبار الذي تريد تشغيله:'),
                  const SizedBox(height: 16),
                  ...[
                    {'title': 'اختبار سريع', 'subtitle': 'إشعار تجريبي بسيط', 'icon': Icons.flash_on, 'color': const Color(0xFF4CAF50), 'action': _runQuickTest},
                    {'title': 'اختبار شامل', 'subtitle': 'جميع أنواع الإشعارات', 'icon': Icons.playlist_add_check, 'color': const Color(0xFF03DAC6), 'action': _runFullTest},
                    {'title': 'اختبار الترحيب', 'subtitle': 'إشعار ترحيب تجريبي', 'icon': Icons.waving_hand, 'color': const Color(0xFFFF9800), 'action': _runWelcomeTest},
                    {'title': 'معلومات النظام', 'subtitle': 'عرض حالة نظام الإشعارات', 'icon': Icons.info, 'color': const Color(0xFF9C27B0), 'action': _showSystemInfo},
                  ].map((e) => _buildTestButton(
                        e['title'] as String,
                        e['subtitle'] as String,
                        e['icon'] as IconData,
                        e['color'] as Color,
                        e['action'] as VoidCallback,
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTestButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ZoomIn(
      duration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
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
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runQuickTest() async {
    try {
      await NotificationTestHelper.quickTest();
      _showSuccessSnackBar('تم إرسال الإشعار التجريبي بنجاح');
    } catch (e) {
      _showErrorSnackBar('خطأ في إرسال الإشعار: $e');
    }
  }

  Future<void> _runFullTest() async {
    try {
      _showInfoSnackBar('جاري إرسال جميع أنواع الإشعارات...');
      await NotificationTestHelper.runFullNotificationTest();
      _showSuccessSnackBar('تم إرسال جميع الإشعارات التجريبية بنجاح');
    } catch (e) {
      _showErrorSnackBar('خطأ في الاختبار الشامل: $e');
    }
  }

  Future<void> _runWelcomeTest() async {
    try {
      await NotificationTestHelper.testWelcomeNotification();
      _showSuccessSnackBar('تم إرسال إشعار الترحيب التجريبي');
    } catch (e) {
      _showErrorSnackBar('خطأ في إرسال إشعار الترحيب: $e');
    }
  }

  void _showSystemInfo() {
    NotificationTestHelper.printSystemInfo();
    _showInfoSnackBar('تم طباعة معلومات النظام في وحدة التحكم');
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFF44336),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _backupService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdminAppBar(
        title: 'لوحة تحكم الإدارة',
        actions: [
          StreamBuilder<int>(
            stream: _databaseService.getAdminNotificationsCount(),
            builder: (context, snapshot) {
              final notificationCount = snapshot.data ?? 0;
              final hasNotifications = notificationCount > 0;

              return FadeIn(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(
                          hasNotifications
                              ? Icons.notifications_active
                              : Icons.notifications_outlined,
                          color: hasNotifications ? Colors.amber : Colors.white,
                          size: 26,
                        ),
                        onPressed: () => context.push('/admin/notifications'),
                        tooltip: hasNotifications
                            ? '$notificationCount إشعار جديد'
                            : 'الإشعارات',
                        style: IconButton.styleFrom(
                          backgroundColor: hasNotifications
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      if (hasNotifications)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                notificationCount > 99
                                    ? '99+'
                                    : notificationCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Enhanced Animated Background
          _buildAnimatedBackground(),
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: ResponsiveHelper.getSpacing(context) * 5),
            child: Column(
              children: [
                SizedBox(height: ResponsiveHelper.getSpacing(context) * 0.5),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    padding: ResponsiveHelper.getPadding(context,
                      mobilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      tabletPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      desktopPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _buildDashboardCards(),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context) * 1.5),
                FadeInUp(
                  duration: const Duration(milliseconds: 700),
                  child: Container(
                    padding: ResponsiveHelper.getPadding(context,
                      mobilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      tabletPadding: const EdgeInsets.symmetric(horizontal: 20),
                      desktopPadding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: _buildManagementOptions(),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context) * 1.75),
                FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  child: Container(
                    padding: ResponsiveHelper.getPadding(context,
                      mobilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      tabletPadding: const EdgeInsets.symmetric(horizontal: 20),
                      desktopPadding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: _buildQuickStatsSection(),
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context) * 1.75),
                FadeInUp(
                  duration: const Duration(milliseconds: 900),
                  child: Container(
                    padding: ResponsiveHelper.getPadding(context,
                      mobilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      tabletPadding: const EdgeInsets.symmetric(horizontal: 20),
                      desktopPadding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: _buildRecentActivitySection(),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AdminBottomNavigation(
        currentIndex: 0,
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedContainer(
      duration: const Duration(seconds: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!.withOpacity(0.3),
            Colors.green[50]!.withOpacity(0.3),
            Colors.orange[50]!.withOpacity(0.3),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 40,
            right: 20,
            child: FadeIn(
              duration: const Duration(seconds: 2),
              child: Icon(
                Icons.directions_bus,
                size: 80,
                color: Colors.blue[300]!.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: 30,
            child: FadeIn(
              duration: const Duration(seconds: 3),
              child: Icon(
                Icons.school,
                size: 60,
                color: Colors.green[300]!.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: 220,
            right: 40,
            child: FadeIn(
              duration: const Duration(seconds: 4),
              child: Icon(
                Icons.child_care,
                size: 50,
                color: Colors.orange[300]!.withOpacity(0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards() {
    return StreamBuilder<List<StudentModel>>(
      stream: _databaseService.getAllStudents(),
      builder: (context, snapshot) {
        final students = snapshot.data ?? [];
        final totalStudents = students.length;
        final studentsOnBus =
            students.where((s) => s.currentStatus == StudentStatus.onBus).length;
        final studentsAtSchool =
            students.where((s) => s.currentStatus == StudentStatus.atSchool).length;

        return FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: Row(
            children: [
              Expanded(
                child: _buildDashboardCard(
                  title: 'إجمالي الطلاب',
                  value: '$totalStudents',
                  icon: Icons.school,
                  color: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardCard(
                  title: 'في الباص',
                  value: '$studentsOnBus',
                  icon: Icons.directions_bus,
                  color: const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDashboardCard(
                  title: 'في المدرسة',
                  value: '$studentsAtSchool',
                  icon: Icons.location_on,
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return ZoomIn(
      duration: const Duration(milliseconds: 400),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: ResponsiveHelper.getPadding(context,
          mobilePadding: const EdgeInsets.all(16),
          tabletPadding: const EdgeInsets.all(20),
          desktopPadding: const EdgeInsets.all(24),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ResponsiveHelper.getBorderRadius(context)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                    mobile: 28, tablet: 32, desktop: 36),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                    mobile: 13, tablet: 14, desktop: 15),
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementOptions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInLeft(
            duration: const Duration(milliseconds: 500),
            child: Row(
              children: [
                Container(
                  padding: ResponsiveHelper.getPadding(context,
                    mobilePadding: const EdgeInsets.all(10),
                    tabletPadding: const EdgeInsets.all(12),
                    desktopPadding: const EdgeInsets.all(14),
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveHelper.getBorderRadius(context) * 0.75),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E88E5).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: ResponsiveHelper.getIconSize(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة النظام',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getFontSize(context,
                              mobile: 22, tablet: 24, desktop: 26),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E88E5),
                        ),
                      ),
                      Text(
                        'لوحة التحكم الرئيسية',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getFontSize(context,
                              mobile: 14, tablet: 15, desktop: 16),
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          ResponsiveGridView(
            mobileColumns: 2,
            tabletColumns: 3,
            desktopColumns: 4,
            largeDesktopColumns: 4,
            mobileAspectRatio: 0.85,
            tabletAspectRatio: 0.8,
            desktopAspectRatio: 0.75,
            largeDesktopAspectRatio: 0.7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildManagementCard(
                icon: Icons.backup,
                label: 'نسخ احتياطي',
                description: 'حفظ واستعادة البيانات',
                color: const Color(0xFF2196F3),
                onTap: () => _showBackupDialog(),
              ),
              _buildManagementCard(
                icon: Icons.people_alt,
                label: 'إدارة أولياء الأمور',
                description: 'إدارة حسابات أولياء الأمور',
                color: const Color(0xFFFF9800),
                onTap: () => context.push('/admin/parents'),
              ),
              _buildManagementCard(
                icon: Icons.settings,
                label: 'إعدادات النظام',
                description: 'تكوين التطبيق',
                color: const Color(0xFF9C27B0),
                onTap: () => _showSystemSettings(),
              ),
              _buildManagementCard(
                icon: Icons.feedback,
                label: 'الشكاوى',
                description: 'إدارة شكاوى أولياء الأمور',
                color: const Color(0xFFFF5722),
                onTap: () => context.push('/admin/complaints'),
              ),
              _buildManagementCard(
                icon: Icons.poll,
                label: 'تقارير الاستبيانات',
                description: 'تقييم المشرفين وسلوك الطلاب',
                color: const Color(0xFF4CAF50),
                onTap: () => context.push('/admin/surveys-reports'),
              ),
              _buildManagementCard(
                icon: Icons.person_off,
                label: 'إدارة الغياب',
                description: 'موافقة طلبات الغياب والإحصائيات',
                color: const Color(0xFFE91E63),
                onTap: () => context.push('/admin/absence-management'),
              ),
              _buildManagementCard(
                icon: Icons.directions_bus,
                label: 'إدارة السيارات',
                description: 'إضافة وتعديل السيارات والسائقين',
                color: const Color(0xFF4CAF50),
                onTap: () => context.push('/admin/buses-management'),
              ),
              _buildManagementCard(
                icon: Icons.assignment_ind,
                label: 'تعيينات المشرفين',
                description: 'ربط المشرفين بالسيارات وإدارة الطوارئ',
                color: const Color(0xFF1E88E5),
                onTap: () => context.push('/admin/supervisor-assignments'),
              ),
              _buildManagementCard(
                icon: Icons.notifications_active,
                label: 'اختبار الإشعارات',
                description: 'اختبار نظام الإشعارات والتنبيهات',
                color: const Color(0xFFFF6B6B),
                onTap: () => _showNotificationTestDialog(),
              ),
              _buildManagementCard(
                icon: Icons.bug_report,
                label: 'تشخيص التطبيق',
                description: 'فحص شامل للنظام وإصلاح المشاكل',
                color: const Color(0xFF9B59B6),
                onTap: () => context.push('/admin/diagnostics'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCard({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getFontSize(context,
                              mobile: 12, tablet: 13, desktop: 14),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A202C),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getFontSize(context,
                              mobile: 9, tablet: 10, desktop: 11),
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.backup,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'النسخ الاحتياطي',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'إدارة النسخ الاحتياطية للبيانات',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getFontSize(context,
                        mobile: 16, tablet: 17, desktop: 18),
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _createBackup();
                        },
                        icon: const Icon(Icons.cloud_upload, size: 20),
                        label: const Text(
                          'إنشاء نسخة',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _restoreBackup();
                        },
                        icon: const Icon(Icons.cloud_download, size: 20),
                        label: const Text(
                          'استعادة',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.blue[600], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'النسخ التلقائي',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<bool>(
                        future: Future.value(_backupService.isAutoBackupEnabled),
                        builder: (context, snapshot) {
                          final isEnabled = snapshot.data ?? false;
                          return SwitchListTile(
                            title: const Text(
                              'تفعيل النسخ التلقائي',
                              style: TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              isEnabled ? 'مفعل - كل 24 ساعة' : 'معطل',
                              style: TextStyle(
                                fontSize: 11,
                                color: isEnabled ? Colors.green : Colors.grey,
                              ),
                            ),
                            value: isEnabled,
                            onChanged: (value) async {
                              await _backupService.setAutoBackupEnabled(value);
                              setState(() {});
                            },
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showBackupStatistics();
              },
              child: const Text('الإحصائيات'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('جاري إنشاء النسخة الاحتياطية...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );

      final backupResult = await _backupService.createSystemBackup();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (backupResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('تم إنشاء النسخة الاحتياطية بنجاح!'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'معرف النسخة: ${backupResult['backupId']}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    'عدد السجلات: ${backupResult['totalRecords']}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              action: SnackBarAction(
                label: 'عرض التفاصيل',
                textColor: Colors.white,
                onPressed: () => _showBackupDetails(backupResult),
              ),
            ),
          );
        } else {
          _showErrorSnackBar('فشل في إنشاء النسخة الاحتياطية: ${backupResult['error']}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('خطأ في إنشاء النسخة الاحتياطية: $e');
      }
    }
  }

  Future<void> _restoreBackup() async {
    _showBackupsList();
  }

  void _showNotificationDialog() {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('إرسال إشعار جماعي'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('إرسال إشعار لجميع أولياء الأمور'),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'نص الإشعار',
                  border: OutlineInputBorder(),
                  hintText: 'اكتب رسالة الإشعار هنا...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (messageController.text.isNotEmpty) {
                  Navigator.pop(context);
                  _sendNotification(messageController.text);
                }
              },
              child: const Text('إرسال'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendNotification(String message) {
    _showSuccessSnackBar('تم إرسال الإشعار: $message');
  }

  void _showSystemSettings() {
    context.push('/admin/settings');
  }

  Widget _buildQuickStatsSection() {
    return StreamBuilder<List<StudentModel>>(
      stream: _databaseService.getAllStudents(),
      builder: (context, snapshot) {
        final students = snapshot.data ?? [];

        return FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[100]!, Colors.green[50]!],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'إحصائيات سريعة',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getFontSize(context,
                            mobile: 20, tablet: 22, desktop: 24),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ResponsiveGridView(
                  mobileColumns: 2,
                  tabletColumns: 2,
                  desktopColumns: 4,
                  largeDesktopColumns: 4,
                  mobileAspectRatio: 1.0,
                  tabletAspectRatio: 0.9,
                  desktopAspectRatio: 0.8,
                  largeDesktopAspectRatio: 0.8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildQuickStatCard(
                      'الطلاب النشطون',
                      '${students.where((s) => s.isActive).length}',
                      Icons.people_alt,
                      Colors.blue,
                      '${students.isNotEmpty ? (students.where((s) => s.isActive).length / students.length * 100).toStringAsFixed(1) : 0}% من الإجمالي',
                    ),
                    _buildQuickStatCard(
                      'في الطريق',
                      '${students.where((s) => s.currentStatus == StudentStatus.onBus).length}',
                      Icons.directions_bus,
                      Colors.orange,
                      'طلاب في الحافلات',
                    ),
                    _buildQuickStatCard(
                      'وصلوا المدرسة',
                      '${students.where((s) => s.currentStatus == StudentStatus.atSchool).length}',
                      Icons.school,
                      Colors.green,
                      'طلاب في المدرسة',
                    ),
                    _buildQuickStatCard(
                      'غير نشطين',
                      '${students.where((s) => !s.isActive).length}',
                      Icons.person_off,
                      Colors.purple,
                      'طلاب غير نشطين',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStatCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return ZoomIn(
      duration: const Duration(milliseconds: 400),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getFontSize(context,
                          mobile: 12, tablet: 13, desktop: 14),
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                    mobile: 24, tablet: 26, desktop: 28),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                    mobile: 10, tablet: 11, desktop: 12),
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo[100]!, Colors.indigo[50]!],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Colors.indigo,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'النشاط الأخير',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getFontSize(context,
                        mobile: 20, tablet: 22, desktop: 24),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/admin/reports'),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<AbsenceModel>>(
              stream: _databaseService.getRecentAbsenceNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildActivityItem(
                    'لا توجد أنشطة حديثة',
                    'اليوم',
                    Icons.info,
                    Colors.grey,
                  );
                }

                final recentActivities = snapshot.data!.take(4).toList();
                return Column(
                  children: recentActivities
                      .asMap()
                      .entries
                      .map((entry) => FadeInUp(
                            duration: Duration(milliseconds: 400 + entry.key * 100),
                            child: Column(
                              children: [
                                _buildActivityItem(
                                  'طلب غياب من ${entry.value.studentName}',
                                  _getTimeAgo(entry.value.createdAt),
                                  Icons.person_off,
                                  _getAbsenceStatusColor(entry.value.status),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/admin/reports'),
                    icon: const Icon(Icons.assessment, size: 18),
                    label: const Text('التقارير'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context,
                      mobile: 14, tablet: 15, desktop: 16),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2C3E50),
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context,
                      mobile: 12, tablet: 13, desktop: 14),
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return 'منذ ${difference.inDays} يوم';
    }
  }

  Color _getAbsenceStatusColor(AbsenceStatus status) {
    switch (status) {
      case AbsenceStatus.pending:
        return Colors.orange;
      case AbsenceStatus.approved:
        return Colors.green;
      case AbsenceStatus.rejected:
        return Colors.red;
      case AbsenceStatus.reported:
        return Colors.blue;
    }
  }

  void _showBackupDetails(Map<String, dynamic> backupResult) {
    showDialog(
      context: context,
      builder: (context) => FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Text('تفاصيل النسخة الاحتياطية'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('معرف النسخة', backupResult['backupId'] ?? 'غير محدد'),
                _buildDetailRow('إجمالي السجلات', '${backupResult['totalRecords'] ?? 0}'),
                _buildDetailRow('عدد المجموعات', '${backupResult['collections'] ?? 0}'),
                _buildDetailRow('الحجم', '${((backupResult['size'] ?? 0) / 1024).toStringAsFixed(1)} KB'),
                _buildDetailRow('التاريخ', DateTime.now().toString().substring(0, 19)),
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
      ),
    );
  }

  void _showBackupsList() {
    showDialog(
      context: context,
      builder: (context) => FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.restore, color: Colors.orange),
              SizedBox(width: 8),
              Text('استعادة النسخة الاحتياطية'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getBackupsList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('خطأ في تحميل النسخ: ${snapshot.error}'));
                }

                final backups = snapshot.data ?? [];

                if (backups.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.backup, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('لا توجد نسخ احتياطية متاحة'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: backups.length,
                  itemBuilder: (context, index) {
                    final backup = backups[index];
                    return FadeInUp(
                      duration: Duration(milliseconds: 300 + index * 100),
                      child: _buildBackupListItem(backup),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupListItem(Map<String, dynamic> backup) {
    final createdAt = backup['createdAt'] as String?;
    final totalRecords = backup['totalRecords'] as int? ?? 0;
    final size = backup['size'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[100]!, Colors.blue[50]!],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.backup, color: Colors.blue),
        ),
        title: Text(
          backup['id'] ?? 'نسخة احتياطية',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: ${createdAt?.substring(0, 19) ?? 'غير محدد'}'),
            Text('السجلات: $totalRecords | الحجم: ${(size / 1024).toStringAsFixed(1)} KB'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info, color: Colors.blue),
              onPressed: () => _showBackupInfo(backup),
              tooltip: 'عرض التفاصيل',
            ),
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.orange),
              onPressed: () => _confirmRestoreBackup(backup),
              tooltip: 'استعادة',
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getBackupsList() {
    return _backupService.getBackupsList();
  }

  void _showBackupInfo(Map<String, dynamic> backup) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Text('معلومات النسخة الاحتياطية'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('المعرف', backup['id'] ?? 'غير محدد'),
                _buildDetailRow('التاريخ', backup['createdAt']?.toString().substring(0, 19) ?? 'غير محدد'),
                _buildDetailRow('المنشئ', backup['createdBy'] ?? 'غير محدد'),
                _buildDetailRow('الإصدار', backup['version'] ?? 'غير محدد'),
                _buildDetailRow('إجمالي السجلات', '${backup['totalRecords'] ?? 0}'),
                _buildDetailRow('الحجم', '${((backup['size'] ?? 0) / 1024).toStringAsFixed(1)} KB'),
                _buildDetailRow('الحالة', backup['status'] ?? 'غير محدد'),
                const SizedBox(height: 16),
                const Text(
                  'المجموعات المشمولة:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (backup['collections'] != null)
                  ...((backup['collections'] as List)
                      .map((collection) => Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.folder, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(collection.toString()),
                              ],
                            ),
                          ))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmRestoreBackup(backup);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('استعادة هذه النسخة'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestoreBackup(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('تأكيد الاستعادة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚠️ تحذير مهم',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'استعادة النسخة الاحتياطية ستؤدي إلى:\n'
                '• حذف جميع البيانات الحالية\n'
                '• استبدالها ببيانات النسخة المحددة\n'
                '• فقدان أي تغييرات حدثت بعد تاريخ النسخة\n\n'
                'هذه العملية لا يمكن التراجع عنها!',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('النسخة المحددة: ${backup['id']}'),
                    Text('التاريخ: ${backup['createdAt']?.toString().substring(0, 19)}'),
                    Text('السجلات: ${backup['totalRecords']}'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performRestore(backup);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('تأكيد الاستعادة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performRestore(Map<String, dynamic> backup) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('جاري استعادة النسخة الاحتياطية...'),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(minutes: 5),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );

      final result = await _restoreFromBackup(backup);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (result['success'] == true) {
          _showSuccessSnackBar('تم استعادة ${result['restoredRecords']} سجل بنجاح');
        } else {
          _showErrorSnackBar('فشل في استعادة النسخة: ${result['error']}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('خطأ في استعادة النسخة: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _restoreFromBackup(Map<String, dynamic> backup) async {
    try {
      final backupData = backup['data'] as Map<String, dynamic>?;
      if (backupData == null) {
        throw Exception('بيانات النسخة الاحتياطية غير صالحة');
      }

      int restoredRecords = 0;
      final firestore = _databaseService.firestore;

      for (final entry in backupData.entries) {
        final collectionName = entry.key;
        final collectionData = entry.value as List<dynamic>;

        debugPrint('🔄 استعادة مجموعة $collectionName: ${collectionData.length} سجل');

        final currentDocs = await firestore.collection(collectionName).get();
        final batch = firestore.batch();

        for (final doc in currentDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        final restoreBatch = firestore.batch();
        for (final record in collectionData) {
          final recordMap = record as Map<String, dynamic>;
          final docId = recordMap['id'] as String;
          recordMap.remove('id');

          restoreBatch.set(
            firestore.collection(collectionName).doc(docId),
            recordMap,
          );
        }
        await restoreBatch.commit();

        restoredRecords += collectionData.length;
        debugPrint('✅ تم استعادة مجموعة $collectionName');
      }

      debugPrint('✅ تم استعادة النسخة الاحتياطية بنجاح: $restoredRecords سجل');

      return {
        'success': true,
        'restoredRecords': restoredRecords,
      };
    } catch (e) {
      debugPrint('❌ خطأ في استعادة النسخة الاحتياطية: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  void _showBackupStatistics() {
    showDialog(
      context: context,
      builder: (context) => FadeInUp(
        duration: const Duration(milliseconds: 300),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue),
              SizedBox(width: 8),
              Text('إحصائيات النسخ الاحتياطي'),
            ],
          ),
          content: FutureBuilder<Map<String, dynamic>>(
            future: _backupService.getBackupStatistics(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Text('خطأ في تحميل الإحصائيات: ${snapshot.error}');
              }

              final stats = snapshot.data ?? {};
              final totalBackups = stats['totalBackups'] ?? 0;
              final lastBackup = stats['lastBackup'] as DateTime?;
              final totalSize = stats['totalSize'] ?? 0;
              final isAutoEnabled = stats['isAutoEnabled'] ?? false;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow('إجمالي النسخ', '$totalBackups نسخة'),
                    _buildStatRow(
                      'آخر نسخة احتياطية',
                      lastBackup != null
                          ? '${lastBackup.toString().substring(0, 19)}'
                          : 'لا توجد نسخ',
                    ),
                    _buildStatRow(
                      'إجمالي الحجم',
                      '${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB',
                    ),
                    _buildStatRow(
                      'النسخ التلقائي',
                      isAutoEnabled ? 'مفعل' : 'معطل',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[50]!, Colors.blue[100]!],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[600], size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                'معلومات مهمة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• يتم الاحتفاظ بآخر 10 نسخ احتياطية فقط\n'
                            '• النسخ التلقائي يعمل كل 24 ساعة\n'
                            '• يمكن تغيير إعدادات النسخ من الإعدادات',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _createBackup();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('إنشاء نسخة الآن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}