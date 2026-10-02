import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
      if (response.statusCode == 401) {
        await Session.handleUnauthorized();
        return;
      }
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

  String _status(String value, String paymentStatus) => switch (value) {
    'pending' when paymentStatus == 'pending' => 'بانتظار الدفع',
    'pending' => 'الحجز قيد المعالجة',
    'accepted' => 'الحجز مؤكد',
    'on_the_way' => 'العامل في الطريق',
    'in_progress' => 'جاري الغسيل',
    'completed' => 'مكتمل',
    'canceled' => 'ملغي',
    _ => value,
  };

  String _paymentStatus(String value) => switch (value) {
    'paid' => 'مدفوع إلكترونيًا',
    'failed' => 'فشل الدفع',
    'expired' => 'انتهت مهلة الدفع',
    _ => '',
  };

  Color _statusColor(String value) => switch (value) {
    'accepted' => Colors.blue,
    'on_the_way' => Colors.indigo,
    'in_progress' => Colors.green,
    'completed' => Colors.teal,
    'canceled' => Colors.red,
    _ => Colors.orange,
  };

  Future<void> _openInvoice(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الفاتورة. حاول مرة أخرى.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الفاتورة. حاول مرة أخرى.')),
        );
      }
    }
  }

  Future<void> _openCheckout(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح صفحة الدفع. حاول مرة أخرى.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح صفحة الدفع. حاول مرة أخرى.')),
        );
      }
    }
  }

  Future<http.Response> _sendCancellation(
    Map<String, dynamic> booking, {
    bool retryAfterRefresh = true,
  }) async {
    final response = await http.post(
      Uri.parse('${widget.baseUrl}/api/bookings/${booking['id']}/cancel/'),
      headers: Session.authHeaders,
    );
    if (response.statusCode == 401 &&
        retryAfterRefresh &&
        await Session.refresh()) {
      return _sendCancellation(booking, retryAfterRefresh: false);
    }
    return response;
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: Text(
          'هل تريد إلغاء حجز ${booking['date']}، ${booking['time_slot']}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await _sendCancellation(booking);
      if (response.statusCode == 200) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء الحجز وإتاحة الوقت من جديد.'),
            ),
          );
        }
      } else {
        var message = 'تعذر إلغاء الحجز. حاول مرة أخرى.';
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          message = data['detail']?.toString() ?? message;
        } catch (_) {}
        throw Exception(message);
      }
    } catch (error) {
      if (mounted) {
        final raw = error.toString();
        final message = raw.startsWith('Exception: ')
            ? raw.substring('Exception: '.length)
            : 'تعذر إلغاء الحجز. حاول مرة أخرى.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 180),
                  Center(child: Text(_error!)),
                ],
              )
            : _bookings.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('لا توجد طلبات حتى الآن')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final booking = _bookings[index];
                  final status = booking['status']?.toString() ?? '';
                  final invoiceUrl = booking['invoice_url']?.toString() ?? '';
                  final paymentStatus =
                      booking['payment_status']?.toString() ?? '';
                  final checkoutUrl =
                      booking['payment_checkout_url']?.toString() ?? '';
                  final paymentLabel = _paymentStatus(paymentStatus);
                  final canCancel = status == 'pending' || status == 'accepted';
                  return Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _statusColor(status),
                            child: const Icon(
                              Icons.local_car_wash,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            booking['service_name']?.toString() ??
                                'غسيل سيارات',
                          ),
                          subtitle: Text(
                            '${booking['date']} • ${booking['time_slot']}\n'
                            '${_status(status, paymentStatus)}'
                            '${paymentLabel.isEmpty ? '' : ' • $paymentLabel'}',
                          ),
                          isThreeLine: true,
                          trailing: SizedBox(
                            width: 115,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${booking['total_price']} ر.س'),
                                const SizedBox(height: 5),
                                if (checkoutUrl.isNotEmpty &&
                                    paymentStatus == 'pending')
                                  FilledButton.icon(
                                    onPressed: () => _openCheckout(checkoutUrl),
                                    icon: const Icon(
                                      Icons.credit_card,
                                      size: 17,
                                    ),
                                    label: const Text('إكمال الدفع'),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                    ),
                                  )
                                else if (invoiceUrl.isNotEmpty &&
                                    status != 'canceled')
                                  OutlinedButton.icon(
                                    onPressed: () => _openInvoice(invoiceUrl),
                                    icon: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 17,
                                    ),
                                    label: const Text('الفاتورة'),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (canCancel)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 12,
                                bottom: 8,
                              ),
                              child: TextButton.icon(
                                onPressed: () => _cancelBooking(booking),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.redAccent,
                                ),
                                label: const Text(
                                  'إلغاء الحجز',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
