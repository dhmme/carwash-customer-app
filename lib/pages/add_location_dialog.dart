import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../session.dart';
import 'map_picker.dart';

Future<Map<String, dynamic>?> showAddLocationDialog(
  BuildContext context, {
  required String baseUrl,
}) => showDialog<Map<String, dynamic>>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _AddLocationDialog(baseUrl: baseUrl),
);

class _AddLocationDialog extends StatefulWidget {
  final String baseUrl;
  const _AddLocationDialog({required this.baseUrl});

  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  final name = TextEditingController();
  LatLng? point;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || name.text.trim().isEmpty || point == null) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final body = jsonEncode({
        'name': name.text.trim(),
        'latitude': point!.latitude,
        'longitude': point!.longitude,
      });
      Future<http.Response> send() => http.post(
        Uri.parse('${widget.baseUrl}/api/locations/'),
        headers: Session.authHeaders,
        body: body,
      );
      var response = await send();
      if (response.statusCode == 401 && await Session.refresh()) {
        response = await send();
      }
      if (response.statusCode == 401) {
        await Session.handleUnauthorized();
        return;
      }
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final location = Map<String, dynamic>.from(jsonDecode(response.body));
        Navigator.pop(context, location);
      } else {
        setState(() => error = 'تعذر حفظ الموقع. حاول مرة أخرى.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'تعذر الاتصال بالخادم. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة موقع جديد'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  enabled: !saving,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'اسم الموقع *',
                    hintText: 'المنزل، العمل...',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final selected = await Navigator.push<LatLng>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MapPickerPage(),
                            ),
                          );
                          if (mounted && selected != null) {
                            setState(() => point = selected);
                          }
                        },
                  icon: const Icon(Icons.map),
                  label: Text(
                    point == null
                        ? 'تحديد الموقع على الخريطة *'
                        : 'تم تحديد الموقع ✓',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: saving || name.text.trim().isEmpty || point == null
                ? null
                : save,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ الموقع'),
          ),
        ],
      ),
    ),
  );
}
