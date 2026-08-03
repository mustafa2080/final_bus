import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/simple_fcm_service.dart';
import 'services/notification_test_service.dart';
import 'services/notification_dialog_service.dart';
import 'services/theme_service.dart';
import 'services/persistent_auth_service.dart';
import 'utils/app_constants.dart';
import 'utils/app_validator.dart';

// ========== معالج الإشعارات في الخلفية (TOP-LEVEL FUNCTION) ==========
// يجب أن تكون خارج أي class وفي أعلى الملف
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // تهيئة Firebase للخلفية
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('🔔 Background Message Received!');
  print('📬 Message ID: ${message.messageId}');
  print('📝 Title: ${message.notification?.title}');
  print('📝 Body: ${message.notification?.body}');
  print('📦 Data: ${message.data}');

  // عرض الإشعار يدوياً لضمان ظهوره خارج التطبيق
  await _showBackgroundNotification(message);
}

// دالة مساعدة لعرض الإشعار في الخلفية
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  try {
    // إنشاء instance من Flutter Local Notifications
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

    // إعدادات Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@drawable/ic_notification');

    // إعدادات iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // تهيئة المكون الإضافي
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(initSettings);

    // إنشاء قناة الإشعارات إذا لم تكن موجودة (Android فقط)
    if (Platform.isAndroid) {
      await _createBackgroundNotificationChannel(localNotifications);
    }

    // تحديد معلومات الإشعار
    final String channelId = message.data['channelId'] ?? 'mybus_notifications';
    final String title = message.notification?.title ?? 'إشعار جديد';
    final String body = message.notification?.body ?? '';

    // إعدادات الإشعار لأندرويد محسنة لتظهر مثل WhatsApp
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/launcher_icon',
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

    // إعدادات الإشعار لـ iOS محسنة
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.mp3',
      badgeNumber: 1,
      subtitle: 'كيدز باص',
      threadIdentifier: 'mybus_notifications',
      categoryIdentifier: 'mybus_category',
    );

    // تجميع الإعدادات
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // إنشاء معرف فريد للإشعار
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    // عرض الإشعار
    await localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: jsonEncode({
        ...message.data,
        'messageId': message.messageId,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );

    print('✅ Background notification shown successfully');
  } catch (e) {
    print('❌ Error showing background notification: $e');
  }
}

// إنشاء قناة الإشعارات في الخلفية (Android)
Future<void> _createBackgroundNotificationChannel(FlutterLocalNotificationsPlugin localNotifications) async {
  try {
    final List<AndroidNotificationChannel> channels = [
      const AndroidNotificationChannel(
        'mybus_notifications',
        'كيدز باص - الإشعارات العامة',
        description: 'إشعارات عامة من تطبيق كيدز باص للنقل المدرسي',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        playSound: true,
        showBadge: true,
        enableLights: true,
        ledColor: Color(0xFF1E88E5),
      ),
      const AndroidNotificationChannel(
        'student_notifications',
        'إشعارات الطلاب',
        description: 'إشعارات متعلقة بالطلاب وأنشطتهم',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
      const AndroidNotificationChannel(
        'bus_notifications',
        'إشعارات الباص',
        description: 'إشعارات ركوب ونزول الباص',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
      const AndroidNotificationChannel(
        'emergency_notifications',
        'تنبيهات الطوارئ',
        description: 'تنبيهات طوارئ مهمة وعاجلة',
        importance: Importance.max,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        enableVibration: true,
        playSound: true,
        showBadge: true,
      ),
    ];

    // إنشاء القنوات
    for (final channel in channels) {
      await localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    print('✅ Background notification channels created');
  } catch (e) {
    print('❌ Error creating background notification channels: $e');
  }
}

// الحصول على اسم القناة
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

// الحصول على وصف القناة
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // تهيئة Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    // ========== تسجيل معالج إشعارات الخلفية ==========
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('✅ Background message handler registered');

    // Firebase Auth يحفظ تسجيل الدخول تلقائياً في Flutter
    print('✅ Firebase Auth persistence is enabled by default');

    // تهيئة خدمة الإشعارات المبسطة
    await SimpleFCMService().initialize();
    print('✅ Simple FCM Service initialized');

    // تهيئة خدمة المصادقة المستمرة
    await PersistentAuthService().initialize();
    print('✅ Persistent auth service initialized');

    runApp(MyApp());
  } catch (e) {
    print('❌ Error in main: $e');
    runApp(MyApp()); // تشغيل التطبيق حتى لو حدث خطأ
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      default:
        break;
    }
  }

  void _handleAppResumed() {
    print('📱 App resumed - in foreground');
  }

  void _handleAppPaused() {
    print('📱 App paused - in background');
  }

  void _handleAppDetached() {
    print('📱 App detached - closing');
    // SimpleFCMService doesn't need disposal
  }

  Future<void> _initializeServices() async {
    try {
      await NotificationDialogService().initialize();
      print('✅ Notification dialog service initialized');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<SimpleFCMService>(create: (_) => SimpleFCMService()),
        Provider<ThemeService>(create: (_) => _themeService),
        ChangeNotifierProvider<PersistentAuthService>(create: (_) => PersistentAuthService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp.router(
            title: 'MyBus - تطبيق تتبع الطلاب',
            debugShowCheckedModeBanner: false,
            
            locale: const Locale('ar', 'SA'),
            supportedLocales: const [
              Locale('ar', 'SA'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeService.currentTheme,
            
            routerConfig: AppRoutes.router,
            
            builder: (context, widget) {
              ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                return _buildErrorWidget(errorDetails);
              };
              return widget!;
            },
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      primaryColor: AppConstants.primaryColor,
      
      appBarTheme: AppBarTheme(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppConstants.primaryColor,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        brightness: Brightness.light,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: AppConstants.primaryColor,
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppConstants.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade800,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.grey.shade800,
      ),
      
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppConstants.primaryColor,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        brightness: Brightness.dark,
      ),
    );
  }

  Widget _buildErrorWidget(FlutterErrorDetails errorDetails) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'حدث خطأ غير متوقع',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                errorDetails.exception.toString(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  runApp(MyApp());
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
