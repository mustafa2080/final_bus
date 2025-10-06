import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/student_model.dart';
import '../../models/trip_model.dart';
import '../../models/user_model.dart';
import '../../widgets/admin_bottom_navigation.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/responsive_grid_view.dart';
import '../../utils/responsive_helper.dart';



class StatCard {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final Future<int> future;

  StatCard({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.future,
  });
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  DateTime _selectedDate = DateTime.now();
  String _selectedPeriod = 'اليوم';

  final List<String> _periods = ['اليوم', 'الأسبوع', 'الشهر', 'السنة'];

  late AnimationController _cardAnimationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Modern light background
      appBar: const AdminAppBar(
        title: 'التقارير والإحصائيات',
      ),
      body: Column(
        children: [
          _buildEnhancedDateSelector(screenWidth, screenHeight, textScaleFactor),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1E88E5),
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: const Color(0xFF1E88E5),
            labelStyle: GoogleFonts.cairo(
              fontSize: 14 * textScaleFactor,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: GoogleFonts.cairo(
              fontSize: 13 * textScaleFactor,
              fontWeight: FontWeight.w500,
            ),
            dividerColor: Colors.transparent,
            tabs: [
              _buildTabItem(Icons.analytics_rounded, 'الإحصائيات'),
              _buildTabItem(Icons.groups_rounded, 'الطلاب'),
              _buildTabItem(Icons.directions_bus_rounded, 'الرحلات'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralStats(screenWidth, screenHeight, textScaleFactor),
                _buildStudentsReport(screenWidth, screenHeight, textScaleFactor),
                _buildTripsReport(screenWidth, screenHeight, textScaleFactor),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AdminBottomNavigation(
        currentIndex: 3,
      ),
    );
  }

  Widget _buildTabItem(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildEnhancedDateSelector(double screenWidth, double screenHeight, double textScaleFactor) {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_cardAnimationController.value * 0.2),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.01),
            padding: EdgeInsets.all(screenWidth * 0.05),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(screenWidth * 0.03),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.date_range_rounded,
                        color: Colors.white,
                        size: 20 * textScaleFactor,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      child: Text(
                        'فترة التقرير',
                        style: GoogleFonts.cairo(
                          fontSize: 18 * textScaleFactor,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    _buildExportButton(screenWidth, textScaleFactor),
                  ],
                ),
                SizedBox(height: screenHeight * 0.025),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildModernDropdown(textScaleFactor),
                    ),
                    SizedBox(width: screenWidth * 0.04),
                    Expanded(
                      flex: 2,
                      child: _buildDateButton(textScaleFactor),
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

  Widget _buildModernDropdown(double textScaleFactor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedPeriod,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          hintText: 'اختر الفترة',
        ),
        style: GoogleFonts.cairo(
          fontSize: 14 * textScaleFactor,
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: Colors.white,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF64748B),
        ),
        items: _periods.map((period) {
          return DropdownMenuItem<String>(
            value: period,
            child: Text(period),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedPeriod = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildDateButton(double textScaleFactor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd/MM/yyyy').format(_selectedDate),
                style: GoogleFonts.cairo(
                  fontSize: 13 * textScaleFactor,
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(double screenWidth, double textScaleFactor) {
    return GestureDetector(
      onTap: _exportTripsReport,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.all(screenWidth * 0.03),
        child: Icon(
          Icons.download_rounded,
          color: Colors.white,
          size: 20 * textScaleFactor,
        ),
      ),
    );
  }

  Widget _buildGeneralStats(double screenWidth, double screenHeight, double textScaleFactor) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Column(
        children: [
          ResponsiveGridView(
            mobileColumns: 2,
            tabletColumns: 4,
            desktopColumns: 4,
            mobileAspectRatio: 0.9,
            tabletAspectRatio: 1.0,
            desktopAspectRatio: 1.1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StatCard(
                title: 'إجمالي الطلاب',
                icon: Icons.groups_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                future: _getTotalStudents(),
              ),
              StatCard(
                title: 'المشرفين',
                icon: Icons.supervisor_account_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                future: _getTotalSupervisors(),
              ),
              StatCard(
                title: 'رحلات اليوم',
                icon: Icons.directions_bus_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                future: _getTodayTrips(),
              ),
              StatCard(
                title: 'الطلاب النشطين',
                icon: Icons.trending_up_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                future: _getActiveStudents(),
              ),
            ].asMap().entries.map((entry) {
              final index = entry.key;
              final stat = entry.value;
              return AnimatedBuilder(
                animation: _cardAnimationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      0,
                      50 * (1 - _cardAnimationController.value) * (index + 1) * 0.1,
                    ),
                    child: Opacity(
                      opacity: _cardAnimationController.value,
                      child: _buildAnimatedStatCard(stat, screenWidth, screenHeight, textScaleFactor),
                    ),
                  );
                },
              );
            }).toList(),
          ),
          SizedBox(height: screenHeight * 0.02),
          _buildStatusDistribution(screenWidth, screenHeight, textScaleFactor),
          SizedBox(height: screenHeight * 0.02),
          _buildTrendChart(screenWidth, screenHeight, textScaleFactor),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatCard(StatCard stat, double screenWidth, double screenHeight, double textScaleFactor) {
    return Container(
      decoration: BoxDecoration(
        gradient: stat.gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: stat.gradient.colors.first.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStatDetails(stat),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    stat.icon,
                    color: Colors.white,
                    size: ResponsiveHelper.getIconSize(context,
                      mobileSize: 24,
                      tabletSize: 28,
                      desktopSize: 32,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                FutureBuilder<int>(
                  future: stat.future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 20 * textScaleFactor,
                        width: 20 * textScaleFactor,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }
                    
                    final value = snapshot.data ?? 0;
                    return TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: value),
                      duration: const Duration(milliseconds: 1500),
                      builder: (context, animatedValue, child) {
                        return Text(
                          '$animatedValue',
                          style: GoogleFonts.cairo(
                            fontSize: ResponsiveHelper.getFontSize(context,
                              mobile: 24,
                              tablet: 28,
                              desktop: 32,
                            ) * textScaleFactor,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  stat.title,
                  style: GoogleFonts.cairo(
                    fontSize: ResponsiveHelper.getFontSize(context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    ) * textScaleFactor,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatDetails(StatCard stat) {
    // Implement detail view if needed
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stat.title),
        content: const Text('Details here...'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildStatusDistribution(double screenWidth, double screenHeight, double textScaleFactor) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع حالات الطلاب',
            style: GoogleFonts.cairo(
              fontSize: 18 * textScaleFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          FutureBuilder<Map<String, int>>(
            future: _getStudentStatusDistribution(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data ?? {};
              return Column(
                children: [
                  _buildCompactStatusRow('في المنزل', data['home'] ?? 0, Colors.green, textScaleFactor),
                  _buildCompactStatusRow('في الباص', data['onBus'] ?? 0, Colors.blue, textScaleFactor),
                  _buildCompactStatusRow('في المدرسة', data['atSchool'] ?? 0, Colors.orange, textScaleFactor),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatusRow(String status, int count, Color color, double textScaleFactor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              style: GoogleFonts.cairo(
                fontSize: 13 * textScaleFactor,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.cairo(
              fontSize: 13 * textScaleFactor,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(double screenWidth, double screenHeight, double textScaleFactor) {
    // Placeholder for trend chart. In real app, use charts_flutter or similar.
    return Container(
      height: screenHeight * 0.3,
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اتجاه النشاط',
            style: GoogleFonts.cairo(
              fontSize: 18 * textScaleFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('Chart Placeholder'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsReport(double screenWidth, double screenHeight, double textScaleFactor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('students')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'لا يوجد طلاب',
              style: GoogleFonts.cairo(
                fontSize: 18 * textScaleFactor,
                color: Colors.grey[600],
              ),
            ),
          );
        }
        
        final students = snapshot.data!.docs
            .map((doc) => StudentModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
        
        return ListView.builder(
          padding: EdgeInsets.all(screenWidth * 0.04),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return Container(
              margin: EdgeInsets.only(bottom: screenHeight * 0.01),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.03),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20 * textScaleFactor,
                      backgroundColor: _getStatusColor(student.currentStatus),
                      child: Text(
                        student.name.isNotEmpty ? student.name[0] : 'ط',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14 * textScaleFactor,
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 14 * textScaleFactor,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Text(
                            '${student.schoolName} • ${student.grade}',
                            style: GoogleFonts.cairo(
                              fontSize: 12 * textScaleFactor,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'خط ${student.busRoute} • ${student.parentName}',
                            style: GoogleFonts.cairo(
                              fontSize: 11 * textScaleFactor,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenHeight * 0.005),
                      decoration: BoxDecoration(
                        color: _getStatusColor(student.currentStatus).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getStatusColor(student.currentStatus).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusText(student.currentStatus),
                        style: GoogleFonts.cairo(
                          color: _getStatusColor(student.currentStatus),
                          fontWeight: FontWeight.bold,
                          fontSize: 10 * textScaleFactor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTripsReport(double screenWidth, double screenHeight, double textScaleFactor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('trips')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_getStartDate()))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_getEndDate()))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyTripsState(screenWidth, screenHeight, textScaleFactor);
        }

        final trips = snapshot.data!.docs
            .map((doc) {
              try {
                return TripModel.fromMap(doc.data() as Map<String, dynamic>);
              } catch (e) {
                debugPrint('Error parsing trip: $e');
                return null;
              }
            })
            .where((trip) => trip != null)
            .cast<TripModel>()
            .toList();
        
        return Column(
          children: [
            _buildTripsStatistics(trips, screenWidth, screenHeight, textScaleFactor),
            SizedBox(height: screenHeight * 0.02),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _buildTripCard(trip, screenWidth, screenHeight, textScaleFactor);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyTripsState(double screenWidth, double screenHeight, double textScaleFactor) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_outlined,
              size: 80 * textScaleFactor,
              color: Colors.grey[400],
            ),
            SizedBox(height: screenHeight * 0.025),
            Text(
              'لا توجد رحلات في هذه الفترة',
              style: GoogleFonts.cairo(
                fontSize: 20 * textScaleFactor,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: screenHeight * 0.01),
            Text(
              'جرب تغيير الفترة الزمنية أو التاريخ المحدد',
              style: GoogleFonts.cairo(
                fontSize: 16 * textScaleFactor,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsStatistics(List<TripModel> trips, double screenWidth, double screenHeight, double textScaleFactor) {
    final totalTrips = trips.length;
    final uniqueStudents = trips.map((trip) => trip.studentId).toSet().length;
    final uniqueSupervisors = trips.map((trip) => trip.supervisorId).toSet().length;
    final uniqueRoutes = trips.map((trip) => trip.busRoute).toSet().length;

    final tripsByAction = <TripAction, int>{};
    for (final trip in trips) {
      tripsByAction[trip.action] = (tripsByAction[trip.action] ?? 0) + 1;
    }

    final tripsByHour = <int, int>{};
    for (final trip in trips) {
      final hour = trip.timestamp.hour;
      tripsByHour[hour] = (tripsByHour[hour] ?? 0) + 1;
    }

    int busiestHour = 0;
    int maxTripsInHour = 0;
    tripsByHour.forEach((hour, tripCount) {
      if (tripCount > maxTripsInHour) {
        maxTripsInHour = tripCount;
        busiestHour = hour;
      }
    });

    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      padding: EdgeInsets.all(screenWidth * 0.05),
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.blue,
                  size: 20 * textScaleFactor,
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              Text(
                'إحصائيات الرحلات',
                style: GoogleFonts.cairo(
                  fontSize: 18 * textScaleFactor,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.025),
          Row(
            children: [
              Expanded(
                child: _buildStatisticItem(
                  'إجمالي الرحلات',
                  totalTrips.toString(),
                  Icons.directions_bus,
                  Colors.blue,
                  textScaleFactor,
                ),
              ),
              Expanded(
                child: _buildStatisticItem(
                  'الطلاب',
                  uniqueStudents.toString(),
                  Icons.people,
                  Colors.green,
                  textScaleFactor,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Row(
            children: [
              Expanded(
                child: _buildStatisticItem(
                  'المشرفين',
                  uniqueSupervisors.toString(),
                  Icons.supervisor_account,
                  Colors.orange,
                  textScaleFactor,
                ),
              ),
              Expanded(
                child: _buildStatisticItem(
                  'الخطوط',
                  uniqueRoutes.toString(),
                  Icons.route,
                  Colors.purple,
                  textScaleFactor,
                ),
              ),
            ],
          ),
          if (maxTripsInHour > 0) ...[
            SizedBox(height: screenHeight * 0.02),
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.amber, size: 16 * textScaleFactor),
                  SizedBox(width: screenWidth * 0.02),
                  Text(
                    'أكثر الأوقات ازدحاماً: ${busiestHour.toString().padLeft(2, '0')}:00 ($maxTripsInHour رحلة)',
                    style: GoogleFonts.cairo(
                      fontSize: 12 * textScaleFactor,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatisticItem(String title, String value, IconData icon, Color color, double textScaleFactor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20 * textScaleFactor),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 16 * textScaleFactor,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 10 * textScaleFactor,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(TripModel trip, double screenWidth, double screenHeight, double textScaleFactor) {
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: _getTripActionColor(trip.action).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTripActionIcon(trip.action),
                color: _getTripActionColor(trip.action),
                size: 24 * textScaleFactor,
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.studentName,
                    style: GoogleFonts.cairo(
                      fontSize: 16 * textScaleFactor,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    'المشرف: ${trip.supervisorName}',
                    style: GoogleFonts.cairo(
                      fontSize: 12 * textScaleFactor,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'الخط: ${trip.busRoute}',
                    style: GoogleFonts.cairo(
                      fontSize: 12 * textScaleFactor,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                    SizedBox(height: screenHeight * 0.005),
                    Text(
                      'ملاحظات: ${trip.notes}',
                      style: GoogleFonts.cairo(
                        fontSize: 12 * textScaleFactor,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('HH:mm').format(trip.timestamp),
                  style: GoogleFonts.cairo(
                    fontSize: 14 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: screenHeight * 0.005),
                Text(
                  DateFormat('dd/MM').format(trip.timestamp),
                  style: GoogleFonts.cairo(
                    fontSize: 12 * textScaleFactor,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02, vertical: screenHeight * 0.005),
                  decoration: BoxDecoration(
                    color: _getTripActionColor(trip.action),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getTripActionText(trip.action),
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10 * textScaleFactor,
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

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  DateTime _getStartDate() {
    switch (_selectedPeriod) {
      case 'اليوم':
        return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      case 'الأسبوع':
        return _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      case 'الشهر':
        return DateTime(_selectedDate.year, _selectedDate.month, 1);
      case 'السنة':
        return DateTime(_selectedDate.year, 1, 1);
      default:
        return _selectedDate;
    }
  }

  DateTime _getEndDate() {
    switch (_selectedPeriod) {
      case 'اليوم':
        return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      case 'الأسبوع':
        return _selectedDate.add(Duration(days: 7 - _selectedDate.weekday));
      case 'الشهر':
        return DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);
      case 'السنة':
        return DateTime(_selectedDate.year, 12, 31, 23, 59, 59);
      default:
        return DateTime.now();
    }
  }

  Future<int> _getTotalStudents() async {
    final snapshot = await _firestore
        .collection('students')
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  Future<int> _getTotalSupervisors() async {
    final snapshot = await _firestore
        .collection('users')
        .where('userType', isEqualTo: 'supervisor')
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  Future<int> _getTodayTrips() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('trips')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();
    return snapshot.docs.length;
  }

  Future<int> _getActiveStudents() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('student_activities')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    final uniqueStudents = <String>{};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['studentId'] != null) {
        uniqueStudents.add(data['studentId']);
      }
    }

    return uniqueStudents.length;
  }

  Future<Map<String, int>> _getStudentStatusDistribution() async {
    final snapshot = await _firestore
        .collection('students')
        .where('isActive', isEqualTo: true)
        .get();

    final distribution = <String, int>{
      'home': 0,
      'onBus': 0,
      'atSchool': 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['currentStatus'] as String?;
      if (status != null && distribution.containsKey(status)) {
        distribution[status] = distribution[status]! + 1;
      }
    }

    return distribution;
  }

  Color _getStatusColor(StudentStatus status) {
    switch (status) {
      case StudentStatus.home:
        return Colors.green;
      case StudentStatus.onBus:
        return Colors.blue;
      case StudentStatus.atSchool:
        return Colors.orange;
    }
  }

  String _getStatusText(StudentStatus status) {
    switch (status) {
      case StudentStatus.home:
        return 'في المنزل';
      case StudentStatus.onBus:
        return 'في الباص';
      case StudentStatus.atSchool:
        return 'في المدرسة';
    }
  }

  Color _getTripActionColor(TripAction action) {
    switch (action) {
      case TripAction.boardBusToSchool:
        return Colors.green;
      case TripAction.arriveAtSchool:
        return Colors.orange;
      case TripAction.boardBusToHome:
        return Colors.blue;
      case TripAction.arriveAtHome:
        return Colors.purple;
      case TripAction.boardBus:
        return Colors.green;
      case TripAction.leaveBus:
        return Colors.blue;
    }
  }

  IconData _getTripActionIcon(TripAction action) {
    switch (action) {
      case TripAction.boardBusToSchool:
        return Icons.directions_bus;
      case TripAction.arriveAtSchool:
        return Icons.school;
      case TripAction.boardBusToHome:
        return Icons.home_work;
      case TripAction.arriveAtHome:
        return Icons.home;
      case TripAction.boardBus:
        return Icons.arrow_upward;
      case TripAction.leaveBus:
        return Icons.arrow_downward;
    }
  }

  String _getTripActionText(TripAction action) {
    switch (action) {
      case TripAction.boardBusToSchool:
        return 'ركب الباص للمدرسة';
      case TripAction.arriveAtSchool:
        return 'وصل للمدرسة';
      case TripAction.boardBusToHome:
        return 'ركب الباص للمنزل';
      case TripAction.arriveAtHome:
        return 'وصل للمنزل';
      case TripAction.boardBus:
        return 'صعود';
      case TripAction.leaveBus:
        return 'نزول';
    }
  }

  Future<void> _exportTripsReport() async {
    try {
      final snapshot = await _firestore
          .collection('trips')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_getStartDate()))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_getEndDate()))
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا توجد رحلات لتصديرها في هذه الفترة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final trips = snapshot.docs
          .map((doc) {
            try {
              return TripModel.fromMap(doc.data());
            } catch (e) {
              return null;
            }
          })
          .where((trip) => trip != null)
          .cast<TripModel>()
          .toList();

      final csvContent = StringBuffer();
      csvContent.writeln('اسم الطالب,المشرف,الخط,نوع الرحلة,الإجراء,التاريخ,الوقت,ملاحظات');

      for (final trip in trips) {
        csvContent.writeln([
          trip.studentName,
          trip.supervisorName,
          trip.busRoute,
          trip.tripType.toString().split('.').last,
          _getTripActionText(trip.action),
          DateFormat('yyyy/MM/dd').format(trip.timestamp),
          DateFormat('HH:mm').format(trip.timestamp),
          trip.notes ?? '',
        ].join(','));
      }

      final cleanContent = _cleanCsvContent(csvContent.toString());
      await _saveReportToFile(cleanContent, 'trips_report_${DateFormat('yyyy_MM_dd').format(DateTime.now())}.csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير ${trips.length} رحلة وحفظها بنجاح'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'عرض',
              onPressed: () {
                _showExportPreview(csvContent.toString());
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تصدير التقرير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportPreview(String csvContent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download, color: Colors.green),
            SizedBox(width: 8),
            Text('معاينة التقرير المُصدر'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              csvContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _saveReportToFile(csvContent, 'report_${DateFormat('yyyy_MM_dd_HH_mm').format(DateTime.now())}.csv');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حفظ التقرير بنجاح في مجلد التحميلات'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReportToFile(String content, String fileName) async {
    try {
      if (content.isEmpty) {
        throw Exception('المحتوى فارغ');
      }

      Directory directory;
      String finalPath;

      if (Platform.isAndroid) {
        try {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getApplicationDocumentsDirectory();
            final reportsDir = Directory('${directory.path}/KidsBus_Reports');
            if (!await reportsDir.exists()) {
              await reportsDir.create(recursive: true);
            }
            directory = reportsDir;
          }
        } catch (e) {
          directory = await getApplicationDocumentsDirectory();
          final reportsDir = Directory('${directory.path}/KidsBus_Reports');
          if (!await reportsDir.exists()) {
            await reportsDir.create(recursive: true);
          }
          directory = reportsDir;
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
        final reportsDir = Directory('${directory.path}/KidsBus_Reports');
        if (!await reportsDir.exists()) {
          await reportsDir.create(recursive: true);
        }
        directory = reportsDir;
      }

      final timestamp = DateFormat('yyyy_MM_dd_HH_mm_ss').format(DateTime.now());
      final uniqueFileName = fileName.replaceAll('.csv', '_$timestamp.csv');
      finalPath = '${directory.path}/$uniqueFileName';

      final file = File(finalPath);

      List<int> bytes;
      try {
        bytes = utf8.encode(content);
      } catch (e) {
        bytes = latin1.encode(content);
      }

      await file.writeAsBytes(bytes, flush: true);

      if (await file.exists()) {
        final fileSize = await file.length();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✅ تم حفظ التقرير بنجاح'),
                  Text('📁 $finalPath',
                    style: const TextStyle(fontSize: 10),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('📊 حجم الملف: ${(fileSize / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'موافق',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      } else {
        throw Exception('فشل في إنشاء الملف');
      }
    } catch (e) {
      debugPrint('خطأ في حفظ الملف: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('❌ خطأ في حفظ الملف'),
                Text('التفاصيل: $e', style: const TextStyle(fontSize: 10)),
                const Text('💡 تأكد من وجود مساحة كافية على الجهاز',
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'إغلاق',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  String _cleanCsvContent(String content) {
    String cleaned = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (!cleaned.startsWith('\uFEFF')) {
      cleaned = '\uFEFF$cleaned';
    }

    return cleaned;
  }
}