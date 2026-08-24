import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/student_model.dart';
import '../../models/student_behavior_model.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class MonthlyBehaviorSurveyScreen extends StatefulWidget {
  const MonthlyBehaviorSurveyScreen({super.key});

  @override
  State<MonthlyBehaviorSurveyScreen> createState() => _MonthlyBehaviorSurveyScreenState();
}

class _MonthlyBehaviorSurveyScreenState extends State<MonthlyBehaviorSurveyScreen> with TickerProviderStateMixin {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  List<StudentModel> _students = [];
  List<StudentBehaviorEvaluation> _evaluations = [];
  bool _isLoading = true;
  
  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// نفس الدالة المستخدمة في الصفحة الرئيسية للمشرف
  Future<List<StudentModel>> _loadSupervisorStudents(String supervisorId) async {
    try {
      debugPrint('🔄 Loading supervisor students for monthly surveys: $supervisorId');

      // استخدام الطريقة البسيطة
      final assignments = await _databaseService.getSupervisorAssignmentsSimple(supervisorId);
      debugPrint('📋 Found ${assignments.length} assignments for supervisor');

      if (assignments.isEmpty) {
        debugPrint('⚠️ No assignments found for supervisor $supervisorId');
        return <StudentModel>[];
      }

      // جمع جميع الطلاب من جميع التكليفات
      List<StudentModel> allStudents = [];

      for (final assignment in assignments) {
        final busRoute = assignment.busRoute;
        final busId = assignment.busId;

        debugPrint('🚌 Processing assignment - Route: "$busRoute", BusId: "$busId"');

        List<StudentModel> students = [];

        // البحث بـ busRoute أولاً
        if (busRoute.isNotEmpty) {
          students = await _databaseService.getStudentsByRouteSimple(busRoute);
          debugPrint('👥 Found ${students.length} students by route "$busRoute"');
        }

        // البحث بـ busId إذا لم نجد طلاب بـ busRoute
        if (students.isEmpty && busId.isNotEmpty) {
          students = await _databaseService.getStudentsByBusIdSimple(busId);
          debugPrint('👥 Found ${students.length} students by busId "$busId"');
        }

        allStudents.addAll(students);
      }

      // إزالة التكرارات
      final uniqueStudents = <String, StudentModel>{};
      for (final student in allStudents) {
        uniqueStudents[student.id] = student;
      }

      final result = uniqueStudents.values.toList();
      debugPrint('✅ Total unique students for supervisor: ${result.length}');

      return result;
    } catch (e) {
      debugPrint('❌ Error loading supervisor students: $e');
      return <StudentModel>[];
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load students for supervisor's route only
      final supervisorId = _authService.currentUser?.uid ?? '';
      debugPrint('🔍 Loading students for supervisor: $supervisorId');

      // استخدام نفس الطريقة المستخدمة في الصفحة الرئيسية للمشرف
      final supervisorStudents = await _loadSupervisorStudents(supervisorId);

      if (mounted) {
        setState(() {
          _students = supervisorStudents;
        });
      }

      debugPrint('👥 Loaded ${supervisorStudents.length} students for monthly surveys');

      // Load evaluations for current month
      await _loadEvaluations();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEvaluations() async {
    try {
      final evaluations = await _databaseService.getBehaviorEvaluations(
        supervisorId: _authService.currentUser?.uid ?? '',
        month: _currentMonth,
        year: _currentYear,
      );
      
      setState(() {
        _evaluations = evaluations;
      });
    } catch (e) {
      debugPrint('Error loading evaluations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('الاستبيانات الشهرية'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _showMonthYearPicker,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.assignment),
              text: 'تقييم الطلاب',
            ),
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'المكتملة',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'الإحصائيات',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Month/Year Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  _getMonthYearText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEvaluationTab(),
                _buildCompletedTab(),
                _buildStatisticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد طلاب',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final evaluation = _evaluations.firstWhere(
          (eval) => eval.studentId == student.id,
          orElse: () => _createEmptyEvaluation(student),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Student Avatar
                CircleAvatar(
                  radius: 25,
                  backgroundColor: evaluation.isSubmitted 
                      ? Colors.green 
                      : const Color(0xFF1E88E5),
                  child: evaluation.isSubmitted
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                          student.name.isNotEmpty ? student.name[0] : 'ط',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                
                // Student Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.grade,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (evaluation.isSubmitted) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              evaluation.averageRatingText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Action Button
                ElevatedButton.icon(
                  onPressed: () => _openEvaluationForm(student, evaluation),
                  icon: Icon(
                    evaluation.isSubmitted ? Icons.edit : Icons.assignment,
                    size: 18,
                  ),
                  label: Text(evaluation.isSubmitted ? 'تعديل' : 'تقييم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evaluation.isSubmitted 
                        ? Colors.orange 
                        : const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
        ),
      ),
    );
  }

  Widget _buildCompletedTab() {
    final completedEvaluations = _evaluations.where((eval) => eval.isSubmitted).toList();

    if (completedEvaluations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_turned_in,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد تقييمات مكتملة',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بتقييم الطلاب لهذا الشهر',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedEvaluations.length,
      itemBuilder: (context, index) {
        final evaluation = completedEvaluations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: const Icon(Icons.check, color: Colors.white),
            ),
            title: Text(
              evaluation.studentName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 4),
                    Text('التقييم العام: ${evaluation.averageRatingText}'),
                  ],
                ),
                Text(
                  'تم التقييم: ${DateFormat('yyyy/MM/dd').format(evaluation.updatedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () => _viewEvaluationDetails(evaluation),
            ),
          ),
        );
      },
        ),
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final completedEvaluations = _evaluations.where((eval) => eval.isSubmitted).toList();
    
    if (completedEvaluations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد إحصائيات',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أكمل بعض التقييمات لعرض الإحصائيات',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
        children: [
          _buildStatisticsCard('إحصائيات عامة', [
            _buildStatRow('عدد الطلاب المقيمين', completedEvaluations.length.toString()),
            _buildStatRow('إجمالي الطلاب', _students.length.toString()),
            _buildStatRow('نسبة الإكمال', '${((completedEvaluations.length / _students.length) * 100).toStringAsFixed(1)}%'),
          ]),
          
          const SizedBox(height: 16),
          
          _buildBehaviorCategoriesChart(completedEvaluations),
        ],
          ),
        ),
      ),
    );
  }

  StudentBehaviorEvaluation _createEmptyEvaluation(StudentModel student) {
    return StudentBehaviorEvaluation(
      id: '',
      studentId: student.id,
      studentName: student.name,
      supervisorId: _authService.currentUser?.uid ?? '',
      supervisorName: 'المشرف',
      busId: student.busId,
      busRoute: student.busRoute,
      month: _currentMonth,
      year: _currentYear,
      ratings: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String _getMonthYearText() {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${months[_currentMonth]} $_currentYear';
  }

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر الشهر والسنة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _currentMonth,
              decoration: const InputDecoration(labelText: 'الشهر'),
              items: List.generate(12, (index) {
                const months = [
                  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
                  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
                ];
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(months[index]),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentMonth = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _currentYear,
              decoration: const InputDecoration(labelText: 'السنة'),
              items: List.generate(5, (index) {
                final year = DateTime.now().year - 2 + index;
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentYear = value;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadEvaluations();
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  void _openEvaluationForm(StudentModel student, StudentBehaviorEvaluation evaluation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudentBehaviorEvaluationForm(
          student: student,
          evaluation: evaluation,
          month: _currentMonth,
          year: _currentYear,
          onSaved: () {
            _loadEvaluations();
          },
        ),
      ),
    );
  }

  void _viewEvaluationDetails(StudentBehaviorEvaluation evaluation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تقييم ${evaluation.studentName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التقييم العام: ${evaluation.averageRatingText}'),
              const SizedBox(height: 16),
              const Text('التقييمات التفصيلية:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...evaluation.ratings.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(StudentBehaviorEvaluation.getBehaviorCategoryName(entry.key)),
                    Text(StudentBehaviorEvaluation.getBehaviorRatingName(entry.value)),
                  ],
                ),
              )),
              if (evaluation.generalNotes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('ملاحظات عامة:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(evaluation.generalNotes),
              ],
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
  }

  Widget _buildStatisticsCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorCategoriesChart(List<StudentBehaviorEvaluation> evaluations) {
    final categoryAverages = <BehaviorCategory, double>{};

    for (final category in StudentBehaviorEvaluation.getAllCategories()) {
      final ratings = evaluations
          .where((eval) => eval.ratings.containsKey(category))
          .map((eval) => eval.ratings[category]!)
          .toList();

      if (ratings.isNotEmpty) {
        final total = ratings.map((rating) => _getRatingValue(rating)).reduce((a, b) => a + b);
        categoryAverages[category] = total / ratings.length;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'متوسط التقييمات حسب الفئة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...categoryAverages.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(StudentBehaviorEvaluation.getBehaviorCategoryName(entry.key)),
                      Text('${entry.value.toStringAsFixed(1)}/5'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: entry.value / 5,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(entry.value),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  int _getRatingValue(BehaviorRating rating) {
    switch (rating) {
      case BehaviorRating.excellent: return 5;
      case BehaviorRating.veryGood: return 4;
      case BehaviorRating.good: return 3;
      case BehaviorRating.fair: return 2;
      case BehaviorRating.poor: return 1;
    }
  }

  Color _getProgressColor(double value) {
    if (value >= 4.0) return Colors.green;
    if (value >= 3.0) return Colors.orange;
    return Colors.red;
  }
}

// صفحة نموذج تقييم الطالب
class StudentBehaviorEvaluationForm extends StatefulWidget {
  final StudentModel student;
  final StudentBehaviorEvaluation evaluation;
  final int month;
  final int year;
  final VoidCallback onSaved;

  const StudentBehaviorEvaluationForm({
    super.key,
    required this.student,
    required this.evaluation,
    required this.month,
    required this.year,
    required this.onSaved,
  });

  @override
  State<StudentBehaviorEvaluationForm> createState() => _StudentBehaviorEvaluationFormState();
}

class _StudentBehaviorEvaluationFormState extends State<StudentBehaviorEvaluationForm> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  late Map<BehaviorCategory, BehaviorRating> _ratings;
  final TextEditingController _notesController = TextEditingController();
  final List<TextEditingController> _positivePointsControllers = [];
  final List<TextEditingController> _improvementAreasControllers = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ratings = Map.from(widget.evaluation.ratings);
    _notesController.text = widget.evaluation.generalNotes;

    // Initialize positive points controllers
    for (final point in widget.evaluation.positivePoints) {
      final controller = TextEditingController(text: point);
      _positivePointsControllers.add(controller);
    }
    if (_positivePointsControllers.isEmpty) {
      _positivePointsControllers.add(TextEditingController());
    }

    // Initialize improvement areas controllers
    for (final area in widget.evaluation.improvementAreas) {
      final controller = TextEditingController(text: area);
      _improvementAreasControllers.add(controller);
    }
    if (_improvementAreasControllers.isEmpty) {
      _improvementAreasControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final controller in _positivePointsControllers) {
      controller.dispose();
    }
    for (final controller in _improvementAreasControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('تقييم ${widget.student.name}'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveEvaluation,
              child: const Text(
                'حفظ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStudentInfoCard(),
                  const SizedBox(height: 16),
                  _buildRatingsSection(),
                  const SizedBox(height: 16),
                  _buildNotesSection(),
                  const SizedBox(height: 16),
                  _buildPositivePointsSection(),
                  const SizedBox(height: 16),
                  _buildImprovementAreasSection(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF1E88E5),
              child: Text(
                widget.student.name.isNotEmpty ? widget.student.name[0] : 'ط',
                style: const TextStyle(
                  color: Colors.white,
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
                    widget.student.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.student.grade,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'خط السير: ${widget.student.busRoute}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getMonthYearText(),
                style: const TextStyle(
                  color: Color(0xFF1E88E5),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تقييم السلوك',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...StudentBehaviorEvaluation.getAllCategories().map((category) =>
              _buildRatingRow(category)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(BehaviorCategory category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            StudentBehaviorEvaluation.getBehaviorCategoryName(category),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              // على الشاشات الضيقة (زي iPhone SE) نقلل حجم الخط والأيقونة
              // ونحمي النص من القطع بدل ما يفيض بره الصندوق
              final isNarrow = constraints.maxWidth < 340;
              final fontSize = isNarrow ? 9.0 : 10.0;
              final iconSize = isNarrow ? 16.0 : 20.0;
              final verticalPadding = isNarrow ? 6.0 : 8.0;

              return Row(
                children: StudentBehaviorEvaluation.getAllRatings().map((rating) {
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
                        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _getRatingColor(rating)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? _getRatingColor(rating)
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getRatingIcon(rating),
                              color: isSelected ? Colors.white : Colors.grey[600],
                              size: iconSize,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              StudentBehaviorEvaluation.getBehaviorRatingName(rating),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[600],
                                fontSize: fontSize,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملاحظات عامة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'اكتب ملاحظاتك حول سلوك الطالب...',
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

  String _getMonthYearText() {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${months[widget.month]} ${widget.year}';
  }

  Color _getRatingColor(BehaviorRating rating) {
    switch (rating) {
      case BehaviorRating.excellent: return Colors.green;
      case BehaviorRating.veryGood: return Colors.lightGreen;
      case BehaviorRating.good: return Colors.orange;
      case BehaviorRating.fair: return Colors.deepOrange;
      case BehaviorRating.poor: return Colors.red;
    }
  }

  IconData _getRatingIcon(BehaviorRating rating) {
    switch (rating) {
      case BehaviorRating.excellent: return Icons.sentiment_very_satisfied;
      case BehaviorRating.veryGood: return Icons.sentiment_satisfied;
      case BehaviorRating.good: return Icons.sentiment_neutral;
      case BehaviorRating.fair: return Icons.sentiment_dissatisfied;
      case BehaviorRating.poor: return Icons.sentiment_very_dissatisfied;
    }
  }

  Widget _buildPositivePointsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'النقاط الإيجابية',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {
                    setState(() {
                      _positivePointsControllers.add(TextEditingController());
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._positivePointsControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'نقطة إيجابية ${index + 1}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.green.withAlpha(12),
                          prefixIcon: const Icon(Icons.star, color: Colors.green),
                        ),
                      ),
                    ),
                    if (_positivePointsControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            controller.dispose();
                            _positivePointsControllers.removeAt(index);
                          });
                        },
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildImprovementAreasSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'مجالات التحسين',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.orange),
                  onPressed: () {
                    setState(() {
                      _improvementAreasControllers.add(TextEditingController());
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._improvementAreasControllers.asMap().entries.map((entry) {
              final index = entry.key;
              final controller = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'مجال تحسين ${index + 1}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.orange.withAlpha(12),
                          prefixIcon: const Icon(Icons.trending_up, color: Colors.orange),
                        ),
                      ),
                    ),
                    if (_improvementAreasControllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            controller.dispose();
                            _improvementAreasControllers.removeAt(index);
                          });
                        },
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final isComplete = _ratings.length == StudentBehaviorEvaluation.getAllCategories().length;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isComplete ? _saveEvaluation : null,
        icon: const Icon(Icons.save),
        label: const Text('حفظ التقييم'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _saveEvaluation() async {
    if (_ratings.length != StudentBehaviorEvaluation.getAllCategories().length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تقييم جميع الفئات'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final positivePoints = _positivePointsControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final improvementAreas = _improvementAreasControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final evaluation = widget.evaluation.copyWith(
        ratings: _ratings,
        generalNotes: _notesController.text.trim(),
        positivePoints: positivePoints,
        improvementAreas: improvementAreas,
        isSubmitted: true,
        updatedAt: DateTime.now(),
      );

      await _databaseService.saveBehaviorEvaluation(evaluation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ تقييم ${widget.student.name} بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ التقييم: $e'),
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
}
