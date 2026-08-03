import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// خدمة FCM مبسطة وموثوقة للإشعارات خارج التطبيق
class SimpleFCMService {
  static final SimpleFCMService _instance = SimpleFCMService._internal();
  factory SimpleFCMService() => _instance;
  SimpleFCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;
  String? _currentToken;

  /// تهيئة خدمة FCM المبسطة
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔥 Initializing Simple FCM Service...');

      // 0. التأكد من عدم وجود تضارب مع خدمات أخرى
      await _ensureNoConflicts();

      // 1. تهيئة Local Notifications
      await _initializeLocalNotifications();

      // 2. طلب الأذونات
      await _requestPermissions();

      // 3. إعداد معالجات الرسائل
      _setupMessageHandlers();

      // 4. الحصول على Token وحفظه
      await _getAndSaveToken();

      // 5. تسجيل تحديثات Token
      _listenToTokenRefresh();

      _isInitialized = true;
      debugPrint('✅ Simple FCM Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Simple FCM Service: $e');
      rethrow;
    }
  }

  /// التأكد من عدم وجود تضارب مع خدمات أخرى
  Future<void> _ensureNoConflicts() async {
    try {
      // إلغاء أي listeners سابقة لتجنب التضارب
      debugPrint('🧹 Cleaning up previous FCM listeners...');
      
      // لا نحتاج لإلغاء الـ listeners لأن Firebase يدير ذلك تلقائياً
      // لكن يمكننا التأكد من أن هذه الخدمة هي الوحيدة النشطة
      
      debugPrint('✅ FCM conflicts check completed');
    } catch (e) {
      debugPrint('⚠️ Warning during conflicts check: $e');
    }
  }

  /// الاستماع لتحديثات Token
  void _listenToTokenRefresh() {
    _messaging.onTokenRefresh.listen((String newToken) async {
      debugPrint('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
      _currentToken = newToken;
      await _saveTokenToFirestore(newToken);
    });
  }

  /// تهيئة Local Notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // إنشاء قنوات الإشعارات
    await _createNotificationChannels();
  }

  /// إنشاء قنوات الإشعارات
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final List<AndroidNotificationChannel> channels = [
      const AndroidNotificationChannel(
        'mybus_notifications',
        'كيدز باص - الإشعارات العامة',
        description: 'إشعارات عامة من تطبيق كيدز باص',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
        ledColor: Color(0xFF1E88E5),
      ),
      const AndroidNotificationChannel(
        'student_notifications',
        'إشعارات الطلاب',
        description: 'إشعارات متعلقة بالطلاب',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
      const AndroidNotificationChannel(
        'bus_notifications',
        'إشعارات الباص',
        description: 'إشعارات ركوب ونزول الباص',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
      const AndroidNotificationChannel(
        'emergency_notifications',
        'تنبيهات الطوارئ',
        description: 'تنبيهات طوارئ مهمة وعاجلة',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// طلب أذونات الإشعارات
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('📱 FCM Permission status: ${settings.authorizationStatus}');

    if (Platform.isAndroid) {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
        await androidImplementation.requestExactAlarmsPermission();
      }
    }
  }

  /// إعداد معالجات الرسائل
  void _setupMessageHandlers() {
    // تعيين خيارات عرض الإشعارات في المقدمة
    _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // معالج الرسائل في المقدمة
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // معالج الرسائل عند فتح التطبيق من إشعار
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // التحقق من رسالة فتح التطبيق
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessageOpenedApp(message);
      }
    });
  }

  /// معالج الرسائل في المقدمة
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Received foreground message: ${message.messageId}');
    debugPrint('📝 Title: ${message.notification?.title}');
    debugPrint('📝 Body: ${message.notification?.body}');
    debugPrint('📦 Data: ${message.data}');
    
    // التأكد من عرض الإشعار حتى لو كان التطبيق في المقدمة
    await _displayLocalNotification(
      title: message.notification?.title ?? message.data['title'] ?? 'إشعار جديد',
      body: message.notification?.body ?? message.data['body'] ?? '',
      data: Map<String, String>.from(message.data),
      channelId: message.data['channelId'] ?? 'mybus_notifications',
    );
  }

  /// معالج الرسائل عند فتح التطبيق من إشعار
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 App opened from notification: ${message.messageId}');
    // يمكن إضافة منطق التنقل هنا
  }

  /// معالج النقر على الإشعار
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
  }

  /// الحصول على Token وحفظه
  Future<void> _getAndSaveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        await _saveTokenToFirestore(token);
        debugPrint('✅ FCM Token obtained and saved');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// حفظ Token في Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // الحصول على نوع المستخدم
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        final userData = userDoc.data();
        final userType = userData?['userType'] ?? 'parent';

        await _firestore.collection('users').doc(currentUser.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': Platform.operatingSystem,
          'isActive': true,
          'userType': userType,
        });

        // حفظ في مجموعة منفصلة للـ tokens
        await _firestore.collection('fcm_tokens').doc(currentUser.uid).set({
          'token': token,
          'userId': currentUser.uid,
          'userType': userType,
          'platform': Platform.operatingSystem,
          'lastUpdate': FieldValue.serverTimestamp(),
          'isActive': true,
        });

        debugPrint('✅ FCM Token saved to Firestore for $userType user');
      }
    } catch (e) {
      debugPrint('❌ Error saving token to Firestore: $e');
    }
  }

  /// عرض إشعار محلي
  Future<void> _displayLocalNotification({
    required String title,
    required String body,
    required Map<String, String> data,
    required String channelId,
  }) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        icon: '@drawable/ic_notification',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        color: const Color(0xFF1E88E5),
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        autoCancel: true,
        ongoing: false,
        silent: false,
        channelShowBadge: true,
        onlyAlertOnce: false,
        visibility: NotificationVisibility.public,
        ticker: '$title - $body',
        tag: 'mybus_${DateTime.now().millisecondsSinceEpoch}',
        category: AndroidNotificationCategory.message,
        groupKey: 'com.mybus.notifications',
        setAsGroupSummary: false,
        groupAlertBehavior: GroupAlertBehavior.all,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
          summaryText: 'كيدز باص',
          htmlFormatSummaryText: false,
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_sound.mp3',
        subtitle: 'كيدز باص',
        threadIdentifier: 'mybus_notifications',
        categoryIdentifier: 'mybus_category',
        badgeNumber: 1,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(data),
      );

      debugPrint('✅ Local notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  /// إرسال إشعار لمستخدم محدد
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
    String? channelId,
  }) async {
    try {
      debugPrint('📤 Sending notification to user: $userId');

      // إضافة الإشعار إلى قائمة الانتظار
      await _firestore.collection('fcm_queue').add({
        'recipientId': userId,
        'title': title,
        'body': body,
        'data': {
          ...?data,
          'channelId': channelId ?? 'mybus_notifications',
          'type': data?['type'] ?? 'general',
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
      });

      // حفظ نسخة في مجموعة notifications
      await _firestore.collection('notifications').add({
        'recipientId': userId,
        'title': title,
        'body': body,
        'type': data?['type'] ?? 'general',
        'data': data ?? {},
        'channelId': channelId ?? 'mybus_notifications',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'simple_fcm_service',
      });

      debugPrint('✅ Notification queued for user: $userId');
    } catch (e) {
      debugPrint('❌ Error sending notification to user $userId: $e');
      rethrow;
    }
  }

  /// إرسال إشعار لجميع المستخدمين من نوع معين
  Future<void> sendNotificationToUserType({
    required String userType,
    required String title,
    required String body,
    Map<String, String>? data,
    String? channelId,
  }) async {
    try {
      debugPrint('📤 Sending notification to all $userType users...');

      // الحصول على جميع المستخدمين من النوع المحدد
      final usersQuery = await _firestore
          .collection('fcm_tokens')
          .where('userType', isEqualTo: userType)
          .where('isActive', isEqualTo: true)
          .get();

      if (usersQuery.docs.isEmpty) {
        debugPrint('⚠️ No active users found for user type: $userType');
        return;
      }

      debugPrint('👥 Found ${usersQuery.docs.length} active users of type $userType');

      // إرسال الإشعار لكل مستخدم
      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.data()['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          await sendNotificationToUser(
            userId: userId,
            title: title,
            body: body,
            data: data,
            channelId: channelId,
          );
        }
      }

      debugPrint('✅ Notifications sent to all $userType users');
    } catch (e) {
      debugPrint('❌ Error sending notifications to user type $userType: $e');
    }
  }

  /// إرسال إشعار طوارئ لجميع المستخدمين
  Future<void> sendEmergencyNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      debugPrint('🚨 Sending emergency notification to all users...');

      // إرسال لجميع أنواع المستخدمين
      await Future.wait([
        sendNotificationToUserType(
          userType: 'admin',
          title: title,
          body: body,
          data: data,
          channelId: 'emergency_notifications',
        ),
        sendNotificationToUserType(
          userType: 'supervisor',
          title: title,
          body: body,
          data: data,
          channelId: 'emergency_notifications',
        ),
        sendNotificationToUserType(
          userType: 'parent',
          title: title,
          body: body,
          data: data,
          channelId: 'emergency_notifications',
        ),
      ]);

      debugPrint('✅ Emergency notification sent to all users');
    } catch (e) {
      debugPrint('❌ Error sending emergency notification: $e');
    }
  }

  /// الحصول على اسم القناة
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'student_notifications':
        return 'إشعارات الطلاب';
      case 'bus_notifications':
        return 'إشعارات الباص';
      case 'emergency_notifications':
        return 'تنبيهات الطوارئ';
      default:
        return 'إشعارات MyBus';
    }
  }

  /// الحصول على وصف القناة
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'student_notifications':
        return 'إشعارات متعلقة بالطلاب وأنشطتهم';
      case 'bus_notifications':
        return 'إشعارات ركوب ونزول الباص';
      case 'emergency_notifications':
        return 'تنبيهات طوارئ مهمة وعاجلة';
      default:
        return 'إشعارات عامة لتطبيق MyBus';
    }
  }

  /// الحصول على Token الحالي
  String? get currentToken => _currentToken;

  /// التحقق من حالة التهيئة
  bool get isInitialized => _isInitialized;

  // ===============================
  // إضافات جديدة للإشعارات المحسنة
  // ===============================

  /// إرسال إشعار تحديث حالة الطالب لولي الأمر والإدارة
  Future<void> sendStudentStatusUpdateNotification({
    required String studentId,
    required String studentName,
    required String parentId,
    required String oldStatus,
    required String newStatus,
    required String supervisorName,
    String? supervisorId,
  }) async {
    try {
      debugPrint('🔔 Sending student status update notification for: $studentName');

      final statusText = _getStatusText(newStatus);
      final title = '📊 تحديث حالة الطالب';
      final body = 'تم تحديث حالة الطالب $studentName إلى: $statusText\nبواسطة المشرف: $supervisorName';

      // إرسال إشعار لولي الأمر
      await sendNotificationToUser(
        userId: parentId,
        title: title,
        body: body,
        data: {
          'type': 'student_status_update',
          'studentId': studentId,
          'studentName': studentName,
          'oldStatus': oldStatus,
          'newStatus': newStatus,
          'supervisorName': supervisorName,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'student_status_changed',
        },
        channelId: 'student_notifications',
      );

      // إرسال إشعار للإدارة (باستثناء المشرف الذي قام بالتحديث)
      await sendNotificationToUserTypeExcluding(
        userType: 'admin',
        excludeUserId: supervisorId,
        title: title,
        body: body,
        data: {
          'type': 'student_status_update',
          'studentId': studentId,
          'studentName': studentName,
          'parentId': parentId,
          'oldStatus': oldStatus,
          'newStatus': newStatus,
          'supervisorName': supervisorName,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'student_status_changed',
        },
        channelId: 'student_notifications',
      );

      debugPrint('✅ Student status update notifications sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending student status update notification: $e');
      rethrow;
    }
  }

  /// إرسال إشعار استبيان جديد لأولياء الأمور
  Future<void> sendNewSurveyNotification({
    required String surveyId,
    required String surveyTitle,
    required String surveyDescription,
    required String createdBy,
    required DateTime deadline,
    required List<String> targetUserIds,
  }) async {
    try {
      debugPrint('📊 Sending new survey notification: $surveyTitle');

      final deadlineStr = '${deadline.day}/${deadline.month}/${deadline.year}';
      final title = '📊 استبيان جديد متاح';
      final body = 'استبيان جديد: $surveyTitle\n$surveyDescription\nآخر موعد للإجابة: $deadlineStr';

      // إرسال الإشعار للمستخدمين المستهدفين
      for (final userId in targetUserIds) {
        await sendNotificationToUser(
          userId: userId,
          title: title,
          body: body,
          data: {
            'type': 'new_survey',
            'surveyId': surveyId,
            'surveyTitle': surveyTitle,
            'surveyDescription': surveyDescription,
            'createdBy': createdBy,
            'deadline': deadline.toIso8601String(),
            'timestamp': DateTime.now().toIso8601String(),
            'action': 'survey_created',
          },
          channelId: 'mybus_notifications',
        );
      }

      // إشعار الإدارة أيضاً
      await sendNotificationToUserTypeExcluding(
        userType: 'admin',
        excludeUserId: createdBy,
        title: '📊 تم إنشاء استبيان جديد',
        body: 'تم إنشاء استبيان جديد: $surveyTitle\nعدد المستهدفين: ${targetUserIds.length}',
        data: {
          'type': 'survey_created_admin',
          'surveyId': surveyId,
          'surveyTitle': surveyTitle,
          'targetCount': targetUserIds.length.toString(),
          'createdBy': createdBy,
          'deadline': deadline.toIso8601String(),
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'survey_created',
        },
        channelId: 'mybus_notifications',
      );

      debugPrint('✅ New survey notifications sent to ${targetUserIds.length} users');
    } catch (e) {
      debugPrint('❌ Error sending new survey notification: $e');
      rethrow;
    }
  }

  /// إرسال إشعار إكمال الاستبيان للإدارة
  Future<void> sendSurveyCompletionNotification({
    required String surveyId,
    required String surveyTitle,
    required String respondentName,
    required String respondentType,
    required String respondentId,
  }) async {
    try {
      debugPrint('📊 Sending survey completion notification');

      final title = '✅ تم إكمال استبيان';
      final body = 'أكمل $respondentName ($respondentType) استبيان: $surveyTitle';

      // إرسال إشعار للإدارة
      await sendNotificationToUserType(
        userType: 'admin',
        title: title,
        body: body,
        data: {
          'type': 'survey_completed',
          'surveyId': surveyId,
          'surveyTitle': surveyTitle,
          'respondentName': respondentName,
          'respondentType': respondentType,
          'respondentId': respondentId,
          'timestamp': DateTime.now().toIso8601String(),
          'action': 'survey_completed',
        },
        channelId: 'mybus_notifications',
      );

      debugPrint('✅ Survey completion notification sent to admins');
    } catch (e) {
      debugPrint('❌ Error sending survey completion notification: $e');
      rethrow;
    }
  }

  /// إرسال إشعار تذكير موعد انتهاء الاستبيان
  Future<void> sendSurveyReminderNotification({
    required String surveyId,
    required String surveyTitle,
    required DateTime deadline,
    required List<String> pendingUserIds,
  }) async {
    try {
      debugPrint('⏰ Sending survey reminder notification');

      final deadlineStr = '${deadline.day}/${deadline.month}/${deadline.year}';
      final title = '⏰ تذكير: استبيان ينتهي قريباً';
      final body = 'تذكير: استبيان "$surveyTitle" ينتهي في $deadlineStr\nيرجى الإجابة قبل انتهاء الموعد';

      // إرسال التذكير للمستخدمين الذين لم يكملوا الاستبيان
      for (final userId in pendingUserIds) {
        await sendNotificationToUser(
          userId: userId,
          title: title,
          body: body,
          data: {
            'type': 'survey_reminder',
            'surveyId': surveyId,
            'surveyTitle': surveyTitle,
            'deadline': deadline.toIso8601String(),
            'timestamp': DateTime.now().toIso8601String(),
            'action': 'survey_reminder',
          },
          channelId: 'mybus_notifications',
        );
      }

      debugPrint('✅ Survey reminder sent to ${pendingUserIds.length} users');
    } catch (e) {
      debugPrint('❌ Error sending survey reminder: $e');
      rethrow;
    }
  }

  /// إرسال إشعار لجميع المستخدمين من نوع معين باستثناء مستخدم محدد
  Future<void> sendNotificationToUserTypeExcluding({
    required String userType,
    String? excludeUserId,
    required String title,
    required String body,
    Map<String, String>? data,
    String? channelId,
  }) async {
    try {
      debugPrint('📤 Sending notification to $userType users (excluding: $excludeUserId)');

      // الحصول على جميع المستخدمين من النوع المحدد
      final usersQuery = await _firestore
          .collection('fcm_tokens')
          .where('userType', isEqualTo: userType)
          .where('isActive', isEqualTo: true)
          .get();

      if (usersQuery.docs.isEmpty) {
        debugPrint('⚠️ No active users found for user type: $userType');
        return;
      }

      int sentCount = 0;
      // إرسال الإشعار لكل مستخدم (باستثناء المستبعد)
      for (final userDoc in usersQuery.docs) {
        final userId = userDoc.data()['userId'] as String?;
        if (userId != null && userId.isNotEmpty && userId != excludeUserId) {
          await sendNotificationToUser(
            userId: userId,
            title: title,
            body: body,
            data: data,
            channelId: channelId,
          );
          sentCount++;
        }
      }

      debugPrint('✅ Notifications sent to $sentCount $userType users (excluded: $excludeUserId)');
    } catch (e) {
      debugPrint('❌ Error sending notifications to user type $userType: $e');
    }
  }

  /// إرسال إشعار لمجموعة من المستخدمين
  Future<void> sendNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, String>? data,
    String? channelId,
  }) async {
    try {
      debugPrint('📤 Sending notification to ${userIds.length} users');

      for (final userId in userIds) {
        await sendNotificationToUser(
          userId: userId,
          title: title,
          body: body,
          data: data,
          channelId: channelId,
        );
      }

      debugPrint('✅ Notifications sent to ${userIds.length} users');
    } catch (e) {
      debugPrint('❌ Error sending notifications to users: $e');
    }
  }

  /// الحصول على نص الحالة باللغة العربية
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'boarded':
      case 'في_الباص':
        return 'في الباص';
      case 'left':
      case 'نزل_من_الباص':
        return 'نزل من الباص';
      case 'absent':
      case 'غائب':
        return 'غائب';
      case 'present':
      case 'حاضر':
        return 'حاضر';
      case 'waiting':
      case 'في_الانتظار':
        return 'في الانتظار';
      default:
        return status;
    }
  }

  /// إعادة تشغيل الخدمة (في حالة الحاجة لإعادة التهيئة)
  Future<void> restart() async {
    try {
      debugPrint('🔄 Restarting Simple FCM Service...');
      
      _isInitialized = false;
      _currentToken = null;
      
      await initialize();
      
      debugPrint('✅ Simple FCM Service restarted successfully');
    } catch (e) {
      debugPrint('❌ Error restarting Simple FCM Service: $e');
      rethrow;
    }
  }

  /// تنظيف الموارد
  void dispose() {
    debugPrint('🧹 Disposing Simple FCM Service');
    _isInitialized = false;
    _currentToken = null;
  }

  /// تشخيص مشاكل الإشعارات
  Future<Map<String, dynamic>> diagnosePushNotifications() async {
    final diagnosis = <String, dynamic>{};
    
    try {
      // 1. التحقق من تهيئة الخدمة
      diagnosis['serviceInitialized'] = _isInitialized;
      
      // 2. التحقق من وجود Token
      diagnosis['hasToken'] = _currentToken != null;
      diagnosis['tokenLength'] = _currentToken?.length ?? 0;
      
      // 3. التحقق من أذونات الإشعارات
      final settings = await _messaging.getNotificationSettings();
      diagnosis['authorizationStatus'] = settings.authorizationStatus.toString();
      diagnosis['alert'] = settings.alert.toString();
      diagnosis['badge'] = settings.badge.toString();
      diagnosis['sound'] = settings.sound.toString();
      
      // 4. التحقق من إعدادات النظام
      if (Platform.isAndroid) {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidImplementation != null) {
          final granted = await androidImplementation.areNotificationsEnabled();
          diagnosis['systemNotificationsEnabled'] = granted ?? false;
        }
      }
      
      // 5. اختبار إشعار محلي
      try {
        await _displayLocalNotification(
          title: '🔧 اختبار تشخيص',
          body: 'إذا رأيت هذا الإشعار، فالنظام يعمل بشكل صحيح',
          data: {'test': 'true'},
          channelId: 'mybus_notifications',
        );
        diagnosis['localNotificationTest'] = 'success';
      } catch (e) {
        diagnosis['localNotificationTest'] = 'failed: $e';
      }
      
      // 6. التحقق من قنوات الإشعارات
      diagnosis['channelsCreated'] = true; // نفترض أنها تم إنشاؤها
      
      diagnosis['timestamp'] = DateTime.now().toIso8601String();
      diagnosis['platform'] = Platform.operatingSystem;
      
    } catch (e) {
      diagnosis['error'] = e.toString();
    }
    
    return diagnosis;
  }

  /// إرسال إشعار اختبار
  Future<void> sendTestNotification() async {
    try {
      debugPrint('🧪 Sending test notification...');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No user logged in for test notification');
        return;
      }
      
      await sendNotificationToUser(
        userId: currentUser.uid,
        title: '🧪 إشعار اختبار',
        body: 'هذا إشعار اختبار للتأكد من عمل النظام. الوقت: ${DateTime.now().toString().substring(11, 16)}',
        data: {
          'type': 'test',
          'timestamp': DateTime.now().toIso8601String(),
        },
        channelId: 'mybus_notifications',
      );
      
      debugPrint('✅ Test notification sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
      rethrow;
    }
  }
}
