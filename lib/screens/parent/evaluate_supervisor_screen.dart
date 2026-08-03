import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/user_model.dart';
import '../../models/supervisor_evaluation_model.dart';

class EvaluateSupervisorScreen extends StatefulWidget {
  final UserModel supervisor;
  final VoidCallback? onEvaluationComplete;

  const EvaluateSupervisorScreen({
    super.key,
    required this.supervisor,
    this.onEvaluationComplete,
  });

  @override
  State<EvaluateSupervisorScreen> createState() => _EvaluateSupervisorScreenState();
}

class _EvaluateSupervisorScreenState extends State<EvaluateSupervisorScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _suggestionsController = TextEditingController();
  
  final Map<EvaluationCategory, EvaluationRating> _ratings = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize all ratings to good by default
    for (final category in EvaluationCategory.values) {
      _ratings[category] = EvaluationRating.good;
    }
  }

  @override
  void dispose() {
    _commentsController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'تقييم ${widget.supervisor.name}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supervisor info card
                _buildSupervisorInfoCard(),

                const SizedBox(height: 20),

                // Evaluation categories
                _buildEvaluationSection(),

                const SizedBox(height: 20),

                // Comments section
                _buildCommentsSection(),

                const SizedBox(height: 20),

                // Suggestions section
                _buildSuggestionsSection(),

                const SizedBox(height: 30),

                // Submit button
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSupervisorInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue[100],
              child: Text(
                widget.supervisor.name.isNotEmpty ? widget.supervisor.name[0] : 'م',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.supervisor.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مشرف/ة الباص المدرسي',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'تقييم شهر ${_getMonthName(DateTime.now().month)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildEvaluationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star, color: Color(0xFF1E88E5), size: 24),
                SizedBox(width: 8),
                Text(
                  'تقييم الأداء',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...EvaluationCategory.values.map((category) => _buildRatingRow(category)),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(EvaluationCategory category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.displayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category.description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: EvaluationRating.values.map((rating) {
              final isSelected = _ratings[category] == rating;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _ratings[category] = rating;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _getRatingColor(rating) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? _getRatingColor(rating) : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          rating.value.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rating.displayName,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.comment, color: Color(0xFF1E88E5), size: 24),
                SizedBox(width: 8),
                Text(
                  'تعليقات إضافية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'شاركنا رأيك حول أداء المشرف (اختياري)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentsController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب تعليقاتك هنا...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Color(0xFF1E88E5), size: 24),
                SizedBox(width: 8),
                Text(
                  'اقتراحات للتحسين',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'اقتراحاتك تساعدنا في تطوير الخدمة (اختياري)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _suggestionsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب اقتراحاتك هنا...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitEvaluation,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  Text('جاري الحفظ...'),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'إرسال التقييم',
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

  Future<void> _submitEvaluation() async {
    setState(() => _isSubmitting = true);

    try {
      debugPrint('🔄 Starting evaluation submission...');

      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }
      debugPrint('✅ User authenticated: ${currentUser.uid}');

      // Get parent's student info for the evaluation
      final students = await _databaseService.getStudentsByParentOnce(currentUser.uid);
      if (students.isEmpty) {
        throw Exception('لا يوجد طلاب مسجلين');
      }
      debugPrint('✅ Found ${students.length} students');

      final student = students.first; // Use first student for now
      final now = DateTime.now();

      final evaluation = SupervisorEvaluationModel(
        id: const Uuid().v4(),
        supervisorId: widget.supervisor.id,
        supervisorName: widget.supervisor.name,
        parentId: currentUser.uid,
        parentName: currentUser.displayName ?? 'ولي الأمر',
        studentId: student.id,
        studentName: student.name,
        busId: student.busId,
        ratings: _ratings,
        comments: _commentsController.text.trim().isNotEmpty
            ? _commentsController.text.trim()
            : null,
        suggestions: _suggestionsController.text.trim().isNotEmpty
            ? _suggestionsController.text.trim()
            : null,
        evaluatedAt: now,
        month: now.month,
        year: now.year,
      );

      debugPrint('📝 Evaluation data prepared:');
      debugPrint('   - Supervisor: ${evaluation.supervisorName}');
      debugPrint('   - Student: ${evaluation.studentName}');
      debugPrint('   - Ratings count: ${evaluation.ratings.length}');

      await _databaseService.createSupervisorEvaluation(evaluation);
      debugPrint('✅ Evaluation saved successfully');

      // إرسال إشعار للإدارة عن التقييم الجديد
      try {
        await _notificationService.notifySupervisorEvaluationWithSound(
          supervisorId: evaluation.supervisorId,
          supervisorName: evaluation.supervisorName,
          parentId: evaluation.parentId,
          parentName: evaluation.parentName,
          studentName: evaluation.studentName,
          rating: evaluation.averageRating,
          comment: evaluation.comments,
        );
        debugPrint('✅ Evaluation notification sent to admins');
      } catch (e) {
        debugPrint('❌ Error sending evaluation notification: $e');
        // لا نوقف العملية إذا فشل الإشعار
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onEvaluationComplete?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال التقييم بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error submitting evaluation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال التقييم: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Color _getRatingColor(EvaluationRating rating) {
    switch (rating) {
      case EvaluationRating.excellent: return Colors.green;
      case EvaluationRating.veryGood: return Colors.lightGreen;
      case EvaluationRating.good: return Colors.blue;
      case EvaluationRating.fair: return Colors.orange;
      case EvaluationRating.poor: return Colors.red;
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month];
  }
}
