import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

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
  const WorkerBookingsPage({super.key});

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
      final res = await http.get(url);

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
            colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
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
                  children: const [
                    Icon(Icons.handyman, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'حجوزات اليوم للعمّال',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
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

  const _BookingCard({
    required this.booking,
    required this.onMap,
    required this.onCall,
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
            )
          ],
        ),
      ),
    );
  }
}
