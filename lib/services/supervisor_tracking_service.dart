import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة تتبع موقع المشرف وإرساله للباص بشكل مباشر
class SupervisorTrackingService {
  // Singleton pattern
  static final SupervisorTrackingService _instance = SupervisorTrackingService._internal();
  factory SupervisorTrackingService() => _instance;
  SupervisorTrackingService._internal();

  // Services
  final Location _locationService = Location();
  IO.Socket? _socket;
  
  // State
  bool _isTracking = false;
  String? _currentBusId;
  String? _currentSupervisorId;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _heartbeatTimer;
  
  // Location data
  LocationData? _lastLocation;
  DateTime? _trackingStartTime;
  int _updateCount = 0;

  // Getters
  bool get isTracking => _isTracking;
  bool get isConnected => _socket?.connected ?? false;
  String? get currentBusId => _currentBusId;
  LocationData? get lastLocation => _lastLocation;
  DateTime? get trackingStartTime => _trackingStartTime;
  
  /// تهيئة Socket.IO connection
  Future<void> initialize() async {
    if (_socket != null && _socket!.connected) {
      debugPrint('✅ Socket already connected');
      return;
    }

    try {
      // TODO: غيّر هذا للـ production URL
      const serverUrl = 'http://localhost:3000';
      
      debugPrint('🔌 Connecting to Socket.IO server: $serverUrl');
      
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      _setupSocketListeners();
      
    } catch (e) {
      debugPrint('❌ Error initializing socket: $e');
      rethrow;
    }
  }

  /// إعداد مستمعي Socket.IO
  void _setupSocketListeners() {
    _socket?.onConnect((_) {
      debugPrint('✅ Socket.IO connected');
    });

    _socket?.onDisconnect((_) {
      debugPrint('❌ Socket.IO disconnected');
    });

    _socket?.onConnectError((error) {
      debugPrint('❌ Connection error: $error');
    });

    _socket?.on('supervisor:trackingStarted', (data) {
      debugPrint('✅ Tracking started confirmation: $data');
    });

    _socket?.on('supervisor:trackingStopped', (data) {
      debugPrint('🛑 Tracking stopped confirmation: $data');
    });

    _socket?.on('error', (error) {
      debugPrint('❌ Socket error: $error');
    });
  }

