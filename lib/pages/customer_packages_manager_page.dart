import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

typedef PackageManagerRequest = Future<dynamic> Function(
  String path,
  String method,
  Map<String, dynamic>? body,
);

Future<T?> showPackageDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) async {
  ModalRoute<dynamic>? dialogRoute;
  final value = await showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      dialogRoute = ModalRoute.of(dialogContext);
      return builder(dialogContext);
    },
  );
  // Dialog controls remain mounted until the reverse transition is complete.
  final route = dialogRoute;
  if (route != null) await route.completed;
  return value;
}

String managerPackageStatus(dynamic status) => switch (status) {
  'active' => 'نشطة',
  'pending' => 'بانتظار الاعتماد',
  'rejected' => 'مرفوضة',
  'expired' => 'منتهية',
  'exhausted' => 'مستهلكة بالكامل',
  'revoked' => 'ملغاة من الإدارة',
  _ => status.toString(),
};

String packageManagerError(Object error) {
  try {
    final text = error.toString().replaceFirst('Exception: ', '');
    final data = jsonDecode(text);
    if (data is Map && data['detail'] is String) return data['detail'];
    if (data is Map) return data.values.map((v) => v is List ? v.join('، ') : v.toString()).join('\n');
  } catch (_) {}
  return 'تعذر إكمال العملية. حاول مرة أخرى.';
}

Future<bool> revokeCustomerPackage(
  BuildContext context,
  Map<String, dynamic> item,
  PackageManagerRequest request,
) async {
  final reason = TextEditingController();
  bool saving = false;
  String? error;
  final result = await showPackageDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => PopScope(
        canPop: !saving,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('إلغاء الباقة'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['customer_name']} — ${item['customer_phone']}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${item['plan_name']} • الرصيد: ${item['remaining_washes']} غسلات',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'سيتوقف استخدام رصيد الباقة. يبقى سجلها محفوظًا، ولا تُلغى الحجوزات السابقة تلقائيًا. راجعها من الطلبات عند الحاجة. هذا الإجراء لا يعيد مبلغًا للعميل تلقائيًا.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reason,
                      enabled: !saving,
                      maxLength: 500,
                      onChanged: (_) => setLocal(() {}),
                      decoration: const InputDecoration(
                        labelText: 'سبب الإلغاء *',
                      ),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('تراجع'),
              ),
              FilledButton(
                onPressed: saving || reason.text.trim().isEmpty
                    ? null
                    : () async {
                        setLocal(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await request(
                            'package-purchases/${item['id']}/revoke/',
                            'POST',
                            {'reason': reason.text.trim()},
                          );
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext, true);
                        } catch (e) {
                          if (dialogContext.mounted)
                            setLocal(() {
                              saving = false;
                              error = packageManagerError(e);
                            });
                        }
                      },
                child: Text(saving ? 'جارٍ الإلغاء...' : 'تأكيد إلغاء الباقة'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result == true;
}

class CustomerPackagesManagerPage extends StatefulWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> plans;
  final PackageManagerRequest request;
  const CustomerPackagesManagerPage({
    super.key,
    required this.customer,
    required this.plans,
    required this.request,
  });

  @override
  State<CustomerPackagesManagerPage> createState() =>
      _CustomerPackagesManagerPageState();
}

