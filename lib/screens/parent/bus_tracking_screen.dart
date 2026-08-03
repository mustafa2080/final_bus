import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/persistent_auth_service.dart';
import '../../services/map_service.dart';
import '../../widgets/curved_app_bar.dart';
import '../../utils/responsive_helper.dart';
import 'dart:async';
import 'dart:math' as math;

class BusTrackingScreen extends StatefulWidget {
  final String? busId;
  
  const BusTrackingScreen({
    super.key,
    this.busId,
  });

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  final MapController _mapController = MapController();
  IO.Socket? _socket;
  StreamSubscription<DocumentSnapshot>? _busStatusSubscription;
  
  // البيانات
  String? _busId;
  String? _busNumber;
  LatLng? _busLocation;
  double _busSpeed = 0.0;
  double _busHeading = 0.0;
  bool _isTracking = false;
  bool _isConnected = false;
  DateTime? _lastUpdate;
  String? _locationAddress;
  bool _isLoading = true; // لتتبع حالة التحميل
  String? _errorMessage; // لعرض رسائل الخطأ
  
  // للتحقق من أن الخريطة تم عرضها
  bool _isMapReady = false;
  
  // معلومات الطلاب وأولياء الأمور
  List<Map<String, dynamic>> _students = [];
  List<String> _parentStudentNames = []; // أسماء طلاب ولي الأمر الحالي
  
  // للانيميشن
  Timer? _locationUpdateTimer;
  LatLng? _previousLocation;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // جلب busId من الطالب الأول لولي الأمر
      if (widget.busId != null) {
        setState(() {
          _busId = widget.busId;
        });
      } else {
        await _getBusIdFromParent();
      }
      
