import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  static const _defaultLocation = LatLng(26.0841, 43.9735);
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission denied');
      }

      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _selectedLocation = point);
      _mapController.move(point, 17);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد موقعك. اختر الموقع يدويًا على الخريطة.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('اختر موقعك على الخريطة')),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultLocation,
                initialZoom: 14,
                onTap: (_, position) {
                  setState(() => _selectedLocation = position);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'sa.codecare.customer',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 54,
                        height: 54,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFF29B6D8),
                          size: 50,
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            PositionedDirectional(
              end: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                heroTag: 'current-location',
                onPressed: _locating ? null : _useCurrentLocation,
                tooltip: 'استخدام موقعي الحالي',
                child: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _selectedLocation == null
                ? null
                : () => Navigator.pop(context, _selectedLocation),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('تأكيد الموقع'),
          ),
        ),
      ),
    );
  }
}
