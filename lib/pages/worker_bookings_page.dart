import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../session.dart';
import '../app_theme.dart';

// رابط الباك إند
const String baseUrl = 'https://carwash-backend-2yz2.onrender.com';

class WorkerBooking {
  final int id;
  final String date;
  final String timeSlot;
  final String status;

  final String customerName;
  final String customerPhone;
  final String carSize; // small / large

  final String serviceName;

  final double? latitude;
  final double? longitude;
  final String? mapsUrl;

  WorkerBooking({
    required this.id,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.carSize,
    required this.serviceName,
    this.latitude,
    this.longitude,
    this.mapsUrl,
  });

  factory WorkerBooking.fromJson(Map<String, dynamic> json) {
    return WorkerBooking(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      timeSlot: json['time_slot'] ?? '',
      status: json['status'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      carSize: json['car_size'] ?? '',
      serviceName: json['service_name'] ?? '',
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      mapsUrl: json['maps_url'],
    );
  }
}

class WorkerBookingsPage extends StatefulWidget {
  final VoidCallback? onLogout;

  const WorkerBookingsPage({super.key, this.onLogout});

  @override
  State<WorkerBookingsPage> createState() => _WorkerBookingsPageState();
}

class _WorkerBookingsPageState extends State<WorkerBookingsPage> {
  bool _isLoading = false;
  String? _error;
  List<WorkerBooking> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('$baseUrl/api/worker/bookings/');
      final res = await http.get(url, headers: Session.authHeaders);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final list = data.map((e) => WorkerBooking.fromJson(e)).toList();
        setState(() {
          _bookings = list;
        });
      } else {
        setState(() {
          _error = 'خطأ في تحميل الحجوزات (${res.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'خطأ في الاتصال: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'on_the_way':
        return Colors.indigo;
      case 'in_progress':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'pending':
        return 'بانتظار القبول';
      case 'accepted':
        return 'مقبول';
      case 'on_the_way':
        return 'في الطريق';
      case 'in_progress':
        return 'جاري التنفيذ';
      case 'completed':
        return 'مكتمل';
      case 'canceled':
        return 'ملغي';
      default:
        return s;
    }
  }

  Future<void> _openMap(String? urlStr) async {
    if (urlStr == null || urlStr.isEmpty) return;

    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer(String phone) async {
    if (phone.trim().isEmpty) return;

    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _updateStatus(int bookingId, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/api/worker/bookings/$bookingId/status/'),
      headers: Session.authHeaders,
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 200) {
      await _loadBookings();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث حالة الطلب')),
      );
    }
  }

  String _carSizeArabic(String size) {
    if (size == "small") return "سيارة صغيرة";
    if (size == "large") return "سيارة كبيرة";
    return "غير محدد";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navy, AppColors.ceruleanDark, AppColors.cerulean],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // عنوان الصفحة
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.handyman, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(child: Text(
                      'حجوزات اليوم للعمّال',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    if (widget.onLogout != null)
                      IconButton(
                        onPressed: widget.onLogout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: RefreshIndicator(
                    onRefresh: _loadBookings,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _error != null
                            ? Center(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            : _bookings.isEmpty
                                ? const Center(
                                    child: Text(
                                      'لا يوجد حجوزات لليوم 👌',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.only(top: 16),
                                    itemCount: _bookings.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 14),
                                    itemBuilder: (_, index) {
                                      final b = _bookings[index];
                                      return _BookingCard(
                                        booking: b,
                                        onMap: () => _openMap(b.mapsUrl),
                                        onCall: () => _callCustomer(b.customerPhone),
                                        onStatus: (status) =>
                                            _updateStatus(b.id, status),
                                      );
                                    },
                                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final WorkerBooking booking;
  final VoidCallback onMap;
  final VoidCallback onCall;
  final ValueChanged<String> onStatus;

  const _BookingCard({
    required this.booking,
    required this.onMap,
    required this.onCall,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = Colors.black87;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // وقت الحجز
            Row(
              children: [
                Icon(Icons.access_time, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 4),
                Text(
                  booking.timeSlot,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  booking.date,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // اسم العميل
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    booking.customerName.isEmpty
                        ? "اسم غير مسجل"
                        : booking.customerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // حجم السيارة
            Row(
              children: [
                const Icon(Icons.directions_car, size: 20, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  booking.carSize == "small"
                      ? "سيارة صغيرة"
                      : booking.carSize == "large"
                          ? "سيارة كبيرة"
                          : "غير محدد",
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // رقم الجوال
            Row(
              children: [
                const Icon(Icons.phone, size: 20, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  booking.customerPhone.isEmpty
                      ? "بدون رقم"
                      : booking.customerPhone,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // نوع الخدمة
            Row(
              children: [
                const Icon(Icons.local_car_wash,
                    size: 20, color: Colors.black54),
                const SizedBox(width: 6),
                Text(
                  booking.serviceName,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: booking.mapsUrl == null ? null : onMap,
                    icon: const Icon(Icons.location_on),
                    label: const Text("الموقع على الخريطة"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: booking.customerPhone.isEmpty ? null : onCall,
                    icon: const Icon(Icons.call),
                    label: const Text("اتصال بالعميل"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<String>(
                initialValue: booking.status,
                decoration: const InputDecoration(
                  labelText: 'تحديث حالة الطلب',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('بانتظار القبول')),
                  DropdownMenuItem(value: 'accepted', child: Text('مقبول')),
                  DropdownMenuItem(value: 'on_the_way', child: Text('في الطريق')),
                  DropdownMenuItem(value: 'in_progress', child: Text('جاري التنفيذ')),
                  DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                  DropdownMenuItem(value: 'canceled', child: Text('ملغي')),
                ],
                onChanged: (value) {
                  if (value != null && value != booking.status) {
                    onStatus(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
