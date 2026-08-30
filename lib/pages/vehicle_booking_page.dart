import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../session.dart';
import 'payment_page.dart';
import 'vehicles_page.dart';

class VehicleBookingPage extends StatefulWidget { final String baseUrl; const VehicleBookingPage({super.key,required this.baseUrl}); @override State<VehicleBookingPage> createState()=>_VehicleBookingPageState(); }
class _VehicleBookingPageState extends State<VehicleBookingPage>{
  bool loading=true, slotsLoading=false; List<Map<String,dynamic>> locations=[],cars=[],services=[],addOns=[]; Set<String> booked={};
  final Map<int,int> addOnQuantities={};
  late List<DateTime> dates; late DateTime date; Map<String,dynamic>? location,car,service; String? time; Map<String,dynamic>? currentLocation;
  final slots=['9 صباحاً','10 صباحاً','11 صباحاً','4 مساءً','5 مساءً','6 مساءً','7 مساءً','8 مساءً','9 مساءً','10 مساءً','11 مساءً','12 مساءً'];
  @override void initState(){super.initState();final now=DateTime.now();dates=List.generate(4,(i)=>DateTime(now.year,now.month,now.day).add(Duration(days:i)));date=dates.first;load();}
  String day(DateTime d)=>['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'][d.weekday-1];
  String iso(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  Future<void> load()async{final rs=await Future.wait([
    http.get(Uri.parse('${widget.baseUrl}/api/locations/'),headers:Session.authHeaders),
    http.get(Uri.parse('${widget.baseUrl}/api/cars/'),headers:Session.authHeaders),
    http.get(Uri.parse('${widget.baseUrl}/api/services/')),
    http.get(Uri.parse('${widget.baseUrl}/api/add-ons/'))]);
    if(mounted)setState((){locations=rs[0].statusCode==200?(jsonDecode(rs[0].body)as List).cast<Map<String,dynamic>>():[];cars=rs[1].statusCode==200?(jsonDecode(rs[1].body)as List).cast<Map<String,dynamic>>():[];services=rs[2].statusCode==200?(jsonDecode(rs[2].body)as List).cast<Map<String,dynamic>>():[];addOns=rs[3].statusCode==200?(jsonDecode(rs[3].body)as List).cast<Map<String,dynamic>>():[];loading=false;});await loadSlots();}
  Future<void> loadSlots()async{setState((){slotsLoading=true;time=null;});final r=await http.get(Uri.parse('${widget.baseUrl}/api/booked-slots/?date=${iso(date)}'));if(mounted)setState((){booked=r.statusCode==200?Set<String>.from(jsonDecode(r.body)['booked']):{};slotsLoading=false;});}
  Future<void> useCurrent()async{try{var p=await Geolocator.checkPermission();if(p==LocationPermission.denied)p=await Geolocator.requestPermission();if(p==LocationPermission.denied||p==LocationPermission.deniedForever)return;final x=await Geolocator.getCurrentPosition();setState((){currentLocation={'id':null,'name':'الموقع الحالي','address_text':'الموقع الحالي','latitude':x.latitude,'longitude':x.longitude};location=currentLocation;});}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر تحديد الموقع الحالي')));}}
  List<Map<String,dynamic>> selectedAddOns()=>addOns.where((x)=>(addOnQuantities[x['id']]??0)>0).map((x)=>{'id':x['id'],'name':x['name'],'unit':x['unit'],'price':x['price'],'quantity':addOnQuantities[x['id']]!}).toList();
  double total(){double value=double.tryParse(service?['price']?.toString()??'0')??0;if(service?['name'].toString().contains('كامل')==true&&car?['size']=='big')value+=10;for(final x in selectedAddOns()){value+=(double.tryParse(x['price'].toString())??0)*(x['quantity'] as int);}return value;}
  void next(){if(location==null||car==null||service==null||time==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أكمل اختيار الموقع والمركبة والخدمة والوقت')));return;}Navigator.push(context,MaterialPageRoute(builder:(_)=>PaymentPage(baseUrl:widget.baseUrl,location:location!,car:car!,service:service!,addOns:selectedAddOns(),total:total(),date:iso(date),time:time!)));}
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('غسيل السيارات')),body:loading?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
    _title('اختر اليوم'),Wrap(spacing:8,runSpacing:8,children:dates.map((d)=>ChoiceChip(selected:date==d,label:Text('${day(d)}\n${d.day}/${d.month}',textAlign:TextAlign.center),onSelected:(_){setState(()=>date=d);loadSlots();})).toList()),
    _title('الموقع'),DropdownButtonFormField<Map<String,dynamic>>(value:location,decoration:const InputDecoration(labelText:'اختر موقعًا محفوظًا'),items:[...locations,if(currentLocation!=null)currentLocation!].map((x)=>DropdownMenuItem(value:x,child:Text(x['name']))).toList(),onChanged:(v)=>setState(()=>location=v)),const SizedBox(height:8),OutlinedButton.icon(onPressed:useCurrent,icon:const Icon(Icons.my_location),label:const Text('استخدام الموقع الحالي')),
    _title('المركبة'),DropdownButtonFormField<Map<String,dynamic>>(value:car,decoration:const InputDecoration(labelText:'اختر مركبة'),items:cars.map((x)=>DropdownMenuItem(value:x,child:Text('${x['vehicle_name'] ?? x['brand']} - ${x['plate_number']}'))).toList(),onChanged:(v)=>setState(()=>car=v)),const SizedBox(height:8),OutlinedButton.icon(onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>VehiclesPage(baseUrl:widget.baseUrl)));await load();},icon:const Icon(Icons.add),label:const Text('إضافة مركبة جديدة')),
    _title('خدمة الغسيل'),...services.map((x)=>RadioListTile<Map<String,dynamic>>(value:x,groupValue:service,onChanged:(v)=>setState(()=>service=v),title:Text(x['name']),subtitle:Text('${x['price']} ر.س'))),
    _title('خدمات إضافية (اختياري)'),...addOns.map((x){final id=x['id'] as int,qty=addOnQuantities[id]??0,allows=x['allows_quantity']==true;return Card(child:Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),child:Row(children:[Checkbox(value:qty>0,onChanged:(v)=>setState(()=>addOnQuantities[id]=v==true?1:0)),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x['name'],style:const TextStyle(fontWeight:FontWeight.bold)),Text('${x['price']} ر.س / ${x['unit']}',style:const TextStyle(color:Colors.black54))])),if(qty>0&&allows)...[IconButton(onPressed:qty<=1?null:()=>setState(()=>addOnQuantities[id]=qty-1),icon:const Icon(Icons.remove_circle_outline)),Text('$qty',style:const TextStyle(fontWeight:FontWeight.bold)),IconButton(onPressed:()=>setState(()=>addOnQuantities[id]=qty+1),icon:const Icon(Icons.add_circle_outline))]])));}),
    _title('الأوقات المتاحة'),if(slotsLoading)const Center(child:CircularProgressIndicator())else Wrap(spacing:8,runSpacing:8,children:slots.map((s)=>ChoiceChip(label:Text(s),selected:time==s,onSelected:booked.contains(s)?null:(_)=>setState(()=>time=s),disabledColor:Colors.grey.shade200)).toList()),
    const SizedBox(height:24),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:Column(children:[_row('الخدمة',service?['name']??'لم تحدد'),_row('الإضافات','${selectedAddOns().length}'),_row('الإجمالي المبدئي','${total().toStringAsFixed(2)} ر.س'),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:next,child:const Text('تأكيد والانتقال للدفع')))])),const SizedBox(height:30)
  ])));
  Widget _title(String x)=>Padding(padding:const EdgeInsets.only(top:22,bottom:10),child:Text(x,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)));
  Widget _row(String a,String b)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(a),Text(b,style:const TextStyle(fontWeight:FontWeight.bold))]));
}
