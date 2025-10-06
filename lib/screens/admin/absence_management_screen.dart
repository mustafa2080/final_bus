import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/absence_model.dart';
import '../../models/student_model.dart';
import '../../services/database_service.dart';
import '../../widgets/curved_app_bar.dart';

class AbsenceManagementScreen extends StatefulWidget {
  const AbsenceManagementScreen({super.key});

  @override
  State<AbsenceManagementScreen> createState() => _AbsenceManagementScreenState();
}

class _AbsenceManagementScreenState extends State<AbsenceManagementScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.grey[900] : Colors.grey[50];
    final cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: EnhancedCurvedAppBar(
        title: 'إشعارات الغياب',
        subtitle: const Text('متابعة إشعارات الغياب من أولياء الأمور'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;
            return Column(
              children: [
                const SizedBox(height: 16),

                // Header with Statistics - Made more responsive
                _buildHeader(cardColor, textColor, subtitleColor),
                const SizedBox(height: 16),

                // Tab Bar - Enhanced with Material 3 style
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(isDarkMode ? 100 : 25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF1E88E5),
                      unselectedLabelColor: subtitleColor,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF1E88E5).withOpacity(0.1),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 13,
                        height: 1.2,
                      ),
                      isScrollable: isSmallScreen,
                      tabAlignment: isSmallScreen ? TabAlignment.start : TabAlignment.fill,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tabs: [
                        Tab(
                          icon: Icon(Icons.notifications_active, size: 18),
                          child: Text(
                            'إشعارات حديثة',
                            style: TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          height: 65,
                        ),
                        Tab(
                          icon: Icon(Icons.history, size: 18),
                          child: Text(
                            'جميع الإشعارات',
                            style: TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          height: 65,
                        ),
                        Tab(
                          icon: Icon(Icons.analytics, size: 18),
                          child: Text(
                            'الإحصائيات',
                            style: TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          height: 65,
                        ),
                        Tab(
                          icon: Icon(Icons.assessment, size: 18),
                          child: Text(
                            'التقرير الشامل',
                            style: TextStyle(fontSize: 11),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          height: 65,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Scroll hint for all tabs
                Container(
                  margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E88E5).withOpacity(0.1),
                        const Color(0xFF1E88E5).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1E88E5).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFF1E88E5),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'يمكنك التمرير لأسفل لرؤية المزيد من المحتوى',
                        style: TextStyle(
                          color: const Color(0xFF1E88E5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: const Color(0xFF1E88E5),
                        size: 16,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Tab Views - Enhanced with better visibility and scroll indicators
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withAlpha(isDarkMode ? 100 : 25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 8 : 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          RefreshIndicator(
                            onRefresh: () async => setState(() {}),
                            child: _buildRecentAbsences(cardColor, textColor, subtitleColor),
                          ),
                          RefreshIndicator(
                            onRefresh: () async => setState(() {}),
                            child: _buildAllAbsences(cardColor, textColor, subtitleColor),
                          ),
                          RefreshIndicator(
                            onRefresh: () async => setState(() {}),
                            child: _buildAbsenceStatistics(cardColor, textColor, subtitleColor),
                          ),
                          RefreshIndicator(
                            onRefresh: () async => setState(() {}),
                            child: _buildComprehensiveReport(cardColor, textColor, subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Color cardColor, Color textColor, Color subtitleColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE91E63),
            Color(0xFFAD1457),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withAlpha(76),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_off,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إشعارات الغياب',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'متابعة إشعارات الغياب من أولياء الأمور',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Stats - Grid for responsiveness
          StreamBuilder<List<AbsenceModel>>(
            stream: _databaseService.getAllAbsencesStream(),
            builder: (context, snapshot) {
              final allAbsences = snapshot.data ?? [];
              final parentAbsences = allAbsences.where((a) => a.source == AbsenceSource.parent).toList();
              final pendingCount = parentAbsences.where((a) => a.status == AbsenceStatus.pending).length;
              final approvedCount = parentAbsences.where((a) => a.status == AbsenceStatus.approved).length;
              final rejectedCount = parentAbsences.where((a) => a.status == AbsenceStatus.rejected).length;
              final totalCount = parentAbsences.length;

              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4, // زيادة عدد الأعمدة لتوفير مساحة
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2, // تقليل الارتفاع
                children: [
                  _buildStatItem(
                    'اليوم',
                    _getTodayAbsencesCount(parentAbsences).toString(),
                    Icons.today,
                  ),
                  _buildStatItem(
                    'هذا الأسبوع',
                    _getWeekAbsencesCount(parentAbsences).toString(),
                    Icons.date_range,
                  ),
                  _buildStatItem(
                    'هذا الشهر',
                    _getMonthAbsencesCount(parentAbsences).toString(),
                    Icons.calendar_month,
                  ),
                  _buildStatItem(
                    'الإجمالي',
                    totalCount.toString(),
                    Icons.assessment,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8), // تقليل الـ padding
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(12), // تقليل الـ border radius
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18), // تقليل حجم الأيقونة
          const SizedBox(height: 4), // تقليل المسافة
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16, // تقليل حجم الخط
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2), // تقليل المسافة
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10, // تقليل حجم الخط
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAbsences(Color cardColor, Color textColor, Color subtitleColor) {
    return Column(
      children: [
        // Header indicator - Enhanced with scroll hint
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.withOpacity(0.2), Colors.blue.withOpacity(0.1)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الإشعارات الحديثة (آخر 7 أيام)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                    fontSize: 16,
                  ),
                ),
              ),
              // Scroll indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_vertical, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'مرر للأسفل',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content with enhanced scrollbar
        Expanded(
          child: StreamBuilder<List<AbsenceModel>>(
            stream: _databaseService.getAllAbsencesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('خطأ: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
              }

              final allAbsences = snapshot.data ?? [];

              // فلترة الإشعارات الحديثة من أولياء الأمور (آخر 7 أيام)
              final recentDate = DateTime.now().subtract(const Duration(days: 7));
              final recentParentNotifications = allAbsences
                  .where((absence) =>
                      absence.source == AbsenceSource.parent &&
                      absence.createdAt.isAfter(recentDate))
                  .toList();

              // ترتيب حسب التاريخ (الأحدث أولاً)
              recentParentNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (recentParentNotifications.isEmpty) {
                return _buildEmptyState(
                  'لا توجد إشعارات حديثة',
                  'لم يتم إرسال إشعارات غياب في آخر 7 أيام',
                  Icons.notifications_off,
                  Colors.blue,
                );
              }

              return Scrollbar(
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(3),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: recentParentNotifications.length + 1, // +1 for bottom indicator
                  itemBuilder: (context, index) {
                    if (index == recentParentNotifications.length) {
                      // Bottom indicator
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.done_all, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'تم عرض جميع الإشعارات الحديثة (${recentParentNotifications.length})',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final absence = recentParentNotifications[index];
                    return _buildSimpleAbsenceCard(absence, cardColor, textColor, subtitleColor);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllAbsences(Color cardColor, Color textColor, Color subtitleColor) {
    return Column(
      children: [
        // Header indicator - Enhanced with scroll hint
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.green[800], size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'جميع الإشعارات',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                    fontSize: 16,
                  ),
                ),
              ),
              // Scroll indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_vertical, color: Colors.green[700], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'مرر للأسفل',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content with enhanced scrollbar
        Expanded(
          child: StreamBuilder<List<AbsenceModel>>(
            stream: _databaseService.getAllAbsencesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allAbsences = snapshot.data ?? [];
              final parentAbsences = allAbsences
                  .where((absence) => absence.source == AbsenceSource.parent)
                  .toList();

              // ترتيب حسب التاريخ (الأحدث أولاً)
              parentAbsences.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (parentAbsences.isEmpty) {
                return _buildEmptyState(
                  'لا توجد إشعارات غياب',
                  'لم يرسل أولياء الأمور أي إشعارات غياب بعد',
                  Icons.notifications_off,
                  Colors.green,
                );
              }

              return Scrollbar(
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(3),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parentAbsences.length + 1, // +1 for bottom indicator
                  itemBuilder: (context, index) {
                    if (index == parentAbsences.length) {
                      // Bottom indicator
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.done_all, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'تم عرض جميع الإشعارات (${parentAbsences.length})',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final absence = parentAbsences[index];
                    return _buildSimpleAbsenceCard(absence, cardColor, textColor, subtitleColor);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbsenceStatistics(Color cardColor, Color textColor, Color subtitleColor) {
    return Column(
      children: [
        // Header indicator - Enhanced with scroll hint
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.withOpacity(0.2), Colors.purple.withOpacity(0.1)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Icon(Icons.analytics, color: Colors.purple[800], size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الإحصائيات والتقارير',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                    fontSize: 16,
                  ),
                ),
              ),
              // Scroll indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_vertical, color: Colors.purple[700], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'مرر للأسفل',
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content with enhanced scrollbar
        Expanded(
          child: StreamBuilder<List<AbsenceModel>>(
            stream: _databaseService.getAllAbsencesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allAbsences = snapshot.data ?? [];
              final parentAbsences = allAbsences
                  .where((absence) => absence.source == AbsenceSource.parent)
                  .toList();

              if (parentAbsences.isEmpty) {
                return _buildEmptyState(
                  'لا توجد بيانات للإحصائيات',
                  'لا توجد إشعارات غياب لعرض الإحصائيات',
                  Icons.analytics,
                  Colors.purple,
                );
              }

              return Scrollbar(
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(3),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatisticsCard('إحصائيات الغياب', [
                        _buildStatRow('إجمالي الإشعارات', parentAbsences.length.toString(), subtitleColor),
                        _buildStatRow('إشعارات اليوم', _getTodayAbsencesCount(parentAbsences).toString(), subtitleColor),
                        _buildStatRow('إشعارات هذا الأسبوع', _getWeekAbsencesCount(parentAbsences).toString(), subtitleColor),
                        _buildStatRow('إشعارات هذا الشهر', _getMonthAbsencesCount(parentAbsences).toString(), subtitleColor),
                      ], cardColor, textColor),
                      const SizedBox(height: 16),
                      _buildStatisticsCard('أنواع الغياب', [
                        _buildStatRow('مرض', _getAbsenceTypeCount(parentAbsences, AbsenceType.sick).toString(), subtitleColor),
                        _buildStatRow('ظروف عائلية', _getAbsenceTypeCount(parentAbsences, AbsenceType.family).toString(), subtitleColor),
                        _buildStatRow('سفر', _getAbsenceTypeCount(parentAbsences, AbsenceType.travel).toString(), subtitleColor),
                        _buildStatRow('طوارئ', _getAbsenceTypeCount(parentAbsences, AbsenceType.emergency).toString(), subtitleColor),
                        _buildStatRow('أخرى', _getAbsenceTypeCount(parentAbsences, AbsenceType.other).toString(), subtitleColor),
                      ], cardColor, textColor),
                      const SizedBox(height: 16),
                      _buildStatisticsCard('حالة الإشعارات', [
                        _buildStatRow('معلقة', parentAbsences.where((a) => a.status == AbsenceStatus.pending).length.toString(), subtitleColor),
                        _buildStatRow('مقبولة', parentAbsences.where((a) => a.status == AbsenceStatus.approved).length.toString(), subtitleColor),
                        _buildStatRow('مرفوضة', parentAbsences.where((a) => a.status == AbsenceStatus.rejected).length.toString(), subtitleColor),
                      ], cardColor, textColor),
                      // Bottom indicator
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.done_all, color: Colors.purple[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'تم عرض جميع الإحصائيات',
                              style: TextStyle(
                                color: Colors.purple[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 80,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleAbsenceCard(AbsenceModel absence, Color cardColor, Color textColor, Color subtitleColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(absence.status).withAlpha(25),
                child: Icon(
                  Icons.person_off,
                  color: _getStatusColor(absence.status),
                  size: 20,
                ),
              ),
              title: Text(
                absence.studentName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                absence.typeDisplayText,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: SizedBox(
                width: 80,
                child: Chip(
                  label: Text(
                    absence.statusDisplayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: _getStatusColor(absence.status),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: subtitleColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تاريخ الغياب: ${_formatDate(absence.date)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (absence.endDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'إلى تاريخ: ${_formatDate(absence.endDate!)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم الإرسال: ${_formatDateTime(absence.createdAt)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'السبب: ${absence.reason}',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (absence.notes != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'ملاحظات: ${absence.notes}',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Notification Status
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(76)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text(
                    'تم استلام الإشعار',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                  const Spacer(),
                  Expanded(
                    child: Text(
                      'من ${absence.approvedBy ?? 'ولي الأمر'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
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

  // Helper methods for statistics
  int _getTodayAbsencesCount(List<AbsenceModel> absences) {
    final today = DateTime.now();
    return absences.where((absence) {
      return absence.date.year == today.year &&
          absence.date.month == today.month &&
          absence.date.day == today.day;
    }).length;
  }

  int _getWeekAbsencesCount(List<AbsenceModel> absences) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return absences.where((absence) => absence.date.isAfter(weekStart)).length;
  }

  int _getMonthAbsencesCount(List<AbsenceModel> absences) {
    final now = DateTime.now();
    return absences.where((absence) {
      return absence.date.year == now.year && absence.date.month == now.month;
    }).length;
  }

  int _getAbsenceTypeCount(List<AbsenceModel> absences, AbsenceType type) {
    return absences.where((absence) => absence.type == type).length;
  }

  Widget _buildStatisticsCard(String title, List<Widget> children, Color cardColor, Color textColor) {
    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: subtitleColor)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E88E5),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AbsenceStatus status) {
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

  // Helper methods for formatting
  String _formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd').format(date);
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy/MM/dd HH:mm').format(dateTime);
  }

  Widget _buildComprehensiveReport(Color cardColor, Color textColor, Color subtitleColor) {
    return Column(
      children: [
        // Header indicator - Enhanced with scroll hint
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.withOpacity(0.2), Colors.teal.withOpacity(0.1)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Icon(Icons.assessment, color: Colors.teal[800], size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'التقرير الشامل للحضور والغياب',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                    fontSize: 16,
                  ),
                ),
              ),
              // Scroll indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_vertical, color: Colors.teal[700], size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'مرر للأسفل',
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Content with enhanced scrollbar
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _databaseService.getAllStudentsWithAbsenceData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print('❌ Error in comprehensive report: ${snapshot.error}');
                print('📝 Error details: ${snapshot.stackTrace}');
                return _buildEmptyState(
                  'خطأ في تحميل البيانات',
                  'حدث خطأ أثناء تحميل بيانات الطلاب: ${snapshot.error}',
                  Icons.error,
                  Colors.red,
                );
              }

              final studentsData = snapshot.data ?? [];

              if (studentsData.isEmpty) {
                return _buildEmptyState(
                  'لا توجد بيانات',
                  'لا يوجد طلاب مسجلين في النظام',
                  Icons.school,
                  Colors.teal,
                );
              }

              return Scrollbar(
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(3),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Summary Statistics Card
                      _buildReportSummaryCard(studentsData, cardColor),
                      const SizedBox(height: 16),

                      // Students Report List
                      ...studentsData.map((studentData) =>
                        _buildStudentReportCard(studentData, cardColor, textColor, subtitleColor)
                      ).toList(),
                      
                      // Bottom indicator
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.teal.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.done_all, color: Colors.teal[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'تم عرض التقرير الشامل لجميع الطلاب (${studentsData.length})',
                              style: TextStyle(
                                color: Colors.teal[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportSummaryCard(List<Map<String, dynamic>> studentsData, Color cardColor) {
    final totalStudents = studentsData.length;
    final totalAbsences = studentsData.fold<int>(
      0,
      (sum, student) => sum + (student['absences'] as List).length,
    );

    final studentsWithAbsences = studentsData
        .where((student) => (student['absences'] as List).isNotEmpty)
        .length;

    final averageAbsenceRate = totalStudents > 0
        ? (totalAbsences / totalStudents).toStringAsFixed(1)
        : '0.0';

    return Card(
      elevation: 4,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.teal.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: Colors.teal.shade700, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ملخص التقرير الشامل',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'إجمالي الطلاب',
                    totalStudents.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'إجمالي الغيابات',
                    totalAbsences.toString(),
                    Icons.event_busy,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'طلاب لديهم غيابات',
                    studentsWithAbsences.toString(),
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'متوسط الغيابات',
                    averageAbsenceRate,
                    Icons.analytics,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(50),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentReportCard(Map<String, dynamic> studentData, Color cardColor, Color textColor, Color subtitleColor) {
    final student = studentData['student'] as StudentModel;
    final absences = studentData['absences'] as List<AbsenceModel>;

    // Calculate statistics
    final totalAbsences = absences.length;
    final approvedAbsences = absences.where((a) => a.status == AbsenceStatus.approved).length;
    final pendingAbsences = absences.where((a) => a.status == AbsenceStatus.pending).length;
    final rejectedAbsences = absences.where((a) => a.status == AbsenceStatus.rejected).length;

    // Calculate attendance rate (assuming 30 days per month for simplicity)
    final totalSchoolDays = 30; // This could be made dynamic
    final attendanceRate = totalSchoolDays > 0
        ? ((totalSchoolDays - approvedAbsences) / totalSchoolDays * 100).toStringAsFixed(1)
        : '100.0';

    // Determine status color
    Color statusColor = Colors.green;
    String statusText = 'ممتاز';
    if (double.parse(attendanceRate) < 70) {
      statusColor = Colors.red;
      statusText = 'يحتاج متابعة';
    } else if (double.parse(attendanceRate) < 85) {
      statusColor = Colors.orange;
      statusText = 'مقبول';
    } else if (double.parse(attendanceRate) < 95) {
      statusColor = Colors.blue;
      statusText = 'جيد';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(51),
          child: Text(
            student.name.isNotEmpty ? student.name.substring(0, 1) : 'ط',
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student.name.isNotEmpty ? student.name : 'غير محدد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${student.schoolName} - ${student.grade}', 
              style: TextStyle(color: subtitleColor, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.analytics, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'نسبة الحضور: $attendanceRate% ($statusText)',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 70,
          child: Chip(
            label: Text(
              '$totalAbsences غياب',
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: statusColor.withAlpha(25),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statistics Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildStatisticItem(
                        'مقبولة',
                        approvedAbsences.toString(),
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                    Expanded(
                      child: _buildStatisticItem(
                        'معلقة',
                        pendingAbsences.toString(),
                        Colors.orange,
                        Icons.pending,
                      ),
                    ),
                    Expanded(
                      child: _buildStatisticItem(
                        'مرفوضة',
                        rejectedAbsences.toString(),
                        Colors.red,
                        Icons.cancel,
                      ),
                    ),
                  ],
                ),

                if (absences.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Recent Absences
                  Row(
                    children: [
                      Icon(Icons.history, size: 16, color: subtitleColor),
                      const SizedBox(width: 8),
                      Text(
                        'آخر الغيابات:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...absences.take(3).map((absence) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getAbsenceStatusColor(absence.status).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getAbsenceStatusColor(absence.status).withAlpha(76),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getAbsenceTypeIcon(absence.type),
                          size: 16,
                          color: _getAbsenceStatusColor(absence.status),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getAbsenceTypeText(absence.type),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat('yyyy/MM/dd').format(absence.date),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            _getAbsenceStatusText(absence.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _getAbsenceStatusColor(absence.status),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ],
                    ),
                  )).toList(),

                  if (absences.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'و ${absences.length - 3} غيابات أخرى...',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
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

  IconData _getAbsenceTypeIcon(AbsenceType type) {
    switch (type) {
      case AbsenceType.sick:
        return Icons.local_hospital;
      case AbsenceType.family:
        return Icons.family_restroom;
      case AbsenceType.travel:
        return Icons.flight;
      case AbsenceType.emergency:
        return Icons.emergency;
      case AbsenceType.other:
        return Icons.help;
    }
  }

  String _getAbsenceTypeText(AbsenceType type) {
    switch (type) {
      case AbsenceType.sick:
        return 'مرض';
      case AbsenceType.family:
        return 'ظروف عائلية';
      case AbsenceType.travel:
        return 'سفر';
      case AbsenceType.emergency:
        return 'طوارئ';
      case AbsenceType.other:
        return 'أخرى';
    }
  }

  String _getAbsenceStatusText(AbsenceStatus status) {
    switch (status) {
      case AbsenceStatus.pending:
        return 'معلق';
      case AbsenceStatus.approved:
        return 'مقبول';
      case AbsenceStatus.rejected:
        return 'مرفوض';
      case AbsenceStatus.reported:
        return 'مبلغ عنه';
    }
  }
}