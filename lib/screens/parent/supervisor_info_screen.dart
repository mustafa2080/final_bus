import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/student_model.dart';
import '../../models/supervisor_assignment_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive_helper.dart';

class SupervisorInfoScreen extends StatefulWidget {
  const SupervisorInfoScreen({super.key});

  @override
  State<SupervisorInfoScreen> createState() => _SupervisorInfoScreenState();
}

class _SupervisorInfoScreenState extends State<SupervisorInfoScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  
  List<StudentModel> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    try {
      setState(() => _isLoading = true);
      
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final children = await _databaseService.getStudentsByParent(currentUser.uid).first;
        setState(() {
          _children = children;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.supervisor_account,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معلومات المشرفين',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'المشرفين المسؤولين عن أطفالك',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E88E5),
                Color(0xFF1976D2),
                Color(0xFF1565C0),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? _buildEmptyState()
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveHelper.getDeviceType(context) ==
                              DeviceType.mobile
                          ? double.infinity
                          : 700,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.all(
                        ResponsiveHelper.getResponsivePadding(context, 16),
                      ),
                      itemCount: _children.length,
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        return _buildChildSupervisorCard(child);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[100]!,
                    Colors.grey[50]!,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا يوجد أطفال مسجلين',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'يرجى التواصل مع إدارة المدرسة لتسجيل أطفالك',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildSupervisorCard(StudentModel child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Child Info Header
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      child.name.isNotEmpty ? child.name[0] : 'ط',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.route, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            'خط السير: ${child.busRoute}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Supervisors Info for both directions
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pickup Supervisor (To School)
                _buildDirectionSupervisorSection(
                  child: child,
                  direction: TripDirection.toSchool,
                  title: 'مشرف رحلة الذهاب',
                  subtitle: 'من المنزل إلى المدرسة',
                  icon: Icons.school,
                  color: Colors.blue,
                ),

                const SizedBox(height: 16),

                // Dropoff Supervisor (From School)
                _buildDirectionSupervisorSection(
                  child: child,
                  direction: TripDirection.fromSchool,
                  title: 'مشرف رحلة العودة',
                  subtitle: 'من المدرسة إلى المنزل',
                  icon: Icons.home,
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDirectionSupervisorSection({
    required StudentModel child,
    required TripDirection direction,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
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
          const SizedBox(height: 12),

          FutureBuilder<SupervisorAssignmentModel?>(
            future: _getSupervisorForChild(child, direction),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('جاري التحميل...'),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'خطأ في التحميل',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                );
              }

              final assignment = snapshot.data;

              if (assignment == null) {
                return Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[600], size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'لم يتم تعيين مشرف لهذه الفترة',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ],
                );
              }

              return _buildCompactSupervisorInfo(assignment, color, assignment.busRoute);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSupervisorInfo(SupervisorAssignmentModel assignment, Color color, String busRoute) {
    return FutureBuilder<UserModel?>(
      future: _databaseService.getUserById(assignment.supervisorId),
      builder: (context, userSnapshot) {
        final supervisor = userSnapshot.data;
        final supervisorName = supervisor?.name ?? assignment.supervisorName;
        final supervisorPhone = supervisor?.phone ?? 'غير متوفر';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.person, 'المشرف', supervisorName),
            _buildInfoRow(Icons.route, 'خط السير', busRoute.isNotEmpty ? busRoute : 'غير محدد'),
            if (supervisorPhone != 'غير متوفر')
              _buildInfoRow(Icons.phone, 'الهاتف', supervisorPhone),

            if (supervisorPhone != 'غير متوفر')
              Align(
                alignment: Alignment.bottomRight,
                child: IconButton(
                  icon: Icon(Icons.call, color: Colors.green[600], size: 24),
                  onPressed: () => _makePhoneCall(supervisorPhone),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSupervisorInfoCard(SupervisorAssignmentModel assignment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.supervisor_account,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'المشرف المسؤول',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          FutureBuilder<UserModel?>(
            future: _databaseService.getUserById(assignment.supervisorId),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final supervisor = userSnapshot.data;
              return Column(
                children: [
                  _buildInfoRow(
                    Icons.person,
                    'الاسم',
                    supervisor?.name ?? assignment.supervisorName,
                  ),
                  _buildInfoRow(
                    Icons.phone,
                    'رقم الهاتف',
                    supervisor?.phone ?? 'غير متوفر',
                  ),
                  _buildInfoRow(
                    Icons.directions_bus,
                    'رقم الباص',
                    assignment.busPlateNumber,
                  ),
                  _buildInfoRow(
                    Icons.route,
                    'خط السير',
                    assignment.busRoute,
                  ),
                  _buildInfoRow(
                    Icons.swap_horiz,
                    'الاتجاه',
                    _getDirectionText(assignment.direction),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoSupervisorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(76)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning,
            color: Colors.orange[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لا يوجد مشرف مُعيَّن',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'لم يتم تعيين مشرف لهذا الخط بعد',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withAlpha(76)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: Colors.red[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2D3748),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDirectionText(TripDirection direction) {
    switch (direction) {
      case TripDirection.toSchool:
        return 'ذهاب للمدرسة';
      case TripDirection.fromSchool:
        return 'عودة من المدرسة';
      case TripDirection.both:
        return 'ذهاب وعودة';
    }
  }

  Future<SupervisorAssignmentModel?> _getSupervisorForChild(StudentModel child, TripDirection direction) async {
    try {
      debugPrint('🔍 Looking for supervisor for child: ${child.name}, route: ${child.busRoute}, busId: ${child.busId}, direction: $direction');

      // First try by busId if available
      if (child.busId.isNotEmpty) {
        final supervisorByBus = await _databaseService.getActiveSupervisorForBus(child.busId, direction: direction);
        if (supervisorByBus != null) {
          debugPrint('✅ Found supervisor by busId: ${supervisorByBus.supervisorName}');
          return supervisorByBus;
        }
      }

      // If not found by busId, try by route
      if (child.busRoute.isNotEmpty) {
        final supervisorByRoute = await _databaseService.getActiveSupervisorForRoute(child.busRoute, direction: direction);
        if (supervisorByRoute != null) {
          debugPrint('✅ Found supervisor by route: ${supervisorByRoute.supervisorName}');
          return supervisorByRoute;
        }
      }

      debugPrint('⚠️ No supervisor found for child: ${child.name}');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting supervisor for child: $e');
      return null;
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن إجراء المكالمة'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إجراء المكالمة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
