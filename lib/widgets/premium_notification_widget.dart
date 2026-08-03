import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/master_notification_service.dart';
import '../utils/responsive_helper.dart';

/// 🎨 Widget الإشعارات الاحترافي
/// يعرض الإشعارات بتصميم جميل ومتجاوب
class PremiumNotificationWidget extends StatefulWidget {
  final bool showUnreadOnly;
  final int? limit;
  final Function(Map<String, dynamic>)? onNotificationTap;
  
  const PremiumNotificationWidget({
    super.key,
    this.showUnreadOnly = false,
    this.limit,
    this.onNotificationTap,
  });

  @override
  State<PremiumNotificationWidget> createState() => _PremiumNotificationWidgetState();
}

class _PremiumNotificationWidgetState extends State<PremiumNotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  final MasterNotificationService _notificationService = MasterNotificationService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutBack,
        )),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _notificationService.getUserNotifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingWidget();
            }

            if (snapshot.hasError) {
              return _buildErrorWidget(snapshot.error.toString());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyWidget();
            }

            List<Map<String, dynamic>> notifications = snapshot.data!;
            
            if (widget.showUnreadOnly) {
              notifications = notifications.where((n) => n['isRead'] != true).toList();
            }

            if (widget.limit != null && notifications.length > widget.limit!) {
              notifications = notifications.take(widget.limit!).toList();
            }

            return _buildNotificationsList(notifications);
          },
        ),
      ),
    );
  }

  /// بناء قائمة الإشعارات
  Widget _buildNotificationsList(List<Map<String, dynamic>> notifications) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.white,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(notifications.length),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(
                  notifications[index], 
                  index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// بناء رأس قائمة الإشعارات
  Widget _buildHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade600,
            Colors.indigo.shade700,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الإشعارات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveHelper.getFontSize(context, 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$count إشعار${count > 1 ? 'ات' : ''}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: ResponsiveHelper.getFontSize(context, 14),
                  ),
                ),
              ],
            ),
          ),
          if (count > 0) ...[
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
              label: Text(
                'قراءة الكل',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveHelper.getFontSize(context, 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// بناء عنصر الإشعار الواحد
  Widget _buildNotificationItem(Map<String, dynamic> notification, int index) {
    final isRead = notification['isRead'] == true;
    final type = notification['type'] ?? 'general';
    final createdAt = notification['createdAt'] as Timestamp?;
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: isRead ? 2 : 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: _getNotificationColor(type).withOpacity(0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleNotificationTap(notification),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  isRead 
                    ? Colors.grey.shade50 
                    : _getNotificationColor(type).withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: isRead 
                  ? Colors.grey.shade200 
                  : _getNotificationColor(type).withOpacity(0.3),
                width: isRead ? 1 : 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationIcon(type, isRead),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'] ?? 'إشعار',
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getFontSize(context, 16),
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                color: isRead ? Colors.grey.shade700 : Colors.black87,
                              ),
                            ),
                          ),
                          if (!isRead) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _getNotificationColor(type),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (notification['body'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          notification['body'],
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getFontSize(context, 14),
                            color: isRead ? Colors.grey.shade600 : Colors.grey.shade700,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildTypeChip(type),
                          const Spacer(),
                          if (createdAt != null) ...[
                            Text(
                              _formatTime(createdAt.toDate()),
                              style: TextStyle(
                                fontSize: ResponsiveHelper.getFontSize(context, 12),
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء أيقونة الإشعار
  Widget _buildNotificationIcon(String type, bool isRead) {
    final color = isRead ? Colors.grey.shade400 : _getNotificationColor(type);
    final icon = _getNotificationIcon(type);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  /// بناء شريحة نوع الإشعار
  Widget _buildTypeChip(String type) {
    final color = _getNotificationColor(type);
    final label = _getTypeLabel(type);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: ResponsiveHelper.getFontSize(context, 11),
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// بناء widget التحميل
  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'جار تحميل الإشعارات...',
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(context, 16),
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// بناء widget الخطأ
  Widget _buildErrorWidget(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ في تحميل الإشعارات',
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(context, 14),
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء widget الفراغ
  Widget _buildEmptyWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.blue.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد إشعارات',
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(context, 20),
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا جميع إشعاراتك الجديدة',
            style: TextStyle(
              fontSize: ResponsiveHelper.getFontSize(context, 14),
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// تحديد لون الإشعار حسب النوع
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'student_assignment':
      case 'student_removal':
      case 'student_update':
        return Colors.green;
      case 'bus_boarding':
      case 'bus_alighting':
      case 'bus_status':
        return Colors.orange;
      case 'absence_request':
      case 'absence_approved':
      case 'absence_rejected':
        return Colors.purple;
      case 'complaint':
      case 'complaint_reply':
        return Colors.indigo;
      case 'emergency':
      case 'urgent_alert':
        return Colors.red;
      case 'admin_alert':
      case 'report_ready':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }

  /// تحديد أيقونة الإشعار حسب النوع
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'student_assignment':
        return Icons.person_add;
      case 'student_removal':
        return Icons.person_remove;
      case 'student_update':
        return Icons.person_outline;
      case 'bus_boarding':
        return Icons.directions_bus;
      case 'bus_alighting':
        return Icons.home;
      case 'bus_status':
        return Icons.location_on;
      case 'absence_request':
        return Icons.event_busy;
      case 'absence_approved':
        return Icons.check_circle;
      case 'absence_rejected':
        return Icons.cancel;
      case 'complaint':
        return Icons.report_problem;
      case 'complaint_reply':
        return Icons.reply;
      case 'emergency':
        return Icons.warning;
      case 'urgent_alert':
        return Icons.priority_high;
      case 'admin_alert':
        return Icons.admin_panel_settings;
      case 'report_ready':
        return Icons.assessment;
      default:
        return Icons.notifications;
    }
  }

  /// تحديد تسمية نوع الإشعار
  String _getTypeLabel(String type) {
    switch (type) {
      case 'student_assignment':
        return 'تسكين طالب';
      case 'student_removal':
        return 'إزالة طالب';
      case 'student_update':
        return 'تحديث طالب';
      case 'bus_boarding':
        return 'ركوب الباص';
      case 'bus_alighting':
        return 'نزول من الباص';
      case 'bus_status':
        return 'حالة الباص';
      case 'absence_request':
        return 'طلب غياب';
      case 'absence_approved':
        return 'موافقة غياب';
      case 'absence_rejected':
        return 'رفض غياب';
      case 'complaint':
        return 'شكوى';
      case 'complaint_reply':
        return 'رد على شكوى';
      case 'emergency':
        return 'طوارئ';
      case 'urgent_alert':
        return 'تنبيه عاجل';
      case 'admin_alert':
        return 'تنبيه إداري';
      case 'report_ready':
        return 'تقرير جاهز';
      default:
        return 'عام';
    }
  }

  /// تنسيق الوقت
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// معالجة نقر الإشعار
  void _handleNotificationTap(Map<String, dynamic> notification) async {
    // تعليم الإشعار كمقروء
    if (notification['isRead'] != true) {
      await _notificationService.markNotificationAsRead(notification['id']);
    }
    
    // استدعاء callback إذا تم توفيره
    if (widget.onNotificationTap != null) {
      widget.onNotificationTap!(notification);
    }
  }

  /// تعليم جميع الإشعارات كمقروءة
  void _markAllAsRead() async {
    await _notificationService.markAllNotificationsAsRead();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم تعليم جميع الإشعارات كمقروءة'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}