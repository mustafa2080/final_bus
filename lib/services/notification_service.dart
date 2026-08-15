import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import 'simple_fcm_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SimpleFCMService _fcmService = SimpleFCMService();
  
  bool _isInitialized = false;

  /// إشعار ترحيبي لولي أمر جديد عند التسجيل
  Future<void> sendWelcomeNotification(String userId, String userName) async {
    try {
      await _fcmService.sendNotificationToUser(
        userId: userId,
        title: 'مرحباً بك في كيدز باص',
        body: 'أهلاً وسهلاً $userName، تم إنشاء حسابك بنجاح',
        data: {
          'type': 'welcome',
          'userName': userName,
        },
        channelId: 'mybus_notifications',
      );
      debugPrint('✅ Welcome notification sent to $userName');
    } catch (e) {
      debugPrint('❌ Error sending welcome notification: $e');
    }
  }

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

  /// إشعار تحديث بيانات الطالب لولي الأمر والمشرف (باستثناء الإدمن الذي حدّث)
  Future<void> notifyStudentDataUpdate({
    required String studentId,
    required String studentName,
    required String parentId,
    required String busId,
    required Map<String, dynamic> updatedFields,
    required String adminName,
    String? adminId,
  }) async {
    try {
      final updatedFieldsText = _formatUpdatedFields(updatedFields);
      final title = '✏️ تحديث بيانات الطالب';
      final body = 'تم تحديث بيانات الطالب $studentName من قبل الإدارة ($adminName)\n$updatedFieldsText';

      // إشعار ولي الأمر (باستثناء لو هو نفسه من قام بالتحديث)
      if (parentId.isNotEmpty && parentId != adminId) {
        await _fcmService.sendNotificationToUser(
          userId: parentId,
          title: title,
          body: body,
          data: {
            'type': 'student_data_update',
            'studentId': studentId,
            'studentName': studentName,
            'updatedFields': jsonEncode(updatedFields),
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
      }

      // إشعار مشرف الباص (إن وجد وليس نفس الإدمن)
      if (busId.isNotEmpty) {
        try {
          final busDoc = await _firestore.collection('buses').doc(busId).get();
          final supervisorId = busDoc.data()?['supervisorId'] as String?;
          if (supervisorId != null && supervisorId.isNotEmpty && supervisorId != adminId) {
            await _fcmService.sendNotificationToUser(
              userId: supervisorId,
              title: title,
              body: body,
              data: {
                'type': 'student_data_update',
                'studentId': studentId,
                'studentName': studentName,
                'busId': busId,
                'updatedFields': jsonEncode(updatedFields),
              },
              channelId: 'student_notifications',
            );
          }
        } catch (e) {
          debugPrint('❌ Error fetching bus supervisor for update notification: $e');
        }
      }

      debugPrint('✅ Student data update notification sent');
    } catch (e) {
      debugPrint('❌ Error sending student data update notification: $e');
    }
  }

  /// إشعار تفعيل الحافلة (للمشرف المعين)
  Future<void> notifyBusActivation({
    required String busId,
    required String busPlateNumber,
    required String driverName,
    required String adminName,
    String? adminId,
  }) async {
    try {
      final supervisorId = await _getActiveSupervisorForBus(busId);
      if (supervisorId != null && supervisorId.isNotEmpty && supervisorId != adminId) {
        await _fcmService.sendNotificationToUser(
          userId: supervisorId,
          title: '🚌 تم تفعيل الحافلة',
          body: 'تم تفعيل الحافلة $busPlateNumber\nالسائق: $driverName\nيمكنك الآن بدء الرحلات',
          data: {
            'type': 'bus_activated',
            'busId': busId,
            'busPlateNumber': busPlateNumber,
            'driverName': driverName,
          },
          channelId: 'bus_notifications',
        );
      }
      debugPrint('✅ Bus activation notification sent for: $busPlateNumber');
    } catch (e) {
      debugPrint('❌ Error sending bus activation notification: $e');
    }
  }

  /// إشعار إيقاف الحافلة (للمشرف وأولياء أمور الطلاب المسكنين)
  Future<void> notifyBusDeactivation({
    required String busId,
    required String busPlateNumber,
    required String driverName,
    required String adminName,
    String? adminId,
  }) async {
    try {
      final supervisorId = await _getActiveSupervisorForBus(busId);
      if (supervisorId != null && supervisorId.isNotEmpty && supervisorId != adminId) {
        await _fcmService.sendNotificationToUser(
          userId: supervisorId,
          title: '⚠️ تم إيقاف الحافلة',
          body: 'تم إيقاف الحافلة $busPlateNumber (السائق: $driverName) من قبل $adminName\n\nيرجى التوقف عن العمليات والرحلات',
          data: {
            'type': 'bus_deactivated',
            'busId': busId,
            'busPlateNumber': busPlateNumber,
            'driverName': driverName,
            'deactivatedBy': adminName,
          },
          channelId: 'bus_notifications',
        );
      }

      final studentsSnapshot = await _firestore
          .collection('students')
          .where('busId', isEqualTo: busId)
          .where('isActive', isEqualTo: true)
          .get();

      for (final studentDoc in studentsSnapshot.docs) {
        final studentData = studentDoc.data();
        final parentId = studentData['parentId'] as String?;
        final studentName = studentData['name'] ?? 'الطالب';

        if (parentId != null && parentId.isNotEmpty && parentId != adminId) {
          await _fcmService.sendNotificationToUser(
            userId: parentId,
            title: '⚠️ تم إيقاف حافلة طفلك',
            body: 'تم إيقاف الحافلة $busPlateNumber الخاصة بـ $studentName مؤقتاً\n\nيرجى ترتيب وسيلة نقل بديلة',
            data: {
              'type': 'bus_deactivated',
              'busId': busId,
              'busPlateNumber': busPlateNumber,
              'studentName': studentName,
              'deactivatedBy': adminName,
            },
            channelId: 'bus_notifications',
          );
        }
      }

      debugPrint('✅ Bus deactivation notifications sent for: $busPlateNumber');
    } catch (e) {
      debugPrint('❌ Error sending bus deactivation notification: $e');
    }
  }

  /// جلب معرف المشرف النشط المعين على الحافلة
  Future<String?> _getActiveSupervisorForBus(String busId) async {
    try {
      final busDoc = await _firestore.collection('buses').doc(busId).get();
      final supervisorId = busDoc.data()?['supervisorId'] as String?;
      if (supervisorId != null && supervisorId.isNotEmpty) return supervisorId;

      // fallback: البحث في تعيينات المشرفين النشطة إن وجدت
      final assignmentQuery = await _firestore
          .collection('supervisor_assignments')
          .where('busId', isEqualTo: busId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (assignmentQuery.docs.isNotEmpty) {
        return assignmentQuery.docs.first.data()['supervisorId'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting active supervisor for bus: $e');
      return null;
    }
  }

  /// تنسيق الحقول المُحدّثة كنص عربي مقروء
  String _formatUpdatedFields(Map<String, dynamic> updatedFields) {
    final buffer = StringBuffer();
    updatedFields.forEach((key, value) {
      if (value is Map && value.containsKey('old') && value.containsKey('new')) {
        buffer.writeln('$key: ${value['old']} ← ${value['new']}');
      } else {
        buffer.writeln('$key: $value');
      }
    });
    return buffer.toString().trim();
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
      rethrow;
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

      await _saveNotificationWithData(
        title: title,
        body: body,
        type: NotificationType.studentBoarded,
        recipientId: parentId,
        studentName: studentName,
        data: {
          'studentId': studentId,
          'busNumber': busNumber,
          if (location != null) 'location': location,
          if (busId != null) 'busId': busId,
        },
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

      await _saveNotificationWithData(
        title: title,
        body: body,
        type: NotificationType.studentLeft,
        data: {
          'studentId': studentId,
          'busNumber': busNumber,
          if (location != null) 'location': location,
          if (busId != null) 'busId': busId,
        },
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

  /// إشعار بإلغاء تسكين طالب من الباص (لولي الأمر + الإدارة)
  Future<void> notifyStudentUnassignmentWithSound({
    required String studentId,
    required String studentName,
    required String parentId,
    String? supervisorId,
    String? busId,
    String? excludeAdminId,
    String? adminId,
  }) async {
    try {
      final title = '🚫 تم إلغاء تسكين $studentName';
      final body = 'تم إلغاء تسكين الطالب $studentName من الباص';

      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'student_unassigned',
          'studentId': studentId,
          'studentName': studentName,
          if (busId != null) 'busId': busId,
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

      // إشعار الإدارة (باستثناء من قام بالإلغاء إن وجد)
      await _fcmService.sendNotificationToUserTypeExcluding(
        userType: 'admin',
        excludeUserId: excludeAdminId ?? adminId,
        title: title,
        body: body,
        data: {
          'type': 'student_unassigned',
          'studentId': studentId,
          'studentName': studentName,
          'parentId': parentId,
          if (busId != null) 'busId': busId,
        },
        channelId: 'student_notifications',
      );

      debugPrint('✅ Student unassignment notification sent');
    } catch (e) {
      debugPrint('❌ Error sending student unassignment notification: $e');
    }
  }

  /// إشعار شكوى جديدة للإدارة (مع حفظ محلي)
  Future<void> notifyNewComplaintWithSound({
    required String complaintId,
    required String parentId,
    required String title,
    required String description,
    String? parentName,
    String? subject,
    String? category,
  }) async {
    try {
      final notifTitle = '📝 شكوى جديدة${parentName != null ? ' من $parentName' : ''}';
      final body = '${subject ?? title}\n$description';

      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: notifTitle,
        body: body,
        data: {
          'type': 'new_complaint',
          'complaintId': complaintId,
          'parentId': parentId,
          'title': title,
          if (subject != null) 'subject': subject,
          if (category != null) 'category': category,
        },
        channelId: 'mybus_notifications',
      );

      debugPrint('✅ New complaint notification sent to admins');
    } catch (e) {
      debugPrint('❌ Error sending new complaint notification: $e');
    }
  }

  /// إشعار طوارئ لجميع المستخدمين المستهدفين (بما فيهم أولياء الأمور/المشرفين/الإدارة)
  Future<void> notifyEmergencyWithSound({
    required String title,
    required String message,
    required List<String> targetUserIds,
    String? busId,
    String? supervisorId,
    List<String>? parentIds,
  }) async {
    try {
      final ids = <String>{...targetUserIds, ...?parentIds}.toList();
      final emergencyTitle = '🚨 $title';

      if (ids.isNotEmpty) {
        await _fcmService.sendNotificationToUsers(
          userIds: ids,
          title: emergencyTitle,
          body: message,
          data: {
            'type': 'emergency',
            if (busId != null) 'busId': busId,
            if (supervisorId != null) 'supervisorId': supervisorId,
          },
          channelId: 'emergency_notifications',
        );
      }

      // نضمن وصول تنبيه الطوارئ للإدارة دائماً
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: emergencyTitle,
        body: message,
        data: {
          'type': 'emergency',
          if (busId != null) 'busId': busId,
          if (supervisorId != null) 'supervisorId': supervisorId,
        },
        channelId: 'emergency_notifications',
      );

      debugPrint('✅ Emergency notification sent to ${ids.length} users + admins');
    } catch (e) {
      debugPrint('❌ Error sending emergency notification: $e');
    }
  }

  /// إشعار تحديث حالة الرحلة (بدء/انتهاء/تأخير) للمستخدمين المتأثرين
  Future<void> notifyTripStatusUpdateWithSound({
    required String tripId,
    required String status,
    required String busNumber,
    required List<String> affectedUsers,
    String? busId,
    String? busRoute,
  }) async {
    try {
      final statusText = _getTripStatusText(status);
      final title = '🚌 تحديث حالة الرحلة';
      final body = 'الباص رقم $busNumber${busRoute != null ? ' - خط $busRoute' : ''}: $statusText';

      if (affectedUsers.isNotEmpty) {
        await _fcmService.sendNotificationToUsers(
          userIds: affectedUsers,
          title: title,
          body: body,
          data: {
            'type': 'trip_status_update',
            'tripId': tripId,
            'status': status,
            'busNumber': busNumber,
            if (busId != null) 'busId': busId,
            if (busRoute != null) 'busRoute': busRoute,
          },
          channelId: 'bus_notifications',
        );
      }

      debugPrint('✅ Trip status update notification sent to ${affectedUsers.length} users');
    } catch (e) {
      debugPrint('❌ Error sending trip status update notification: $e');
    }
  }

  /// إشعار الإدارة بتقييم جديد لمشرف
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
    try {
      final title = '⭐ تقييم جديد للمشرف${supervisorName != null ? ' $supervisorName' : ''}';
      final body = 'قيّم ولي الأمر $parentName المشرف بتقييم $rating/5'
          '${comment != null && comment.isNotEmpty ? '\nتعليق: $comment' : ''}';

      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: title,
        body: body,
        data: {
          'type': 'supervisor_evaluation',
          'supervisorId': supervisorId,
          'rating': rating.toString(),
          if (supervisorName != null) 'supervisorName': supervisorName,
          if (parentId != null) 'parentId': parentId,
          if (studentName != null) 'studentName': studentName,
          if (averageRating != null) 'averageRating': averageRating.toString(),
        },
        channelId: 'mybus_notifications',
      );

      debugPrint('✅ Supervisor evaluation notification sent to admins');
    } catch (e) {
      debugPrint('❌ Error sending supervisor evaluation notification: $e');
    }
  }

  /// إشعار بدء الرحلة لأولياء الأمور المتأثرين
  Future<void> sendTripStartedNotification({
    required String tripId,
    required String busNumber,
    required List<String> affectedUsers,
    String? recipientId,
    String? studentName,
    String? busRoute,
    DateTime? timestamp,
  }) async {
    try {
      final title = '🚌 بدأت الرحلة';
      final body = 'بدأت رحلة الباص رقم $busNumber${busRoute != null ? ' - خط $busRoute' : ''}';

      final ids = <String>{...affectedUsers, if (recipientId != null) recipientId}.toList();
      if (ids.isNotEmpty) {
        await _fcmService.sendNotificationToUsers(
          userIds: ids,
          title: title,
          body: body,
          data: {
            'type': 'trip_started',
            'tripId': tripId,
            'busNumber': busNumber,
            if (busRoute != null) 'busRoute': busRoute,
            if (studentName != null) 'studentName': studentName,
          },
          channelId: 'bus_notifications',
        );
      }

      debugPrint('✅ Trip started notification sent to ${ids.length} users');
    } catch (e) {
      debugPrint('❌ Error sending trip started notification: $e');
    }
  }

  /// نص حالة الرحلة بالعربي
  String _getTripStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'started':
        return 'بدأت الرحلة';
      case 'completed':
      case 'ended':
        return 'انتهت الرحلة';
      case 'delayed':
        return 'تأخرت الرحلة';
      case 'cancelled':
        return 'ألغيت الرحلة';
      default:
        return status;
    }
  }

  /// حفظ إشعار في قاعدة البيانات
  Future<void> _saveNotification({
    required String title,
    required String body,
    required NotificationType type,
    required String recipientId,
    String? studentName,
  }) async {
    // لا نحفظ من التطبيق: SimpleFCMService يضيف الطلب إلى fcm_queue،
    // وCloud Function تنشئ السجل الواحد بعد نجاح الإرسال. الحفظ هنا كان
    // ينتج نسخة مطابقة في شاشة ولي الأمر.
    debugPrint('ℹ️ Notification record will be created by notification delivery');
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
    // نفس المسار الموحد أعلاه؛ البيانات تُرسل ضمن fcm_queue وتحفظها الدالة
    // السحابية في سجل الإشعار النهائي.
    debugPrint('ℹ️ Notification record with data will be created by notification delivery');
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
