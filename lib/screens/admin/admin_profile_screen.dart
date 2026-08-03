import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:animations/animations.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/admin_bottom_navigation.dart';

// استيراد النماذج من مجلد models
import '../../models/user_model.dart';
import '../../models/student_model.dart';
import '../../models/complaint_model.dart';
import '../../models/trip_model.dart';
import '../../models/bus_model.dart';
import '../../services/database_service.dart';
import '../../widgets/responsive_grid_view.dart';
import '../../utils/responsive_helper.dart';



// خلفية متحركة
class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE3F2FD),
            const Color(0xFFBBDEFB),
            const Color(0xFF90CAF9),
          ],
        ),
      ),
      child: widget.child,
    );
  }
}

// شبكة عرض متجاوبة
class ResponsiveGridView extends StatelessWidget {
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int largeDesktopColumns;
  final double mobileAspectRatio;
  final double tabletAspectRatio;
  final double desktopAspectRatio;
  final double largeDesktopAspectRatio;
  final List<Widget> children;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGridView({
    super.key,
    this.mobileColumns = 2,
    this.tabletColumns = 3,
    this.desktopColumns = 4,
    this.largeDesktopColumns = 5,
    this.mobileAspectRatio = 1.0,
    this.tabletAspectRatio = 1.0,
    this.desktopAspectRatio = 1.0,
    this.largeDesktopAspectRatio = 1.0,
    required this.children,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio;

        if (constraints.maxWidth < 600) {
          // Mobile
          crossAxisCount = mobileColumns;
          childAspectRatio = mobileAspectRatio;
        } else if (constraints.maxWidth < 1024) {
          // Tablet
          crossAxisCount = tabletColumns;
          childAspectRatio = tabletAspectRatio;
        } else if (constraints.maxWidth < 1440) {
          // Desktop
          crossAxisCount = desktopColumns;
          childAspectRatio = desktopAspectRatio;
        } else {
          // Large Desktop
          crossAxisCount = largeDesktopColumns;
          childAspectRatio = largeDesktopAspectRatio;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: shrinkWrap,
          physics: physics,
          children: children,
        );
      },
    );
  }
}

