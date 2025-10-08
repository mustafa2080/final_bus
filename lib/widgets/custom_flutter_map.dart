import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// خريطة مخصصة باستخدام Flutter Map مع OpenStreetMap
/// 
/// Features:
/// - خرائط مجانية من OpenStreetMap
/// - Custom markers
/// - أدوات تحكم تفاعلية
/// - أزرار التكبير والتصغير
/// - دعم الموقع الحالي
class CustomFlutterMap extends StatefulWidget {
  /// مركز الخريطة الأولي
  final LatLng center;

  /// مستوى التكبير الأولي (1-18)
  final double zoom;

  /// قائمة بالعلامات لعرضها على الخريطة
  final List<Marker> markers;

  /// نمط الخريطة
  final MapStyle style;

  /// إظهار/إخفاء أزرار التكبير
  final bool showZoomControls;

  /// تمكين/تعطيل دوران الخريطة
  final bool enableRotation;

  /// الحد الأدنى للتكبير
  final double minZoom;

  /// الحد الأقصى للتكبير
  final double maxZoom;

  /// يتم الاستدعاء عند النقر على الخريطة
  final void Function(LatLng)? onTap;

  /// يتم الاستدعاء عند الضغط الطويل على الخريطة
  final void Function(LatLng)? onLongPress;

  /// متحكم الخريطة للتحكم البرمجي
  final MapController? controller;

  /// إظهار زر الموقع الحالي
  final bool showLocationButton;

  /// علامة الموقع الحالي
  final LatLng? currentLocation;

  /// خطوط متعددة لرسمها على الخريطة (مثل المسارات)
  final List<Polyline> polylines;

  const CustomFlutterMap({
    super.key,
    this.center = const LatLng(30.0444, 31.2357), // القاهرة، مصر
    this.zoom = 13.0,
    this.markers = const [],
    this.style = MapStyle.standard,
    this.showZoomControls = true,
    this.enableRotation = false,
    this.minZoom = 3.0,
    this.maxZoom = 18.0,
    this.onTap,
    this.onLongPress,
    this.controller,
    this.showLocationButton = true,
    this.currentLocation,
    this.polylines = const [],
  });

  @override
  State<CustomFlutterMap> createState() => _CustomFlutterMapState();
}

class _CustomFlutterMapState extends State<CustomFlutterMap> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = widget.controller ?? MapController();
  }

  String _getTileUrl() {
    switch (widget.style) {
      case MapStyle.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapStyle.dark:
        return 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png';
      case MapStyle.satellite:
        // Esri World Imagery (مجاني)
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapStyle.terrain:
        return 'https://tiles.stadiamaps.com/tiles/outdoors/{z}/{x}/{y}{r}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: widget.zoom,
            minZoom: widget.minZoom,
            maxZoom: widget.maxZoom,
            interactionOptions: InteractionOptions(
              flags: widget.enableRotation
                  ? InteractiveFlag.all
                  : InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (tapPosition, point) {
              widget.onTap?.call(point);
            },
            onLongPress: (tapPosition, point) {
              widget.onLongPress?.call(point);
            },
          ),
          children: [
            // Tile Layer (الخرائط)
            TileLayer(
              urlTemplate: _getTileUrl(),
              userAgentPackageName: 'com.example.mybus',
              maxZoom: 20,
              tileProvider: NetworkTileProvider(),
            ),

            // Polylines Layer (المسارات)
            if (widget.polylines.isNotEmpty)
              PolylineLayer(
                polylines: widget.polylines,
              ),

            // Markers Layer (العلامات)
            MarkerLayer(
              markers: [
                ...widget.markers,
                // إضافة علامة الموقع الحالي إذا تم توفيرها
                if (widget.currentLocation != null)
                  Marker(
                    point: widget.currentLocation!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue,
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // أزرار التحكم بالتكبير
        if (widget.showZoomControls)
          Positioned(
            right: 16,
            bottom: 80,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
              ],
            ),
          ),

        // زر الموقع الحالي
        if (widget.showLocationButton && widget.currentLocation != null)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'current_location',
              onPressed: () {
                _mapController.move(
                  widget.currentLocation!,
                  15.0,
                );
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
      ],
    );
  }
}

/// أنماط الخرائط المتاحة
enum MapStyle {
  /// الخريطة القياسية من OpenStreetMap
  standard,
  
  /// خريطة داكنة
  dark,
  
  /// صور الأقمار الصناعية
  satellite,
  
  /// خريطة التضاريس
  terrain,
}

/// Helper class لإنشاء علامات مخصصة
class MapMarkerHelper {
  /// إنشاء علامة للباص
  static Marker createBusMarker({
    required LatLng position,
    required String busNumber,
    Color color = Colors.blue,
    VoidCallback? onTap,
  }) {
    return Marker(
      point: position,
      width: 80,
      height: 80,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                busNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              Icons.directions_bus,
              color: color,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  /// إنشاء علامة للطالب
  static Marker createStudentMarker({
    required LatLng position,
    required String name,
    String? photoUrl,
    VoidCallback? onTap,
  }) {
    return Marker(
      point: position,
      width: 60,
      height: 80,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: photoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// إنشاء علامة موقع عادية
  static Marker createPinMarker({
    required LatLng position,
    String? label,
    Color color = Colors.red,
    VoidCallback? onTap,
  }) {
    return Marker(
      point: position,
      width: 40,
      height: 60,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            if (label != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (label != null) const SizedBox(height: 4),
            Icon(
              Icons.location_pin,
              color: color,
              size: 40,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
