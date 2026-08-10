import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/parent_student_link_service.dart';
import '../../models/student_model.dart';

class LinkStudentScreen extends StatefulWidget {
  const LinkStudentScreen({super.key});

  @override
  State<LinkStudentScreen> createState() => _LinkStudentScreenState();
}

class _LinkStudentScreenState extends State<LinkStudentScreen> {
  final AuthService _authService = AuthService();
  final ParentStudentLinkService _linkService = ParentStudentLinkService();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSearching = false;
  bool _hasSearched = false;
  List<StudentModel> _results = [];
  final Set<String> _linkingIds = {};

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    if (phone.isEmpty && name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم الهاتف أو اسم ولي الأمر للبحث'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _linkService.searchUnlinkedStudents(
        parentPhone: phone.isNotEmpty ? phone : null,
        parentName: name.isNotEmpty ? name : null,
      );
      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في البحث: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _linkStudent(StudentModel student) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الربط'),
        content: Text('هل أنت متأكد من ربط الطالب "${student.name}" بحسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              foregroundColor: Colors.white,
            ),
            child: const Text('ربط'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _linkingIds.add(student.id));

    try {
      await _linkService.linkStudentToParent(student.id, currentUser.uid);
      if (mounted) {
        setState(() {
          _results.removeWhere((s) => s.id == student.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ربط الطالب ${student.name} بحسابك بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الربط: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _linkingIds.remove(student.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2D3748)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'ربط طالب موجود',
          style: TextStyle(color: Color(0xFF2D3748), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 16),
            _buildSearchCard(),
            const SizedBox(height: 16),
            if (_isSearching)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (_hasSearched)
              _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF667EEA).withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667EEA).withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF667EEA)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لو المدرسة سجلت بيانات طفلك مسبقاً، ابحث برقم هاتفك أو اسمك المسجل عند الإدارة لربطه بحسابك',
              style: TextStyle(color: Colors.grey[800], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم هاتف ولي الأمر (كما هو مسجل عند المدرسة)',
              prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF667EEA)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'اسم ولي الأمر (اختياري)',
              prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF667EEA)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('بحث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'لا يوجد طلاب مطابقين لبيانات البحث\nتأكد من رقم الهاتف أو الاسم كما هو مسجل عند المدرسة',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _results.map((student) => _buildStudentCard(student)).toList(),
    );
  }

  Widget _buildStudentCard(StudentModel student) {
    final isLinking = _linkingIds.contains(student.id);
    final hasPhone = student.parentPhone.isNotEmpty;
    final hasParentName = student.parentName.isNotEmpty;
    final hasSchoolInfo = student.schoolName.isNotEmpty || student.grade.isNotEmpty;
    final hasAddress = student.address.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: صورة الطالب + الاسم + زرار الربط
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF667EEA).withAlpha(30),
                  child: Text(
                    student.name.isNotEmpty ? student.name[0] : 'ط',
                    style: const TextStyle(
                      color: Color(0xFF667EEA),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name.isNotEmpty ? student.name : 'بدون اسم',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(0xFF2D3748),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasSchoolInfo) ...[
                        const SizedBox(height: 4),
                        Text(
                          [student.schoolName, student.grade].where((s) => s.isNotEmpty).join(' - '),
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // تفاصيل الطالب - كل المعلومات المتاحة ظاهرة بوضوح
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'ولي الأمر',
                  value: hasParentName ? student.parentName : 'غير مسجل',
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  icon: Icons.phone_outlined,
                  label: 'رقم الهاتف',
                  value: hasPhone ? student.parentPhone : 'غير مسجل',
                ),
                if (hasAddress) ...[
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'العنوان',
                    value: student.address,
                  ),
                ],
                const SizedBox(height: 10),
                _buildDetailRow(
                  icon: Icons.qr_code_2_rounded,
                  label: 'كود الطالب',
                  value: student.qrCode.isNotEmpty ? student.qrCode : student.id,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  icon: Icons.directions_bus_outlined,
                  label: 'الحالة الحالية',
                  value: student.statusDisplayText,
                  valueColor: _statusColor(student.currentStatus),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // زرار الربط
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: isLinking
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _linkStudent(student),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('ربط بحسابي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF667EEA)),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF2D3748),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _statusColor(StudentStatus status) {
    switch (status) {
      case StudentStatus.home:
        return const Color(0xFF64748B);
      case StudentStatus.onBus:
        return const Color(0xFFF59E0B);
      case StudentStatus.atSchool:
        return const Color(0xFF10B981);
    }
  }
}
