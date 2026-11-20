import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../session.dart';

class ManagerWorkerBonuses extends StatefulWidget {
  final String baseUrl;
  final int refreshToken;
  const ManagerWorkerBonuses({super.key, required this.baseUrl, this.refreshToken = 0});
  @override
  State<ManagerWorkerBonuses> createState() => _ManagerWorkerBonusesState();
}

class _ManagerWorkerBonusesState extends State<ManagerWorkerBonuses> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Map<String, dynamic>> _workers = [];
  String? _error;
  bool _loading = true;
  int _requestId = 0;
  String get _monthCode => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant ManagerWorkerBonuses oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }
  Future<void> _load() async {
    final id = ++_requestId;
    final month = _monthCode;
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(Uri.parse('${widget.baseUrl}/api/manager/worker-bonuses/?month=$month'), headers: Session.authHeaders);
      if (response.statusCode != 200) throw Exception();
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (mounted && id == _requestId) setState(() {
        _workers = (data['workers'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (_) {
      if (mounted && id == _requestId) setState(() => _error = 'تعذر تحميل البونص. حاول التحديث.');
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }
  void _changeMonth(int difference) {
    setState(() => _month = DateTime(_month.year, _month.month + difference));
    _load();
  }
  Future<void> _edit(Map<String, dynamic> worker) async {
    final controller = TextEditingController(text: worker['amount'].toString());
    final month = _monthCode;
    bool saving = false;
    String? error;
    final saved = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text('بونص ${worker['name']} — $month'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('أدخل إجمالي بونص العامل لهذا الشهر. القيمة الجديدة تستبدل الإجمالي المسجل، ولا تضاف إليه.'),
          const SizedBox(height: 12),
          TextField(controller: controller, enabled: !saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'إجمالي البونص (ر.س)', errorText: error)),
        ]),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: saving ? null : () async {
            final amount = controller.text.trim();
            final parsed = double.tryParse(amount);
            if (parsed == null || !parsed.isFinite || parsed < 0) {
              update(() => error = 'أدخل مبلغًا صحيحًا لا يقل عن صفر.'); return;
            }
            update(() { saving = true; error = null; });
            try {
              final response = await http.put(Uri.parse('${widget.baseUrl}/api/manager/workers/${worker['id']}/bonus/'),
                headers: Session.authHeaders, body: jsonEncode({'month': month, 'amount': amount, 'expected_updated_at': worker['updated_at']}));
              if (!ctx.mounted) return;
              if (response.statusCode == 200) { Navigator.pop(ctx, true); return; }
              final body = jsonDecode(utf8.decode(response.bodyBytes));
              update(() { saving = false; error = body['detail']?.toString() ?? 'تعذر الحفظ. تحقق من المبلغ وحدّث القائمة إذا تغير البونص.'; });
            } catch (_) {
              if (ctx.mounted) update(() { saving = false; error = 'تعذر التأكد من الحفظ. أغلق النافذة وحدّث القائمة قبل إعادة المحاولة.'; });
            }
          }, child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ البونص')),
        ],
      )));
    controller.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بونص العامل لهذا الشهر.')));
      await _load();
    } else if (mounted) {
      await _load();
    }
  }
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('بونص العمال الشهري', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const Text('تسجيل يدوي لكل عامل • سجل مستقل لكل شهر'),
      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton(onPressed: () => _changeMonth(-1), child: const Text('الشهر السابق')),
        Text(_monthCode, style: const TextStyle(fontWeight: FontWeight.bold)),
        TextButton(onPressed: () => _changeMonth(1), child: const Text('الشهر التالي')),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'تحديث البونص'),
      ]),
      if (_loading) const LinearProgressIndicator()
      else if (_error != null) Text(_error!)
      else if (_workers.isEmpty) const Text('لا يوجد عمال مسجلون.')
      else ..._workers.map((worker) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(worker['name'].toString()),
        subtitle: Text('${worker['amount']} ر.س'),
        trailing: TextButton(onPressed: () => _edit(worker), child: const Text('تعديل البونص')),
      )),
    ]),
  ));
}
