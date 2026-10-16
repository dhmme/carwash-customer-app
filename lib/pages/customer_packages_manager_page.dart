import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

typedef PackageManagerRequest = Future<dynamic> Function(
  String path,
  String method,
  Map<String, dynamic>? body,
);

String managerPackageStatus(dynamic status) => switch (status) {
  'active' => 'نشطة',
  'pending' => 'بانتظار الاعتماد',
  'rejected' => 'مرفوضة',
  'expired' => 'منتهية',
  'revoked' => 'ملغاة من الإدارة',
  _ => status.toString(),
};

String packageManagerError(Object error) {
  try {
    final text = error.toString().replaceFirst('Exception: ', '');
    final data = jsonDecode(text);
    if (data is Map && data['detail'] is String) return data['detail'];
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
  final result = await showDialog<bool>(
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

  String reference() {
    final random = Random.secure();
    final hex = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> grant() async {
    final available = widget.plans
        .where((p) => p['is_active'] == true)
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف أو فعّل باقة من الخدمات أولًا.')),
      );
      return;
    }
    final reason = TextEditingController();
    Map<String, dynamic>? plan;
    bool confirmed = false, saving = false;
    String? dialogError;
    final operationReference = reference();
    final saved = await showDialog<bool>(
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
                        '${widget.customer['name']} — ${widget.customer['phone']}',
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
                            await widget.request('package-purchases/', 'POST', {
                              'customer': widget.customer['id'],
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
    if (mounted && saved == true) await load();
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
                            Text(managerPackageStatus(item['status'])),
                            Text(
                              '${revoked ? 'الرصيد الموقوف' : 'الرصيد'}: ${item['remaining_washes']} غسلات',
                            ),
                            if (item['expires_at'] != null)
                              Text(
                                'تنتهي: ${item['expires_at'].toString().split('T').first}',
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
