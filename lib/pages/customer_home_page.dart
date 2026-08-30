import 'package:flutter/material.dart';
import 'locations_page.dart';
import 'my_bookings_page.dart';
import 'services_page.dart';
import 'vehicles_page.dart';
import '../app_theme.dart';

class CustomerHomePage extends StatelessWidget {
  final String baseUrl;
  final VoidCallback onLogout;
  const CustomerHomePage({super.key, required this.baseUrl, required this.onLogout});
  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('طلب الخدمات', 'احجز خدمة جديدة', Icons.cleaning_services, AppColors.cerulean, () => _open(context, ServicesPage(baseUrl: baseUrl))),
      _Item('الطلبات', 'السابقة والحالية', Icons.receipt_long, AppColors.ceruleanDark, () => _open(context, MyBookingsPage(baseUrl: baseUrl))),
      _Item('المواقع', 'احفظ مواقع الخدمة', Icons.location_on, AppColors.sky, () => _open(context, LocationsPage(baseUrl: baseUrl))),
      _Item('المركبات', 'أضف وأدر مركباتك', Icons.directions_car, AppColors.navy, () => _open(context, VehiclesPage(baseUrl: baseUrl))),
    ];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('الرئيسية', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: onLogout, icon: const Icon(Icons.logout), tooltip: 'تسجيل الخروج')]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.navy, AppColors.ceruleanDark, AppColors.cerulean]), borderRadius: BorderRadius.circular(24)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أهلًا بك 👋', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            SizedBox(height: 6), Text('وش تحب نخدمك اليوم؟', style: TextStyle(color: Colors.white70, fontSize: 16))])),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (_, c) => GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: c.maxWidth > 650 ? 4 : 2,
            childAspectRatio: c.maxWidth > 650 ? 1.05 : .92, crossAxisSpacing: 14, mainAxisSpacing: 14),
          itemCount: items.length, itemBuilder: (_, i) => _Card(item: items[i]))),
      ]),
    ));
  }
  void _open(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _Item { final String title, subtitle; final IconData icon; final Color color; final VoidCallback tap;
  _Item(this.title, this.subtitle, this.icon, this.color, this.tap); }
class _Card extends StatelessWidget {
  final _Item item; const _Card({required this.item});
  @override Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(22), onTap: item.tap,
    child: Ink(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white,
      borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 28, backgroundColor: item.color.withValues(alpha: .12), child: Icon(item.icon, color: item.color, size: 30)),
        const Spacer(), Text(item.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5), Text(item.subtitle, style: const TextStyle(color: Colors.black54))])));
}
