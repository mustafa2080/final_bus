# 🗺️ دليل استخدام Geoapify في مشروع KidsBus

## 📋 نظرة عامة

تم استبدال Google Maps بـ Geoapify في المشروع بالكامل. Geoapify يوفر خدمات خرائط مجانية وقوية باستخدام OpenStreetMap.

## 🔑 مفتاح API

```dart
API Key: 78333e9ccec04ca1ac6d969d6cda7fa8
```

المفتاح موجود في: `lib/config/geoapify_config.dart`

## 📦 المكتبات المستخدمة

```yaml
dependencies:
  flutter_map: ^7.0.2      # خريطة Flutter
  latlong2: ^0.9.1         # إحداثيات الموقع
  location: ^6.0.2         # خدمات الموقع
```

## 🎯 الملفات الرئيسية

### 1. **GeoapifyConfig** (`lib/config/geoapify_config.dart`)
ملف الإعدادات الرئيسي:

```dart
import 'package:kidsbus/config/geoapify_config.dart';

// الحصول على رابط الخريطة
String tileUrl = GeoapifyConfig.getTileUrl('osm-bright');

// API للبحث عن عنوان
String geocodingUrl = GeoapifyConfig.getGeocodingUrl('Cairo Egypt');

// API للبحث العكسي (من إحداثيات لعنوان)
String reverseUrl = GeoapifyConfig.getReverseGeocodingUrl(30.0444, 31.2357);

// API للحصول على مسار
String routeUrl = GeoapifyConfig.getRouteUrl(30.0444, 31.2357, 30.0500, 31.2400);
```

### 2. **GeoapifyMap Widget** (`lib/widgets/geoapify_map.dart`)
Widget جاهز للاستخدام:

```dart
import 'package:kidsbus/widgets/geoapify_map.dart';
import 'package:latlong2/latlong.dart';

GeoapifyMap(
  center: LatLng(30.0444, 31.2357), // القاهرة
  zoom: 13.0,
  markers: [
    // إضافة علامات على الخريطة
  ],
  onTap: (LatLng position) {
    print('تم النقر على: ${position.latitude}, ${position.longitude}');
  },
)
```

## 🎨 أنواع الخرائط المتاحة

| Style | الوصف |
|-------|-------|
| `osm-bright` | خريطة مشرقة (الافتراضي) ✨ |
| `osm-bright-grey` | خريطة رمادية 🌫️ |
| `dark-matter` | خريطة داكنة 🌙 |
| `positron` | خريطة فاتحة جداً ☀️ |
| `toner` | خريطة بالأبيض والأسود 🖤 |

### تغيير نوع الخريطة:

```dart
GeoapifyMap(
  style: 'dark-matter', // خريطة داكنة
  // ... باقي الإعدادات
)
```

## 📍 إضافة علامات (Markers)

### 1. علامة الباص 🚌

```dart
import 'package:kidsbus/widgets/geoapify_map.dart';

Marker busMarker = MapMarkerHelper.createBusMarker(
  position: LatLng(30.0444, 31.2357),
  busNumber: 'B-101',
  color: Colors.blue,
  onTap: () {
    print('تم النقر على الباص');
  },
);
```

### 2. علامة الطالب 👨‍🎓

```dart
Marker studentMarker = MapMarkerHelper.createStudentMarker(
  position: LatLng(30.0500, 31.2400),
  name: 'أحمد محمد',
  photoUrl: 'https://example.com/photo.jpg',
  onTap: () {
    print('تم النقر على الطالب');
  },
);
```

### 3. علامة موقع 📌

```dart
Marker pinMarker = MapMarkerHelper.createPinMarker(
  position: LatLng(30.0600, 31.2500),
  label: 'المدرسة',
  color: Colors.red,
  onTap: () {
    print('تم النقر على الموقع');
  },
);
```

## 🛣️ رسم مسارات (Polylines)

