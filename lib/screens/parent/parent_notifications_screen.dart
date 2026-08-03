import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/notification_model.dart';
import '../../utils/notification_test_helper.dart';

class ParentNotificationsScreen extends StatefulWidget {
  const ParentNotificationsScreen({super.key});

  @override
  State<ParentNotificationsScreen> createState() => _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState extends State<ParentNotificationsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  late Stream<List<NotificationModel>> _notificationsStream;

  @override
  void initState() {
    super.initState();
    _initializeStream();
    // Mark all notifications as read when opening the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllAsRead();
    });
  }

  void _initializeStream() {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      _notificationsStream = _databaseService.getParentNotifications(userId);
    } else {
      _notificationsStream = Stream.value([]);
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      await _databaseService.markAllNotificationsAsRead(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'الإشعارات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // زر إصلاح الإشعارات (للتطوير فقط)
          IconButton(
            icon: const Icon(Icons.build),
            onPressed: _fixNotifications,
            tooltip: 'إصلاح الإشعارات',
          ),
          // زر اختبار الإشعارات (للتطوير فقط)
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => NotificationTestHelper.showQuickTestMenu(context),
            tooltip: 'اختبار الإشعارات',
          ),
          StreamBuilder<int>(
            stream: _databaseService.getParentNotificationsCount(_authService.currentUser?.uid ?? ''),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count > 0) {
                return IconButton(
                  icon: const Icon(Icons.mark_email_read),
                  onPressed: _markAllAsRead,
                  tooltip: 'تحديد الكل كمقروء',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationsStream,
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
                  Text('خطأ في تحميل الإشعارات: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد إشعارات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ستظهر الإشعارات الجديدة هنا',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationCard(notification);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    // تسجيل تشخيصي لفهم محتوى الإشعار
    debugPrint('🔍 Notification Debug:');
    debugPrint('  - ID: ${notification.id}');
    debugPrint('  - Title: "${notification.title}"');
    debugPrint('  - Body: "${notification.body}"');
    debugPrint('  - Body length: ${notification.body.length}');
    debugPrint('  - Type: ${notification.type}');
    debugPrint('  - IsRead: ${notification.isRead}');
    debugPrint('  - Data: ${notification.data}');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: notification.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: notification.isRead 
            ? BorderSide.none 
            : BorderSide(color: Colors.blue.withAlpha(76), width: 1),
      ),
      child: InkWell(
        onTap: () {
          debugPrint('🔔 InkWell onTap triggered for: ${notification.title}');
          _handleNotificationTap(notification);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: notification.isRead ? Colors.white : Colors.blue.withAlpha(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getNotificationColor(notification.type).withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                            color: const Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Body - عرض النص الكامل مع إمكانية التوسع
              _buildNotificationBody(notification),
              
              // Student info if available
              if (notification.studentName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'الطالب: ${notification.studentName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
              ],
              
              // إضافة زر خاص للشكاوى
              if (notification.type == NotificationType.complaintResponded ||
                  notification.type == NotificationType.complaintSubmitted) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withAlpha(76)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.feedback, color: Color(0xFF1E88E5), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notification.type == NotificationType.complaintResponded
                              ? 'تم الرد على شكواك - اضغط لعرض التفاصيل'
                              : 'تم استلام شكواك - اضغط لعرض التفاصيل',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E88E5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF1E88E5), size: 16),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildNotificationBody(NotificationModel notification) {
    // الحصول على النص الكامل من body أو message أو data
    String fullText = '';

    // محاولة الحصول على النص من مصادر متعددة
    if (notification.body.isNotEmpty && notification.body.trim().isNotEmpty) {
      fullText = notification.body.trim();
    } else if (notification.data != null) {
      // ترتيب الأولوية: message > body > description > response
      fullText = notification.data!['message']?.toString()?.trim() ?? 
                 notification.data!['body']?.toString()?.trim() ?? 
                 notification.data!['description']?.toString()?.trim() ?? 
                 notification.data!['response']?.toString()?.trim() ?? 
                 '';
    }
    
    // إذا لم نجد نص، عرض رسالة افتراضية
    if (fullText.isEmpty) {
      // للشكاوى، عرض رسالة خاصة
      if (notification.type == NotificationType.complaintResponded ||
          notification.type == NotificationType.complaintSubmitted) {
        fullText = 'اضغط هنا لعرض تفاصيل الشكوى كاملة';
      } else {
        fullText = 'اضغط لعرض التفاصيل';
      }
    }

    // إذا كان النص قصير، عرضه مباشرة
    if (fullText.length <= 100) {
      return Text(
        fullText,
        style: TextStyle(
          fontSize: 14,
          color: fullText.contains('اضغط') ? const Color(0xFF1E88E5) : Colors.grey[700],
          height: 1.4,
          fontStyle: fullText.contains('اضغط') ? FontStyle.italic : FontStyle.normal,
          fontWeight: fullText.contains('اضغط') ? FontWeight.w500 : FontWeight.normal,
        ),
      );
    }

    // إذا كان النص طويل، عرضه مع إمكانية التوسع
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fullText.length > 100 ? '${fullText.substring(0, 100)}...' : fullText,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.4,
          ),
        ),
        if (fullText.length > 100) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showFullNotificationDialog(notification, fullText),
            child: const Text(
              'اضغط لعرض النص الكامل',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1E88E5),
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    try {
      debugPrint('🔔 تم الضغط على إشعار: ${notification.title} (ID: ${notification.id})');
      debugPrint('   - isRead قبل: ${notification.isRead}');
      
      // تحديد الإشعار كمقروء أولاً
      if (!notification.isRead) {
        await _markAsRead(notification);
        debugPrint('✅ تم تحديد الإشعار كمقروء');
      }

    // عرض التفاصيل حسب نوع الإشعار
    if (notification.type == NotificationType.complaintResponded ||
        notification.type == NotificationType.complaintSubmitted) {
      // إشعار شكوى - عرض التفاصيل في Dialog
      _showComplaintNotificationDialog(notification);
    } else {
      // إشعار عادي - عرض التفاصيل في Dialog
      // محاولة الحصول على النص الكامل من مصادر متعددة
      String fullText = notification.body.trim();
      
      if (fullText.isEmpty && notification.data != null) {
        fullText = notification.data!['message']?.toString()?.trim() ?? 
                   notification.data!['body']?.toString()?.trim() ?? 
                   notification.data!['description']?.toString()?.trim() ?? 
                   notification.data!['response']?.toString()?.trim() ?? 
                   'لا يوجد محتوى إضافي';
      }
      
        debugPrint('📝 عرض dialog عادي - طول النص: ${fullText.length}');
        _showFullNotificationDialog(notification, fullText);
      }
    } catch (e) {
      debugPrint('❌ خطأ في معالجة نقرة الإشعار: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ أثناء فتح الإشعار'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showComplaintNotificationDialog(NotificationModel notification) {
    // استخراج معلومات الشكوى من data
    final complaintTitle = notification.data?['complaintTitle']?.toString() ?? 'الشكوى';
    final complaintDescription = notification.data?['description']?.toString() ?? notification.body;
    final complaintId = notification.data?['complaintId']?.toString() ?? '';
    final response = notification.data?['response']?.toString() ?? '';
    final status = notification.data?['status']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: notification.type == NotificationType.complaintResponded
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  notification.type == NotificationType.complaintResponded
                      ? Icons.mark_chat_read
                      : Icons.feedback,
                  color: notification.type == NotificationType.complaintResponded
                      ? Colors.green
                      : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // عنوان الشكوى
                if (complaintTitle.isNotEmpty) ...[
                  const Text(
                    'عنوان الشكوى:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      complaintTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // وصف الشكوى
                if (complaintDescription.isNotEmpty) ...[
                  const Text(
                    'التفاصيل:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      complaintDescription,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D3748),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // رد الإدارة (إن وجد)
                if (response.isNotEmpty) ...[
                  const Text(
                    'رد الإدارة:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      response,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D3748),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // الحالة
                if (status.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'الحالة: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontSize: 13,
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // الوقت
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      notification.relativeTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (complaintId.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // الانتقال لصفحة الشكاوى
                  Navigator.pushNamed(context, '/parent/complaints');
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('عرض جميع الشكاوى'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1E88E5),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'قيد المراجعة';
      case 'inprogress':
      case 'in_progress':
        return 'جاري المعالجة';
      case 'resolved':
        return 'تم الحل';
      case 'closed':
        return 'مغلقة';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'inprogress':
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showFullNotificationDialog(NotificationModel notification, String fullText) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  notification.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // النص الكامل
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    fullText,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2D3748),
                      height: 1.6,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // معلومات إضافية
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      notification.relativeTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                if (notification.studentName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'الطالب: ${notification.studentName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'إغلاق',
                style: TextStyle(
                  color: Color(0xFF1E88E5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fixNotifications() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جاري إصلاح الإشعارات...'),
          backgroundColor: Colors.orange,
        ),
      );

      await _databaseService.fixExistingNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إصلاح الإشعارات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error fixing notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في إصلاح الإشعارات'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    try {
      debugPrint('📝 محاولة تحديد الإشعار كمقروء: ${notification.id}');
      
      await _databaseService.markNotificationAsRead(notification.id);
      
      debugPrint('✅ تم تحديد الإشعار كمقروء بنجاح: ${notification.id}');
      
      // تحديث الواجهة فوراً لإظهار التغيير
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ خطأ في تحديد الإشعار كمقروء: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في تحديث حالة الإشعار'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.studentBoarded:
        return Colors.green;
      case NotificationType.studentLeft:
        return Colors.orange;
      case NotificationType.tripStarted:
        return Colors.blue;
      case NotificationType.tripEnded:
        return Colors.purple;
      case NotificationType.complaintSubmitted:
        return const Color(0xFFE53E3E); // أحمر للشكوى الجديدة
      case NotificationType.complaintResponded:
        return const Color(0xFF38A169); // أخضر للرد على الشكوى
      case NotificationType.general:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.studentBoarded:
        return Icons.directions_bus;
      case NotificationType.studentLeft:
        return Icons.home;
      case NotificationType.tripStarted:
        return Icons.play_arrow;
      case NotificationType.tripEnded:
        return Icons.stop;
      case NotificationType.complaintSubmitted:
        return Icons.feedback;
      case NotificationType.complaintResponded:
        return Icons.mark_chat_read;
      case NotificationType.general:
        return Icons.info;
      default:
        return Icons.info;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} يوم';
    } else {
      return DateFormat('yyyy/MM/dd').format(timestamp);
    }
  }
}
