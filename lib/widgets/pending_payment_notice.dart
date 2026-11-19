import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../session.dart';

/// Foreground reminder; the server remains authoritative for hold expiry.
class PendingPaymentNotice extends StatefulWidget {
  final String baseUrl;
  final VoidCallback? onChanged;
  const PendingPaymentNotice({super.key, required this.baseUrl, this.onChanged});
  @override
  State<PendingPaymentNotice> createState() => _PendingPaymentNoticeState();
}

class _PendingPaymentNoticeState extends State<PendingPaymentNotice>
    with WidgetsBindingObserver {
  Timer? _pollTimer, _clock;
  bool _fetching = false, _acting = false;
  List<Map<String, dynamic>> _pending = [];
  final Set<String> _tracked = {}, _expired = {};
  static final Set<String> _announced = {};
  static final Set<String> _warned = {};

  bool get _visible => mounted && (ModalRoute.of(context)?.isCurrent ?? false)
      && WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_visible || _pending.isEmpty) return;
      setState(() {});
      for (final p in _pending) {
        final remaining = _remaining(p);
        if (remaining > 0 && remaining <= 60 && _warned.add('${p['id']}')) {
          _message('باقي أقل من دقيقة لإكمال دفع الحجز #${p['id']}. أكمل الدفع للحفاظ على الموعد.');
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _poll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  int _remaining(Map<String, dynamic> p) {
    final expiry = DateTime.tryParse(p['payment_expires_at']?.toString() ?? '');
    if (expiry == null) return 0;
    final seconds = expiry.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  void _message(String text) {
    if (!_visible) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _poll() async {
    if (!_visible || _fetching) return;
    _fetching = true;
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/api/bookings/'), headers: Session.authHeaders);
      if (!mounted || !_visible || response.statusCode != 200) return;
      final bookings = (jsonDecode(utf8.decode(response.bodyBytes)) as List)
          .map((e) => Map<String, dynamic>.from(e)).toList();
      final pending = bookings.where((p) => p['status'] == 'pending' && p['payment_status'] == 'pending').toList();
      bool changed = false;
      for (final p in bookings) {
        final id = '${p['id']}';
        if (_tracked.contains(id) && p['payment_status'] == 'expired' && _expired.add(id)) {
          _message('انتهت مهلة دفع الحجز #$id وتحرر الموعد. تقدر تختار موعدًا وتحجز من جديد.');
          changed = true;
        }
      }
      for (final p in pending.take(1)) {
        final id = '${p['id']}';
        _tracked.add(id);
        if (_announced.add(id)) {
          _message('حجزك #$id بانتظار الدفع. أكمل الدفع قبل انتهاء المهلة أو ألغِه إذا ما تحتاجه.');
        }
      }
      setState(() => _pending = pending);
      if (changed) widget.onChanged?.call();
    } catch (_) {
      // Keep a temporary hold visible on connection failure; never infer payment success.
    } finally {
      _fetching = false;
    }
  }

  Future<void> _cancel(Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('إلغاء الحجز غير المدفوع؟'),
      content: const Text('سيصبح الموعد متاحًا للآخرين. إذا خُصم منك مبلغ فلا تُعد الدفع وتواصل مع الدعم.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إلغاء الحجز'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      final response = await http.post(Uri.parse('${widget.baseUrl}/api/bookings/${p['id']}/cancel/'), headers: Session.authHeaders);
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      _message(data['detail']?.toString() ?? 'تعذر إلغاء الحجز. حدّث الطلبات.');
      await _poll();
      if (response.statusCode == 200) widget.onChanged?.call();
    } catch (_) {
      _message('تعذر الاتصال. حدّث الطلبات للتحقق من حالة الحجز.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _pay(Map<String, dynamic> p) async {
    // Refresh before opening a payment link so stale reminders cannot renew a hold.
    await _poll();
    if (!mounted) return;
    final current = _pending.where((row) => row['id'] == p['id']);
    if (current.isEmpty || _remaining(current.first) == 0) return;
    final url = current.first['payment_checkout_url']?.toString() ?? '';
    if (url.isEmpty) return;
    try {
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault, webOnlyWindowName: '_self')) {
        _message('تعذر فتح صفحة الدفع. حاول من طلباتي.');
      }
    } catch (_) {
      _message('تعذر فتح صفحة الدفع. حاول من طلباتي.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending.isEmpty) return const SizedBox.shrink();
    return Column(children: _pending.take(1).map((p) {
      final seconds = _remaining(p);
      final time = '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
      return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔔 حجزك #${p['id']} بانتظار الدفع', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${p['date']} • ${p['time_slot']}'),
          Text(seconds > 0 ? 'المتبقي $time. أكمل الدفع لتأكيد الموعد، أو ألغِ الحجز إذا ما تحتاجه.' : 'انتهت المهلة؛ جارٍ تحديث حالة الموعد.'),
          Wrap(spacing: 10, children: [
            FilledButton(onPressed: _acting || seconds == 0 ? null : () => _pay(p), child: const Text('إكمال الدفع')),
            TextButton(onPressed: _acting ? null : () => _cancel(p), child: const Text('إلغاء الحجز')),
          ]),
        ],
      )));
    }).toList());
  }
}
