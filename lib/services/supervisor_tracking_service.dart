import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة تتبع موقع المشرف (Singleton) وكتابته مباشرة على Firestore في
/// buses/{busId}.lastLocation، وده اللي بتقرأ منه شاشة ولي الأمر
/// (bus_tracking_screen.dart) عشان تعرض موقع الباص لحظيًا.
///
/// التتبع عايش هنا كـ Singleton مستقل عن دورة حياة أي شاشة، عشان لو
/// المشرف اتنقل بين شاشات جوه التطبيق التتبعميتوقفش. الشاشات بتسجل
/// نفسها كـ callbacks (onLocationUpdate / onTrackingStateChanged) وتفك
/// التسجيل في dispose بس من غير ما توقف التتبع نفسه.
class SupervisorTrackingService {
  // Singleton pattern
  static final SupervisorTrackingService _instance =
      SupervisorTrackingService._internal();
  factory SupervisorTrackingService() => _instance;
  SupervisorTrackingService._internal();

  final Location _locationService = Location();

  bool _isTracking = false;
  String? _currentBusId;
  String? _currentSupervisorId;
  StreamSubscription<LocationData>? _locationSubscription;
  int _locationUpdatesCount = 0;

  /// Callback بيتنادى مع كل تحديث موقع جديد (بعد ما يتكتب في Firestore).
  void Function(LocationData locationData)? onLocationUpdate;

  /// Callback بيتنادى لما حالة التتبع تتغيّر (بدأ/اتوقف)، سواء بفعل
  /// المشرف أو تلقائيًا (مثلًا فشل في الأذونات).
  void Function(bool isTracking)? onTrackingStateChanged;

  bool get isTracking => _isTracking;
  String? get currentBusId => _currentBusId;
  int get locationUpdatesCount => _locationUpdatesCount;

  /// تهيئة إعدادات مزود الموقع. آمنة الاستدعاء أكتر من مرة.
  Future<void> initialize() async {
    try {
      await _locationService.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 3000, // كل 3 ثواني
        distanceFilter: 5, // أو كل 5 متر تحرك
      );
    } catch (e) {
      debugPrint('❌ Error initializing SupervisorTrackingService: $e');
    }
  }

  /// بدء تتبع الباص وكتابة الموقع مباشرة في Firestore.
  Future<bool> startTracking({
    required String busId,
    required String supervisorId,
  }) async {
    if (_isTracking) {
      debugPrint('⚠️ Tracking already in progress for bus $_currentBusId');
      return true;
    }

    try {
      debugPrint('\n🚀 Starting bus tracking...');
      debugPrint('   Bus ID: $busId');
      debugPrint('   Supervisor ID: $supervisorId');

      if (!await _checkLocationPermissions()) {
        debugPrint('❌ Location permissions not granted');
        return false;
      }

      final currentLocation = await _locationService.getLocation();
      if (currentLocation.latitude == null ||
          currentLocation.longitude == null) {
        debugPrint('❌ Failed to get current location');
        return false;
      }

      _currentBusId = busId;
      _currentSupervisorId = supervisorId;
      _locationUpdatesCount = 0;

      await FirebaseFirestore.instance.collection('buses').doc(busId).update({
        'isTracking': true,
        'currentSupervisorId': supervisorId,
        'trackingStartedAt': FieldValue.serverTimestamp(),
      });

      await _startLocationUpdates();

      _isTracking = true;
      onTrackingStateChanged?.call(true);

      // أول موقع فورًا بدل الانتظار لأول تحديث دوري
      await _writeLocation(currentLocation);

      debugPrint('✅ Tracking started successfully\n');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting tracking: $e');
      return false;
    }
  }

  Future<bool> _checkLocationPermissions() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) return false;
      }

      PermissionStatus permission = await _locationService.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _locationService.requestPermission();
        if (permission != PermissionStatus.granted) return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  Future<void> _startLocationUpdates() async {
    try {
      await _locationSubscription?.cancel();

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

  Future<void> _handleLocationUpdate(LocationData locationData) async {
    if (!_isTracking || _currentBusId == null) return;
    await _writeLocation(locationData);
  }

  Future<void> _writeLocation(LocationData locationData) async {
    final latitude = locationData.latitude;
    final longitude = locationData.longitude;
    if (latitude == null || longitude == null || _currentBusId == null) {
      return;
    }

    try {
      final speed = locationData.speed ?? 0.0;
      final heading = locationData.heading ?? 0.0;

      await FirebaseFirestore.instance
          .collection('buses')
          .doc(_currentBusId)
          .update({
        'lastLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'heading': heading,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      _locationUpdatesCount++;

      if (_locationUpdatesCount % 10 == 0) {
        debugPrint('📍 Location update #$_locationUpdatesCount sent');
        debugPrint('   Lat: ${latitude.toStringAsFixed(6)}');
        debugPrint('   Lng: ${longitude.toStringAsFixed(6)}');
        debugPrint('   Speed: ${speed.toStringAsFixed(1)} m/s');
      }

      onLocationUpdate?.call(locationData);
    } catch (e) {
      debugPrint('❌ Error writing location to Firestore: $e');
    }
  }

  /// إيقاف تتبع الباص.
  Future<void> stopTracking() async {
    if (!_isTracking && _currentBusId == null) return;

    try {
      debugPrint('\n🛑 Stopping bus tracking...');

      await _locationSubscription?.cancel();
      _locationSubscription = null;

      if (_currentBusId != null) {
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(_currentBusId)
            .update({
          'isTracking': false,
          'trackingStoppedAt': FieldValue.serverTimestamp(),
        });
      }

      _isTracking = false;
      _currentBusId = null;
      _currentSupervisorId = null;
      _locationUpdatesCount = 0;

      onTrackingStateChanged?.call(false);

      debugPrint('✅ Tracking stopped successfully\n');
    } catch (e) {
      debugPrint('❌ Error stopping tracking: $e');
    }
  }

  /// تنظيف الموارد (بيتنادى فقط لما التطبيق نفسه بيتقفل، مش من dispose
  /// شاشة معينة - راجع التعليق في supervisor_home_screen.dart).
  Future<void> dispose() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }
}
