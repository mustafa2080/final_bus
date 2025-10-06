import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/persistent_auth_service.dart';
import '../../models/student_model.dart';
import '../../models/absence_model.dart';
import '../../widgets/curved_app_bar.dart';
import '../../widgets/modern_bottom_navigation.dart';
import '../../widgets/student_avatar.dart';
import '../../widgets/custom_button.dart';
import '../../models/user_model.dart';
import 'report_absence_screen.dart';

class ParentLocationScreen extends StatefulWidget {
  const ParentLocationScreen({super.key});

  @override
  State<ParentLocationScreen> createState() => _ParentLocationScreenState();
}

class _ParentLocationScreenState extends State<ParentLocationScreen> {
  late PersistentAuthService _authService;
  final DatabaseService _databaseService = DatabaseService();
  List<StudentModel> _students = [];
  List<AbsenceModel> _absences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<PersistentAuthService>(context, listen: false);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        // Load students data
        final studentsStream = _databaseService.getStudentsByParent(currentUser.uid);
        studentsStream.listen((students) {
          setState(() {
            _students = students;
          });
        });

        // Load absences data
        final absencesStream = _databaseService.getAbsencesByParent(currentUser.uid);
        absencesStream.listen((absences) {
          setState(() {
            _absences = absences;
            _isLoading = false;
          });
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
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

  IconData _getStatusIcon(AbsenceStatus status) {
    switch (status) {
      case AbsenceStatus.pending:
        return Icons.schedule;
      case AbsenceStatus.approved:
        return Icons.check_circle;
      case AbsenceStatus.rejected:
        return Icons.cancel;
      case AbsenceStatus.reported:
        return Icons.report;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _reportAbsence() {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب مسجلين'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_students.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReportAbsenceScreen(student: _students.first),
        ),
      ).then((_) => _loadData());
    } else {
      _showStudentSelectionDialog();
    }
  }

  void _showStudentSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('اختر الطالب'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _students.map((student) {
            return ListTile(
              leading: StudentAvatar(
                photoUrl: student.photoUrl,
                studentName: student.name,
                radius: 20,
                backgroundColor: Colors.blue.withAlpha(25),
                textColor: Colors.blue,
              ),
              title: Text(student.name),
              subtitle: Text('الصف: ${student.grade} - الخط: ${student.busRoute}'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportAbsenceScreen(student: student),
                  ),
                ).then((_) => _loadData());
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          EnhancedCurvedAppBar(
            title: 'إدارة الغياب',
            subtitle: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off, size: 16, color: Colors.white70),
                SizedBox(width: 8),
                Text('إبلاغ وتتبع غياب أطفالك'),
              ],
            ),
            backgroundColor: const Color(0xFFFF9800),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _reportAbsence,
                tooltip: 'إبلاغ غياب جديد',
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF9800),
                    ),
                  )
                : _buildAbsenceContent(),
          ),
        ],
      ),
      bottomNavigationBar: ModernBottomNavigation(
        currentIndex: 2, // Absence tab index
        userType: UserType.parent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _reportAbsence,
        backgroundColor: const Color(0xFFFF9800),
        icon: const Icon(Icons.person_add_disabled, color: Colors.white),
        label: const Text('إبلاغ غياب', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAbsenceContent() {
    if (_absences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد طلبات غياب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'جميع أطفالك يحضرون بانتظام',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            CustomButton(
              text: 'إبلاغ غياب جديد',
              onPressed: _reportAbsence,
              backgroundColor: const Color(0xFFFF9800),
              icon: Icons.person_add_disabled,
              width: 200,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _absences.length,
        itemBuilder: (context, index) {
          final absence = _absences[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getStatusColor(absence.status).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getStatusColor(absence.status).withOpacity(0.2),
                          radius: 25,
                          child: Icon(
                            _getStatusIcon(absence.status),
                            color: _getStatusColor(absence.status),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                absence.studentName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(absence.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  absence.statusDisplayText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.event,
                      'التاريخ',
                      _formatDate(absence.date),
                      Colors.blue,
                    ),
                    if (absence.isMultipleDays)
                      _buildInfoRow(
                        Icons.event_available,
                        'إلى',
                        _formatDate(absence.endDate!),
                        Colors.blue,
                      ),
                    _buildInfoRow(
                      Icons.info,
                      'النوع',
                      absence.typeDisplayText,
                      Colors.green,
                    ),
                    _buildInfoRow(
                      Icons.description,
                      'السبب',
                      absence.reason,
                      Colors.orange,
                    ),
                    if (absence.notes != null && absence.notes!.isNotEmpty)
                      _buildInfoRow(
                        Icons.note,
                        'ملاحظات',
                        absence.notes!,
                        Colors.purple,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تم الإرسال: ${_formatDate(absence.requestDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
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
}
