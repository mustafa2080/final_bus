import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/notification_sender_service.dart';
import '../../models/complaint_model.dart';
import '../../models/student_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AddComplaintScreen extends StatefulWidget {
  const AddComplaintScreen({super.key});

  @override
  State<AddComplaintScreen> createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  final NotificationSenderService _notificationSender = NotificationSenderService();
  final ImagePicker _imagePicker = ImagePicker();

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // State variables
  bool _isLoading = false;
  ComplaintType _selectedType = ComplaintType.other;
  ComplaintPriority _selectedPriority = ComplaintPriority.medium;
  String? _selectedStudentId;
  List<StudentModel> _students = [];
  final List<File> _attachments = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    final user = _authService.currentUser;
    if (user != null) {
      _databaseService.getStudentsByParent(user.uid).listen((students) {
        setState(() {
          _students = students;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('إضافة شكوى'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Card
            _buildHeaderCard(),
            const SizedBox(height: 20),

            // Complaint Information
            _buildComplaintInfoCard(),
            const SizedBox(height: 20),

            // Attachments Section
            _buildAttachmentsSection(),
            const SizedBox(height: 20),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade300,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.feedback, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'تقديم شكوى',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'نحن نهتم بآرائكم وملاحظاتكم لتحسين خدماتنا',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفاصيل الشكوى',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Complaint Title
          CustomTextField(
            controller: _titleController,
            label: 'عنوان الشكوى',
            hint: 'أدخل عنوان مختصر للشكوى',
            prefixIcon: Icons.title,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال عنوان الشكوى';
              }
              if (value.trim().length < 5) {
                return 'عنوان الشكوى يجب أن يكون أكثر من 5 أحرف';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Complaint Type
          DropdownButtonFormField<ComplaintType>(
            value: _selectedType,
            decoration: InputDecoration(
              labelText: 'نوع الشكوى',
              prefixIcon: const Icon(Icons.category),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E88E5)),
              ),
            ),
            items: ComplaintType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(_getComplaintTypeDisplayName(type)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Priority
          DropdownButtonFormField<ComplaintPriority>(
            value: _selectedPriority,
            decoration: InputDecoration(
              labelText: 'الأولوية',
              prefixIcon: const Icon(Icons.priority_high),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E88E5)),
              ),
            ),
            items: ComplaintPriority.values.map((priority) {
              return DropdownMenuItem(
                value: priority,
                child: Text(_getComplaintPriorityDisplayName(priority)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPriority = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Related Student (Optional)
          if (_students.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: _selectedStudentId,
              decoration: InputDecoration(
                labelText: 'الطالب المتعلق بالشكوى (اختياري)',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1E88E5)),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('لا يوجد طالب محدد'),
                ),
                ..._students.map((student) {
                  return DropdownMenuItem(
                    value: student.id,
                    child: Text(student.name),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStudentId = value;
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          // Description
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'تفاصيل الشكوى',
              hintText: 'اشرح الشكوى بالتفصيل...',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.description),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E88E5)),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال تفاصيل الشكوى';
              }
              if (value.trim().length < 10) {
                return 'تفاصيل الشكوى يجب أن تكون أكثر من 10 أحرف';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المرفقات (اختياري)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Add Attachment Button
          OutlinedButton.icon(
            onPressed: _attachments.length < 3 ? _addAttachment : null,
            icon: const Icon(Icons.attach_file),
            label: Text('إضافة مرفق (${_attachments.length}/3)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E88E5),
              side: const BorderSide(color: Color(0xFF1E88E5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Attachments List
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(_attachments.length, (index) {
              final file = _attachments[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Color(0xFF1E88E5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.path.split('/').last,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeAttachment(index),
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 8),
          Text(
            'يمكنك إضافة حتى 3 صور لتوضيح الشكوى',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        CustomButton(
          text: _isLoading ? 'جاري الإرسال...' : 'إرسال الشكوى',
          onPressed: _isLoading ? null : _submitComplaint,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 12),
        CustomButton(
          text: 'إلغاء',
          onPressed: () => context.pop(),
          backgroundColor: Colors.grey[300],
          textColor: Colors.black87,
        ),
      ],
    );
  }

  String _getComplaintTypeDisplayName(ComplaintType type) {
    switch (type) {
      case ComplaintType.busService:
        return 'خدمة الباص';
      case ComplaintType.driverBehavior:
        return 'سلوك السائق';
      case ComplaintType.safety:
        return 'السلامة';
      case ComplaintType.timing:
        return 'التوقيت';
      case ComplaintType.communication:
        return 'التواصل';
      case ComplaintType.other:
        return 'أخرى';
    }
  }

  String _getComplaintPriorityDisplayName(ComplaintPriority priority) {
    switch (priority) {
      case ComplaintPriority.low:
        return 'منخفضة';
      case ComplaintPriority.medium:
        return 'متوسطة';
      case ComplaintPriority.high:
        return 'عالية';
      case ComplaintPriority.urgent:
        return 'عاجلة';
    }
  }

  Future<void> _addAttachment() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _attachments.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // Get parent information
      final parentData = await _databaseService.getUserData(currentUser.uid);
      if (parentData == null) {
        throw Exception('لم يتم العثور على بيانات ولي الأمر');
      }

      // Upload attachments if any
      List<String> attachmentUrls = [];
      for (int i = 0; i < _attachments.length; i++) {
        try {
          final fileName = 'complaint_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final imageBytes = await _attachments[i].readAsBytes();
          final url = await _storageService.uploadFile(
            imageBytes,
            fileName,
            'complaint_attachments',
            contentType: 'image/jpeg',
            customMetadata: {
              'type': 'complaint_attachment',
              'parentId': currentUser.uid,
            },
          );
          attachmentUrls.add(url);
        } catch (uploadError) {
          debugPrint('Failed to upload attachment $i: $uploadError');
          // Continue without this attachment
        }
      }

      // Get selected student info if any
      String? studentName;
      if (_selectedStudentId != null) {
        final student = _students.firstWhere(
          (s) => s.id == _selectedStudentId,
          orElse: () => _students.first,
        );
        studentName = student.name;
      }

      // Create complaint model
      final complaint = ComplaintModel(
        id: '', // Will be generated by database service
        parentId: currentUser.uid,
        parentName: parentData['name'] ?? '',
        parentPhone: parentData['phone'] ?? '',
        studentId: _selectedStudentId,
        studentName: studentName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        priority: _selectedPriority,
        attachments: attachmentUrls,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to database
      await _databaseService.addComplaint(complaint);

      // إرسال إشعار للإدارة مع الصوت (النظام القديم)
      await NotificationService().notifyNewComplaintWithSound(
        complaintId: complaint.id,
        parentId: currentUser.uid,
        parentName: parentData['name'] ?? 'ولي أمر',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        subject: _titleController.text.trim(),
        category: _selectedType.toString().split('.').last,
      );

      // إرسال إشعار push للأدمن (النظام الجديد المحسن)
      await _notificationSender.sendComplaintNotificationToAdmin(
        complaintId: complaint.id,
        parentName: parentData['name'] ?? 'ولي أمر',
        studentName: studentName ?? 'غير محدد',
        complaintType: _getComplaintTypeText(_selectedType),
      );

      // تأكيد إرسال الإشعار خارج التطبيق
      debugPrint('📧 Complaint notification sent to admin for outside app display');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الشكوى بنجاح. سيتم الرد عليها في أقرب وقت.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Go back to parent home
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال الشكوى: $e'),
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

  /// تحويل نوع الشكوى إلى نص عربي
  String _getComplaintTypeText(ComplaintType type) {
    switch (type) {
      case ComplaintType.busService:
        return 'شكوى خدمة الباص';
      case ComplaintType.driverBehavior:
        return 'شكوى سلوك السائق';
      case ComplaintType.safety:
        return 'شكوى أمان';
      case ComplaintType.timing:
        return 'شكوى التوقيت';
      case ComplaintType.communication:
        return 'شكوى التواصل';
      case ComplaintType.other:
        return 'شكوى أخرى';
    }
  }
}
