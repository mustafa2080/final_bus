import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:kidsbus/widgets/geoapify_map.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kidsbus/config/geoapify_config.dart';

/// Location Picker Dialog
/// 
/// Dialog لاختيار موقع على الخريطة مع إمكانية البحث
class LocationPickerDialog extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;

  const LocationPickerDialog({
    super.key,
    this.initialLocation,
    this.title = 'اختر الموقع',
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedAddress;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? const LatLng(30.0444, 31.2357);
    if (widget.initialLocation != null) {
      _getAddressFromCoordinates(_selectedLocation);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    try {
      final url = GeoapifyConfig.getReverseGeocodingUrl(
        location.latitude,
        location.longitude,
      );
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'].isNotEmpty) {
          setState(() {
            _selectedAddress = data['features'][0]['properties']['formatted'];
          });
        }
      }
    } catch (e) {
      debugPrint('خطأ في البحث العكسي: $e');
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final url = GeoapifyConfig.getGeocodingUrl(query);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = (data['features'] as List)
              .map((feature) => {
                    'name': feature['properties']['formatted'] ?? '',
                    'lat': feature['geometry']['coordinates'][1],
                    'lng': feature['geometry']['coordinates'][0],
                  })
              .toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('خطأ في البحث: $e');
      setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final location = LatLng(result['lat'], result['lng']);
    setState(() {
      _selectedLocation = location;
      _selectedAddress = result['name'];
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(location, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن عنوان...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                if (value.length >= 3) {
                  _searchLocation(value);
                } else {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
            const SizedBox(height: 8),

            // Search Results
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              )
            else if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(
                        result['name'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectSearchResult(result),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // Map
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    GeoapifyMap(
                      center: _selectedLocation,
                      zoom: 15.0,
                      controller: _mapController,
                      markers: [
                        MapMarkerHelper.createPinMarker(
                          position: _selectedLocation,
                          color: Colors.red,
                        ),
                      ],
                      onTap: (position) {
                        setState(() {
                          _selectedLocation = position;
                          _selectedAddress = null;
                        });
                        _getAddressFromCoordinates(position);
                      },
                      showZoomControls: true,
                      showLocationButton: false,
                    ),
                    // Center Crosshair (optional)
                    Center(
                      child: IgnorePointer(
                        child: Icon(
                          Icons.add,
                          size: 40,
                          color: Colors.red.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Address Info
            if (_selectedAddress != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAddress!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Coordinates Info
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.my_location, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'خط العرض: ${_selectedLocation.latitude.toStringAsFixed(6)} | '
                    'خط الطول: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'location': _selectedLocation,
                        'address': _selectedAddress,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('تأكيد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show location picker
Future<Map<String, dynamic>?> showLocationPicker({
  required BuildContext context,
  LatLng? initialLocation,
  String title = 'اختر الموقع',
}) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => LocationPickerDialog(
      initialLocation: initialLocation,
      title: title,
    ),
  );
}
