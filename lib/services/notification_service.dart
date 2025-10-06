import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import 'simple_fcm_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SimpleFCMService _fcmService = SimpleFCMService();
  
  bool _isInitialized = false;

  /// تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _isInitialized = true;
      debugPrint('✅ NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  /// تنظيف الموارد
  void dispose() {
    _isInitialized = false;
    debugPrint('🗑️ NotificationService disposed');
  }

  /// إشعار بالموافقة على طلب الغياب مع الصوت
  Future<void> notifyAbsenceApprovedWithSound({
    required String studentId,
    required String studentName,
    required String parentId,
    required String supervisorId,
    required DateTime absenceDate,
    required String approvedBy,
    String? approvedBySupervisorId,
    DateTime? date,
  }) async {
    try {
      final title = '✅ تمت الموافقة على طلب الغياب';
      final body = 'تمت الموافقة على غياب $studentName بتاريخ ${_formatDate(absenceDate)} بواسطة $approvedBy';
      
      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'absence_approved',
          'studentId': studentId,
          'studentName': studentName,
          'absenceDate': absenceDate.toIso8601String(),
          'approvedBy': approvedBy,
        },
        channelId: 'mybus_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.absenceApproved,
        recipientId: parentId,
        studentName: studentName,
      );

      debugPrint('✅ Absence approved notification sent');
    } catch (e) {
      debugPrint('❌ Error in notifyAbsenceApprovedWithSound: $e');
    }
  }

  /// إشعار برفض طلب الغياب مع الصوت
  Future<void> notifyAbsenceRejectedWithSound({
    required String studentId,
    required String studentName,
    required String parentId,
    required String supervisorId,
    required DateTime absenceDate,
    required String rejectedBy,
    required String reason,
    String? rejectedBySupervisorId,
    DateTime? date,
  }) async {
    try {
      final title = '❌ تم رفض طلب الغياب';
      final body = 'تم رفض طلب غياب $studentName بتاريخ ${_formatDate(absenceDate)}\nالسبب: $reason';
      
      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'absence_rejected',
          'studentId': studentId,
          'studentName': studentName,
          'absenceDate': absenceDate.toIso8601String(),
          'rejectedBy': rejectedBy,
          'reason': reason,
        },
        channelId: 'mybus_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.absenceRejected,
        recipientId: parentId,
        studentName: studentName,
      );

      debugPrint('✅ Absence rejected notification sent');
    } catch (e) {
      debugPrint('❌ Error in notifyAbsenceRejectedWithSound: $e');
    }
  }

  /// إشعار بالرد على الشكوى مع الصوت
  Future<void> notifyComplaintResponseWithSound({
    required String complaintId,
    required String parentId,
    required String subject,
    required String response,
    String? description,
  }) async {
    try {
      final title = '💬 تم الرد على شكواك';
      final bodyText = 'الموضوع: $subject\n\nالرد: $response';
      
      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: bodyText,
        data: {
          'type': 'complaintResponded',
          'complaintId': complaintId,
          'subject': subject,
          'response': response,
          'message': bodyText,
          'body': bodyText,
        },
        channelId: 'mybus_notifications',
      );

      await _saveNotificationWithData(
        title: title,
        body: bodyText,
        type: NotificationType.complaintResponded,
        recipientId: parentId,
        data: {
          'complaintId': complaintId,
          'subject': subject,
          'response': response,
          'message': bodyText,
        },
      );

      debugPrint('✅ Complaint response notification sent with body: $bodyText');
    } catch (e) {
      debugPrint('❌ Error in notifyComplaintResponseWithSound: $e');
    }
  }

  /// تحديد الإشعار كمقروء
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// إرسال إشعار تغيير حالة الطالب
  Future<void> sendStudentStatusChangeNotification({
    required String studentId,
    required String studentName,
    required String status,
    required String parentId,
    String? supervisorId,
    String? oldStatus,
    String? newStatus,
    String? supervisorName,
  }) async {
    try {
      final statusText = _getStatusText(newStatus ?? status);
      final title = '📊 تحديث حالة $studentName';
      final body = 'تم تحديث حالة الطالب إلى: $statusText';
      
      if (supervisorName != null) {
        body + '\nبواسطة: $supervisorName';
      }

      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'student_status_update',
          'studentId': studentId,
          'studentName': studentName,
          'status': status,
          'newStatus': newStatus ?? status,
          if (oldStatus != null) 'oldStatus': oldStatus,
          if (supervisorName != null) 'supervisorName': supervisorName,
        },
        channelId: 'student_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.general,
        recipientId: parentId,
        studentName: studentName,
      );
      
      debugPrint('✅ Student status change notification sent');
    } catch (e) {
      debugPrint('❌ Error sending student status change notification: $e');
    }
  }

  /// إرسال إشعار تسكين الطالب
  Future<void> notifyStudentAssignmentWithSound({
    required String studentId,
    required String studentName,
    required String parentId,
    required String busNumber,
    String? supervisorId,
    String? busPlate,
    String? busId,
    String? busRoute,
    String? supervisorName,
    String? parentName,
    String? parentPhone,
    String? excludeAdminId,
    String? adminId,
  }) async {
    try {
      final title = '🚌 تم تسكين $studentName';
      final body = 'تم تسكين الطالب على الباص رقم $busNumber${busRoute != null ? ' - خط $busRoute' : ''}';
      
      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'student_assigned',
          'studentId': studentId,
          'studentName': studentName,
          'busNumber': busNumber,
          if (busRoute != null) 'busRoute': busRoute,
          if (busId != null) 'busId': busId,
        },
        channelId: 'student_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.studentAssigned,
        recipientId: parentId,
        studentName: studentName,
      );
      
      debugPrint('✅ Student assignment notification sent');
    } catch (e) {
      debugPrint('❌ Error sending student assignment notification: $e');
    }
  }

  /// إرسال إشعار شكوى جديدة
  Future<void> sendComplaintNotification({
    required String complaintId,
    required String parentId,
    required String title,
    required String description,
    String? parentName,
    String? status,
    String? category,
  }) async {
    try {
      final notifTitle = '📝 شكوى جديدة';
      final body = 'العنوان: $title\n$description';
      
      // إرسال للإدارة
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: notifTitle,
        body: body,
        data: {
          'type': 'new_complaint',
          'complaintId': complaintId,
          'parentId': parentId,
          'title': title,
          if (category != null) 'category': category,
        },
        channelId: 'mybus_notifications',
      );
      
      debugPrint('✅ Complaint notification sent to admins');
    } catch (e) {
      debugPrint('❌ Error sending complaint notification: $e');
    }
  }

  /// إرسال إشعار غياب طالب
  Future<void> sendStudentAbsenceNotification({
    required String studentId,
    required String studentName,
    required String parentId,
    required DateTime date,
    required String reason,
    String? status,
    DateTime? absenceDate,
  }) async {
    try {
      final title = '🏠 طلب غياب جديد';
      final body = 'طلب غياب للطالب $studentName\nالتاريخ: ${_formatDate(absenceDate ?? date)}\nالسبب: $reason';
      
      // إرسال للإدارة والمشرفين
      await Future.wait([
        _fcmService.sendNotificationToUserType(
          userType: 'admin',
          title: title,
          body: body,
          data: {
            'type': 'absence_request',
            'studentId': studentId,
            'studentName': studentName,
            'parentId': parentId,
            'date': (absenceDate ?? date).toIso8601String(),
            'reason': reason,
          },
          channelId: 'mybus_notifications',
        ),
        _fcmService.sendNotificationToUserType(
          userType: 'supervisor',
          title: title,
          body: body,
          data: {
            'type': 'absence_request',
            'studentId': studentId,
            'studentName': studentName,
            'parentId': parentId,
            'date': (absenceDate ?? date).toIso8601String(),
            'reason': reason,
          },
          channelId: 'mybus_notifications',
        ),
      ]);
      
      debugPrint('✅ Absence notification sent');
    } catch (e) {
      debugPrint('❌ Error sending absence notification: $e');
    }
  }

  /// إرسال إشعار تعيين مشرف
  Future<void> sendSupervisorAssignmentNotification({
    required String supervisorId,
    required String busId,
    required String busNumber,
    String? supervisorName,
    String? busPlateNumber,
    String? adminName,
  }) async {
    try {
      final title = '👨‍✈️ تعيين جديد';
      final body = 'تم تعيينك للإشراف على الباص ${busPlateNumber ?? busNumber}';
      
      await _fcmService.sendNotificationToUser(
        userId: supervisorId,
        title: title,
        body: body,
        data: {
          'type': 'supervisor_assigned',
          'busId': busId,
          'busNumber': busNumber,
          if (busPlateNumber != null) 'busPlateNumber': busPlateNumber,
        },
        channelId: 'mybus_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.assignment,
        recipientId: supervisorId,
      );
      
      debugPrint('✅ Supervisor assignment notification sent');
    } catch (e) {
      debugPrint('❌ Error sending supervisor assignment notification: $e');
    }
  }

  /// الحصول على الإشعارات غير المقروءة
  Stream<List<NotificationModel>> getUnreadNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  /// إرسال إشعار ركوب طالب
  Future<void> notifyStudentBoardedWithSound({
    required String studentId,
    required String studentName,
    required String parentId,
    required String busNumber,
    String? supervisorId,
    String? location,
    String? busId,
  }) async {
    try {
      final title = '🚌 ركب $studentName الباص';
      final body = 'ركب الطالب الباص رقم $busNumber${location != null ? ' في $location' : ''}';
      
      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'student_boarded',
          'studentId': studentId,
          'studentName': studentName,
          'busNumber': busNumber,
          if (location != null) 'location': location,
          if (busId != null) 'busId': busId,
        },
        channelId: 'bus_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.studentBoarded,
        recipientId: parentId,
        studentName: studentName,
      );
      
      debugPrint('✅ Student boarded notification sent');
    } catch (e) {
      debugPrint('❌ Error sending student boarded notification: $e');
    }
  }

  /// إرسال إشعار نزول طالب
  Future<void> notifyStudentAlightedWithSound({
    required String studentId,
    required String studentName,
    required String parentId,
    required String busNumber,
    String? supervisorId,
    String? location,
    String? busId,
  }) async {
    try {
      final title = '🏠 نزل $studentName من الباص';
      final body = 'نزل الطالب من الباص رقم $busNumber${location != null ? ' في $location' : ''}';
      
      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'student_alighted',
          'studentId': studentId,
          'studentName': studentName,
          'busNumber': busNumber,
          if (location != null) 'location': location,
          if (busId != null) 'busId': busId,
        },
        channelId: 'bus_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.studentLeft,
        recipientId: parentId,
        studentName: studentName,
      );
      
      debugPrint('✅ Student alighted notification sent');
    } catch (e) {
      debugPrint('❌ Error sending student alighted notification: $e');
    }
  }

  /// إرسال طلب غياب مع صوت
  Future<void> notifyAbsenceRequestWithSound({
    required String studentId,
    required String studentName,
    required String parentId,
    required DateTime date,
    required String reason,
    String? supervisorId,
    String? parentName,
    String? busId,
    DateTime? absenceDate,
  }) async {
    try {
      final title = '🏠 طلب غياب جديد - $studentName';
      final body = 'أبلغ ولي أمر $studentName عن غياب يوم ${_formatDate(absenceDate ?? date)}\nالسبب: $reason';
      
      // إرسال للمشرف
      if (supervisorId != null && supervisorId.isNotEmpty) {
        await _fcmService.sendNotificationToUser(
          userId: supervisorId,
          title: title,
          body: body,
          data: {
            'type': 'absence_requested',
            'studentId': studentId,
            'studentName': studentName,
            'parentId': parentId,
            'date': (absenceDate ?? date).toIso8601String(),
            'reason': reason,
          },
          channelId: 'mybus_notifications',
        );
      }

      // إرسال للإدارة
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: title,
        body: body,
        data: {
          'type': 'absence_requested',
          'studentId': studentId,
          'studentName': studentName,
          'parentId': parentId,
          'date': (absenceDate ?? date).toIso8601String(),
          'reason': reason,
        },
        channelId: 'mybus_notifications',
      );
      
      debugPrint('✅ Absence request notification sent');
    } catch (e) {
      debugPrint('❌ Error sending absence request notification: $e');
    }
  }

  /// إرسال إشعار عام محسن
  Future<void> sendEnhancedGeneralNotification({
    required String title,
    required String body,
    required String targetUserId,
    Map<String, dynamic>? data,
    String? recipientId,
    bool? enableExternalDisplay,
  }) async {
    try {
      final userId = targetUserId;
      
      await _fcmService.sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data?.map((key, value) => MapEntry(key, value.toString())),
        channelId: 'mybus_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.general,
        recipientId: userId,
      );
      
      debugPrint('✅ Enhanced notification sent');
    } catch (e) {
      debugPrint('❌ Error sending enhanced notification: $e');
    }
  }

  /// إرسال إشعار عام
  Future<void> sendGeneralNotification({
    required String title,
    required String body,
    String? targetUserId,
    Map<String, dynamic>? data,
    String? recipientId,
  }) async {
    try {
      final userId = targetUserId ?? recipientId;
      if (userId == null) {
        debugPrint('⚠️ No target user ID provided');
        return;
      }
      
      await _fcmService.sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data?.map((key, value) => MapEntry(key, value.toString())),
        channelId: 'mybus_notifications',
      );

      await _saveNotification(
        title: title,
        body: body,
        type: NotificationType.general,
        recipientId: userId,
      );
      
      debugPrint('✅ General notification sent');
    } catch (e) {
      debugPrint('❌ Error sending general notification: $e');
    }
  }

  // Stub methods (للتوافق مع الاستدعاءات الموجودة)
  Future<void> notifyStudentUnassignmentWithSound({
    required String studentId,
    required String studentName,
    required String parentId,
    String? supervisorId,
    String? busId,
    String? excludeAdminId,
    String? adminId,
  }) async {
    debugPrint('📢 notifyStudentUnassignmentWithSound called');
  }

  Future<void> notifyNewComplaintWithSound({
    required String complaintId,
    required String parentId,
    required String title,
    required String description,
    String? parentName,
    String? subject,
    String? category,
  }) async {
    debugPrint('📢 notifyNewComplaintWithSound called');
  }

  Future<void> notifyEmergencyWithSound({
    required String title,
    required String message,
    required List<String> targetUserIds,
    String? busId,
    String? supervisorId,
    List<String>? parentIds,
  }) async {
    debugPrint('📢 notifyEmergencyWithSound called');
  }

  Future<void> notifyTripStatusUpdateWithSound({
    required String tripId,
    required String status,
    required String busNumber,
    required List<String> affectedUsers,
    String? busId,
    String? busRoute,
  }) async {
    debugPrint('📢 notifyTripStatusUpdateWithSound called');
  }

  Future<void> notifySupervisorEvaluationWithSound({
    required String supervisorId,
    required String parentName,
    required double rating,
    String? comment,
    String? supervisorName,
    String? parentId,
    String? studentName,
    double? averageRating,
  }) async {
    debugPrint('📢 notifySupervisorEvaluationWithSound called');
  }

  Future<void> sendTripStartedNotification({
    required String tripId,
    required String busNumber,
    required List<String> affectedUsers,
    String? recipientId,
    String? studentName,
    String? busRoute,
    DateTime? timestamp,
  }) async {
    debugPrint('📢 sendTripStartedNotification called');
  }

  /// حفظ إشعار في قاعدة البيانات
  Future<void> _saveNotification({
    required String title,
    required String body,
    required NotificationType type,
    required String recipientId,
    String? studentName,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'title': title,
        'body': body,
        'message': body,
        'type': type.toString().split('.').last,
        'recipientId': recipientId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        if (studentName != null) 'studentName': studentName,
      });
      debugPrint('✅ Notification saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving notification: $e');
    }
  }

  /// حفظ إشعار مع بيانات إضافية
  Future<void> _saveNotificationWithData({
    required String title,
    required String body,
    required NotificationType type,
    required String recipientId,
    Map<String, dynamic>? data,
    String? studentName,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'title': title,
        'body': body,
        'message': body,
        'type': type.toString().split('.').last,
        'recipientId': recipientId,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        if (studentName != null) 'studentName': studentName,
        if (data != null) 'data': data,
      });
      debugPrint('✅ Notification with data saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving notification with data: $e');
    }
  }

  /// تنسيق التاريخ
  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  /// الحصول على نص الحالة بالعربي
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'boarded':
      case 'onbus':
        return 'في الباص';
      case 'left':
      case 'alighted':
        return 'نزل من الباص';
      case 'absent':
        return 'غائب';
      case 'present':
        return 'حاضر';
      case 'waiting':
        return 'في الانتظار';
      default:
        return status;
    }
  }
}