```dart
import 'package:flutter_map/flutter_map.dart';

List<Polyline> routes = [
  Polyline(
    points: [
      LatLng(30.0444, 31.2357),
      LatLng(30.0500, 31.2400),
      LatLng(30.0600, 31.2500),
    ],
    strokeWidth: 4.0,
    color: Colors.blue,
  ),
];

GeoapifyMap(
  polylines: routes,
  // ... باقي الإعدادات
)
```

## 🎮 التحكم في الخريطة

### استخدام MapController

```dart
import 'package:flutter_map/flutter_map.dart';

class MyMapScreen extends StatefulWidget {
  @override
  State<MyMapScreen> createState() => _MyMapScreenState();
}

class _MyMapScreenState extends State<MyMapScreen> {
  final MapController _mapController = MapController();

  void _moveToLocation() {
    _mapController.move(
      LatLng(30.0444, 31.2357),
      15.0, // مستوى التقريب
    );
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(
      _mapController.camera.center,
      currentZoom + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GeoapifyMap(
      controller: _mapController,
      // ... باقي الإعدادات
    );
  }
}
```

## 📱 مثال كامل: شاشة تتبع الطالب

```dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:kidsbus/widgets/geoapify_map.dart';
import 'package:flutter_map/flutter_map.dart';

class StudentTrackingScreen extends StatefulWidget {
  @override
  State<StudentTrackingScreen> createState() => _StudentTrackingScreenState();
}

class _StudentTrackingScreenState extends State<StudentTrackingScreen> {
  final MapController _mapController = MapController();
  
  LatLng _busLocation = LatLng(30.0444, 31.2357);
  LatLng _studentHome = LatLng(30.0600, 31.2500);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تتبع الطالب')),
      body: GeoapifyMap(
        center: _busLocation,
        zoom: 13.0,
        controller: _mapController,
        markers: [
          // علامة الباص
          MapMarkerHelper.createBusMarker(
            position: _busLocation,
            busNumber: 'B-101',
            color: Colors.blue,
          ),
          // علامة منزل الطالب
          MapMarkerHelper.createStudentMarker(
            position: _studentHome,
            name: 'أحمد محمد',
          ),
        ],
        polylines: [
          // رسم خط بين الباص والمنزل
          Polyline(
            points: [_busLocation, _studentHome],
            strokeWidth: 3.0,
            color: Colors.blue.withOpacity(0.7),
            isDotted: true,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // التركيز على الباص
          _mapController.move(_busLocation, 15.0);
        },
        child: Icon(Icons.directions_bus),
      ),
    );
  }
}
```

## 🌐 استخدام API للبحث عن عناوين

### البحث عن عنوان (Geocoding)

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kidsbus/config/geoapify_config.dart';

Future<LatLng?> searchAddress(String address) async {
  try {
    final url = GeoapifyConfig.getGeocodingUrl(address);
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'].isNotEmpty) {
        final coords = data['features'][0]['geometry']['coordinates'];
        return LatLng(coords[1], coords[0]); // [lng, lat] -> LatLng(lat, lng)
      }
    }
  } catch (e) {
    print('خطأ في البحث: $e');
  }
  return null;
}

// مثال استخدام
void _searchLocation() async {
  LatLng? location = await searchAddress('القاهرة، مصر');
  if (location != null) {
    _mapController.move(location, 13.0);
  }
}
```

### البحث العكسي (Reverse Geocoding)

```dart
Future<String?> getAddressFromCoordinates(double lat, double lng) async {
  try {
    final url = GeoapifyConfig.getReverseGeocodingUrl(lat, lng);
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'].isNotEmpty) {
        return data['features'][0]['properties']['formatted'];
      }
    }
  } catch (e) {
    print('خطأ في البحث العكسي: $e');
  }
  return null;
}

// مثال استخدام
void _getAddress() async {
  String? address = await getAddressFromCoordinates(30.0444, 31.2357);
  if (address != null) {
    print('العنوان: $address');
  }
}
```

## 📍 الحصول على الموقع الحالي

```dart
import 'package:location/location.dart';