  /// بدء تتبع الباص
  Future<bool> startTracking({
    required String busId,
    required String supervisorId,
  }) async {
    try {
      debugPrint('\n🚀 Starting bus tracking...');
      debugPrint('   Bus ID: $busId');
      debugPrint('   Supervisor ID: $supervisorId');

      // التحقق من الأذونات
      if (!await _checkLocationPermissions()) {
        debugPrint('❌ Location permissions not granted');
        return false;
      }

      // الحصول على الموقع الحالي
      final currentLocation = await _locationService.getLocation();
      
      if (currentLocation.latitude == null || currentLocation.longitude == null) {
        debugPrint('❌ Failed to get current location');
        return false;
      }

      // تهيئة Socket.IO إذا لم يكن متصلاً
      if (_socket == null || !_socket!.connected) {
        await initialize();
        await Future.delayed(const Duration(seconds: 1)); // انتظار الاتصال
      }

      if (!isConnected) {
        debugPrint('❌ Socket not connected');
        return false;
      }

      // حفظ معلومات التتبع
      _currentBusId = busId;
      _currentSupervisorId = supervisorId;
      _trackingStartTime = DateTime.now();
      _updateCount = 0;

      // إرسال حدث بدء التتبع
      _socket!.emit('supervisor:startTracking', {
        'busId': busId,
        'supervisorId': supervisorId,
        'latitude': currentLocation.latitude!,
        'longitude': currentLocation.longitude!,
      });

      debugPrint('📤 Sent startTracking event');

      // بدء الاستماع لتحديثات الموقع
      await _startLocationUpdates();

      // بدء heartbeat timer للتحقق من الاتصال
      _startHeartbeat();

      _isTracking = true;
      
      // تحديث Firestore
      await FirebaseFirestore.instance
          .collection('buses')
          .doc(busId)
          .update({
        'isTracking': true,
        'currentSupervisorId': supervisorId,
        'trackingStartedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Tracking started successfully\n');
      return true;

    } catch (e) {
      debugPrint('❌ Error starting tracking: $e');
      return false;
    }
  }

  /// التحقق من أذونات الموقع
  Future<bool> _checkLocationPermissions() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          return false;
        }
      }

      PermissionStatus permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) {
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// بدء الاستماع لتحديثات الموقع
  Future<void> _startLocationUpdates() async {
    try {
      // إلغاء الاشتراك السابق إن وجد
      await _locationSubscription?.cancel();

      // تعيين إعدادات الموقع
      await _locationService.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 3000, // كل 3 ثواني
        distanceFilter: 5, // كل 5 متر
      );

      // بدء الاستماع
      _locationSubscription = _locationService.onLocationChanged.listen(
        _handleLocationUpdate,
        onError: (error) {
          debugPrint('❌ Location update error: $error');
        },
      );

      debugPrint('✅ Started listening to location updates');
    } catch (e) {
      debugPrint('❌ Error starting location updates: $e');
    }
  }

  /// معالجة تحديث الموقع
  void _handleLocationUpdate(LocationData locationData) {
    if (!_isTracking || _currentBusId == null) return;

    try {
      _lastLocation = locationData;
      _updateCount++;

      final latitude = locationData.latitude;
      final longitude = locationData.longitude;
      final speed = locationData.speed ?? 0.0;
      final heading = locationData.heading ?? 0.0;

      if (latitude == null || longitude == null) {
        return;
      }

      // إرسال التحديث عبر Socket.IO
      if (isConnected) {
        _socket!.emit('supervisor:updateLocation', {
          'busId': _currentBusId,
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'heading': heading,
        });

        if (_updateCount % 10 == 0) {
          // طباعة كل 10 تحديثات
          debugPrint('📍 Location update #$_updateCount sent');
          debugPrint('   Lat: ${latitude.toStringAsFixed(6)}');
          debugPrint('   Lng: ${longitude.toStringAsFixed(6)}');
          debugPrint('   Speed: ${speed.toStringAsFixed(1)} m/s');
        }
      } else {
        debugPrint('⚠️ Socket not connected, skipping update');
      }

    } catch (e) {
      debugPrint('❌ Error handling location update: $e');
    }
  }

  /// بدء heartbeat للتحقق من الاتصال
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isConnected) {
        debugPrint('⚠️ Socket disconnected, attempting reconnect...');
        _socket?.connect();
      }
    });
  }

  /// إيقاف تتبع الباص
  Future<void> stopTracking() async {
    try {
      debugPrint('\n🛑 Stopping bus tracking...');

      if (_currentBusId != null && isConnected) {
        // إرسال حدث إيقاف التتبع
        _socket!.emit('supervisor:stopTracking', {
          'busId': _currentBusId,
        });
        debugPrint('📤 Sent stopTracking event');
      }

      // إلغاء الاشتراك في تحديثات الموقع
      await _locationSubscription?.cancel();
      _locationSubscription = null;

      // إيقاف heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;

      // تحديث Firestore
      if (_currentBusId != null) {
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(_currentBusId)
            .update({
          'isTracking': false,
          'trackingStoppedAt': FieldValue.serverTimestamp(),
        });
      }

      // إعادة تعيين الحالة
      _isTracking = false;
      _currentBusId = null;
      _currentSupervisorId = null;
      _lastLocation = null;
      _trackingStartTime = null;
      _updateCount = 0;

      debugPrint('✅ Tracking stopped successfully\n');

    } catch (e) {
      debugPrint('❌ Error stopping tracking: $e');
    }
  }

  /// الحصول على مدة التتبع
  Duration? getTrackingDuration() {
    if (_trackingStartTime == null) return null;
    return DateTime.now().difference(_trackingStartTime!);
  }

  /// تنظيف الموارد
  Future<void> dispose() async {
    await stopTracking();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
