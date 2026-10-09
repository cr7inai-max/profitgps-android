import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_scope.dart';
import '../services/secure_access.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final pin = TextEditingController();
  final confirmation = TextEditingController();
  bool loading = true;
  bool busy = false;
  bool createOwner = false;
  bool obscure = true;
  String role = 'Owner';

  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    try {
      final exists = await SecureAccess.hasPin('Owner');
      if (mounted) setState(() {createOwner = !exists; loading = false;});
    } catch (e) {
      if (mounted) setState(() {loading = false;});
      if (mounted) _error('Secure credential storage could not be opened: ' + e.toString());
    }
  }
  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  Future<void> _continue() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (createOwner) {
        if (pin.text != confirmation.text) throw const FormatException('PIN confirmation does not match.');
        await SecureAccess.setPin('Owner', pin.text);
      } else {
        if (!await SecureAccess.checkPin(role, pin.text)) {
          throw const FormatException('Incorrect PIN or staff PIN is not configured.');
        }
      }
      final app = AppScope.of(context);
      app.data!.business.activeRole = role;
      if (role == 'Worker') app.data!.business.showProfitInBilling = false;
      await app.persist();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    } catch (e) {
      if (mounted) _error(e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  void dispose() { pin.dispose(); confirmation.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Card(
        child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            const Row(children:[
              Icon(Icons.lock_outline_rounded,size:33),
              SizedBox(width:12),
              Expanded(child:Text('ProfitGPS',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900))),
            ]),
            const SizedBox(height:16),
            if (loading) const Center(child:CircularProgressIndicator())
            else ...[
              Text(createOwner?'Secure owner setup':'Sign in',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
              const SizedBox(height:7),
              Text(createOwner?'Create your own 6–12 digit Owner PIN. There are no default credentials.':
                'Enter the PIN configured for this device.',style:const TextStyle(fontSize:12)),
              const SizedBox(height:14),
              if (!createOwner) SegmentedButton<String>(
                segments:const [
                  ButtonSegment(value:'Owner',label:Text('Owner'),icon:Icon(Icons.admin_panel_settings_outlined)),
                  ButtonSegment(value:'Worker',label:Text('Worker'),icon:Icon(Icons.badge_outlined)),
                ],
                selected:{role},
                onSelectionChanged:(roles)=>setState((){
                  role = roles.first;
                  pin.clear();
                }),
              ),
              const SizedBox(height:10),
              TextField(controller:pin,obscureText:obscure,
                keyboardType:TextInputType.number,
                inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(12)],
                decoration:InputDecoration(labelText:createOwner?'New owner PIN':'PIN',prefixIcon:const Icon(Icons.pin_outlined),
                  suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),
                    icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined)))),
              if (createOwner) ...[
                const SizedBox(height:8),
                TextField(controller:confirmation,obscureText:true,keyboardType:TextInputType.number,
                  inputFormatters:[FilteringTextInputFormatter.digitsOnly,LengthLimitingTextInputFormatter(12)],
                  decoration:const InputDecoration(labelText:'Confirm owner PIN',prefixIcon:Icon(Icons.verified_user_outlined))),
              ],
              const SizedBox(height:15),
              FilledButton.icon(onPressed:busy?null:_continue,
                icon:const Icon(Icons.login_rounded),label:Text(busy?'Working…':createOwner?'Secure this device':'Sign in')),
              const SizedBox(height:10),
              const Text('Keep a current backup. Forgotten PINs cannot be recovered by a default password.',
                textAlign:TextAlign.center,style:TextStyle(fontSize:11)),
            ],
          ])),
      )),
    ))),
  );
}
