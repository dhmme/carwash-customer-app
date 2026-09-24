import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../session.dart';
import '../worker_localization.dart';
import '../app_config.dart';

const baseUrl = AppConfig.apiBaseUrl;

class WorkerBooking {
  final int id;
  final String date, timeSlot, status, customerName, customerPhone;
  final String carName,
      carColor,
      plateNumber,
      serviceName,
      serviceGroupName,
      addressText;
  final String mapsUrl, totalPrice, paymentMethod;
  final List<Map<String, dynamic>> addOns;
  WorkerBooking.fromJson(Map<String, dynamic> j)
    : id = j['id'] ?? 0,
      date = j['date'] ?? '',
      timeSlot = j['time_slot'] ?? '',
      status = j['status'] ?? '',
      customerName = j['customer_name'] ?? '',
      customerPhone = j['customer_phone'] ?? '',
      carName = j['car_name'] ?? '',
      carColor = j['car_color'] ?? '',
      plateNumber = j['plate_number'] ?? '',
      serviceName = j['service_name'] ?? '',
      serviceGroupName = j['service_group_name'] ?? '',
      addressText = j['address_text'] ?? '',
      mapsUrl = j['maps_url'] ?? '',
      totalPrice = '${j['total_price'] ?? ''}',
      paymentMethod = j['payment_method'] ?? '',
      addOns = List<Map<String, dynamic>>.from(j['add_ons'] ?? const []);
}

class WorkerBookingsPage extends StatefulWidget {
  final VoidCallback? onLogout;
  final WorkerLocalizations localizations;
  final ValueChanged<WorkerLanguage> onLanguageChanged;
  const WorkerBookingsPage({
    super.key,
    this.onLogout,
    required this.localizations,
    required this.onLanguageChanged,
  });
  @override
  State<WorkerBookingsPage> createState() => _WorkerBookingsPageState();
}

class _WorkerBookingsPageState extends State<WorkerBookingsPage> {
  bool loading = true;
  String? error;
  List<WorkerBooking> bookings = [];
  @override
  void initState() {
    super.initState();
    loadBookings();
  }

  Future<void> loadBookings() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/worker/bookings/'),
        headers: Session.authHeaders,
      );
      if (r.statusCode == 401 || r.statusCode == 403) {
        await Session.handleUnauthorized();
        return;
      }
      if (r.statusCode != 200) throw Exception();
      final data = jsonDecode(r.body) as List;
      if (mounted)
        setState(
          () => bookings = data.map((e) => WorkerBooking.fromJson(e)).toList(),
        );
    } catch (_) {
      if (mounted) setState(() => error = widget.localizations.loadFailed);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateStatus(WorkerBooking b, String status) async {
    final r = await http.patch(
      Uri.parse('$baseUrl/api/worker/bookings/${b.id}/status/'),
      headers: Session.authHeaders,
      body: jsonEncode({'status': status}),
    );
    if (r.statusCode == 401 || r.statusCode == 403)
      await Session.handleUnauthorized();
    else if (r.statusCode == 200)
      await loadBookings();
    else if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.localizations.updateFailed)),
      );
  }

  Future<void> launch(String value) async {
    final uri = Uri.parse(value);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      foregroundColor: AppColors.text,
      title: Text(widget.localizations.todayBookings),
      actions: [
        PopupMenuButton<WorkerLanguage>(
          tooltip: widget.localizations.changeLanguage,
          initialValue: widget.localizations.language,
          onSelected: widget.onLanguageChanged,
          icon: const Icon(Icons.language),
          itemBuilder: (_) => WorkerLanguage.values
              .map(
                (language) => PopupMenuItem(
                  value: language,
                  child: Text(widget.localizations.languageLabel(language)),
                ),
              )
              .toList(),
        ),
        IconButton(
          tooltip: widget.localizations.refresh,
          onPressed: loadBookings,
          icon: const Icon(Icons.refresh),
        ),
        if (widget.onLogout != null)
          IconButton(
            tooltip: widget.localizations.logout,
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: loadBookings,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? ListView(
              children: [
                const SizedBox(height: 260),
                Center(child: Text(error!)),
              ],
            )
          : bookings.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 260),
                Center(child: Text(widget.localizations.noBookings)),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _BookingCard(
                booking: bookings[i],
                localizations: widget.localizations,
                onStatus: (s) => updateStatus(bookings[i], s),
                onCall: () => launch('tel:${bookings[i].customerPhone}'),
                onMap: () => launch(bookings[i].mapsUrl),
              ),
            ),
    ),
  );
}

class _BookingCard extends StatelessWidget {
  final WorkerBooking booking;
  final WorkerLocalizations localizations;
  final ValueChanged<String> onStatus;
  final VoidCallback onCall, onMap;
  const _BookingCard({
    required this.booking,
    required this.localizations,
    required this.onStatus,
    required this.onCall,
    required this.onMap,
  });
  Widget info(IconData icon, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final canComplete =
        booking.status != 'completed' && booking.status != 'canceled';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  booking.timeSlot,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Chip(label: Text(localizations.status(booking.status))),
              ],
            ),
            info(
              Icons.person,
              '${booking.customerName} — ${booking.customerPhone}',
            ),
            if (booking.carName.isNotEmpty)
              info(
                Icons.directions_car,
                '${booking.carName} • ${booking.carColor} • ${booking.plateNumber}',
              ),
            info(Icons.local_car_wash, booking.serviceName),
            if (booking.addOns.isNotEmpty)
              info(
                Icons.add_circle_outline,
                booking.addOns
                    .map((a) => '${a['name']} × ${a['quantity']}')
                    .join('، '),
              ),
            info(
              Icons.location_on,
              booking.addressText.isEmpty
                  ? localizations.selectedMapLocation
                  : booking.addressText,
            ),
            info(
              Icons.payments,
              '${booking.totalPrice} ${localizations.currency} • ${localizations.paymentMethod(booking.paymentMethod)}',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: booking.customerPhone.isEmpty ? null : onCall,
                    icon: const Icon(Icons.phone),
                    label: Text(localizations.call),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: booking.mapsUrl.isEmpty ? null : onMap,
                    icon: const Icon(Icons.navigation),
                    label: Text(localizations.location),
                  ),
                ),
              ],
            ),
            if (canComplete) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onStatus('completed'),
                  icon: const Icon(Icons.check_circle),
                  label: Text(localizations.completeWash),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
