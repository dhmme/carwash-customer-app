import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPickerPage extends StatefulWidget {
  @override
  _MapPickerPageState createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("اختر موقعك على الخريطة")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(24.7136, 46.6753), // موقع افتراضي للرياض
          zoom: 14,
        ),
        onTap: (position) {
          setState(() {
            _selectedLocation = position;
          });
        },
        markers: _selectedLocation != null
            ? {
                Marker(
                  markerId: MarkerId("selected"),
                  position: _selectedLocation!,
                ),
              }
            : {},
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton(
          onPressed: _selectedLocation == null
              ? null
              : () {
                  Navigator.pop(context, _selectedLocation);
                },
          child: Text("تأكيد الموقع"),
        ),
      ),
    );
  }
}