// مساعد الاستجابة
class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1024;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;
}

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with TickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _adminUser;
  bool _isLoading = true;

  // إحصائيات النظام من قاعدة البيانات
  int _totalStudents = 0;
  int _totalParents = 0;
  int _totalSupervisors = 0;
  int _totalBuses = 0;
  int _todayTrips = 0;
  int _totalComplaints = 0;
  int _pendingComplaints = 0;
  int _resolvedComplaints = 0;

  // معلومات الأداء
  double _systemUptime = 99.8;
  double _responseTime = 2.3;
  int _activeUsers = 0;

  // آخر الأنشطة
  List<Map<String, dynamic>> _recentActivities = [];

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    _loadAllData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      await Future.wait([
        _loadAdminData(),
        _loadSystemStats(),
        _loadRecentActivities(),
      ]);
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAdminData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await _databaseService.getUserById(user.uid);
        if (userData != null) {
          setState(() {
            _adminUser = userData;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading admin data: $e');
    }
  }

  Future<void> _loadSystemStats() async {
    try {
      // جلب إحصائيات الطلاب
      final studentsSnapshot = await _firestore.collection('students').get();
      _totalStudents = studentsSnapshot.docs.length;

      // جلب إحصائيات أولياء الأمور
      final parentsSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'parent')
          .get();
      _totalParents = parentsSnapshot.docs.length;

      // جلب إحصائيات المشرفين
      final supervisorsSnapshot = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'supervisor')
          .get();
      _totalSupervisors = supervisorsSnapshot.docs.length;

      // جلب إحصائيات الحافلات
      final busesSnapshot = await _firestore.collection('buses').get();
      _totalBuses = busesSnapshot.docs.length;

      // جلب إحصائيات الرحلات اليوم
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
      final tripsSnapshot = await _firestore
          .collection('trips')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      _todayTrips = tripsSnapshot.docs.length;

      // جلب إحصائيات الشكاوى
      final complaintsSnapshot = await _firestore.collection('complaints').get();
      _totalComplaints = complaintsSnapshot.docs.length;

      // تصنيف الشكاوى
      _pendingComplaints = 0;
      _resolvedComplaints = 0;
      
      for (var doc in complaintsSnapshot.docs) {
        final status = doc.data()['status'] as String?;
        if (status == 'pending') {
          _pendingComplaints++;
        } else if (status == 'resolved') {
          _resolvedComplaints++;
        }
      }

      // حساب المستخدمين النشطين (الذين سجلوا دخول في آخر ساعة)
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final activeUsersSnapshot = await _firestore
          .collection('users')
          .where('lastLoginAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneHourAgo))
          .get();
      _activeUsers = activeUsersSnapshot.docs.length;

    } catch (e) {
      debugPrint('❌ Error loading system stats: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      List<Map<String, dynamic>> activities = [];

      // آخر الرحلات
      final recentTrips = await _firestore
          .collection('trips')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      for (var doc in recentTrips.docs) {
        final data = doc.data();
        final studentName = data['studentName'] ?? 'غير معروف';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        activities.add({
          'type': 'trip',
          'title': 'رحلة جديدة',
          'description': 'رحلة للطالب $studentName',
          'time': createdAt,
          'icon': Icons.directions_bus,
          'color': Colors.blue,
        });
      }

      // آخر الشكاوى
      final recentComplaints = await _firestore
          .collection('complaints')
          .orderBy('createdAt', descending: true)
          .limit(2)
          .get();

      for (var doc in recentComplaints.docs) {
        final data = doc.data();
        final title = data['title'] ?? 'شكوى جديدة';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        activities.add({
          'type': 'complaint',
          'title': 'شكوى جديدة',
          'description': title,
          'time': createdAt,
          'icon': Icons.feedback,
          'color': Colors.red,
        });
      }

      // آخر المستخدمين المسجلين
      final recentUsers = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(2)
          .get();

      for (var doc in recentUsers.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'مستخدم جديد';
        final userType = data['userType'] ?? 'parent';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        String description = 'تسجيل ';
        if (userType == 'parent') {
          description += 'ولي أمر جديد: $name';
        } else if (userType == 'supervisor') {
          description += 'مشرف جديد: $name';
        } else {
          description += 'مستخدم جديد: $name';
        }

        activities.add({
          'type': 'user',
          'title': 'مستخدم جديد',
          'description': description,
          'time': createdAt,
          'icon': Icons.person_add,
          'color': Colors.purple,
        });
      }

      // ترتيب الأنشطة حسب الوقت
      activities.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));
      
      setState(() {
        _recentActivities = activities.take(6).toList();
      });

    } catch (e) {
      debugPrint('❌ Error loading recent activities: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: AnimatedBackground(
        child: _isLoading ? _buildLoadingScreen() : _buildProfileContent(),
      ),
      bottomNavigationBar: const AdminBottomNavigation(currentIndex: 4),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
          ),
          SizedBox(height: 16),
          Text(
            'جاري تحميل البيانات...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF1E88E5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(),
              ),
              backgroundColor: const Color(0xFF1E88E5),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadAllData();
                  },
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildSystemOverview(),
                    const SizedBox(height: 24),
                    _buildDetailedStats(),
                    const SizedBox(height: 24),
                    _buildPerformanceMetrics(),
                    const SizedBox(height: 24),
                    _buildRecentActivities(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 80), // مسافة للتنقل السفلي
                  ],
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.01,
            numberOfParticles: 50,
            maxBlastForce: 100,
            minBlastForce: 80,
            gravity: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E88E5),
            const Color(0xFF1976D2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الملف الشخصي',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'عرض معلومات المدير وإحصائيات النظام',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(204),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF1E88E5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminUser?.name ?? 'مدير النظام',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _adminUser?.email ?? 'admin@mybus.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withAlpha(204),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withAlpha(128)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Colors.green, size: 8),
                                  SizedBox(width: 4),
                                  Text(
                                    'متصل',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard, color: Color(0xFF1E88E5), size: 24),
              SizedBox(width: 8),
              Text(
                'نظرة عامة على النظام',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ResponsiveGridView(
            mobileColumns: 2,
            tabletColumns: 4,
            desktopColumns: 4,
            largeDesktopColumns: 4,
            mobileAspectRatio: 1.2,
            tabletAspectRatio: 1.0,
            desktopAspectRatio: 1.0,
            largeDesktopAspectRatio: 1.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard('الطلاب', _totalStudents, Icons.school, Colors.blue),
              _buildStatCard(
                  'أولياء الأمور', _totalParents, Icons.people, Colors.green),
              _buildStatCard('المشرفين', _totalSupervisors,
                  Icons.supervisor_account, Colors.orange),
              _buildStatCard(
                  'الحافلات', _totalBuses, Icons.directions_bus, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return PageTransitionSwitcher(
      transitionBuilder: (
        Widget child,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
      duration: const Duration(milliseconds: 500),
      child: Container(
        key: ValueKey<int>(value),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF1E88E5), size: 24),
              SizedBox(width: 8),
              Text(
                'إحصائيات مفصلة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailedStatRow(
              'رحلات اليوم', _todayTrips, Icons.today, Colors.indigo),
          const SizedBox(height: 12),
          _buildDetailedStatRow('إجمالي الشكاوى', _totalComplaints,
              Icons.feedback, Colors.red),
          const SizedBox(height: 12),
          _buildDetailedStatRow('الشكاوى المعلقة', _pendingComplaints,
              Icons.pending, Colors.orange),
          const SizedBox(height: 12),
          _buildDetailedStatRow('الشكاوى المحلولة', _resolvedComplaints,
              Icons.check_circle, Colors.green),
          const SizedBox(height: 12),
          _buildDetailedStatRow('المستخدمين النشطين', _activeUsers,
              Icons.people_alt, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildDetailedStatRow(
      String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed, color: Color(0xFF1E88E5), size: 24),
              SizedBox(width: 8),
              Text(
                'مؤشرات الأداء',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPerformanceIndicator(
              'وقت تشغيل النظام',
              '${_systemUptime.toStringAsFixed(1)}%',
              _systemUptime / 100,
              Colors.green),
          const SizedBox(height: 16),
          _buildPerformanceIndicator(
              'وقت الاستجابة',
              '${_responseTime.toStringAsFixed(1)}s',
              1 - (_responseTime / 10),
              Colors.blue),
          const SizedBox(height: 16),
          _buildPerformanceIndicator(
              'معدل الرضا',
              '${((_resolvedComplaints /
                              (_totalComplaints == 0 ? 1 : _totalComplaints)) *
                          100)
                      .toStringAsFixed(1)}%',
              _resolvedComplaints / (_totalComplaints == 0 ? 1 : _totalComplaints),
              Colors.purple),
        ],
      ),
    );
  }

  Widget _buildPerformanceIndicator(
      String title, String value, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 800),
          builder: (context, value, child) {
            return LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivities() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Color(0xFF1E88E5), size: 24),
              SizedBox(width: 8),
              Text(
                'آخر الأنشطة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentActivities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'لا توجد أنشطة حديثة',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )
          else
            Column(
              children: _recentActivities.map((activity) {
                return _buildActivityItem(activity);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final dateTime = activity['time'] as DateTime;
    final timeAgo = _getTimeAgo(dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (activity['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              activity['icon'] as IconData,
              color: activity['color'] as Color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity['description'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
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

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, color: Color(0xFF1E88E5), size: 24),
              SizedBox(width: 8),
              Text(
                'إجراءات سريعة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ResponsiveGridView(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            largeDesktopColumns: 3,
            mobileAspectRatio: 3.5,
            tabletAspectRatio: 3.0,
            desktopAspectRatio: 2.8,
            largeDesktopAspectRatio: 2.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildActionButton(
                'إعدادات النظام',
                Icons.settings,
                Colors.blue,
                () => context.push('/admin/settings'),
              ),
              _buildActionButton(
                'التقارير',
                Icons.assessment,
                Colors.green,
                () => context.push('/admin/reports'),
              ),
              _buildActionButton(
                'النسخ الاحتياطي',
                Icons.backup,
                Colors.orange,
                () => _showBackupDialog(),
              ),
              _buildActionButton(
                'إدارة المستخدمين',
                Icons.people_alt,
                Colors.purple,
                () => context.push('/admin/students'),
              ),
              _buildActionButton(
                'الشكاوى',
                Icons.feedback,
                Colors.red,
                () => context.push('/admin/complaints'),
              ),
              _buildActionButton(
                'التحليلات المتقدمة',
                Icons.analytics,
                Colors.teal,
                () => context.push('/admin/advanced-analytics'),
              ),
              _buildActionButton(
                'اختبار الإشعارات',
                Icons.notifications_active,
                Colors.deepPurple,
                () => context.push('/admin/notification-test'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.backup, color: Color(0xFF1E88E5)),
            SizedBox(width: 8),
            Text('النسخ الاحتياطي'),
          ],
        ),
        content: const Text('هل تريد إنشاء نسخة احتياطية من البيانات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performBackup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('إنشاء نسخة احتياطية'),
          ),
        ],
      ),
    );
  }

  void _performBackup() {
    _confettiController.play();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم بدء عملية النسخ الاحتياطي...'),
        backgroundColor: Colors.green,
      ),
    );
  }

}