import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/notification_model.dart';
import '../../utils/responsive_helper.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: _markAllAsRead,
            tooltip: 'تحديد الكل كمقروء',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUnreadCountHeader(),
          Expanded(child: _buildNotificationsList()),
        ],
      ),
    );
  }

  Widget _buildUnreadCountHeader() {
    return StreamBuilder<int>(
      stream: _databaseService.getParentNotificationsCount(
        _authService.currentUser?.uid ?? '',
      ),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        if (unreadCount == 0) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'لديك $unreadCount إشعار غير مقروء',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text('تحديد الكل كمقروء'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<List<NotificationModel>>(
      stream: _databaseService.getParentNotifications(
        _authService.currentUser?.uid ?? '',
      ),
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
                  onPressed: () => setState(() {}),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 20),
                Text(
                  'لا توجد إشعارات',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ستظهر هنا الإشعارات المتعلقة بأطفالك',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              padding: ResponsiveHelper.getPadding(context,
                mobilePadding: const EdgeInsets.symmetric(horizontal: 12),
                tabletPadding: const EdgeInsets.symmetric(horizontal: 24),
                desktopPadding: const EdgeInsets.symmetric(horizontal: 48)),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(notification);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[200]! : Colors.blue[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _markAsRead(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildNotificationIcon(notification.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                            color: notification.isRead
                                ? Colors.grey[800]
                                : Colors.blue[800],
                          ),
                        ),
                        if (notification.studentName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'الطالب: ${notification.studentName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
              _buildNotificationBody(notification),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    notification.formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case NotificationType.studentBoarded:
      case NotificationType.studentLeft:
        iconData = Icons.directions_bus;
        iconColor = Colors.green;
        break;
      case NotificationType.tripStarted:
      case NotificationType.tripEnded:
        iconData = Icons.home;
        iconColor = Colors.blue;
        break;
      case NotificationType.tripDelayed:
        iconData = Icons.access_time;
        iconColor = Colors.orange;
        break;
      case NotificationType.absenceRequested:
      case NotificationType.absenceApproved:
      case NotificationType.absenceRejected:
        iconData = Icons.person_off;
        iconColor = Colors.red;
        break;
      case NotificationType.emergency:
        iconData = Icons.warning_amber_rounded;
        iconColor = Colors.red;
        break;
      case NotificationType.complaintSubmitted:
      case NotificationType.complaintResponded:
        iconData = Icons.campaign;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  Widget _buildNotificationBody(NotificationModel notification) {
    if (notification.body.isEmpty) return const SizedBox.shrink();
    return Text(
      notification.body,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[700],
      ),
    );
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    try {
      await _databaseService.markNotificationAsRead(notification.id);
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = _authService.currentUser?.uid;
    if (userId == null || userId.isEmpty) return;
    try {
      await _databaseService.markAllParentNotificationsAsRead(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديد جميع الإشعارات كمقروءة')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }
}
