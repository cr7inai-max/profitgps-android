import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/secure_access.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});
  @override
  State<SecuritySettingsScreen> createState()=>_SecuritySettingsState();
}
class _SecuritySettingsState extends State<SecuritySettingsScreen> {
  final oldPin=TextEditingController();
  final newPin=TextEditingController();
  final confirm=TextEditingController();
  String target='Worker';
  bool busy=false;
  @override void dispose(){oldPin.dispose();newPin.dispose();confirm.dispose();super.dispose();}
  Future<void> save()async{
    setState(()=>busy=true);
    try{
      if(!await SecureAccess.checkPin('Owner',oldPin.text))
        throw const FormatException('Current owner PIN is incorrect.');
      if(newPin.text!=confirm.text)
        throw const FormatException('New PINs do not match.');
      await SecureAccess.setPin(target,newPin.text);
      oldPin.clear();newPin.clear();confirm.clear();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(target+' PIN saved to secure device storage.')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(e.toString().replaceFirst('FormatException: ',''))));
    }finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Text('Access security',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),
    const SizedBox(height:7),
    const Text('Owner approval is required to change an owner PIN or set the worker PIN.'),
    const SizedBox(height:12),
    SegmentedButton<String>(segments:const [
      ButtonSegment(value:'Owner',label:Text('Change Owner PIN')),
      ButtonSegment(value:'Worker',label:Text('Set Worker PIN')),
    ],selected:{target},onSelectionChanged:(v)=>setState(()=>target=v.first)),
    const SizedBox(height:12),
    for(final form in <(String,TextEditingController)>[
      ('Current owner PIN',oldPin),('New '+target+' PIN (6–12 digits)',newPin),
      ('Confirm new PIN',confirm),
    ])Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(
      controller:form.$2,obscureText:true,keyboardType:TextInputType.number,
      inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(12)],
      decoration:InputDecoration(labelText:form.$1,border:const OutlineInputBorder()))),
    FilledButton.icon(onPressed:busy?null:save,icon:const Icon(Icons.verified_user_outlined),label:const Text('Save access settings')),
    const SizedBox(height:12),
    const Text('Security PINs are not exported in ordinary inventory backups. Losing the owner PIN can prevent access.',
      style:TextStyle(fontSize:12)),
  ]);
}
