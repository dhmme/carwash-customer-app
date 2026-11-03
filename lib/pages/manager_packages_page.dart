import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../app_theme.dart';
import '../session.dart';
import 'customer_packages_manager_page.dart';

class ManagerPackagesPage extends StatefulWidget {
  final PackageManagerRequest request;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> customers;
  final Future<void> Function() onChanged;
  const ManagerPackagesPage({super.key, required this.request, required this.services,
    required this.customers, required this.onChanged});
  @override
  State<ManagerPackagesPage> createState() => _ManagerPackagesPageState();
}

class _ManagerPackagesPageState extends State<ManagerPackagesPage> {
  bool loading = true;
  String? error;
  String filter = 'all', search = '';
  List<Map<String, dynamic>> plans = [];
  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await widget.request('packages/', 'GET', null) as List;
      if (mounted) setState(() => plans = rows.map((p) => Map<String, dynamic>.from(p)).toList());
    } catch (e) {
      if (mounted) setState(() => error = packageManagerError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changed() async { await load(); await widget.onChanged(); }
  void failure(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(packageManagerError(e))));
  }

  Future<void> edit([Map<String, dynamic>? plan]) async {
    if (await editPackagePlan(context, widget.request, widget.services, plan: plan) && mounted) await changed();
  }

  Future<void> archive(Map<String, dynamic> plan) async {
    final restore = plan['is_archived'] == true;
    final confirmed = await showPackageDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(restore ? 'استعادة الباقة' : 'حذف الباقة من البيع'),
      content: Text(restore
        ? 'ستعود الباقة إلى القائمة بحالة موقوفة، ويمكنك تفعيل بيعها بعد مراجعة إعداداتها.'
        : 'سيُوقف بيع «${plan['name']}» وتنتقل للأرشيف. تبقى باقات العملاء وأرصدتهم وصلاحياتهم كما هي، وتستمر إدارتهم من صفحة الباقة.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(restore ? 'استعادة' : 'حذف من البيع وحفظ الاشتراكات')),
      ],
    ));
    if (confirmed != true) return;
    try { await widget.request('packages/${plan['id']}/', restore ? 'POST' : 'DELETE', null); await changed(); }
    catch (e) { failure(e); }
  }

  Future<void> manage(Map<String, dynamic> plan) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PackageMembersManagerPage(
      initialPlan: plan, request: widget.request, customers: widget.customers,
    )));
    if (mounted) await changed();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: TextButton(onPressed: load, child: Text('$error — إعادة المحاولة')));
    final visible = plans.where((p) {
      final archived = p['is_archived'] == true;
      final active = p['is_active'] == true && !archived;
      return (filter == 'all' || (filter == 'available' && active) ||
        (filter == 'paused' && !active && !archived) || (filter == 'archived' && archived)) &&
        ('${p['name']} ${p['id']}'.contains(search.trim()));
    }).toList();
    return RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const Expanded(child: Text('الباقات والمشتركون', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        IconButton(tooltip: 'تحديث الباقات', onPressed: load, icon: const Icon(Icons.refresh)),
        IconButton(tooltip: 'إضافة باقة', onPressed: () => edit(), icon: const Icon(Icons.add_circle_outline)),
      ]),
      const Text('لكل باقة إدارة مستقلة، وتبقى الاشتراكات السابقة محفوظة عند تعديل الباقة أو أرشفتها.'),
      const SizedBox(height: 16),
      TextField(decoration: const InputDecoration(labelText: 'البحث باسم الباقة أو رقمها', prefixIcon: Icon(Icons.search)),
        onChanged: (v) => setState(() => search = v)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: filter, decoration: const InputDecoration(labelText: 'عرض الباقات'),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('كل الباقات')),
          DropdownMenuItem(value: 'available', child: Text('متاحة للبيع')),
          DropdownMenuItem(value: 'paused', child: Text('موقوفة')),
          DropdownMenuItem(value: 'archived', child: Text('المؤرشفة / المحذوفة من البيع')),
        ],
        onChanged: (v) => setState(() => filter = v ?? 'all'),
      ),
      const SizedBox(height: 16),
      if (visible.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('لا توجد باقات مطابقة.'))),
      ...visible.map((plan) => PackagePlanCard(
        plan: plan, onManage: () => manage(plan), onEdit: () => edit(plan),
        onArchive: () => archive(plan),
        onToggle: plan['is_archived'] == true ? null : () async {
          try {
            await widget.request('packages/${plan['id']}/', 'PATCH', {'is_active': plan['is_active'] != true});
            await changed();
          } catch (e) { failure(e); }
        },
      )),
    ]));
  }
}

class PackagePlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onManage, onEdit, onArchive;
  final VoidCallback? onToggle;
  const PackagePlanCard({super.key, required this.plan, required this.onManage,
    required this.onEdit, required this.onArchive, this.onToggle});
  @override
  Widget build(BuildContext context) {
    final archived = plan['is_archived'] == true;
    return Card(margin: const EdgeInsets.only(bottom: 14), child: Padding(
      padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${plan['name']} • #${plan['id']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))),
          if (!archived) Switch(value: plan['is_active'] == true, onChanged: onToggle == null ? null : (_) => onToggle!()),
        ]),
        Text(archived ? 'مؤرشفة — إدارة المشتركين متاحة' : plan['is_active'] == true ? 'متاحة للبيع' : 'موقوفة عن البيع',
          style: const TextStyle(color: AppColors.sky)),
        const SizedBox(height: 8),
        Text('${plan['price']} ر.س • ${plan['washes_count']} غسلات • ${plan['validity_days']} يومًا'),
        Text('تشمل: ${plan['included_service_name'] ?? '—'}'),
        const Divider(height: 24),
        Wrap(spacing: 18, runSpacing: 8, children: [
          Text('المشترون: ${plan['buyers_count'] ?? 0}'),
          Text('مرات الشراء: ${plan['purchase_count'] ?? 0}'),
          Text('المنح الإدارية: ${plan['grants_count'] ?? 0}'),
          Text('كل العملاء: ${plan['customer_count'] ?? 0}'),
          Text('سارية: ${plan['active_count'] ?? 0}'),
          Text('بانتظار الاعتماد: ${plan['pending_count'] ?? 0}'),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: onManage, icon: const Icon(Icons.people_outline), label: const Text('إدارة الباقة والمشتركين')),
          OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.settings_outlined), label: const Text('الإعدادات')),
          TextButton.icon(onPressed: onArchive, icon: Icon(archived ? Icons.unarchive_outlined : Icons.archive_outlined),
            label: Text(archived ? 'استعادة الباقة' : 'حذف من البيع')),
        ]),
      ]),
    ));
  }
}

Future<bool> editPackagePlan(BuildContext context, PackageManagerRequest request,
  List<Map<String, dynamic>> services, {Map<String, dynamic>? plan}) async {
  final available = services.where((s) => s['group_key'] == 'car_wash').toList();
  if (available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف خدمة غسيل سيارات أولًا.')));
    return false;
  }
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: plan?['name']?.toString() ?? '');
  final price = TextEditingController(text: plan?['price']?.toString() ?? '');
  final washes = TextEditingController(text: plan?['washes_count']?.toString() ?? '');
  final validity = TextEditingController(text: plan?['validity_days']?.toString() ?? '60');
  int service = available.any((s) => s['id'] == plan?['included_service'])
    ? plan!['included_service'] as int : available.first['id'] as int;
  bool saving = false;
  String? error;
  String? positive(String? v) {
    final number = int.tryParse(packageNumber(v ?? ''));
    return number == null || number < 1 || number > 10000 ? 'أدخل عددًا من 1 إلى 10000' : null;
  }
  final saved = await showPackageDialog<bool>(context: context, barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(builder: (context, setLocal) => PopScope(
      canPop: !saving,
      child: AlertDialog(
        title: Text(plan == null ? 'إضافة باقة' : 'إعدادات الباقة'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Form(key: form, child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(controller: name, enabled: !saving, maxLength: 100,
              decoration: const InputDecoration(labelText: 'اسم الباقة'),
              validator: (v) => v == null || v.trim().isEmpty ? 'أدخل اسم الباقة' : null),
            const SizedBox(height: 12),
            TextFormField(controller: price, enabled: !saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'السعر بالريال'),
              validator: (v) { final n = double.tryParse(packageNumber(v ?? '')); return n == null || !n.isFinite || n < 0 ? 'أدخل سعرًا صحيحًا' : null; }),
            const SizedBox(height: 12),
            TextFormField(controller: washes, enabled: !saving, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الغسلات'), validator: positive),
            const SizedBox(height: 12),
            TextFormField(controller: validity, enabled: !saving, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مدة الصلاحية بالأيام'), validator: positive),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(value: service, isExpanded: true,
              decoration: const InputDecoration(labelText: 'خدمة الغسيل المشمولة'),
              items: available.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name'].toString()))).toList(),
              onChanged: saving ? null : (v) => setLocal(() => service = v ?? service)),
            const SizedBox(height: 12),
            const Text('التعديلات تسري على الاشتراكات الجديدة. تبقى اشتراكات العملاء السابقة بشروطها ورصيدها وصلاحيتها.'),
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        )))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('تراجع')),
          FilledButton(onPressed: saving ? null : () async {
            if (!form.currentState!.validate()) return;
            setLocal(() { saving = true; error = null; });
            try {
              await request(plan == null ? 'packages/' : 'packages/${plan['id']}/', plan == null ? 'POST' : 'PATCH', {
                'name': name.text.trim(), 'price': packageNumber(price.text),
                'washes_count': int.parse(packageNumber(washes.text)), 'validity_days': int.parse(packageNumber(validity.text)),
                'included_service': service, 'is_active': plan?['is_active'] ?? true,
                'ordering': plan?['ordering'] ?? 0,
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (e) {
              if (dialogContext.mounted) setLocal(() { saving = false; error = packageManagerError(e); });
            }
          }, child: Text(saving ? 'جارٍ الحفظ...' : 'حفظ الباقة')),
        ],
      ),
    )),
  );
  for (final controller in [name, price, washes, validity]) { controller.dispose(); }
  return saved == true;
}

