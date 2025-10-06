import 'package:flutter/material.dart';
import 'simple_fcm_service.dart';
import 'database_service.dart';

/// خدمة اختبار الإشعارات المحسنة
class NotificationTestService {
  static final NotificationTestService _instance = NotificationTestService._internal();
  factory NotificationTestService() => _instance;
  NotificationTestService._internal();

  final SimpleFCMService _fcmService = SimpleFCMService();
  final DatabaseService _databaseService = DatabaseService();

  /// اختبار إشعار تحديث حالة الطالب
  Future<void> testStudentStatusNotification() async {
    try {
      debugPrint('🧪 Testing student status update notification...');

      await _fcmService.sendStudentStatusUpdateNotification(
        studentId: 'test_student_123',
        studentName: 'أحمد محمد',
        parentId: 'test_parent_123',
        oldStatus: 'waiting',
        newStatus: 'boarded',
        supervisorName: 'المشرفة سارة',
        supervisorId: 'test_supervisor_123',
      );

      debugPrint('✅ Student status notification test completed');
    } catch (e) {
      debugPrint('❌ Student status notification test failed: $e');
    }
  }

  /// اختبار إشعار الاستبيان الجديد
  Future<void> testNewSurveyNotification() async {
    try {
      debugPrint('🧪 Testing new survey notification...');

      await _fcmService.sendNewSurveyNotification(
        surveyId: 'test_survey_123',
        surveyTitle: 'استبيان تجريبي',
        surveyDescription: 'هذا استبيان تجريبي لاختبار النظام',
        createdBy: 'test_admin_123',
        deadline: DateTime.now().add(const Duration(days: 7)),
        targetUserIds: ['test_parent_123', 'test_parent_456'],
      );

      debugPrint('✅ New survey notification test completed');
    } catch (e) {
      debugPrint('❌ New survey notification test failed: $e');
    }
  }

  /// اختبار إشعار إكمال الاستبيان
  Future<void> testSurveyCompletionNotification() async {
    try {
      debugPrint('🧪 Testing survey completion notification...');

      await _fcmService.sendSurveyCompletionNotification(
        surveyId: 'test_survey_123',
        surveyTitle: 'استبيان تجريبي',
        respondentName: 'محمد أحمد',
        respondentType: 'parent',
        respondentId: 'test_parent_123',
      );

      debugPrint('✅ Survey completion notification test completed');
    } catch (e) {
      debugPrint('❌ Survey completion notification test failed: $e');
    }
  }

  /// اختبار إشعار تذكير الاستبيان
  Future<void> testSurveyReminderNotification() async {
    try {
      debugPrint('🧪 Testing survey reminder notification...');

      await _fcmService.sendSurveyReminderNotification(
        surveyId: 'test_survey_123',
        surveyTitle: 'استبيان تجريبي',
        deadline: DateTime.now().add(const Duration(days: 2)),
        pendingUserIds: ['test_parent_123', 'test_parent_456'],
      );

      debugPrint('✅ Survey reminder notification test completed');
    } catch (e) {
      debugPrint('❌ Survey reminder notification test failed: $e');
    }
  }

  /// اختبار إشعار الطوارئ
  Future<void> testEmergencyNotification() async {
    try {
      debugPrint('🧪 Testing emergency notification...');

      await _fcmService.sendEmergencyNotification(
        title: '🚨 حالة طوارئ تجريبية',
        body: 'هذا اختبار لإشعار الطوارئ - لا تقلق، هذا مجرد اختبار',
        data: {
          'type': 'emergency_test',
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'emergency_test',
        },
      );

      debugPrint('✅ Emergency notification test completed');
    } catch (e) {
      debugPrint('❌ Emergency notification test failed: $e');
    }
  }

  /// اختبار شامل لجميع الإشعارات
  Future<void> runAllTests() async {
    try {
      debugPrint('🧪 Running comprehensive notification tests...');

      // تهيئة الخدمة
      await _fcmService.initialize();

      // تشغيل جميع الاختبارات
      await testStudentStatusNotification();
      await Future.delayed(const Duration(seconds: 2));

      await testNewSurveyNotification();
      await Future.delayed(const Duration(seconds: 2));

      await testSurveyCompletionNotification();
      await Future.delayed(const Duration(seconds: 2));

      await testSurveyReminderNotification();
      await Future.delayed(const Duration(seconds: 2));

      await testEmergencyNotification();

      debugPrint('✅ All notification tests completed successfully');
    } catch (e) {
      debugPrint('❌ Notification tests failed: $e');
    }
  }

  /// اختبار إرسال إشعار لمستخدم محدد
  Future<void> testSendToSpecificUser(String userId) async {
    try {
      debugPrint('🧪 Testing notification to specific user: $userId');

      await _fcmService.sendNotificationToUser(
        userId: userId,
        title: '🧪 اختبار إشعار',
        body: 'هذا إشعار تجريبي للتأكد من عمل النظام بشكل صحيح',
        data: {
          'type': 'test_notification',
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'test',
        },
        channelId: 'mybus_notifications',
      );

      debugPrint('✅ Specific user notification test completed');
    } catch (e) {
      debugPrint('❌ Specific user notification test failed: $e');
    }
  }

  /// اختبار إرسال إشعار لنوع مستخدم محدد
  Future<void> testSendToUserType(String userType) async {
    try {
      debugPrint('🧪 Testing notification to user type: $userType');

      await _fcmService.sendNotificationToUserType(
        userType: userType,
        title: '🧪 اختبار إشعار جماعي',
        body: 'هذا إشعار تجريبي لجميع مستخدمي $userType',
        data: {
          'type': 'test_bulk_notification',
          'userType': userType,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'test',
        },
        channelId: 'mybus_notifications',
      );

      debugPrint('✅ User type notification test completed');
    } catch (e) {
      debugPrint('❌ User type notification test failed: $e');
    }
  }

  /// اختبار حالة الخدمة
  Future<bool> testServiceHealth() async {
    try {
      debugPrint('🧪 Testing service health...');

      // التحقق من تهيئة الخدمة
      if (!_fcmService.isInitialized) {
        await _fcmService.initialize();
      }

      // التحقق من وجود Token
      final token = _fcmService.currentToken;
      if (token == null || token.isEmpty) {
        debugPrint('❌ No FCM token available');
        return false;
      }

      debugPrint('✅ Service health check passed');
      debugPrint('📱 FCM Token available: ${token.substring(0, 20)}...');
      
      return true;
    } catch (e) {
      debugPrint('❌ Service health check failed: $e');
      return false;
    }
  }

  /// إحصائيات الاختبار
  Future<Map<String, dynamic>> getTestStatistics() async {
    try {
      final isHealthy = await testServiceHealth();
      
      return {
        'serviceHealthy': isHealthy,
        'fcmInitialized': _fcmService.isInitialized,
        'hasToken': _fcmService.currentToken != null,
        'testTimestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting test statistics: $e');
      return {
        'serviceHealthy': false,
        'fcmInitialized': false,
        'hasToken': false,
        'error': e.toString(),
        'testTimestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}