      if (_busId != null) {
        await _loadBusDetails();
        _connectToSocket();
      } else {
        setState(() {
          _errorMessage = 'لم يتم تعيين باص لأي من أبنائك';
        });
      }
    } catch (e) {
      debugPrint('❌ Error in _initializeData: $e');
      setState(() {
        _errorMessage = 'حدث خطأ في تحميل البيانات';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getBusIdFromParent() async {
    try {
      final authService = Provider.of<PersistentAuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('parentId', isEqualTo: currentUser.uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
        
        if (studentsSnapshot.docs.isNotEmpty) {
          final studentData = studentsSnapshot.docs.first.data();
          setState(() {
            _busId = studentData['busId'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting busId: $e');
    }
  }

  Future<void> _loadBusDetails() async {
    if (_busId == null) return;
    
    try {
      debugPrint('🔍 جاري تحميل بيانات الباص: $_busId');
      
      final busDoc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(_busId)
          .get();
      
      if (!busDoc.exists) {
        debugPrint('❌ الباص غير موجود: $_busId');
        setState(() {
          _errorMessage = 'الباص غير موجود في قاعدة البيانات';
        });
        return;
      }
      
      final busData = busDoc.data()!;
      
      // طباعة البيانات لفحصها
      debugPrint('🔍 Bus Data: $busData');
      debugPrint('🔍 isActive value: ${busData['isActive']}');
      debugPrint('🔍 Keys available: ${busData.keys.toList()}');
      
      setState(() {
        _busNumber = busData['busNumber'] as String?;
        // جلب حالة الباص من isActive
        _isTracking = busData['isActive'] as bool? ?? false;
        
        debugPrint('✅ Final _isTracking value: $_isTracking');
        
        // جلب آخر موقع معروف
        final lastLocation = busData['lastLocation'] as Map<String, dynamic>?;
        if (lastLocation != null) {
          final lat = (lastLocation['latitude'] as num?)?.toDouble();
          final lng = (lastLocation['longitude'] as num?)?.toDouble();
          final speed = (lastLocation['speed'] as num?)?.toDouble();
          final heading = (lastLocation['heading'] as num?)?.toDouble();
          
          if (lat != null && lng != null) {
            _busLocation = LatLng(lat, lng);
            _busSpeed = speed ?? 0.0;
            _busHeading = heading ?? 0.0;
            
            // تحديث آخر تحديث من timestamp في Firestore
            if (lastLocation['timestamp'] != null) {
              try {
                final timestamp = lastLocation['timestamp'] as Timestamp;
                _lastUpdate = timestamp.toDate();
                debugPrint('✅ تم تحديث آخر تحديث من Firestore: $_lastUpdate');
              } catch (e) {
                debugPrint('⚠️ خطأ في قراءة timestamp: $e');
                _lastUpdate = DateTime.now();
              }
            }
            
            // لا نحرك الخريطة هنا - سننتظر حتى يتم عرضها
            _loadLocationAddress();
          } else {
            // إذا لم يكن هناك موقع، استخدم موقع افتراضي (الرياض)
            _busLocation = const LatLng(24.7136, 46.6753);
            debugPrint('⚠️ لا يوجد موقع محفوظ - استخدام الموقع الافتراضي');
          }
        } else {
          // إذا لم يكن هناك lastLocation، استخدم موقع افتراضي
          _busLocation = const LatLng(24.7136, 46.6753);
          debugPrint('⚠️ لا يوجد lastLocation - استخدام الموقع الافتراضي');
        }
      });
      
      // جلب طلاب ولي الأمر الحالي
      await _loadParentStudents();
      
      // جلب جميع الطلاب في الباص
      await _loadBusStudents();
      
      // البدء في مراقبة حالة الباص من Firebase
      _startBusStatusMonitoring();
      
      debugPrint('✅ تم تحميل بيانات الباص بنجاح');
      
    } catch (e, stackTrace) {
      debugPrint('\n❌ ========================================');
      debugPrint('❌ CRITICAL ERROR in _loadBusDetails');
      debugPrint('❌ Error Type: ${e.runtimeType}');
      debugPrint('❌ Error Message: $e');
      debugPrint('❌ Stack Trace:');
      debugPrint(stackTrace.toString());
      debugPrint('========================================\n');
      
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ في تحميل بيانات الباص:\n${e.toString()}';
          // استخدم موقع افتراضي حتى في حالة الخطأ
          _busLocation = const LatLng(24.7136, 46.6753);
        });
      }
    }
  }

  void _startBusStatusMonitoring() {
    if (_busId == null) return;
    
    _busStatusSubscription = FirebaseFirestore.instance
        .collection('buses')
        .doc(_busId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        // جلب حالة الباص من isActive
        final isTracking = data['isActive'] as bool? ?? false;
        
        debugPrint('🔍 Bus status changed: $isTracking');
        
        if (mounted && _isTracking != isTracking) {
          setState(() {
            _isTracking = isTracking;
          });
          
          // عرض إشعار عند تغير الحالة
          _showSnackBar(
            isTracking ? 'بدأ تتبع الباص' : 'توقف تتبع الباص',
            isTracking ? Colors.green : Colors.orange,
          );
        }
      }
    });
  }

  Future<void> _loadParentStudents() async {
    try {
      final authService = Provider.of<PersistentAuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('parentId', isEqualTo: currentUser.uid)
            .where('isActive', isEqualTo: true)
            .get();
        
        setState(() {
          _parentStudentNames = studentsSnapshot.docs
              .map((doc) => doc.data()['name'] as String)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading parent students: $e');
    }
  }

  Future<void> _loadBusStudents() async {
    try {
      // جلب طلاب ولي الأمر الحالي
      final authService = Provider.of<PersistentAuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      debugPrint('\n🔍 ========================================');
      debugPrint('🔍 Loading students for parent');
      debugPrint('🔍 Current User ID: ${currentUser?.uid}');
      debugPrint('🔍 Current User Email: ${currentUser?.email}');
      debugPrint('========================================\n');
      
      if (currentUser == null) {
        debugPrint('❌ Current user is null!');
        return;
      }
      
      // جلب الطلاب بدون فلترة busId أولاً لنرى كل الطلاب
      final allStudentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('parentId', isEqualTo: currentUser.uid)
          .get();
      
      debugPrint('📊 Total students for this parent: ${allStudentsSnapshot.docs.length}');
      
      for (var doc in allStudentsSnapshot.docs) {
        final data = doc.data();
        debugPrint('  📌 Student: ${data['name']}');
        debugPrint('     - Grade: ${data['grade']}');
        debugPrint('     - BusId: ${data['busId']}');
        debugPrint('     - isActive: ${data['isActive']}');
      }
      
      // الآن جلب الطلاب النشطين فقط
      final activeStudentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('parentId', isEqualTo: currentUser.uid)
          .where('isActive', isEqualTo: true)
          .get();
      
      debugPrint('\n✅ Active students: ${activeStudentsSnapshot.docs.length}');
      
      setState(() {
        _students = activeStudentsSnapshot.docs
            .map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] as String? ?? 'غير محدد',
                'grade': data['grade'] as String? ?? 'غير محدد',
                'busId': data['busId'] as String? ?? '',
              };
            })
            .toList();
      });
      
      debugPrint('✅ تم جلب ${_students.length} طالب نشط');
      if (_students.isEmpty) {
        debugPrint('⚠️ WARNING: No active students found!');
        debugPrint('⚠️ Check:');
        debugPrint('   1. Students have parentId = ${currentUser.uid}');
        debugPrint('   2. Students have isActive = true');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading students: $e');
      debugPrint('❌ Stack trace: $stackTrace');
    }
  }

  Future<void> _loadLocationAddress() async {
    if (_busLocation == null) return;
    
    final address = await MapService.getAddressFromCoordinates(
      lat: _busLocation!.latitude,
      lon: _busLocation!.longitude,
    );
    
    if (mounted) {
      setState(() {
        _locationAddress = address;
      });
    }
  }

  void _connectToSocket() {
    if (_busId == null) return;
    
    try {
      // تحديد عنوان الخادم بناءً على المنصة
      String serverUrl;
      if (kIsWeb) {
        serverUrl = 'http://localhost:3000';
        debugPrint('🌐 Web platform: using $serverUrl');
      } else {
        serverUrl = 'http://192.168.2.2:3000';
        debugPrint('📱 Mobile platform: using $serverUrl');
      }
      
      // اتصال بالـ backend
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );

      _socket!.connect();

      // الاستماع لحالة الاتصال
      _socket!.onConnect((_) {
        debugPrint('✅ Socket.IO متصل');
        setState(() {
          _isConnected = true;
        });
        
        // الاشتراك في تتبع الباص
        final authService = Provider.of<PersistentAuthService>(context, listen: false);
        final userId = authService.currentUser?.uid;
        
        if (userId != null) {
          _socket!.emit('parent:subscribeToBus', {
            'userId': userId,
            'busId': _busId,
          });
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('❌ Socket.IO انقطع الاتصال');
        setState(() {
          _isConnected = false;
        });
      });

      // الاستماع للموقع الحالي عند الاشتراك
      _socket!.on('bus:currentLocation', (data) {
        debugPrint('📍 تم استلام الموقع الحالي');
        _handleLocationUpdate(data);
      });

      // الاستماع لتحديثات الموقع المباشرة
      _socket!.on('bus:locationUpdate', (data) {
        debugPrint('📍 تحديث موقع جديد');
        _handleLocationUpdate(data);
      });

      // الاستماع لبدء التتبع
      _socket!.on('bus:trackingStarted', (data) {
        debugPrint('🚌 بدأ التتبع');
        setState(() {
          _isTracking = true;
        });
        _showSnackBar('بدأ تتبع الباص', Colors.green);
      });

      // الاستماع لإيقاف التتبع
      _socket!.on('bus:trackingStopped', (data) {
        debugPrint('🛑 توقف التتبع');
        setState(() {
          _isTracking = false;
        });
        _showSnackBar('توقف تتبع الباص', Colors.orange);
      });

      // الاستماع لتأكيد الاشتراك
      _socket!.on('parent:subscribed', (data) {
        debugPrint('✅ تم الاشتراك بنجاح في تتبع الباص');
        _showSnackBar('تم الاشتراك في تتبع الباص', Colors.green);
      });

      // الاستماع للأخطاء
      _socket!.on('error', (data) {
        debugPrint('❌ خطأ: $data');
        _showSnackBar('حدث خطأ: ${data['message']}', Colors.red);
      });

    } catch (e) {
      debugPrint('❌ Error connecting to socket: $e');
    }
  }

  void _handleLocationUpdate(dynamic data) {
    try {
      debugPrint('\n📍 ========== LOCATION UPDATE ==========');
      debugPrint('📍 Raw data: $data');
      debugPrint('📍 Data type: ${data.runtimeType}');
      debugPrint('📍 Data keys: ${(data as Map).keys.toList()}');
      
      final location = data['location'] as Map<String, dynamic>;
      final lat = location['latitude'] as double;
      final lng = location['longitude'] as double;
      
      debugPrint('📍 Location: ($lat, $lng)');
      
      // جلب السرعة - تأكد من التحويل الصحيح
      double speed = 0.0;
      if (data['speed'] != null) {
        debugPrint('📍 Speed field exists: ${data['speed']} (type: ${data['speed'].runtimeType})');
        // التحويل الآمن من int أو double إلى double
        if (data['speed'] is int) {
          speed = (data['speed'] as int).toDouble();
        } else if (data['speed'] is double) {
          speed = data['speed'] as double;
        } else {
          speed = double.tryParse(data['speed'].toString()) ?? 0.0;
        }
        debugPrint('🚗 Speed converted: $speed km/h');
      } else {
        debugPrint('⚠️ Speed field is NULL!');
      }
      
      final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
      debugPrint('🧭 Heading: $heading°');
      debugPrint('========================================\n');
      
      if (mounted) {
        setState(() {
          _previousLocation = _busLocation;
          _busLocation = LatLng(lat, lng);
          _busSpeed = speed;
          _busHeading = heading;
          _lastUpdate = DateTime.now();
          _isTracking = data['isTracking'] as bool? ?? true;
        });
        
        debugPrint('\n✅ ========== STATE UPDATED ==========');
        debugPrint('✅ Location: ($lat, $lng)');
        debugPrint('✅ Speed: $_busSpeed km/h');
        debugPrint('✅ Heading: $_busHeading°');
        debugPrint('✅ Last Update: $_lastUpdate');
        debugPrint('✅ Is Tracking: $_isTracking');
        debugPrint('====================================\n');
        
        // تحريك الكاميرا للموقع الجديد (فقط إذا كانت الخريطة جاهزة)
        if (_isMapReady) {
          try {
            _mapController.move(_busLocation!, _mapController.camera.zoom);
          } catch (e) {
            debugPrint('⚠️ Could not move map: $e');
          }
        }
        
        // تحديث العنوان
        _loadLocationAddress();
      }
    } catch (e) {
      debugPrint('❌ Error handling location update: $e');
      debugPrint('❌ Data was: $data');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _busStatusSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          EnhancedCurvedAppBar(
            title: 'تتبع الباص',
            subtitle: _parentStudentNames.isEmpty
                ? const Text(
                    'تحميل...',
                    style: TextStyle(fontSize: 14),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isTracking ? Icons.gps_fixed : Icons.gps_off,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _parentStudentNames.length == 1
                              ? _parentStudentNames[0]
                              : _parentStudentNames.join('، '),
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
          ),
          
          // معلومات الحالة
          _buildStatusBar(),
          
          // الخريطة
          Expanded(
            child: _isLoading
                ? _buildLoadingView()
                : _errorMessage != null
                    ? _buildErrorView()
                    : _busLocation == null
                        ? _buildNoLocationView()
                        : Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _busLocation ?? const LatLng(24.7136, 46.6753),
                          initialZoom: 15.0,
                          minZoom: 3.0,
                          maxZoom: 18.0,
                          onMapReady: () {
                            debugPrint('✅ Map is ready!');
                            setState(() {
                              _isMapReady = true;
                            });
                            // الآن يمكننا تحريك الخريطة إلى موقع الباص
                            if (_busLocation != null) {
                              _mapController.move(_busLocation!, 15.0);
                            }
                          },
                        ),
                        children: [
                          // طبقة الخريطة من OpenStreetMap
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.mybus',
                          ),
                          // ماركر الباص
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 100.0,
                                height: 100.0,
                                point: _busLocation!,
                                child: Transform.rotate(
                                  angle: _busHeading * math.pi / 180,
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isTracking ? Colors.green : Colors.orange,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _parentStudentNames.join('، '),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.yellow.shade700,
                                          borderRadius: BorderRadius.circular(25),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.directions_bus,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // معلومات الباص
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: _buildBusInfoCard(),
                      ),
                      
                      // أزرار التحكم
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Column(
                          children: [
                            _buildControlButton(
                              icon: Icons.my_location,
                              onPressed: () {
                                if (_busLocation != null && _isMapReady) {
                                  try {
                                    _mapController.move(_busLocation!, 15.0);
                                  } catch (e) {
                                    debugPrint('⚠️ Could not move to bus location: $e');
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildControlButton(
                              icon: Icons.add,
                              onPressed: () {
                                if (_isMapReady) {
                                  try {
                                    _mapController.move(
                                      _mapController.camera.center,
                                      _mapController.camera.zoom + 1,
                                    );
                                  } catch (e) {
                                    debugPrint('⚠️ Could not zoom in: $e');
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            _buildControlButton(
                              icon: Icons.remove,
                              onPressed: () {
                                if (_isMapReady) {
                                  try {
                                    _mapController.move(
                                      _mapController.camera.center,
                                      _mapController.camera.zoom - 1,
                                    );
                                  } catch (e) {
                                    debugPrint('⚠️ Could not zoom out: $e');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // زر قائمة الطلاب
                      if (_students.isNotEmpty)
                        Positioned(
                          top: 20,
                          left: 20,
                          child: _buildStudentsButton(),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isTracking ? Colors.green.shade50 : Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(
            color: _isTracking ? Colors.green.shade200 : Colors.orange.shade200,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isTracking ? Colors.green : Colors.orange,
              boxShadow: [
                BoxShadow(
                  color: (_isTracking ? Colors.green : Colors.orange).withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTracking ? 'الباص نشط' : 'الباص غير نشط',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isTracking ? Colors.green.shade900 : Colors.orange.shade900,
                  ),
                ),
                if (_lastUpdate != null)
                  Text(
                    'آخر تحديث: ${_formatLastUpdate()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            _isConnected ? Icons.cloud_done : Icons.cloud_off,
            color: _isConnected ? Colors.green : Colors.red,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF1E88E5),
          ),
          const SizedBox(height: 20),
          Text(
            'جاري تحميل بيانات الباص...',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: ResponsiveHelper.getPadding(context,
          mobilePadding: const EdgeInsets.all(20),
          tabletPadding: const EdgeInsets.all(28),
          desktopPadding: const EdgeInsets.all(36)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: ResponsiveHelper.getIconSize(context,
                mobileSize: 60, tabletSize: 80, desktopSize: 90),
              color: Colors.red.shade300,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context,
              mobileSpacing: 18, tabletSpacing: 24, desktopSpacing: 28)),
            Text(
              _errorMessage ?? 'حدث خطأ',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                  mobile: 16, tablet: 18, desktop: 20),
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context,
              mobileSpacing: 12, tabletSpacing: 16, desktopSpacing: 18)),
            Text(
              'يرجى المحاولة مرة أخرى أو التواصل مع الدعم الفني',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                  mobile: 13, tablet: 14, desktop: 15),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context,
              mobileSpacing: 24, tabletSpacing: 32, desktopSpacing: 36)),
            ElevatedButton.icon(
              onPressed: () {
                _initializeData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoLocationView() {
    return Center(
      child: Padding(
        padding: ResponsiveHelper.getPadding(context,
          mobilePadding: const EdgeInsets.all(20),
          tabletPadding: const EdgeInsets.all(28),
          desktopPadding: const EdgeInsets.all(36)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: ResponsiveHelper.getIconSize(context,
                mobileSize: 60, tabletSize: 80, desktopSize: 90),
              color: Colors.orange.shade300,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context,
              mobileSpacing: 18, tabletSpacing: 24, desktopSpacing: 28)),
            Text(
              'لا يوجد موقع للباص',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                  mobile: 16, tablet: 18, desktop: 20),
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context,
              mobileSpacing: 12, tabletSpacing: 16, desktopSpacing: 18)),
            Text(
              'لم يتم تسجيل أي موقع للباص بعد. سيظهر الموقع عندما يبدأ السوبرفايزر التتبع.',
              style: TextStyle(
                fontSize: ResponsiveHelper.getFontSize(context,
                  mobile: 13, tablet: 14, desktop: 15),
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusInfoCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Color(0xFF1E88E5),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _parentStudentNames.isNotEmpty
                            ? _parentStudentNames.join('، ')
                            : 'طلاب',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E88E5),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        _students.isNotEmpty 
                            ? '${_students.length} طالب في الباص'
                            : 'لا يوجد طلاب',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.speed,
                    'السرعة',
                    '${_busSpeed.toStringAsFixed(1)} كم/س',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoItem(
                    Icons.access_time,
                    'آخر تحديث',
                    _formatLastUpdate(),
                    Colors.green,
                  ),
                ),
              ],
            ),
            if (_locationAddress != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationAddress!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1E88E5),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsButton() {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _showStudentsList,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(
                  Icons.people,
                  color: Color(0xFF1E88E5),
                ),
              ),
              if (_students.isNotEmpty)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_students.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الطلاب في الباص (${_students.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
                        child: Text(
                          student['name'].toString().substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF1E88E5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        student['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text('الصف: ${student['grade']}'),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastUpdate() {
    if (_lastUpdate == null) return 'لا يوجد';
    
    final now = DateTime.now();
    final difference = now.difference(_lastUpdate!);
    
    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} د';
    } else {
      return 'منذ ${difference.inHours} س';
    }
  }
}
