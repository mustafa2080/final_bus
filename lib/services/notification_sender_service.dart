import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'simple_fcm_service.dart';

/// خدمة إرسال الإشعارات المستهدفة
/// تسهل إرسال الإشعارات لأنواع مختلفة من المستخدمين
class NotificationSenderService {
  static final NotificationSenderService _instance = NotificationSenderService._internal();
  factory NotificationSenderService() => _instance;
  NotificationSenderService._internal();

  final SimpleFCMService _fcmService = SimpleFCMService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// إرسال إشعار شكوى جديدة للأدمن
  Future<void> sendComplaintNotificationToAdmin({
    required String complaintId,
    required String parentName,
    required String studentName,
    required String complaintType,
  }) async {
    try {
      // إرسال إشعار FCM للأدمن
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: '📝 شكوى جديدة من ولي الأمر',
        body: 'قدم $parentName شكوى $complaintType للطالب $studentName',
        data: {
          'type': 'parent_complaint',
          'action': 'parent_action',
          'complaintId': complaintId,
          'parentName': parentName,
          'studentName': studentName,
          'complaintType': complaintType,
          'timestamp': DateTime.now().toIso8601String(),
        },
        channelId: 'admin_notifications',
      );
      
      debugPrint('✅ Complaint notification sent to admin');
    } catch (e) {
      debugPrint('❌ Error sending complaint notification: $e');
    }
  }

  /// إرسال إشعار غياب جديد للأدمن
  Future<void> sendAbsenceNotificationToAdmin({
    required String absenceId,
    required String parentName,
    required String studentName,
    required String absenceDate,
    required String reason,
    String? endDate,
  }) async {
    try {
      final dateText = endDate != null 
          ? 'من $absenceDate إلى $endDate'
          : 'يوم $absenceDate';
      
      // إرسال إشعار FCM للأدمن
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: '🚑 إشعار غياب جديد - $studentName',
        body: 'أبلغ $parentName عن غياب $studentName $dateText\nالسبب: $reason',
        data: {
          'type': 'parent_absence',
          'action': 'parent_action',
          'absenceId': absenceId,
          'parentName': parentName,
          'studentName': studentName,
          'absenceDate': absenceDate,
          'endDate': endDate ?? '',
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
        channelId: 'admin_notifications',
      );
      
      debugPrint('✅ Absence notification sent to admin');
    } catch (e) {
      debugPrint('❌ Error sending absence notification: $e');
    }
  }

  /// إرسال إشعار إضافة طالب جديد للأدمن
  Future<void> sendNewStudentNotificationToAdmin({
    required String parentName,
    required String studentName,
    required String studentGrade,
  }) async {
    try {
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: '👨‍🎓 طالب جديد تم إضافته',
        body: 'أضاف $parentName الطالب $studentName في الصف $studentGrade',
        data: {
          'type': 'parent_student',
          'action': 'parent_action',
          'parentName': parentName,
          'studentName': studentName,
          'studentGrade': studentGrade,
          'timestamp': DateTime.now().toIso8601String(),
        },
        channelId: 'admin_notifications',
      );
      
      debugPrint('✅ New student notification sent to admin');
    } catch (e) {
      debugPrint('❌ Error sending new student notification: $e');
    }
  }

  /// إرسال إشعار إتمام استبيان للأدمن
  Future<void> sendSurveyCompletionNotificationToAdmin({
    required String parentName,
    required String surveyTitle,
  }) async {
    try {
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: '📊 استبيان تم إكماله',
        body: 'أكمل $parentName استبيان "$surveyTitle"',
        data: {
          'type': 'parent_survey',
          'action': 'parent_action',
          'parentName': parentName,
          'surveyTitle': surveyTitle,
          'timestamp': DateTime.now().toIso8601String(),
        },
        channelId: 'admin_notifications',
      );
      
      debugPrint('✅ Survey completion notification sent to admin');
    } catch (e) {
      debugPrint('❌ Error sending survey completion notification: $e');
    }
  }

  /// إرسال إشعار استبيان جديد لأولياء الأمور
  Future<void> sendNewSurveyNotificationToParents({
    required String surveyId,
    required String surveyTitle,
    required String surveyDescription,
    required DateTime deadline,
  }) async {
    try {
      final deadlineStr = '${deadline.day}/${deadline.month}/${deadline.year}';
      
      await _fcmService.sendNotificationToUserType(
        userType: 'parent',
        title: '📊 استبيان جديد متاح',
        body: 'استبيان جديد: $surveyTitle\nآخر موعد للإجابة: $deadlineStr',
        data: {
          'type': 'new_survey',
          'action': 'admin_action',
          'surveyId': surveyId,
          'surveyTitle': surveyTitle,
          'surveyDescription': surveyDescription,
          'deadline': deadline.toIso8601String(),
          'timestamp': DateTime.now().toIso8601String(),
        },
        channelId: 'parent_notifications',
      );
      
      debugPrint('✅ New survey notification sent to all parents');
    } catch (e) {
      debugPrint('❌ Error sending new survey notification: $e');
    }
  }

  /// إرسال إشعار تسجيل مستخدم جديد للأدمن
  Future<void> sendNewUserNotificationToAdmin({
    required String userName,
    required String userEmail,
    required String userType,
  }) async {
    try {
      await _fcmService.sendNotificationToUserType(
        userType: 'admin',
        title: '🎉 مستخدم جديد انضم',
        body: 'سجل $userName ($userType) حساب جديد',
        data: {
          'type': 'new_user_registration',
          'action': 'parent_action',
          'userName': userName,
          'userEmail': userEmail,
          'userType': userType,
          'timestamp': DateTime.now().toIso8601String(),
        },
        channelId: 'admin_notifications',
      );
      
      debugPrint('✅ New user notification sent to admin');
    } catch (e) {
      debugPrint('❌ Error sending new user notification: $e');
    }
  }

  /// إرسال إشعار تغيير حالة الطالب لولي الأمر
  Future<void> sendStudentStatusNotificationToParent({
    required String parentId,
    required String studentName,
    required String status,
    required String busNumber,
    String? location,
  }) async {
    try {
      String body;
      String channelId = 'student_notifications';
      
      switch (status.toLowerCase()) {
        case 'onbus':
          body = 'ركب $studentName الحافلة رقم $busNumber';
          if (location != null) body += ' من $location';
          break;
        case 'home':
          body = 'وصل $studentName إلى المنزل من الحافلة رقم $busNumber';
          if (location != null) body += ' في $location';
          break;
        case 'atschool':
          body = 'وصل $studentName إلى المدرسة بالحافلة رقم $busNumber';
          if (location != null) body += ' في $location';
          break;
        case 'absent':
          body = '$studentName غائب اليوم';
          break;
        default:
          body = 'تحديث حالة $studentName: $status';
      }

      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: 'تحديث حالة الطالب',
        body: body,
        data: {
          'type': 'student_status',
          'studentName': studentName,
          'status': status,
          'busNumber': busNumber,
          'location': location ?? '',
        },
        channelId: channelId,
      );
      
      debugPrint('✅ Student status notification sent to parent');
    } catch (e) {
      debugPrint('❌ Error sending student status notification: $e');
    }
  }

  /// إرسال إشعار رسالة إدارية
  Future<void> sendAdminMessage({
    required String title,
    required String message,
    String? targetUserType, // null = جميع المستخدمين
    String? targetUserId, // إرسال لمستخدم محدد
  }) async {
    try {
      if (targetUserId != null) {
        // إرسال لمستخدم محدد
        await _fcmService.sendNotificationToUser(
          userId: targetUserId,
          title: title,
          body: message,
          data: {
            'type': 'admin_message',
            'title': title,
            'message': message,
          },
          channelId: 'mybus_notifications',
        );
      } else if (targetUserType != null) {
        // إرسال لنوع مستخدمين محدد
        await _fcmService.sendNotificationToUserType(
          userType: targetUserType,
          title: title,
          body: message,
          data: {
            'type': 'admin_message',
            'title': title,
            'message': message,
          },
          channelId: 'mybus_notifications',
        );
      } else {
        // إرسال لجميع المستخدمين
        await Future.wait([
          _fcmService.sendNotificationToUserType(
            userType: 'admin',
            title: title,
            body: message,
            data: {
              'type': 'admin_message',
              'title': title,
              'message': message,
            },
            channelId: 'mybus_notifications',
          ),
          _fcmService.sendNotificationToUserType(
            userType: 'supervisor',
            title: title,
            body: message,
            data: {
              'type': 'admin_message',
              'title': title,
              'message': message,
            },
            channelId: 'mybus_notifications',
          ),
          _fcmService.sendNotificationToUserType(
            userType: 'parent',
            title: title,
            body: message,
            data: {
              'type': 'admin_message',
              'title': title,
              'message': message,
            },
            channelId: 'mybus_notifications',
          ),
        ]);
      }
      
      debugPrint('✅ Admin message sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending admin message: $e');
    }
  }

  /// إرسال إشعار بداية/انتهاء الرحلة للمشرف
  Future<void> sendTripNotificationToSupervisor({
    required String supervisorId,
    required String busNumber,
    required String routeName,
    required String status, // 'started' أو 'completed'
    String? estimatedTime,
  }) async {
    try {
      String title;
      String body;
      
      if (status == 'started') {
        title = 'بداية الرحلة';
        body = 'بدأت رحلة الحافلة رقم $busNumber - $routeName';
        if (estimatedTime != null) body += '\nالوقت المتوقع للوصول: $estimatedTime';
      } else {
        title = 'انتهاء الرحلة';
        body = 'انتهت رحلة الحافلة رقم $busNumber - $routeName بنجاح';
      }

      await _fcmService.sendNotificationToUser(
        userId: supervisorId,
        title: title,
        body: body,
        data: {
          'type': 'trip_status',
          'busNumber': busNumber,
          'routeName': routeName,
          'status': status,
          'estimatedTime': estimatedTime ?? '',
        },
        channelId: 'bus_notifications',
      );
      
      debugPrint('✅ Trip notification sent to supervisor');
    } catch (e) {
      debugPrint('❌ Error sending trip notification: $e');
    }
  }

  /// إرسال إشعار طوارئ
  Future<void> sendEmergencyNotification({
    required String title,
    required String message,
    String? busNumber,
    String? location,
  }) async {
    try {
      String body = message;
      if (busNumber != null) body += '\nالحافلة: $busNumber';
      if (location != null) body += '\nالموقع: $location';

      await _fcmService.sendEmergencyNotification(
        title: title,
        body: body,
        data: {
          'type': 'emergency',
          'title': title,
          'message': message,
          'busNumber': busNumber ?? '',
          'location': location ?? '',
        },
      );
      
      debugPrint('✅ Emergency notification sent to all users');
    } catch (e) {
      debugPrint('❌ Error sending emergency notification: $e');
    }
  }

  /// إرسال إشعار تأخير الحافلة لأولياء الأمور
  Future<void> sendBusDelayNotificationToParents({
    required String busNumber,
    required String routeName,
    required int delayMinutes,
    String? reason,
  }) async {
    try {
      // الحصول على أولياء الأمور المرتبطين بهذه الحافلة
      final studentsQuery = await _firestore
          .collection('students')
          .where('busNumber', isEqualTo: busNumber)
          .get();

      final parentIds = <String>{};
      for (final doc in studentsQuery.docs) {
        final studentData = doc.data();
        final parentId = studentData['parentId'] as String?;
        if (parentId != null) {
          parentIds.add(parentId);
        }
      }

      String body = 'تأخرت الحافلة رقم $busNumber - $routeName لمدة $delayMinutes دقيقة';
      if (reason != null) body += '\nالسبب: $reason';

      // إرسال الإشعار لكل ولي أمر
      for (final parentId in parentIds) {
        await _fcmService.sendNotificationToUser(
          userId: parentId,
          title: 'تأخير الحافلة',
          body: body,
          data: {
            'type': 'bus_delay',
            'busNumber': busNumber,
            'routeName': routeName,
            'delayMinutes': delayMinutes.toString(),
            'reason': reason ?? '',
          },
          channelId: 'bus_notifications',
        );
      }
      
      debugPrint('✅ Bus delay notification sent to ${parentIds.length} parents');
    } catch (e) {
      debugPrint('❌ Error sending bus delay notification: $e');
    }
  }

  /// إرسال إشعار تقييم سلوك الطالب لولي الأمر
  Future<void> sendBehaviorNotificationToParent({
    required String parentId,
    required String studentName,
    required String behaviorType,
    required String description,
    String? supervisorName,
  }) async {
    try {
      String title;
      String channelId = 'student_notifications';
      
      switch (behaviorType.toLowerCase()) {
        case 'positive':
          title = 'تقييم إيجابي';
          break;
        case 'negative':
          title = 'تقييم سلوكي';
          channelId = 'emergency_notifications'; // للتنبيهات المهمة
          break;
        default:
          title = 'تقييم سلوك الطالب';
      }

      String body = 'تقييم سلوك $studentName: $description';
      if (supervisorName != null) body += '\nبواسطة: $supervisorName';

      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'student_behavior',
          'studentName': studentName,
          'behaviorType': behaviorType,
          'description': description,
          'supervisorName': supervisorName ?? '',
        },
        channelId: channelId,
      );
      
      debugPrint('✅ Behavior notification sent to parent');
    } catch (e) {
      debugPrint('❌ Error sending behavior notification: $e');
    }
  }

  /// إرسال إشعار لولي الأمر
  Future<void> sendNotificationToParent({
    required String parentId,
    required String title,
    required String message,
    String? studentName,
    String? studentId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      debugPrint('📧 Sending notification to parent: $parentId');
      
      await _fcmService.sendNotificationToUser(
        userId: parentId,
        title: title,
        body: message,
        data: {
          'type': 'parent_notification',
          'parentId': parentId,
          'studentName': studentName ?? '',
          'studentId': studentId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          ...?additionalData,
        },
        channelId: 'parent_notifications',
      );
      
      debugPrint('✅ Notification sent to parent successfully');
    } catch (e) {
      debugPrint('❌ Error sending notification to parent: $e');
      throw Exception('فشل في إرسال الإشعار لولي الأمر: $e');
    }
  }

  /// إرسال إشعار للمشرف
  Future<void> sendNotificationToSupervisor({
    required String supervisorId,
    required String title,
    required String message,
    String? busId,
    String? busRoute,
    String? studentName,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      debugPrint('👨‍🏫 Sending notification to supervisor: $supervisorId');
      
      await _fcmService.sendNotificationToUser(
        userId: supervisorId,
        title: title,
        body: message,
        data: {
          'type': 'supervisor_notification',
          'supervisorId': supervisorId,
          'busId': busId ?? '',
          'busRoute': busRoute ?? '',
          'studentName': studentName ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          ...?additionalData,
        },
        channelId: 'supervisor_notifications',
      );
      
      debugPrint('✅ Notification sent to supervisor successfully');
    } catch (e) {
      debugPrint('❌ Error sending notification to supervisor: $e');
      throw Exception('فشل في إرسال الإشعار للمشرف: $e');
    }
  }
}
