import 'package:flutter/material.dart';
import 'vehicle_booking_page.dart';
import '../app_theme.dart';

class ServicesPage extends StatelessWidget {
  final String baseUrl; const ServicesPage({super.key, required this.baseUrl});
  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('طلب الخدمات')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      _tile('غسيل السيارات', 'احجز غسيل مركبتك في موقعك', Icons.local_car_wash, false,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleBookingPage(baseUrl: baseUrl)))),
      _tile('غسيل الأثاث', 'قريبًا', Icons.chair, true, null),
      _tile('غسيل الأحواش', 'قريبًا', Icons.home_work, true, null),
    ])));
  Widget _tile(String title, String subtitle, IconData icon, bool disabled, VoidCallback? tap) =>
    Card(margin: const EdgeInsets.only(bottom: 12), color: disabled ? AppColors.pale : AppColors.surface,
      child: ListTile(contentPadding: const EdgeInsets.all(18), onTap: tap, leading: CircleAvatar(radius: 28, child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), subtitle: Text(subtitle),
        trailing: disabled ? const Chip(label: Text('قريبًا')) : const Icon(Icons.chevron_left)));
}