class PackageMembersManagerPage extends StatefulWidget {
  final Map<String, dynamic> initialPlan;
  final PackageManagerRequest request;
  final List<Map<String, dynamic>> customers;
  const PackageMembersManagerPage({super.key, required this.initialPlan, required this.request, required this.customers});
  @override
  State<PackageMembersManagerPage> createState() => _PackageMembersManagerPageState();
}

class _PackageMembersManagerPageState extends State<PackageMembersManagerPage> {
  late Map<String, dynamic> plan;
  List<Map<String, dynamic>> members = [];
  bool loading = true, busy = false;
  String? error;
  String status = '', source = '';
  final search = TextEditingController();
  DateTimeRange? dates;
  Timer? debounce;
  int page = 1, pages = 1, count = 0, generation = 0;
  @override
  void initState() { super.initState(); plan = widget.initialPlan; load(); }
  @override
  void dispose() { debounce?.cancel(); search.dispose(); super.dispose(); }
  String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String get query => Uri(queryParameters: {
    if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
    if (status.isNotEmpty) 'status': status, if (source.isNotEmpty) 'source': source,
    if (dates != null) 'from': day(dates!.start), if (dates != null) 'to': day(dates!.end),
  }).query;
  Future<void> load() async {
    final version = ++generation;
    setState(() { loading = true; error = null; });
    try {
      final data = await Future.wait([
        widget.request('packages/${plan['id']}/', 'GET', null),
        widget.request('package-purchases/?plan=${plan['id']}&page=$page&page_size=50&$query', 'GET', null),
      ]);
      if (!mounted || version != generation) return;
      final result = Map<String, dynamic>.from(data[1]);
      setState(() {
        plan = Map<String, dynamic>.from(data[0]); count = (result['count'] as num).toInt();
        pages = (result['total_pages'] as num).toInt();
        members = (result['results'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      if (mounted && version == generation) setState(() => error = packageManagerError(e));
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }
  void filterChanged() { page = 1; load(); }
  Future<void> perform(Future<bool> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try { if (await action() && mounted) await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(packageManagerError(e)))); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<bool> decide(Map<String, dynamic> item, String state) async {
    final approved = state == 'active';
    final yes = await showPackageDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(approved ? 'اعتماد الباقة' : 'رفض طلب الشراء'),
      content: Text(approved ? 'بعد التحقق من استلام المبلغ، سيتم تفعيل اشتراك ${item['customer_name']} بشروطه عند الشراء: ${item['washes_count']} غسلات، ${item['price']} ر.س.'
        : 'هل تريد رفض طلب ${item['customer_name']}؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approved ? 'اعتماد وتفعيل' : 'رفض الطلب')),
      ],
    ));
    if (yes != true) return false;
    await widget.request('package-purchases/${item['id']}/', 'PATCH', {'status': state});
    return true;
  }
  Future<bool> grant() async {
    final customer = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => PackageCustomerPicker(request: widget.request, initialCustomers: widget.customers),
    );
    if (customer == null || !mounted) return false;
    return grantCustomerPackage(context, customer, [plan], widget.request, planId: plan['id'] as int);
  }
  Future<void> export() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/manager/packages/${plan['id']}/export/?$query');
      var response = await http.get(uri, headers: Session.authHeaders);
      if (response.statusCode == 401 && await Session.refresh()) response = await http.get(uri, headers: Session.authHeaders);
      if (response.statusCode != 200) throw Exception('تعذر تصدير المشتركين');
      await FileSaver.instance.saveFile(name: 'code-care-package-${plan['id']}-members',
        bytes: response.bodyBytes, fileExtension: 'xlsx', mimeType: MimeType.custom,
        customMimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تصدير المشتركين. حاول مرة أخرى.')));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: Text('${plan['name']} • #${plan['id']}'), actions: [
      IconButton(tooltip: 'تحديث المشتركين', onPressed: busy ? null : load, icon: const Icon(Icons.refresh)),
    ]),
    body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(16), children: [
      if (plan['is_archived'] == true) const Card(child: Padding(padding: EdgeInsets.all(12),
        child: Text('هذه الباقة محذوفة من البيع. اشتراكات العملاء محفوظة ويمكنك إدارتها هنا.'))),
      Text('${plan['washes_count']} غسلات • ${plan['price']} ر.س • ${plan['validity_days']} يومًا'),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 8, children: [
        Text('المشترون: ${plan['buyers_count'] ?? 0}'),
        Text('مرات الشراء: ${plan['purchase_count'] ?? 0}'),
        Text('المنح الإدارية: ${plan['grants_count'] ?? 0}'),
        Text('سارية: ${plan['active_count'] ?? 0}'),
        Text('منتهية: ${plan['expired_count'] ?? 0}'),
        Text('مستهلكة: ${plan['exhausted_count'] ?? 0}'),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: busy || plan['is_archived'] == true || plan['is_active'] != true ? null : () => perform(grant),
          icon: const Icon(Icons.add_card), label: const Text('منح هذه الباقة لعميل')),
        OutlinedButton.icon(onPressed: busy ? null : export, icon: const Icon(Icons.download_outlined), label: const Text('تصدير Excel')),
      ]),
      const SizedBox(height: 16),
      TextField(controller: search, decoration: const InputDecoration(labelText: 'بحث باسم العميل أو جواله', prefixIcon: Icon(Icons.search)),
        onChanged: (_) { debounce?.cancel(); debounce = Timer(const Duration(milliseconds: 350), filterChanged); }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'حالة الاشتراك'),
        items: ['', 'active', 'pending', 'expired', 'exhausted', 'revoked', 'rejected'].map((v) =>
          DropdownMenuItem(value: v, child: Text(v.isEmpty ? 'كل الحالات' : managerPackageStatus(v)))).toList(),
        onChanged: busy ? null : (v) { setState(() => status = v ?? ''); filterChanged(); }),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: source, decoration: const InputDecoration(labelText: 'مصدر الاشتراك'),
        items: const [DropdownMenuItem(value: '', child: Text('كل المصادر')),
          DropdownMenuItem(value: 'purchase', child: Text('طلبات الشراء')), DropdownMenuItem(value: 'grant', child: Text('المنح الإدارية'))],
        onChanged: busy ? null : (v) { setState(() => source = v ?? ''); filterChanged(); }),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(onPressed: busy ? null : () async {
          final picked = await showDateRangePicker(context: context, initialDateRange: dates, firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (picked != null && mounted) { setState(() => dates = picked); filterChanged(); }
        }, icon: const Icon(Icons.date_range), label: Text(dates == null ? 'فترة الشراء' : '${day(dates!.start)} — ${day(dates!.end)}')),
        if (dates != null) TextButton(onPressed: () { setState(() => dates = null); filterChanged(); }, child: const Text('مسح الفترة')),
      ]),
      const SizedBox(height: 16),
      if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
      else if (error != null) TextButton(onPressed: load, child: Text('$error — إعادة المحاولة'))
      else ...[
        Text('$count اشتراك مطابق • صفحة $page من $pages'),
        if (members.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('لا يوجد مشتركون مطابقون لهذه الباقة.'))),
        ...members.map((item) => PackageMemberCard(
          item: item, busy: busy,
          onEdit: () => perform(() => adjustCustomerPackage(context, item, widget.request)),
          onRevoke: () => perform(() => revokeCustomerPackage(context, item, widget.request)),
          onHistory: () => showPackageHistory(context, item, widget.request),
          onApprove: () => perform(() => decide(item, 'active')),
          onReject: () => perform(() => decide(item, 'rejected')),
        )),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(tooltip: 'الصفحة السابقة', onPressed: busy || page <= 1 ? null : () { page--; load(); }, icon: const Icon(Icons.chevron_right)),
          Text('$page / $pages'),
          IconButton(tooltip: 'الصفحة التالية', onPressed: busy || page >= pages ? null : () { page++; load(); }, icon: const Icon(Icons.chevron_left)),
        ]),
      ],
    ])),
  ));
}

class PackageMemberCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onEdit, onRevoke, onHistory, onApprove, onReject;
  const PackageMemberCard({super.key, required this.item, this.busy = false, required this.onEdit,
    required this.onRevoke, required this.onHistory, required this.onApprove, required this.onReject});
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(top: 12), child: Padding(
    padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${item['customer_name']} • اشتراك #${item['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      SelectableText(item['customer_phone']?.toString() ?? '', textDirection: TextDirection.ltr),
      Text(managerPackageStatus(item['effective_status'] ?? item['status']), style: const TextStyle(color: AppColors.sky)),
      Text('${item['plan_name']} • ${item['payment_method'] == 'manager_grant' ? 'منح إداري' : 'شراء'}'),
      Text('شروط الاشتراك: ${item['washes_count']} غسلات • ${item['price']} ر.س'),
      Text('الغسلات المستخدمة والمحجوزة: ${item['used_washes'] ?? 0}'),
      Text('الغسلات المتبقية: ${item['remaining_washes']}', style: const TextStyle(fontWeight: FontWeight.bold)),
      Text('تاريخ الشراء: ${packageDate(item['purchased_at'])}'),
      Text('تاريخ الانتهاء: ${packageDate(item['expires_at'])}'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (item['status'] == 'pending') ...[
          FilledButton.icon(onPressed: busy ? null : onApprove, icon: const Icon(Icons.check), label: const Text('اعتماد الشراء')),
          TextButton(onPressed: busy ? null : onReject, child: const Text('رفض')),
        ],
        if (item['status'] == 'active' || item['status'] == 'expired')
          OutlinedButton.icon(onPressed: busy ? null : onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('تعديل الرصيد والصلاحية')),
        if (item['status'] != 'revoked' && item['status'] != 'rejected')
          TextButton.icon(onPressed: busy ? null : onRevoke, icon: const Icon(Icons.cancel_outlined), label: const Text('إلغاء الاشتراك')),
        TextButton.icon(onPressed: busy ? null : onHistory, icon: const Icon(Icons.history), label: const Text('سجل التعديلات')),
      ]),
    ]),
  ));
}

