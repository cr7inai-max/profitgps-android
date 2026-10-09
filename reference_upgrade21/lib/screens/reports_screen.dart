import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../services/analytics_engine.dart';
import '../services/report_service.dart';
import '../widgets/common.dart';

class ReportsScreen extends StatefulWidget { const ReportsScreen({super.key}); @override State<ReportsScreen> createState()=>_ReportsScreenState(); }
class _ReportsScreenState extends State<ReportsScreen> {
  bool busy=false;
  @override Widget build(BuildContext context){
    final c=AppScope.of(context); final d=c.data!;
    final today=AnalyticsEngine.salesInDays(d,1);
    final pm=<String,double>{}; for(final s in today){pm[s.paymentMethod]=(pm[s.paymentMethod]??0)+s.total;}
    return ListView(padding:const EdgeInsets.all(24),children:[
      SectionTitle('Reports & Sharing',subtitle:'Generate locally, then share through the device share sheet (Gmail, Telegram, etc.).',trailing:FilledButton.icon(onPressed:busy?null:()=>_share(context),icon:busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.share),label:const Text('Generate & Share PDF'))),
      LayoutBuilder(builder:(context,x)=>GridView.count(crossAxisCount:x.maxWidth>900?3:1,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),childAspectRatio:2.4,crossAxisSpacing:12,mainAxisSpacing:12,children:[MetricCard(label:'Today bills',value:'${today.length}',icon:Icons.receipt_long),MetricCard(label:'Today sales',value:money(AnalyticsEngine.salesTotal(today)),icon:Icons.payments),MetricCard(label:'Today profit',value:money(AnalyticsEngine.profitTotal(today)),icon:Icons.trending_up)])),
      const SizedBox(height:20),const SectionTitle('Payment mix'),
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:pm.entries.map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[Expanded(child:Text(e.key)),Text(money(e.value),style:const TextStyle(fontWeight:FontWeight.w800))]))).toList()))),
      const SizedBox(height:20),const SectionTitle('Available report set'),
      const Card(child:Column(children:[
        ListTile(leading:Icon(Icons.today,color:AppTheme.red),title:Text('Daily sales & Profit GPS report'),subtitle:Text('Implemented PDF export')),
        ListTile(leading:Icon(Icons.store_mall_directory,color:AppTheme.green),title:Text('Branch comparison'),subtitle:Text('Included in daily PDF and on-screen control center')),
        ListTile(leading:Icon(Icons.inventory,color:AppTheme.amber),title:Text('Inventory / expiry / low-stock'),subtitle:Text('Available from local data; export extension ready')),
        ListTile(leading:Icon(Icons.people_alt_outlined),title:Text('Employee performance & appraisal scenarios'),subtitle:Text('Available on-screen; PDF template extension ready')),
      ]))
    ]);
  }
  Future<void> _share(BuildContext context) async{
    setState(()=>busy=true);
    try{final path=await ReportService.dailyPdf(AppScope.of(context).data!);await Share.shareXFiles([XFile(path)],text:'Profit GPS daily business report');}
    finally{if(mounted)setState(()=>busy=false);}
  }
}
