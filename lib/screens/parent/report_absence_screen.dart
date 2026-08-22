import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/absence_model.dart';
import '../../models/student_model.dart';
import '../../services/database_service.dart';
import '../../widgets/curved_app_bar.dart';
import '../../utils/responsive_helper.dart';

class ReportAbsenceScreen extends StatefulWidget {
  final StudentModel student;

  const ReportAbsenceScreen({
    super.key,
    required this.student,
  });

  @override
  State<ReportAbsenceScreen> createState() => _ReportAbsenceScreenState();
}

class _ReportAbsenceScreenState extends State<ReportAbsenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _databaseService = DatabaseService();

  AbsenceType _selectedType = AbsenceType.sick;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isMultipleDays = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const EnhancedCurvedAppBar(
        title: 'إبلاغ غياب',
        subtitle: Text('إشعار المدرسة بغياب الطالب'),
        backgroundColor: Color(0xFF1E88E5),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: ResponsiveHelper.getPadding(context,
            mobilePadding: const EdgeInsets.all(12),
            tabletPadding: const EdgeInsets.all(20),
            desktopPadding: const EdgeInsets.all(28)),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
            // Student Info Card
            _buildStudentInfoCard(),
            const SizedBox(height: 20),

            // Absence Type Selection
            _buildAbsenceTypeCard(),
            const SizedBox(height: 20),

            // Date Selection
            _buildDateSelectionCard(),
            const SizedBox(height: 20),

            // Reason Input
            _buildReasonCard(),
            const SizedBox(height: 20),

            // Notes Input
            _buildNotesCard(),
            const SizedBox(height: 30),

            // Submit Button
            _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الصف: ${widget.student.grade} - الخط: ${widget.student.busRoute}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenceTypeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
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
              Icon(Icons.category, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'نوع الغياب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AbsenceType.values.map((type) {
              final isSelected = _selectedType == type;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedType = type;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getAbsenceTypeIcon(type),
                        size: 16,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getAbsenceTypeText(type),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
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
              Icon(Icons.calendar_today, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'تاريخ الغياب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Multiple days toggle
          Row(
            children: [
              Checkbox(
                value: _isMultipleDays,
                onChanged: (value) {
                  setState(() {
                    _isMultipleDays = value ?? false;
                    if (!_isMultipleDays) {
                      _endDate = null;
                    }
                  });
                },
              ),
              const Text('غياب لعدة أيام'),
            ],
          ),
          const SizedBox(height: 12),
          
          // Start date
          InkWell(
            onTap: _selectStartDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _isMultipleDays ? 'من تاريخ: ' : 'تاريخ الغياب: ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(DateFormat('yyyy/MM/dd').format(_startDate)),
                ],
              ),
            ),
          ),
          
          // End date (if multiple days)
          if (_isMultipleDays) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectEndDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'إلى تاريخ: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(_endDate != null 
                        ? DateFormat('yyyy/MM/dd').format(_endDate!) 
                        : 'اختر التاريخ'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReasonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
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
              Icon(Icons.description, color: Colors.purple, size: 20),
              SizedBox(width: 8),
              Text(
                'سبب الغياب',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اكتب سبب الغياب بالتفصيل...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى كتابة سبب الغياب';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
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
              Icon(Icons.note_add, color: Colors.teal, size: 20),
              SizedBox(width: 8),
              Text(
                'ملاحظات إضافية (اختياري)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'أي ملاحظات إضافية...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitAbsenceReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'إبلاغ عن الغياب',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Helper methods
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
        return Icons.more_horiz;
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

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        // Reset end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 1)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _submitAbsenceReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isMultipleDays && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تاريخ النهاية'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final absenceId = DateTime.now().millisecondsSinceEpoch.toString();
      final absence = AbsenceModel(
        id: absenceId,
        studentId: widget.student.id,
        studentName: widget.student.name,
        parentId: widget.student.parentId,
        type: _selectedType,
        status: AbsenceStatus.approved, // إشعار مقبول تلقائياً
        source: AbsenceSource.parent,
        date: _startDate,
        endDate: _endDate,
        reason: _reasonController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        approvedBy: 'ولي الأمر', // تم الإبلاغ من قبل ولي الأمر
        approvedAt: DateTime.now(), // وقت الإبلاغ
      );

      debugPrint('ًں”„ Parent creating absence request:');
      debugPrint('   ID: $absenceId');
      debugPrint('   Student: ${widget.student.name} (${widget.student.id})');
      debugPrint('   Parent: ${widget.student.parentId}');
      debugPrint('   Status: ${absence.status.toString().split('.').last}');
      debugPrint('   Date: ${absence.date}');
      debugPrint('   Reason: ${absence.reason}');

      await _databaseService.createAbsence(absence);

      debugPrint('âœ… Absence notification created successfully!');

      // ملحوظة: مبنبعتش إشعار مباشر من هنا عن قصد. الباك اند (backend/index.js)
      // بيراقب collection('absences') عن طريق onSnapshot وبيبعت إشعار واحد
      // لكل المشرفين والإدارة أول ما يشوف الغياب الجديد. كنا قبل كده بنبعت
      // من هنا كمان (مرتين: _sendEnhancedNotificationsToStaff و
      // _sendAbsenceNotificationToAdmin) فكان المستلم بياخد 3 إشعارات مختلفة
      // الصياغة عن نفس الحدث، ودالة الـ deduplication الموجودة مكنتش تمسك
      // التكرار ده لأنها مصممة تمنع تكرار نفس الرسالة بالظبط مش 3 رسايل
      // مختلفة عن نفس الحدث. لو حبينا إشعار فوري تاني قدام العميل، لازم
      // يتبعت عن طريق fcm_queue برضه (زي SimpleFCMService) مش استدعاء مباشر.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إبلاغ المدرسة عن الغياب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ملحوظة: الدوال اللي كانت هنا (_sendEnhancedNotificationsToStaff،
  // _sendNotificationsToStaffWithSound، _sendNotificationsToStaff،
  // _sendAbsenceNotificationToAdmin) اتشالوا. كانوا بيبعتوا إشعار مباشر
  // للمشرفين/الإدارة بعد إنشاء الغياب، وده كان بيسبب تكرار الإشعار مع
  // إشعار الباك اند (backend/index.js يراقب collection('absences') عن
  // طريق onSnapshot ويبعت إشعار واحد بس). شوف الملحوظة فوق
  // _submitAbsenceReport لتفاصيل أكتر.
}


