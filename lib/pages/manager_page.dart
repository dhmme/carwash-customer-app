import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../session.dart';

const baseUrl = 'https://carwash-backend-2yz2.onrender.com';

class ManagerPage extends StatefulWidget {
  final VoidCallback onLogout;
  const ManagerPage({super.key, required this.onLogout});
  @override State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  int tab = 0;
  bool loading = true;
  String? error;
  Map<String, dynamic> stats = {};
  List<dynamic> services = [], addOns = [], categories = [], bookings = [], invoices = [], workers = [];

  @override void initState() { super.initState(); loadAll(); }

  Future<dynamic> api(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl/api/manager/$path');
    final r = switch (method) {
      'POST' => await http.post(uri, headers: Session.authHeaders, body: jsonEncode(body)),
      'PATCH' => await http.patch(uri, headers: Session.authHeaders, body: jsonEncode(body)),
      'DELETE' => await http.delete(uri, headers: Session.authHeaders),
      _ => await http.get(uri, headers: Session.authHeaders),
    };
    if (r.statusCode == 401 || r.statusCode == 403) { await Session.handleUnauthorized(); throw Exception(); }
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(r.body);
    return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<void> loadAll() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final data = await Future.wait([
        api('dashboard/'), api('services/'), api('add-ons/'), api('categories/'),
        api('bookings/'), api('invoices/'), api('workers/'),
      ]);
      if (mounted) setState(() {
        stats = Map<String, dynamic>.from(data[0]); services = data[1]; addOns = data[2];
        categories = data[3]; bookings = data[4]; invoices = data[5]; workers = data[6];
      });
    } catch (_) { if (mounted) setState(() => error = 'تعذر تحميل بيانات الإدارة'); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> saveCatalog(String type, Map<String, dynamic> values, [int? id]) async {
    await api('$type/${id == null ? '' : '$id/'}', method: id == null ? 'POST' : 'PATCH', body: values);
    await loadAll();
  }

  Future<void> toggleCatalog(String type, Map<String, dynamic> item) async {
    await api('$type/${item['id']}/', method: 'PATCH', body: {'is_active': item['is_active'] != true});
    await loadAll();
  }

  Future<void> setBookingStatus(int id, String value) async {
    final r = await http.patch(Uri.parse('$baseUrl/api/worker/bookings/$id/status/'),
      headers: Session.authHeaders, body: jsonEncode({'status': value}));
    if (r.statusCode == 200) await loadAll();
  }

  @override Widget build(BuildContext context) {
    const titles = ['نظرة عامة','الخدمات والأسعار','الطلبات','الفواتير','العمال'];
    return Scaffold(
      appBar: AppBar(foregroundColor: AppColors.text, title: Text(titles[tab]), actions: [
        IconButton(onPressed: loadAll, icon: const Icon(Icons.refresh)),
        IconButton(onPressed: widget.onLogout, icon: const Icon(Icons.logout)),
      ]),
      body: loading ? const Center(child: CircularProgressIndicator())
        : error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!), TextButton(onPressed: loadAll, child: const Text('إعادة المحاولة'))]))
        : IndexedStack(index: tab, children: [
            _dashboard(), _catalog(), _bookings(), _invoices(), _workers(),
          ]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.sell), label: 'الخدمات'),
        NavigationDestination(icon: Icon(Icons.receipt_long), label: 'الطلبات'),
        NavigationDestination(icon: Icon(Icons.description), label: 'الفواتير'),
        NavigationDestination(icon: Icon(Icons.engineering), label: 'العمال'),
      ]),
    );
  }

  Widget _dashboard() {
    final cards = [
      ('طلبات اليوم', stats['today_total'], Icons.today), ('قيد التنفيذ', stats['today_active'], Icons.pending_actions),
      ('مكتملة اليوم', stats['today_completed'], Icons.task_alt), ('إيراد اليوم', '${stats['today_revenue']} ر.س', Icons.payments),
      ('إيراد الشهر', '${stats['month_revenue']} ر.س', Icons.trending_up), ('العملاء', stats['customers'], Icons.people),
      ('العمال', stats['workers'], Icons.engineering),
    ];
    return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, mainAxisExtent: 145, crossAxisSpacing: 12, mainAxisSpacing: 12), itemCount: cards.length, itemBuilder: (_, i) {
      final c = cards[i];
      return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(c.$3,size:30,color:AppColors.cerulean),const Spacer(),Text('${c.$2}',style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),Text(c.$1,style:const TextStyle(color:AppColors.muted))])));
    });
  }

  Widget _catalog() => ListView(padding: const EdgeInsets.all(16), children: [
    _catalogSection('خدمات الغسيل', 'services', services, Icons.local_car_wash),
    _catalogSection('فئات المركبات', 'categories', categories, Icons.directions_car),
    _catalogSection('الخدمات الإضافية', 'add-ons', addOns, Icons.add_circle),
  ]);

  Widget _catalogSection(String title, String type, List<dynamic> items, IconData icon) => Card(child: ExpansionTile(
    leading: Icon(icon), title: Text(title), initiallyExpanded: true,
    trailing: IconButton(onPressed: () => _catalogDialog(type), icon: const Icon(Icons.add)),
    children: items.map((raw) { final x = Map<String,dynamic>.from(raw); return ListTile(
      title: Text(x['name'] ?? ''),
      subtitle: Text(type == 'categories' ? 'زيادة السعر: ${x['price_adjustment']} ر.س' : '${x['price']} ر.س${type == 'add-ons' ? ' / ${x['unit']}' : ''}'),
      leading: Switch(value: x['is_active'] == true, onChanged: (_) => toggleCatalog(type, x)),
      trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _catalogDialog(type, x)),
    ); }).toList(),
  ));

  Future<void> _catalogDialog(String type, [Map<String,dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    final existingPrice = item == null
        ? null
        : (type == 'categories' ? item['price_adjustment'] : item['price']);
    final price = TextEditingController(text: existingPrice?.toString() ?? '0');
    final key = TextEditingController(text: item?['key']?.toString() ?? '');
    final unit = TextEditingController(text: item?['unit']?.toString() ?? 'خدمة');
    bool quantity = item?['allows_quantity'] == true;
    await showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: Text(item == null ? 'إضافة عنصر' : 'تعديل العنصر'),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
        const SizedBox(height: 10),
        if (type == 'categories') TextField(controller: key, enabled: item == null, decoration: const InputDecoration(labelText: 'المعرّف بالإنجليزية مثل sedan')),
        if (type == 'categories') const SizedBox(height: 10),
        TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: type == 'categories' ? 'الزيادة على السعر' : 'السعر')),
        if (type == 'add-ons') ...[const SizedBox(height:10),TextField(controller:unit,decoration:const InputDecoration(labelText:'الوحدة')),SwitchListTile(value:quantity,onChanged:(v)=>setLocal(()=>quantity=v),title:const Text('السماح بتحديد الكمية'))],
      ]))),
      actions: [TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:() async {
        final values=<String,dynamic>{'name':name.text.trim(),'is_active':true};
        if(type=='categories'){values['key']=key.text.trim();values['price_adjustment']=price.text;}
        else {values['price']=price.text;if(type=='services')values['description']='';if(type=='add-ons'){values['unit']=unit.text;values['allows_quantity']=quantity;}}
        Navigator.pop(context); await saveCatalog(type,values,item?['id']);
      },child:const Text('حفظ'))],
    )));
  }

  Widget _bookings() => ListView.separated(padding: const EdgeInsets.all(16), itemCount: bookings.length, separatorBuilder:(_,__)=>const SizedBox(height:10), itemBuilder:(_,i){
    final b=bookings[i] as Map<String,dynamic>;
    return Card(child: ListTile(isThreeLine:true,
      title: Text('#${b['id']}  ${b['customer_name']} — ${b['service_name']}'),
      subtitle: Text('${b['date']} • ${b['time_slot']}\n${b['car_name']} • ${b['total_price']} ر.س'),
      trailing: DropdownButton<String>(value:b['status'],items:const [
        DropdownMenuItem(value:'pending',child:Text('مؤكد')),DropdownMenuItem(value:'accepted',child:Text('مؤكد')),
        DropdownMenuItem(value:'on_the_way',child:Text('في الطريق')),DropdownMenuItem(value:'in_progress',child:Text('قيد التنفيذ')),
        DropdownMenuItem(value:'completed',child:Text('مكتمل')),DropdownMenuItem(value:'canceled',child:Text('ملغي')),
      ],onChanged:(v){if(v!=null)setBookingStatus(b['id'],v);}),
    ));
  });

  Widget _invoices() => ListView.separated(padding:const EdgeInsets.all(16),itemCount:invoices.length,separatorBuilder:(_,__)=>const SizedBox(height:10),itemBuilder:(_,i){
    final x=invoices[i] as Map<String,dynamic>;
    return Card(child:ListTile(leading:const Icon(Icons.description),title:Text(x['number']??''),subtitle:Text('${x['customer_name']} • ${x['date']}'),trailing:Text('${x['total']} ر.س',style:const TextStyle(fontWeight:FontWeight.bold)),onTap:()=>_invoiceDialog(x)));
  });

  void _invoiceDialog(Map<String,dynamic> x) => showDialog(context:context,builder:(context)=>AlertDialog(title:Text('فاتورة ${x['number']}'),content:SizedBox(width:430,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('العميل: ${x['customer_name']}'),Text('الجوال: ${x['customer_phone']}'),Text('التاريخ: ${x['date']}'),const Divider(),Text('الخدمة: ${x['service_name']}'),
    ...(x['add_ons'] as List? ?? []).map((a)=>Text('${a['name']} × ${a['quantity']} — ${a['subtotal']} ر.س')),
    const Divider(),Text('الإجمالي: ${x['total']} ر.س',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),Text('الدفع: ${x['payment_method']}'),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إغلاق'))]));

  Widget _workers() => ListView(padding:const EdgeInsets.all(16),children:[
    Align(alignment:Alignment.centerLeft,child:FilledButton.icon(onPressed:()=>_workerDialog(),icon:const Icon(Icons.add),label:const Text('إضافة عامل'))),const SizedBox(height:12),
    ...workers.map((raw){final w=raw as Map<String,dynamic>;return Card(child:SwitchListTile(value:w['is_active']==true,onChanged:(v)async{await api('workers/${w['id']}/',method:'PATCH',body:{'is_active':v});await loadAll();},title:Text(w['first_name']??''),subtitle:Text(w['username']??''),secondary:const Icon(Icons.engineering)));}),
  ]);

  Future<void> _workerDialog() async {
    final name=TextEditingController(),phone=TextEditingController(),password=TextEditingController();
    await showDialog(context:context,builder:(context)=>AlertDialog(title:const Text('إضافة عامل'),content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'اسم العامل')),const SizedBox(height:10),
      TextField(controller:phone,decoration:const InputDecoration(labelText:'رقم الجوال')),const SizedBox(height:10),
      TextField(controller:password,obscureText:true,decoration:const InputDecoration(labelText:'كلمة المرور')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('إلغاء')),FilledButton(onPressed:()async{Navigator.pop(context);await api('workers/',method:'POST',body:{'first_name':name.text,'username':phone.text,'password':password.text,'is_active':true});await loadAll();},child:const Text('إضافة'))]));
  }
}
