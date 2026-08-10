import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../session.dart';

class MyBookingsPage extends StatefulWidget {
  final String baseUrl;

  const MyBookingsPage({super.key, required this.baseUrl});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/bookings/'),
        headers: Session.authHeaders,
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        setState(() => _bookings = list.cast<Map<String, dynamic>>());
      } else {
        setState(() => _error = 'تعذر تحميل الطلبات.');
      }
    } catch (_) {
      setState(() => _error = 'تعذر الاتصال بالخادم.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _status(String value) => switch (value) {
        'pending' => 'بانتظار الموافقة',
        'accepted' => 'تمت الموافقة',
        'on_the_way' => 'العامل في الطريق',
        'in_progress' => 'جاري الغسيل',
        'completed' => 'مكتمل',
        'canceled' => 'ملغي',
        _ => value,
      };

  Color _statusColor(String value) => switch (value) {
        'accepted' => Colors.blue,
        'on_the_way' => Colors.indigo,
        'in_progress' => Colors.green,
        'completed' => Colors.teal,
        'canceled' => Colors.red,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 180),
                    Center(child: Text(_error!)),
                  ])
                : _bookings.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 180),
                        Center(child: Text('لا توجد طلبات حتى الآن')),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final booking = _bookings[index];
                          final status = booking['status']?.toString() ?? '';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(status),
                                child: const Icon(Icons.local_car_wash,
                                    color: Colors.white),
                              ),
                              title: Text(booking['service_name']?.toString() ??
                                  'غسيل سيارات'),
                              subtitle: Text(
                                '${booking['date']} • ${booking['time_slot']}\n'
                                '${_status(status)}',
                              ),
                              isThreeLine: true,
                              trailing: Text('${booking['total_price']} ر.س'),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
