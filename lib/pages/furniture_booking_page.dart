import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import '../booking_time.dart';
import '../session.dart';
import 'payment_page.dart';

class FurnitureBookingPage extends StatefulWidget {
  final String baseUrl;
  final Map<String, dynamic> group;
  const FurnitureBookingPage({
    super.key,
    required this.baseUrl,
    required this.group,
  });
  @override
  State<FurnitureBookingPage> createState() => _FurnitureBookingPageState();
}

class _FurnitureBookingPageState extends State<FurnitureBookingPage> {
  bool loading = true, slotsLoading = false;
  List<Map<String, dynamic>> locations = [], services = [], timeSlots = [];
  final Map<int, int> quantities = {};
  Set<String> booked = {}, unavailable = {};
  Map<String, dynamic>? location, currentLocation;
  String? time;
  late List<DateTime> dates;
  late DateTime date;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dates = List.generate(
      4,
      (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)),
    );
    date = dates.first;
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    load();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String day(DateTime d) => [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ][d.weekday - 1];

  Future<void> load() async {
    final rs = await Future.wait([
      http.get(
        Uri.parse('${widget.baseUrl}/api/locations/'),
        headers: Session.authHeaders,
      ),
      http.get(
        Uri.parse('${widget.baseUrl}/api/services/?group=furniture_wash'),
      ),
      http.get(
        Uri.parse(
          '${widget.baseUrl}/api/booking-time-slots/?group=furniture_wash',
        ),
      ),
    ]);
    if (rs.first.statusCode == 401) {
      await Session.handleUnauthorized();
      return;
    }
    if (mounted)
      setState(() {
        locations = rs[0].statusCode == 200
            ? (jsonDecode(rs[0].body) as List).cast<Map<String, dynamic>>()
            : [];
        services = rs[1].statusCode == 200
            ? (jsonDecode(rs[1].body) as List).cast<Map<String, dynamic>>()
            : [];
        timeSlots = rs[2].statusCode == 200
            ? (jsonDecode(rs[2].body) as List).cast<Map<String, dynamic>>()
            : [];
        loading = false;
      });
    await loadSlots();
  }

  Future<void> loadSlots() async {
    setState(() {
      slotsLoading = true;
      time = null;
    });
    final r = await http.get(
      Uri.parse(
        '${widget.baseUrl}/api/booked-slots/?date=${iso(date)}&group=furniture_wash',
      ),
    );
    if (mounted)
      setState(() {
        final data = r.statusCode == 200
            ? jsonDecode(r.body)
            : <String, dynamic>{};
        booked = Set<String>.from(data['booked'] ?? []);
        unavailable = Set<String>.from(data['unavailable'] ?? []);
        slotsLoading = false;
      });
  }

  Future<void> useCurrent() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever)
        return;
      final x = await Geolocator.getCurrentPosition();
      setState(() {
        currentLocation = {
          'name': 'الموقع الحالي',
          'address_text': 'الموقع الحالي',
          'latitude': x.latitude,
          'longitude': x.longitude,
        };
        location = currentLocation;
      });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد الموقع الحالي')),
        );
    }
  }

  List<Map<String, dynamic>> selected() => services
      .where((x) => (quantities[x['id']] ?? 0) > 0)
      .map((x) => {...x, 'quantity': quantities[x['id']]!})
      .toList();
  double total() => selected().fold(
    0,
    (sum, x) =>
        sum +
        (double.tryParse(x['price'].toString()) ?? 0) * (x['quantity'] as int),
  );
  void next() {
    if (location == null || selected().isEmpty || time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل اختيار الموقع والخدمات والوقت')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          baseUrl: widget.baseUrl,
          location: location!,
          serviceGroup: widget.group,
          serviceItems: selected(),
          addOns: const [],
          total: total(),
          date: iso(date),
          time: time!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('غسيل الأثاث')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                title('اختر اليوم'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dates
                      .map(
                        (d) => ChoiceChip(
                          selected: date == d,
                          label: Text(
                            '${day(d)}\n${d.day}/${d.month}',
                            textAlign: TextAlign.center,
                          ),
                          onSelected: (_) {
                            setState(() => date = d);
                            loadSlots();
                          },
                        ),
                      )
                      .toList(),
                ),
                title('الموقع'),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: location,
                  decoration: const InputDecoration(
                    labelText: 'اختر موقعًا محفوظًا',
                  ),
                  items:
                      [
                            ...locations,
                            if (currentLocation != null) currentLocation!,
                          ]
                          .map(
                            (x) => DropdownMenuItem(
                              value: x,
                              child: Text(x['name']),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => location = v),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: useCurrent,
                  icon: const Icon(Icons.my_location),
                  label: const Text('استخدام الموقع الحالي'),
                ),
                title('الخدمات'),
                ...services.map((x) {
                  final id = x['id'] as int, q = quantities[id] ?? 0;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            child: Icon(
                              x['name'] == 'كنب'
                                  ? Icons.chair
                                  : x['name'] == 'سجاد'
                                  ? Icons.texture
                                  : Icons.weekend,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  x['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  '${x['price']} ر.س / ${x['unit']}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: q > 0
                                ? () => setState(() => quantities[id] = q - 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            '$q',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => quantities[id] = q + 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                title('الأوقات المتاحة'),
                if (slotsLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Builder(
                    builder: (_) {
                      final visible = timeSlots.where((s) {
                        final l = s['label'].toString();
                        return !unavailable.contains(l) &&
                            !isBookingSlotPast(date, s);
                      }).toList();
                      return visible.isEmpty
                          ? const Text('لا توجد أوقات متاحة لهذا اليوم')
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: visible.map((s) {
                                final l = s['label'].toString();
                                return ChoiceChip(
                                  label: Text(l),
                                  selected: time == l,
                                  onSelected: booked.contains(l)
                                      ? null
                                      : (_) => setState(() => time = l),
                                );
                              }).toList(),
                            );
                    },
                  ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        row('الخدمات المختارة', '${selected().length}'),
                        row(
                          'الإجمالي المبدئي',
                          '${total().toStringAsFixed(2)} ر.س',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: next,
                            child: const Text('تأكيد والانتقال للدفع'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
  Widget title(String value) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Text(
      value,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    ),
  );
  Widget row(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(a),
        Text(b, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
