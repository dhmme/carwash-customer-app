import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../session.dart';

class PackagesPage extends StatefulWidget {
  final String baseUrl;
  const PackagesPage({super.key, required this.baseUrl});
  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  bool loading = true;
  List<Map<String, dynamic>> plans = [], owned = [], methods = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final values = await Future.wait([
      http.get(Uri.parse('${widget.baseUrl}/api/packages/')),
      http.get(
        Uri.parse('${widget.baseUrl}/api/customer-packages/'),
        headers: Session.authHeaders,
      ),
      http.get(Uri.parse('${widget.baseUrl}/api/payment-config/')),
    ]);
    if (!mounted) return;
    setState(() {
      plans = values[0].statusCode == 200
          ? (jsonDecode(values[0].body) as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : [];
      owned = values[1].statusCode == 200
          ? (jsonDecode(values[1].body) as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : [];
      final config = values[2].statusCode == 200
          ? jsonDecode(values[2].body)
          : {};
      methods = (config['methods'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e['requires_gateway'] != true)
          .toList();
      if (methods.isEmpty) {
        methods = [
          {'code': 'cash', 'name': 'كاش'},
        ];
      }
      loading = false;
    });
  }

  Future<void> buy(Map<String, dynamic> plan) async {
    String method = methods.isEmpty
        ? 'bank_transfer'
        : methods.first['code'].toString();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('شراء ${plan['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${plan['washes_count']} غسلات كاملة • ${plan['price']} ر.س',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: methods
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['code'].toString(),
                        child: Text(m['name'].toString()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => method = v!),
              ),
              if (methods.any(
                (m) =>
                    m['code'] == method &&
                    (m['instructions']?.toString() ?? '').isNotEmpty,
              ))
                ListTile(
                  title: Text(
                    methods
                        .firstWhere((m) => m['code'] == method)['instructions']
                        .toString(),
                  ),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('نسخ'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: methods
                              .firstWhere(
                                (m) => m['code'] == method,
                              )['instructions']
                              .toString(),
                        ),
                      );
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ بيانات التحويل'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              const SizedBox(height: 8),
              const Text('يُفعّل الرصيد بعد مراجعة الإدارة للدفع.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إرسال الطلب'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final response = await http.post(
      Uri.parse('${widget.baseUrl}/api/customer-packages/'),
      headers: Session.authHeaders,
      body: jsonEncode({'plan': plan['id'], 'payment_method': method}),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.statusCode == 201
              ? 'تم إرسال طلب الباقة للإدارة'
              : 'تعذر إرسال الطلب',
        ),
      ),
    );
    if (response.statusCode == 201) load();
  }

  String statusName(String value) =>
      {
        'pending': 'بانتظار الاعتماد',
        'active': 'نشطة',
        'rejected': 'مرفوضة',
        'expired': 'منتهية',
      }[value] ??
      value;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('باقات الغسيل')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'باقاتي',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (owned.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('لا توجد باقات حتى الآن'),
                      ),
                    ),
                  ...owned.map(
                    (p) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.confirmation_number),
                        title: Text(p['plan_name'].toString()),
                        subtitle: Text(
                          '${statusName(p['status'].toString())} • متبقي ${p['remaining_washes']} غسلات\nصالحة حتى: ${p['expires_at']?.toString().split('T').first ?? '-'}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'الباقات المتاحة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ...plans.map(
                    (p) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.local_car_wash),
                        title: Text(p['name'].toString()),
                        subtitle: Text(
                          '${p['washes_count']} غسلات كاملة • صالحة ${p['validity_days']} يومًا\nتشمل: ${p['included_service_name']}',
                        ),
                        trailing: FilledButton(
                          onPressed: () => buy(p),
                          child: Text('${p['price']} ر.س'),
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
