import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../session.dart';
import 'map_picker.dart';

class LocationsPage extends StatefulWidget { final String baseUrl; const LocationsPage({super.key,required this.baseUrl}); @override State<LocationsPage> createState()=>_LocationsPageState(); }
class _LocationsPageState extends State<LocationsPage>{ bool loading=true; List<Map<String,dynamic>> items=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{final r=await http.get(Uri.parse('${widget.baseUrl}/api/locations/'),headers:Session.authHeaders);if(r.statusCode==401){await Session.handleUnauthorized();return;}if(mounted)setState((){items=r.statusCode==200?(jsonDecode(r.body)as List).cast<Map<String,dynamic>>():[];loading=false;});}
  Future<void> add()async{final name=TextEditingController(),address=TextEditingController();LatLng? point;
    final saved=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setLocal)=>Directionality(textDirection:TextDirection.rtl,child:AlertDialog(title:const Text('إضافة موقع'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'اسم الموقع (المنزل، العمل...)')),const SizedBox(height:10),TextField(controller:address,decoration:const InputDecoration(labelText:'وصف العنوان')),const SizedBox(height:12),OutlinedButton.icon(onPressed:()async{final p=await Navigator.push<LatLng>(context,MaterialPageRoute(builder:(_)=>MapPickerPage()));if(p!=null)setLocal(()=>point=p);},icon:const Icon(Icons.map),label:Text(point==null?'تحديد الموقع على الخريطة':'تم تحديد الموقع ✓'))])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('إلغاء')),FilledButton(onPressed:point==null?null:()=>Navigator.pop(context,true),child:const Text('حفظ'))]))));
    if(saved==true&&point!=null){final r=await http.post(Uri.parse('${widget.baseUrl}/api/locations/'),headers:Session.authHeaders,body:jsonEncode({'name':name.text,'address_text':address.text,'latitude':point!.latitude,'longitude':point!.longitude}));if(r.statusCode==401){await Session.handleUnauthorized();return;}load();}}
  @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(appBar:AppBar(title:const Text('المواقع')),floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add_location_alt),label:const Text('إضافة موقع')),body:loading?const Center(child:CircularProgressIndicator()):items.isEmpty?const Center(child:Text('لا توجد مواقع محفوظة')):ListView.builder(padding:const EdgeInsets.all(16),itemCount:items.length,itemBuilder:(_,i){final x=items[i];return Card(child:ListTile(contentPadding:const EdgeInsets.all(16),leading:const CircleAvatar(child:Icon(Icons.location_on)),title:Text(x['name']??'',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(x['address_text']??'')));})));
}
