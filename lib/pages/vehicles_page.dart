import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../session.dart';

class VehiclesPage extends StatefulWidget {
  final String baseUrl; const VehiclesPage({super.key, required this.baseUrl});
  @override State<VehiclesPage> createState() => _VehiclesPageState();
}
class _VehiclesPageState extends State<VehiclesPage> {
  bool loading = true; List<Map<String, dynamic>> items = [];
  @override void initState(){ super.initState(); load(); }
  Future<void> load() async { final r = await http.get(Uri.parse('${widget.baseUrl}/api/cars/'), headers: Session.authHeaders);
    if (mounted) setState(() { items = r.statusCode == 200 ? (jsonDecode(r.body) as List).cast<Map<String,dynamic>>() : []; loading = false; }); }
  Future<void> add() async {
    final type=TextEditingController(), brand=TextEditingController(), model=TextEditingController(), color=TextEditingController(), plate=TextEditingController(); String size='small';
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(builder: (context,setLocal) => Directionality(textDirection: TextDirection.rtl,
      child: AlertDialog(title: const Text('إضافة مركبة'), content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller:type, decoration: const InputDecoration(labelText:'نوع المركبة (سيدان، SUV...)')), const SizedBox(height:10),
        Row(children:[Expanded(child: TextField(controller:brand, decoration: const InputDecoration(labelText:'الماركة'))), const SizedBox(width:8), Expanded(child: TextField(controller:model, decoration: const InputDecoration(labelText:'الموديل')))]), const SizedBox(height:10),
        DropdownButtonFormField(value:size, decoration: const InputDecoration(labelText:'الحجم'), items: const [DropdownMenuItem(value:'small',child:Text('صغيرة')),DropdownMenuItem(value:'big',child:Text('كبيرة'))], onChanged:(v)=>setLocal(()=>size=v!)), const SizedBox(height:10),
        Row(children:[Expanded(child: TextField(controller:color, decoration: const InputDecoration(labelText:'اللون'))), const SizedBox(width:8), Expanded(child: TextField(controller:plate, decoration: const InputDecoration(labelText:'رقم اللوحة')))])
      ]))), actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('حفظ'))]))));
    if(saved==true){ await http.post(Uri.parse('${widget.baseUrl}/api/cars/'), headers:Session.authHeaders, body:jsonEncode({'vehicle_type':type.text,'brand':brand.text,'model':model.text,'size':size,'color':color.text,'plate_number':plate.text})); load(); }
  }
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl, child:Scaffold(appBar:AppBar(title:const Text('المركبات')),
    floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('إضافة مركبة')),
    body:loading?const Center(child:CircularProgressIndicator()):items.isEmpty?const Center(child:Text('لا توجد مركبات محفوظة')):ListView.builder(padding:const EdgeInsets.all(16),itemCount:items.length,itemBuilder:(_,i){final v=items[i];return Card(child:ListTile(contentPadding:const EdgeInsets.all(16),leading:const CircleAvatar(child:Icon(Icons.directions_car)),title:Text('${v['brand']} ${v['model']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${v['vehicle_type']} • ${v['size']=='big'?'كبيرة':'صغيرة'} • ${v['color']}\nاللوحة: ${v['plate_number']}')));})));
}
