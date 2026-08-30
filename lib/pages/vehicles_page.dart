import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../session.dart';

const popularVehicles = <String>[
  'تويوتا كامري', 'تويوتا كورولا', 'تويوتا يارس', 'تويوتا أفالون',
  'تويوتا راف فور', 'تويوتا فورتشنر', 'تويوتا برادو', 'تويوتا لاندكروزر',
  'هوندا أكورد', 'هوندا سيفيك', 'هوندا CR-V', 'هوندا بايلوت',
  'هيونداي أكسنت', 'هيونداي إلنترا', 'هيونداي سوناتا', 'هيونداي توسان', 'هيونداي سنتافي',
  'كيا بيجاس', 'كيا سيراتو', 'كيا K5', 'كيا سبورتاج', 'كيا سورينتو',
  'نيسان صني', 'نيسان ألتيما', 'نيسان إكس تريل', 'نيسان باترول',
  'مازدا 3', 'مازدا 6', 'مازدا CX-5', 'فورد تورس', 'فورد إكسبلورر',
  'شفروليه ماليبو', 'شفروليه تاهو', 'جي إم سي يوكن', 'لكزس ES', 'لكزس RX',
  'مرسيدس', 'بي إم دبليو', 'أودي', 'أخرى',
];

class VehiclesPage extends StatefulWidget {
  final String baseUrl;
  const VehiclesPage({super.key, required this.baseUrl});
  @override State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  bool loading = true;
  List<Map<String, dynamic>> items = [];
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    final r = await http.get(Uri.parse('${widget.baseUrl}/api/cars/'), headers: Session.authHeaders);
    if (mounted) setState(() {
      items = r.statusCode == 200 ? (jsonDecode(r.body) as List).cast<Map<String, dynamic>>() : [];
      loading = false;
    });
  }

  String categoryLabel(String? value) => switch (value) {
    'small_suv' => 'جيب صغير', 'family_suv' => 'جيب عائلي', _ => 'سيدان',
  };

  Uint8List? imageBytes(String? data) {
    if (data == null || data.isEmpty) return null;
    try { return base64Decode(data.contains(',') ? data.split(',').last : data); } catch (_) { return null; }
  }

  Future<String?> pickVehicle(BuildContext context, String current) async {
    final search = TextEditingController();
    return showDialog<String>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (dialogContext, setSearch) {
        final query = search.text.trim().toLowerCase();
        final filtered = popularVehicles.where((name) =>
          query.isEmpty || name.toLowerCase().contains(query)).toList();
        return Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
          title: const Text('اختر نوع السيارة'),
          content: SizedBox(width: 430, height: 480, child: Column(children: [
            TextField(controller: search, autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث مثلًا: كامري، أكسنت...'),
              onChanged: (_) => setSearch(() {})),
            const SizedBox(height: 10),
            Expanded(child: filtered.isEmpty
              ? const Center(child: Text('لا توجد نتائج'))
              : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
                  final name = filtered[i];
                  return ListTile(
                    leading: Icon(name == current ? Icons.check_circle : Icons.directions_car,
                      color: name == current ? Theme.of(context).colorScheme.primary : null),
                    title: Text(name),
                    onTap: () => Navigator.pop(dialogContext, name),
                  );
                })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء'))],
        ));
      }));
  }

  Future<void> add() async {
    String category = 'sedan', vehicle = popularVehicles.first;
    final color = TextEditingController(), plate = TextEditingController(), custom = TextEditingController();
    Uint8List? photo;
    String? mime;
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(
        title: const Text('إضافة مركبة'),
        content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField(value: category, decoration: const InputDecoration(labelText: 'فئة السيارة'),
            items: const [DropdownMenuItem(value:'sedan',child:Text('سيدان')), DropdownMenuItem(value:'small_suv',child:Text('جيب صغير')), DropdownMenuItem(value:'family_suv',child:Text('جيب عائلي'))],
            onChanged: (v) => setLocal(() => category = v!)),
          const SizedBox(height: 12),
          InkWell(onTap: () async {
            final selected = await pickVehicle(context, vehicle);
            if (selected != null) setLocal(() => vehicle = selected);
          }, child: InputDecorator(
            decoration: const InputDecoration(labelText: 'نوع السيارة', prefixIcon: Icon(Icons.search)),
            child: Row(children: [Expanded(child: Text(vehicle)), const Icon(Icons.arrow_drop_down)]),
          )),
          if (vehicle == 'أخرى') ...[const SizedBox(height: 12), TextField(controller: custom, decoration: const InputDecoration(labelText: 'اكتب نوع السيارة'))],
          const SizedBox(height: 12),
          TextField(controller: color, decoration: const InputDecoration(labelText: 'اللون')),
          const SizedBox(height: 12),
          TextField(controller: plate, decoration: const InputDecoration(labelText: 'لوحة السيارة')),
          const SizedBox(height: 14),
          InkWell(onTap: () async {
            final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 65, maxWidth: 900);
            if (x != null) { final bytes = await x.readAsBytes(); setLocal(() { photo = bytes; mime = x.mimeType ?? 'image/jpeg'; }); }
          }, child: Container(height: 130, width: double.infinity, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.blue.shade100)),
            child: photo == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 34), SizedBox(height:6), Text('إضافة صورة (اختياري)')])
              : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.memory(photo!, fit: BoxFit.cover)))),
        ]))),
        actions: [TextButton(onPressed:()=>Navigator.pop(context,false), child:const Text('إلغاء')),
          FilledButton(onPressed:()=>Navigator.pop(context,true), child:const Text('حفظ'))],
      )),
    ));
    final name = vehicle == 'أخرى' ? custom.text.trim() : vehicle;
    if (saved == true && name.isNotEmpty && color.text.trim().isNotEmpty && plate.text.trim().isNotEmpty) {
      final imageData = photo == null ? '' : 'data:${mime ?? 'image/jpeg'};base64,${base64Encode(photo!)}';
      final response = await http.post(Uri.parse('${widget.baseUrl}/api/cars/'), headers: Session.authHeaders,
        body: jsonEncode({'category':category, 'vehicle_name':name, 'color':color.text.trim(), 'plate_number':plate.text.trim(), 'image_data':imageData}));
      if (!mounted) return;
      if (response.statusCode == 201) {
        final created = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => items.insert(0, created));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المركبة')));
      } else {
        String message = 'تعذر إضافة المركبة.';
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          message = data.values.first.toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    }
  }

  @override Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('المركبات')),
    floatingActionButton: FloatingActionButton.extended(onPressed:add, icon:const Icon(Icons.add), label:const Text('إضافة مركبة')),
    body: loading ? const Center(child:CircularProgressIndicator()) : items.isEmpty ? const Center(child:Text('لا توجد مركبات محفوظة'))
      : ListView.builder(padding:const EdgeInsets.all(16), itemCount:items.length, itemBuilder:(_,i) {
          final v=items[i], bytes=imageBytes(v['image_data']?.toString());
          return Card(margin: const EdgeInsets.only(bottom:12), clipBehavior:Clip.antiAlias, child: Row(children:[
            SizedBox(width:120,height:110,child:bytes==null?Container(color:Colors.blue.shade50,child:const Icon(Icons.directions_car,size:45,color:Colors.blue)):Image.memory(bytes,fit:BoxFit.cover)),
            Expanded(child:ListTile(title:Text(v['vehicle_name']?.toString() ?? '${v['brand']} ${v['model']}',style:const TextStyle(fontWeight:FontWeight.bold)),
              subtitle:Text('${categoryLabel(v['category']?.toString())} • ${v['color']}\nاللوحة: ${v['plate_number']}'))),
          ]));
        }),
  ));
}
