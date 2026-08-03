import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:kidsbus/widgets/custom_flutter_map.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

/// Student Location Tracking Screen with Flutter Map
/// 
/// Real-time tracking of student location during bus trips
class StudentLocationTrackingScreen extends StatefulWidget {
  final String studentId;
  final String busId;

  const StudentLocationTrackingScreen({
    super.key,
    required this.studentId,
    required this.busId,
  });

  @override
  State<StudentLocationTrackingScreen> createState() =>
      _StudentLocationTrackingScreenState();
}

class _StudentLocationTrackingScreenState
    extends State<StudentLocationTrackingScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<DocumentSnapshot>? _studentSubscription;

  LatLng? _studentLocation;
  String _studentName = '';
  String? _studentPhotoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void didUpdateWidget(StudentLocationTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // منع إعادة التحميل إذا لم يتغير شيء
    if (oldWidget.studentId != widget.studentId || oldWidget.busId != widget.busId) {
      _initializeTracking();
    }
  }

  @override
  void dispose() {
    _studentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    if (!mounted) return;
    
    try {
      // جلب معلومات الطالب
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (!mounted) return;

      // معلومات الطالب
      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        _studentName = data['name'] ?? 'الطالب';
        _studentPhotoUrl = data['photoUrl'];
        
        // محاولة جلب الموقع من عدة حقول محتملة
        if (data['homeLocation'] != null) {
          final homeLocation = data['homeLocation'] as Map<String, dynamic>;
          if (homeLocation['latitude'] != null && homeLocation['longitude'] != null) {
            _studentLocation = LatLng(
              homeLocation['latitude'],
              homeLocation['longitude'],
            );
          }
        } else if (data['location'] != null) {
          // جرب location إذا لم يكن homeLocation موجود
          final location = data['location'] as Map<String, dynamic>;
          if (location['latitude'] != null && location['longitude'] != null) {
            _studentLocation = LatLng(
              location['latitude'],
              location['longitude'],
            );
          }
        }
        
        debugPrint('✅ موقع الطالب: $_studentLocation');
        debugPrint('✅ اسم الطالب: $_studentName');
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // البدء في الاستماع للتحديثات
      _studentSubscription = FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          setState(() {
            _studentName = data['name'] ?? 'الطالب';
            _studentPhotoUrl = data['photoUrl'];
            
            // تحديث الموقع
            if (data['homeLocation'] != null) {
              final homeLocation = data['homeLocation'] as Map<String, dynamic>;
              if (homeLocation['latitude'] != null && homeLocation['longitude'] != null) {
                _studentLocation = LatLng(
                  homeLocation['latitude'],
                  homeLocation['longitude'],
                );
              }
            } else if (data['location'] != null) {
              final location = data['location'] as Map<String, dynamic>;
              if (location['latitude'] != null && location['longitude'] != null) {
                _studentLocation = LatLng(
                  location['latitude'],
                  location['longitude'],
                );
              }
            }
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Add student home marker only
    if (_studentLocation != null) {
      markers.add(
        MapMarkerHelper.createStudentMarker(
          position: _studentLocation!,
          name: _studentName,
          photoUrl: _studentPhotoUrl,
          onTap: () {
            _showStudentInfo();
          },
        ),
      );
    }

    return markers;
  }

  void _showStudentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (_studentPhotoUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(_studentPhotoUrl!),
                radius: 20,
              )
            else
              const CircleAvatar(
                child: Icon(Icons.person),
                radius: 20,
              ),
            const SizedBox(width: 8),
            Expanded(child: Text(_studentName)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_studentLocation != null) ...[
              const Text(
                'موقع المنزل:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'خط العرض: ${_studentLocation!.latitude.toStringAsFixed(6)}',
              ),
              Text(
                'خط الطول: ${_studentLocation!.longitude.toStringAsFixed(6)}',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _centerOnStudent() {
    if (_studentLocation != null) {
      _mapController.move(_studentLocation!, 15.0);
    } else {
      // إظهار رسالة لتحديد موقع المنزل
      _showSetHomeLocationDialog();
    }
  }

  void _showSetHomeLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.home, color: Colors.orange),
            SizedBox(width: 8),
            Text('تحديد موقع المنزل'),
          ],
        ),
        content: const Text(
          'لم يتم تحديد موقع منزل الطالب بعد.\n\n'
          'يمكنك الضغط على الخريطة لتحديد موقع المنزل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _confirmSetHomeLocation(LatLng location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.home, color: Colors.blue),
            SizedBox(width: 8),
            Text('تأكيد موقع المنزل'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل تريد حفظ هذا الموقع كموقع للمنزل؟'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خط العرض: ${location.latitude.toStringAsFixed(6)}'),
                  Text('خط الطول: ${location.longitude.toStringAsFixed(6)}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _setHomeLocation(location);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _setHomeLocation(LatLng location) async {
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .update({
        'homeLocation': {
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ موقع المنزل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ الموقع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('موقع $_studentName'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري تحميل الموقع...'),
                ],
              ),
            )
          : Stack(
              children: [
                CustomFlutterMap(
                  center: _studentLocation ?? const LatLng(30.0444, 31.2357),
                  zoom: 13.0,
                  markers: _buildMarkers(),
                  polylines: const [],
                  controller: _mapController,
                  showZoomControls: true,
                  showLocationButton: false,
                  style: MapStyle.standard,
                  onTap: _studentLocation == null
                      ? (latLng) => _confirmSetHomeLocation(latLng)
                      : null,
                ),
                // Info Card
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _studentLocation != null ? Icons.person : Icons.location_off,
                            color: _studentLocation != null ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الطالب: $_studentName',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_studentLocation == null)
                                  const Text(
                                    'اضغط على الخريطة لتحديد موقع المنزل',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_studentLocation != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.home,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'في المنزل',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Control Buttons
                Positioned(
                  left: 16,
                  bottom: 80,
                  child: Column(
                    children: [
                      // زر التوسيط على موقع الطالب
                      FloatingActionButton.small(
                        heroTag: 'center_student',
                        onPressed: _centerOnStudent,
                        backgroundColor: Colors.green,
                        tooltip: 'موقع منزل الطالب',
                        child: const Icon(Icons.home, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      // زر عرض تفاصيل الطالب
                      FloatingActionButton.small(
                        heroTag: 'student_info',
                        onPressed: _showStudentInfo,
                        backgroundColor: Colors.blue,
                        tooltip: 'معلومات الطالب',
                        child: const Icon(Icons.info, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