class _CustomerPackagesManagerPageState
    extends State<CustomerPackagesManagerPage> {
  bool loading = true;
  String? error;
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.request(
        'package-purchases/?customer=${widget.customer['id']}',
        'GET',
        null,
      );
      if (mounted) setState(() => items = data);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل باقات العميل');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> grant() async {
    if (await grantCustomerPackage(context, widget.customer, widget.plans, widget.request) && mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: Text('باقات ${widget.customer['name']}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: TextButton(
                onPressed: load,
                child: Text('$error — إعادة المحاولة'),
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(widget.customer['phone'].toString()),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: grant,
                    icon: const Icon(Icons.add_card),
                    label: const Text('منح باقة للعميل'),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('لا توجد باقات لهذا العميل'),
                    ),
                  ...items.map((raw) {
                    final item = Map<String, dynamic>.from(raw);
                    final revoked = item['status'] == 'revoked';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['plan_name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(managerPackageStatus(item['effective_status'] ?? item['status'])),
                            Text(
                              '${revoked ? 'الرصيد الموقوف' : 'الرصيد'}: ${item['remaining_washes']} غسلات',
                            ),
                            if (item['expires_at'] != null)
                              Text(
                                'تنتهي: ${item['expires_at'].toString().split('T').first}',
                              ),
                            TextButton.icon(
                                onPressed: () => showPackageHistory(context, item, widget.request),
                                icon: const Icon(Icons.history),
                                label: const Text('سجل التعديلات'),
                              ),
                            if (item['status'] == 'active' || item['status'] == 'expired')
                              TextButton.icon(
                                onPressed: () async {
                                  if (await adjustCustomerPackage(context, item, widget.request) && mounted) await load();
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('تعديل الرصيد والصلاحية'),
                              ),
                            if (!revoked && item['status'] != 'rejected')
                              TextButton.icon(
                                onPressed: () async {
                                  if (await revokeCustomerPackage(
                                        context,
                                        item,
                                        widget.request,
                                      ) &&
                                      mounted)
                                    await load();
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('إلغاء الباقة'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    ),
  );
}


String newPackageReference() {
  final random = Random.secure();
  final hex = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Future<bool> grantCustomerPackage(BuildContext context, Map<String, dynamic> customer, List<Map<String, dynamic>> plans, PackageManagerRequest request, {int? planId}) async {
  final available = plans
      .where((p) => p['is_active'] == true && p['is_archived'] != true)
      .toList();
  if (available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أضف أو فعّل باقة من تبويب الباقات أولًا.')),
    );
    return false;
  }
  final reason = TextEditingController();
  final matching = available.where((p) => p['id'] == planId).toList();
  Map<String, dynamic>? plan = matching.isEmpty ? null : matching.first;
  bool confirmed = false, saving = false;
  String? dialogError;
  final operationReference = newPackageReference();
  final saved = await showPackageDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => PopScope(
        canPop: !saving,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('منح باقة للعميل'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${customer['name']} — ${customer['phone']}',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      isExpanded: true,
                      value: plan,
                      decoration: const InputDecoration(
                        labelText: 'اختر الباقة',
                      ),
                      items: available
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                '${p['name']} • ${p['washes_count']} غسلات',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => setLocal(() => plan = value),
                    ),
                    if (plan != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'السعر المعلن: ${plan!['price']} ر.س • الصلاحية: ${plan!['validity_days']} يومًا من الآن',
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: reason,
                      enabled: !saving,
                      maxLength: 500,
                      onChanged: (_) => setLocal(() {}),
                      decoration: const InputDecoration(
                        labelText: 'سبب المنح أو مرجع الدفع *',
                        hintText: 'دفع خارج الموقع، هدية، تعويض...',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: confirmed,
                      onChanged: saving
                          ? null
                          : (value) =>
                                setLocal(() => confirmed = value == true),
                      title: const Text(
                        'تحققت من استلام الدفع، أو أعتمد منح الباقة مجانًا',
                      ),
                    ),
                    const Text(
                      'تتفعل الباقة مباشرة. المنح الإداري لا يسجل عملية قبض في دفتر اليومية؛ سجل القبض الفعلي حسب الإجراء المتبع.',
                    ),
                    if (dialogError != null)
                      Text(
                        dialogError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: const Text('تراجع'),
              ),
              FilledButton(
                onPressed:
                    saving ||
                        plan == null ||
                        !confirmed ||
                        reason.text.trim().isEmpty
                    ? null
                    : () async {
                        setLocal(() {
                          saving = true;
                          dialogError = null;
                        });
                        try {
                          await request('package-purchases/', 'POST', {
                            'customer': customer['id'],
                            'plan': plan!['id'],
                            'reason': reason.text.trim(),
                            'reference': operationReference,
                          });
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext, true);
                        } catch (e) {
                          if (dialogContext.mounted)
                            setLocal(() {
                              saving = false;
                              dialogError = packageManagerError(e);
                            });
                        }
                      },
                child: Text(saving ? 'جارٍ المنح...' : 'تأكيد منح الباقة'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  reason.dispose();
  return saved == true;
}

String packageDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (parsed == null) return 'غير محدد';
  return '${parsed.year}/${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}';
}

String packageNumber(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    text = text.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  return text.trim().replaceAll('٫', '.').replaceAll('٬', '');
}

Future<bool> adjustCustomerPackage(
  BuildContext context, Map<String, dynamic> item, PackageManagerRequest request,
) async {
  final balance = TextEditingController(text: '${item['remaining_washes']}');
  final reason = TextEditingController();
  final current = (item['remaining_washes'] as num).toInt();
  final originalExpiry = DateTime.tryParse(item['expires_at']?.toString() ?? '')?.toLocal();
  DateTime expiry = originalExpiry ?? DateTime.now().add(const Duration(days: 60));
  final reference = newPackageReference();
  bool saving = false;
  String? error;
  final result = await showPackageDialog<bool>(
    context: context, barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) {
        final count = int.tryParse(packageNumber(balance.text));
        final changed = count != current || expiry != originalExpiry;
        return PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('تعديل رصيد الباقة وصلاحيتها'),
            content: SizedBox(width: 480, child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${item['customer_name']} — ${item['customer_phone']}'),
                Text('${item['plan_name']} • اشتراك #${item['id']}'),
                const SizedBox(height: 16),
                Text('الرصيد الحالي: $current غسلات'),
                const SizedBox(height: 8),
                Row(children: [
                  IconButton(tooltip: 'إنقاص غسلة', onPressed: saving || (count ?? 0) <= 0 ? null : () => setLocal(() => balance.text = '${count! - 1}'), icon: const Icon(Icons.remove_circle_outline)),
                  Expanded(child: TextField(
                    controller: balance, enabled: !saving, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الرصيد الجديد'),
                    onChanged: (_) => setLocal(() {}),
                  )),
                  IconButton(tooltip: 'إضافة غسلة', onPressed: saving || (count ?? 10000) >= 10000 ? null : () => setLocal(() => balance.text = '${count! + 1}'), icon: const Icon(Icons.add_circle_outline)),
                ]),
                const SizedBox(height: 8),
                Text('بعد الحفظ: $current ← ${count ?? '—'} غسلات', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: saving ? null : () async {
                    final picked = await showDatePicker(context: dialogContext,
                      initialDate: expiry, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setLocal(() => expiry = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                  },
                  icon: const Icon(Icons.event),
                  label: Text('تاريخ الانتهاء: ${packageDate(expiry.toIso8601String())}'),
                ),
                const SizedBox(height: 12),
                TextField(controller: reason, enabled: !saving, maxLength: 500, minLines: 2, maxLines: 4,
                  decoration: const InputDecoration(labelText: 'سبب التعديل *'),
                  onChanged: (_) => setLocal(() {})),
                const Text('التعديل يخص هذا الاشتراك فقط، ويُحفظ الرصيد والصلاحية قبل التعديل وبعده.'),
                if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ]),
            )),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('تراجع')),
              FilledButton(
                onPressed: saving || count == null || count < 0 || count > 10000 || !changed || reason.text.trim().isEmpty ? null : () async {
                  setLocal(() { saving = true; error = null; });
                  try {
                    await request('package-purchases/${item['id']}/adjust/', 'POST', {
                      'remaining_washes': count, 'expires_at': expiry.toUtc().toIso8601String(),
                      'expected_remaining_washes': current, 'expected_expires_at': item['expires_at'],
                      'expected_status': item['status'], 'reason': reason.text.trim(), 'reference': reference,
                    });
                    if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                  } catch (e) {
                    if (dialogContext.mounted) setLocal(() { saving = false; error = packageManagerError(e); });
                  }
                },
                child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ التعديل'),
              ),
            ],
          ),
        );
      },
    ),
  );
  balance.dispose();
  reason.dispose();
  return result == true;
}

Future<void> showPackageHistory(
  BuildContext context, Map<String, dynamic> item, PackageManagerRequest request,
) async {
  try {
    final history = await request('package-purchases/${item['id']}/history/', 'GET', null) as List;
    if (!context.mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('سجل تعديلات الاشتراك'),
      content: SizedBox(width: 560, height: 420, child: ListView(
        children: [
          Text('${item['customer_name']} — ${item['plan_name']} • #${item['id']}'),
          if (history.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('لا توجد تعديلات إدارية مسجلة لهذا الاشتراك.')),
          ...history.map((entry) {
            final before = entry['before'] as Map? ?? {};
            final after = entry['after'] as Map? ?? {};
            final action = switch (entry['action']) {
              'grant' => 'منح باقة', 'approve' => 'اعتماد الشراء', 'reject' => 'رفض الشراء',
              'revoke' => 'إلغاء الاشتراك', _ => 'تعديل الرصيد والصلاحية',
            };
            return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${entry['actor']} • ${packageDate(entry['created_at'])}'),
                Text('السبب: ${entry['reason']}'),
                Text('الرصيد: ${before['remaining_washes'] ?? '—'} ← ${after['remaining_washes'] ?? '—'}'),
                Text('الصلاحية: ${packageDate(before['expires_at'])} ← ${packageDate(after['expires_at'])}'),
              ],
            )));
          }),
        ],
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
    ));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(packageManagerError(e))));
  }
}