class LocationHelper {
  static Future<LatLng?> getCurrentLocation() async {
    Location location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return null;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return null;
    }

    LocationData locationData = await location.getLocation();
    return LatLng(locationData.latitude!, locationData.longitude!);
  }
}

// مثال استخدام
void _goToMyLocation() async {
  LatLng? myLocation = await LocationHelper.getCurrentLocation();
  if (myLocation != null) {
    _mapController.move(myLocation, 15.0);
  }
}
```

## 🔧 نصائح وحيل

### 1. تحسين الأداء

```dart
GeoapifyMap(
  // تحديد حدود التقريب
  minZoom: 3.0,
  maxZoom: 18.0,
  
  // تعطيل الدوران لتحسين الأداء
  enableRotation: false,
)
```

### 2. التركيز على عدة نقاط

```dart
void _fitMultiplePoints(List<LatLng> points) {
  if (points.isEmpty) return;
  
  final bounds = LatLngBounds.fromPoints(points);
  _mapController.fitCamera(
    CameraFit.bounds(
      bounds: bounds,
      padding: EdgeInsets.all(50),
    ),
  );
}
```

### 3. تحديث موقع الباص في الوقت الفعلي

```dart
StreamSubscription<DocumentSnapshot>? _locationSubscription;

void _startTracking(String busId) {
  _locationSubscription = FirebaseFirestore.instance
    .collection('buses')
    .doc(busId)
    .snapshots()
    .listen((snapshot) {
      if (snapshot.exists) {
        final location = snapshot.data()!['currentLocation'];
        setState(() {
          _busLocation = LatLng(
            location['latitude'],
            location['longitude'],
          );
        });
      }
    });
}

@override
void dispose() {
  _locationSubscription?.cancel();
  super.dispose();
}
```

## ⚠️ مشاكل شائعة وحلولها

### 1. الخريطة لا تظهر

**السبب**: مشكلة في الاتصال بالإنترنت أو API Key خاطئ

**الحل**:
```dart
// تأكد من وجود الإنترنت
// تأكد من صحة API Key في geoapify_config.dart
```

### 2. العلامات لا تظهر

**السبب**: الإحداثيات خاطئة أو خارج نطاق الخريطة

**الحل**:
```dart
// تأكد من الإحداثيات صحيحة
// LatLng(latitude, longitude) وليس العكس
print('Lat: ${position.latitude}, Lng: ${position.longitude}');
```

### 3. الخريطة بطيئة

**الحل**:
```dart
// قلل عدد العلامات على الخريطة
// استخدم maxZoom و minZoom
// عطل الدوران enableRotation: false
```

## 📚 موارد إضافية

- [Geoapify Documentation](https://www.geoapify.com/docs/)
- [Flutter Map Documentation](https://docs.fleaflet.dev/)
- [Geoapify API Playground](https://apidocs.geoapify.com/playground/)

## 🎉 خلاصة

الآن لديك كل ما تحتاجه لاستخدام Geoapify في مشروع KidsBus:

✅ تم حذف Google Maps بالكامل
✅ تم إضافة Geoapify كبديل مجاني وقوي
✅ Widget جاهز للاستخدام (GeoapifyMap)
✅ أدوات مساعدة لإنشاء العلامات (MapMarkerHelper)
✅ أمثلة كاملة للاستخدام
✅ دعم البحث عن العناوين والمواقع
✅ دعم رسم المسارات
✅ دعم التتبع في الوقت الفعلي

**للمساعدة أو الأسئلة**:
- راجع هذا الملف
- راجع ملف المثال: `student_location_tracking_screen.dart`
- اقرأ [Geoapify Docs](https://www.geoapify.com/docs/)

---

**ملاحظة**: تذكر أن Geoapify لديه حدود استخدام مجانية يومية. راجع [خطط الأسعار](https://www.geoapify.com/pricing/) للتفاصيل.
