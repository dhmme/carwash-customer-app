import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../session.dart';

class PaymentPage extends StatefulWidget {
  final String baseUrl, date, time;
  final Map<String, dynamic> location, car, service;
  final List<Map<String, dynamic>> addOns;
  final double total;

  const PaymentPage({
    super.key,
    required this.baseUrl,
    required this.location,
    required this.car,
    required this.service,
    required this.addOns,
    required this.total,
    required this.date,
    required this.time,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String method = 'cash';
  bool sending = false;
  bool onlineConfigLoading = true;
  bool onlineEnabled = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadPaymentConfig();
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/payment-config/'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        onlineEnabled = data['online_enabled'] == true;
      }
    } catch (_) {
      onlineEnabled = false;
    } finally {
      if (mounted) setState(() => onlineConfigLoading = false);
    }
  }

  Future<void> submit() async {
    if (method == 'online' && !onlineEnabled) {
      setState(() => error = 'الدفع الإلكتروني غير مفعّل حاليًا.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/api/bookings/'),
        headers: Session.authHeaders,
        body: jsonEncode({
          'car': widget.car['id'],
          'service': widget.service['id'],
          'car_size': widget.car['size'],
          'address_text': widget.location['address_text'],
          'latitude': widget.location['latitude'],
          'longitude': widget.location['longitude'],
          'date': widget.date,
          'time_slot': widget.time,
          'payment_method': method,
          'add_ons': widget.addOns
              .map((item) => {'id': item['id'], 'quantity': item['quantity']})
              .toList(),
        }),
      );
      if (response.statusCode == 401) {
        await Session.handleUnauthorized();
        return;
      }
      if (!mounted) return;
      if (response.statusCode != 201) {
        setState(() => error = _apiError(response));
        return;
      }

      final booking = jsonDecode(response.body) as Map<String, dynamic>;
      if (method == 'online') {
        final checkoutUrl = booking['payment_checkout_url']?.toString() ?? '';
        if (checkoutUrl.isEmpty) {
          setState(
            () => error = 'تم إنشاء الطلب، لكن صفحة الدفع غير متاحة حاليًا.',
          );
          return;
        }
        final opened = await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
        if (!opened && mounted) {
          setState(() => error = 'تم إنشاء الطلب. أكمل الدفع من صفحة طلباتي.');
        }
        return;
      }

      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 55),
          title: const Text('تم تأكيد طلبك'),
          content: const Text('يمكنك متابعة حالة الطلب من صفحة الطلبات.'),
          actions: [
            FilledButton(
              onPressed: () =>
                  Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted)
        setState(() => error = 'تعذر الاتصال بالخادم. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String _apiError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final value =
            body['time_slot'] ?? body['payment_method'] ?? body['detail'];
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value != null) return value.toString();
      }
    } catch (_) {}
    return 'تعذر تأكيد الطلب، تحقق من أن الوقت ما زال متاحًا.';
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('الدفع')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'ملخص الطلب',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  row('الخدمة', widget.service['name']),
                  ...widget.addOns.map(
                    (item) => row(
                      item['name'],
                      '${item['quantity']} × ${item['price']} ر.س',
                    ),
                  ),
                  row(
                    'المركبة',
                    widget.car['vehicle_name'] ?? widget.car['brand'],
                  ),
                  row('الموقع', widget.location['name']),
                  row('الموعد', '${widget.date} • ${widget.time}'),
                  const Divider(),
                  row('الإجمالي', '${widget.total.toStringAsFixed(2)} ر.س'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'طريقة الدفع',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          RadioListTile<String>(
            value: 'online',
            groupValue: method,
            onChanged: onlineEnabled
                ? (value) => setState(() => method = value!)
                : null,
            title: const Text('دفع إلكتروني'),
            subtitle: Text(
              onlineConfigLoading
                  ? 'جاري التحقق من توفر الدفع...'
                  : onlineEnabled
                  ? 'مدى، Visa أو Mastercard — تجريبي حاليًا'
                  : 'سيظهر بعد تفعيل حساب ميسر التجريبي',
            ),
            secondary: const Icon(Icons.credit_card),
          ),
          RadioListTile<String>(
            value: 'cash',
            groupValue: method,
            onChanged: (value) => setState(() => method = value!),
            title: const Text('كاش'),
          ),
          RadioListTile<String>(
            value: 'card',
            groupValue: method,
            onChanged: (value) => setState(() => method = value!),
            title: const Text('شبكة عند الوصول'),
          ),
          RadioListTile<String>(
            value: 'bank_transfer',
            groupValue: method,
            onChanged: (value) => setState(() => method = value!),
            title: const Text('تحويل بنكي'),
          ),
          if (method == 'online')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'سيُحجز الموعد لمدة 15 دقيقة حتى تكتمل عملية الدفع.',
                style: TextStyle(color: Colors.lightBlueAccent),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: sending ? null : submit,
            child: sending
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    method == 'online'
                        ? 'المتابعة للدفع الإلكتروني'
                        : 'تأكيد الطلب',
                  ),
          ),
        ],
      ),
    ),
  );

  Widget row(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Flexible(
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}