class PackageCustomerPicker extends StatefulWidget {
  final PackageManagerRequest request;
  final List<Map<String, dynamic>> initialCustomers;
  const PackageCustomerPicker({super.key, required this.request, required this.initialCustomers});
  @override
  State<PackageCustomerPicker> createState() => _PackageCustomerPickerState();
}

class _PackageCustomerPickerState extends State<PackageCustomerPicker> {
  late List<Map<String, dynamic>> customers;
  Timer? timer;
  bool loading = false;
  String? error;
  int generation = 0;
  @override
  void initState() { super.initState(); customers = widget.initialCustomers.where((c) => c['is_active'] != false).toList(); }
  @override
  void dispose() { timer?.cancel(); super.dispose(); }
  Future<void> findCustomers(String term) async {
    final version = ++generation;
    setState(() { loading = true; error = null; });
    try {
      final rows = await widget.request('customers/?q=${Uri.encodeQueryComponent(term.trim())}', 'GET', null) as List;
      if (mounted && version == generation) setState(() => customers = rows.map((c) =>
        Map<String, dynamic>.from(c)).where((c) => c['is_active'] != false).toList());
    } catch (e) {
      if (mounted && version == generation) setState(() => error = packageManagerError(e));
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('اختر العميل لمنح الباقة'),
    content: SizedBox(width: 480, height: 400, child: Column(children: [
      TextField(decoration: const InputDecoration(labelText: 'الاسم أو رقم الجوال', prefixIcon: Icon(Icons.search)),
        onChanged: (term) {
          timer?.cancel();
          generation++;
          setState(() => loading = true);
          timer = Timer(const Duration(milliseconds: 350), () => findCustomers(term));
        }),
      const SizedBox(height: 12),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : error != null
        ? Center(child: Text(error!)) : ListView(children: [
          if (customers.isEmpty) const Text('لا يوجد عميل مطابق.'),
          ...customers.map((c) => ListTile(title: Text(c['name'].toString()), subtitle: Text(c['phone'].toString()),
            onTap: () => Navigator.pop(context, c))),
        ])),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع'))],
  );
}
