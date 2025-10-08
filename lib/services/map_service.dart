import 'package:http/http.dart' as http;
import 'dart:convert';
// استيراد math للحسابات
import 'dart:math' as math;

/// خدمة الخرائط باستخدام OpenStreetMap و Nominatim
/// 
/// هذه الخدمة توفر:
/// - Reverse Geocoding (تحويل الإحداثيات إلى عنوان)
/// - Geocoding (البحث عن موقع)
/// - حساب المسافة بين نقطتين
class MapService {
  // استخدام Nominatim API المجاني من OpenStreetMap
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  
  // User agent مطلوب لـ Nominatim
  static const String _userAgent = 'MyBusApp/1.0';

  /// الحصول على عنوان من الإحداثيات (Reverse Geocoding)
  static Future<String?> getAddressFromCoordinates({
    required double lat,
    required double lon,
  }) async {
    try {
      final url = Uri.parse(
        '$_nominatimBaseUrl/reverse?lat=$lat&lon=$lon&format=json&accept-language=ar',
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  /// البحث عن موقع (Geocoding)
  static Future<Map<String, dynamic>?> searchLocation(String query) async {
    try {
      final url = Uri.parse(
        '$_nominatimBaseUrl/search?q=$query&format=json&accept-language=ar&limit=1',
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': _userAgent,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final result = data[0];
          return {
            'lat': double.parse(result['lat']),
            'lon': double.parse(result['lon']),
            'name': result['display_name'],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error searching location: $e');
      return null;
    }
  }

  /// حساب المسافة بين نقطتين (بالمتر)
  /// يستخدم صيغة Haversine
  static double calculateDistance({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    const double earthRadius = 6371000; // متر

    final double dLat = _toRadians(endLat - startLat);
    final double dLon = _toRadians(endLon - startLon);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(startLat)) *
            math.cos(_toRadians(endLat)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// تحويل الدرجات إلى راديان
  static double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// حساب المسافة والوقت التقريبي للوصول
  static Future<Map<String, dynamic>?> calculateRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    try {
      // حساب المسافة المباشرة
      final distance = calculateDistance(
        startLat: startLat,
        startLon: startLon,
        endLat: endLat,
        endLon: endLon,
      );

      // تقدير الوقت (بافتراض سرعة 40 كم/ساعة في المدينة)
      const double averageSpeed = 40 * 1000 / 3600; // 40 كم/ساعة بالمتر/ثانية
      final time = distance / averageSpeed;

      return {
        'distance': distance, // بالمتر
        'time': time, // بالثانية
      };
    } catch (e) {
      print('Error calculating route: $e');
      return null;
    }
  }
}

