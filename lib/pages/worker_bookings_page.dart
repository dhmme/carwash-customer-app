import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../session.dart';

const baseUrl = 'https://carwash-backend-2yz2.onrender.com';

class WorkerBooking {
  final int id;
  final String date, timeSlot, status, customerName, customerPhone;
  final String carName, carColor, plateNumber, serviceName, addressText;
  final String mapsUrl, totalPrice, paymentMethod;
  final List<Map<String, dynamic>> addOns;
  WorkerBooking.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0, date = j['date'] ?? '', timeSlot = j['time_slot'] ?? '',
        status = j['status'] ?? '', customerName = j['customer_name'] ?? '',
        customerPhone = j['customer_phone'] ?? '', carName = j['car_name'] ?? 'مركبة',
        carColor = j['car_color'] ?? '', plateNumber = j['plate_number'] ?? '',
        serviceName = j['service_name'] ?? '', addressText = j['address_text'] ?? '',
        mapsUrl = j['maps_url'] ?? '', totalPrice = '${j['total_price'] ?? ''}',
        paymentMethod = j['payment_method'] ?? '',
        addOns = List<Map<String, dynamic>>.from(j['add_ons'] ?? const []);
}

class WorkerBookingsPage extends StatefulWidget {
  final VoidCallback? onLogout;
  const WorkerBookingsPage({super.key, this.onLogout});
  @override State<WorkerBookingsPage> createState() => _WorkerBookingsPageState();
}

class _WorkerBookingsPageState extends State<WorkerBookingsPage> {
  bool loading = true;
  String? error;
  List<WorkerBooking> bookings = [];
  @override void initState() { super.initState(); loadBookings(); }

  Future<void> loadBookings() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await http.get(Uri.parse('$baseUrl/api/worker/bookings/'), headers: Session.authHeaders);
      if (r.statusCode == 401 || r.statusCode == 403) { await Session.handleUnauthorized(); return; }
      if (r.statusCode != 200) throw Exception();
      final data = jsonDecode(r.body) as List;
      if (mounted) setState(() => bookings = data.map((e) => WorkerBooking.fromJson(e)).toList());
    } catch (_) { if (mounted) setState(() => error = 'تعذر تحميل حجوزات اليوم'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> updateStatus(WorkerBooking b, String status) async {
    final r = await http.patch(Uri.parse('$baseUrl/api/worker/bookings/${b.id}/status/'),
      headers: Session.authHeaders, body: jsonEncode({'status': status}));
    if (r.statusCode == 401 || r.statusCode == 403) await Session.handleUnauthorized();
    else if (r.statusCode == 200) await loadBookings();
    else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديث الحالة')));
  }

  Future<void> launch(String value) async {
    final uri = Uri.parse(value);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(foregroundColor: AppColors.text, title: const Text('طلبات اليوم'), actions: [
      IconButton(onPressed: loadBookings, icon: const Icon(Icons.refresh)),
      if (widget.onLogout != null) IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
    ]),
    body: RefreshIndicator(onRefresh: loadBookings, child: loading
      ? const Center(child: CircularProgressIndicator())
      : error != null ? ListView(children: [const SizedBox(height: 260), Center(child: Text(error!))])
      : bookings.isEmpty ? ListView(children: const [SizedBox(height: 260), Center(child: Text('لا توجد طلبات اليوم'))])
      : ListView.separated(padding: const EdgeInsets.all(16), itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _BookingCard(booking: bookings[i],
            onStatus: (s) => updateStatus(bookings[i], s),
            onCall: () => launch('tel:${bookings[i].customerPhone}'),
            onMap: () => launch(bookings[i].mapsUrl)))),
  );
}

class _BookingCard extends StatelessWidget {
  final WorkerBooking booking;
  final ValueChanged<String> onStatus;
  final VoidCallback onCall, onMap;
  const _BookingCard({required this.booking, required this.onStatus, required this.onCall, required this.onMap});
  static const names = {'pending':'بانتظار القبول','accepted':'تم القبول','on_the_way':'في الطريق','in_progress':'قيد التنفيذ','completed':'مكتمل','canceled':'ملغي'};
  static const next = {'pending':('accepted','قبول الطلب'),'accepted':('on_the_way','بدء التوجه'),'on_the_way':('in_progress','بدء الغسيل'),'in_progress':('completed','إنهاء الطلب')};
  Widget info(IconData icon, String value) => Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(icon,size:19),const SizedBox(width:8),Expanded(child:Text(value))]));

  @override Widget build(BuildContext context) {
    final action = next[booking.status];
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(booking.timeSlot,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const Spacer(),Chip(label:Text(names[booking.status] ?? booking.status))]),
      info(Icons.person,'${booking.customerName} — ${booking.customerPhone}'),
      info(Icons.directions_car,'${booking.carName} • ${booking.carColor} • ${booking.plateNumber}'),
      info(Icons.local_car_wash,booking.serviceName),
      if (booking.addOns.isNotEmpty) info(Icons.add_circle_outline,booking.addOns.map((a)=>'${a['name']} × ${a['quantity']}').join('، ')),
      info(Icons.location_on,booking.addressText.isEmpty?'الموقع المحدد على الخريطة':booking.addressText),
      info(Icons.payments,'${booking.totalPrice} ر.س • ${booking.paymentMethod}'),
      const SizedBox(height:14),
      Row(children:[Expanded(child:OutlinedButton.icon(onPressed:booking.customerPhone.isEmpty?null:onCall,icon:const Icon(Icons.phone),label:const Text('اتصال'))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:booking.mapsUrl.isEmpty?null:onMap,icon:const Icon(Icons.navigation),label:const Text('الموقع')))]),
      if(action!=null)...[const SizedBox(height:10),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>onStatus(action.$1),child:Text(action.$2)))],
      if(booking.status!='completed'&&booking.status!='canceled') Align(alignment:Alignment.center,child:TextButton(onPressed:()=>onStatus('canceled'),child:const Text('إلغاء الطلب'))),
    ])));
  }
}
