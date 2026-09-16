import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import 'furniture_booking_page.dart';
import 'vehicle_booking_page.dart';

class ServicesPage extends StatefulWidget {
  final String baseUrl;
  const ServicesPage({super.key, required this.baseUrl});
  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  bool loading = true;
  List<Map<String, dynamic>> groups = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await http.get(
        Uri.parse('${widget.baseUrl}/api/service-groups/'),
      );
      if (r.statusCode == 200)
        groups = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  IconData icon(String key) => key == 'car_wash'
      ? Icons.local_car_wash
      : key == 'furniture_wash'
      ? Icons.chair
      : Icons.home_work;
  void open(Map<String, dynamic> group) {
    if (group['is_active'] != true) return;
    if (group['key'] == 'car_wash')
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VehicleBookingPage(baseUrl: widget.baseUrl),
        ),
      );
    if (group['key'] == 'furniture_wash')
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              FurnitureBookingPage(baseUrl: widget.baseUrl, group: group),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('طلب الخدمات')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: groups.map((g) {
                  final disabled = g['is_active'] != true;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: disabled ? AppColors.pale : AppColors.surface,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(18),
                      onTap: disabled ? null : () => open(g),
                      leading: CircleAvatar(
                        radius: 28,
                        child: Icon(icon(g['key'])),
                      ),
                      title: Text(
                        g['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Text(
                        disabled ? 'غير متاح حاليًا' : g['description'] ?? '',
                      ),
                      trailing: disabled
                          ? const Chip(label: Text('متوقف'))
                          : const Icon(Icons.chevron_left),
                    ),
                  );
                }).toList(),
              ),
            ),
    ),
  );
}
