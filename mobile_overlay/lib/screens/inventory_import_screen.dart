import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/app_scope.dart';
import '../models/entities.dart';
import 'suppliers_screen.dart';

/// Unverified spreadsheet items remain separate from billable Products.
class InventoryImportScreen extends StatefulWidget {
  const InventoryImportScreen({super.key});
  @override
  State<InventoryImportScreen> createState() => _InventoryImportScreenState();
}

class _InventoryImportScreenState extends State<InventoryImportScreen> {
  static const fields = <String, String>{
    'name':'Product name', 'productCode':'SKU / product code',
    'barcode':'Barcode', 'brand':'Brand', 'category':'Category',
    'subcategory':'Subcategory', 'unit':'Selling unit',
    'packType':'Pack type', 'netContent':'Net content',
    'conversionQty':'Purchase to selling conversion', 'purchaseUnit':'Purchase unit',
    'sourceType':'Source (Supplier / Local/Farmer / Own)',
    'supplierId':'Supplier ID', 'supplierName':'Supplier name',
    'taxCategory':'GST category', 'gstRate':'GST rate %',
    'hsnSac':'HSN / SAC', 'taxInclusive':'GST inclusive (yes/no)',
    'mrp':'MRP', 'sellingPrice':'Selling price', 'purchasePrice':'Purchase price',
    'stock':'Stock', 'reorderLevel':'Reorder level', 'expiryDate':'Expiry date',
    'mfgDate':'Manufacturing date', 'expiryPolicy':'Expiry option',
  };
  static const aliases = <String, List<String>>{
    'name':['name','productname','itemname','description'],
    'productCode':['sku','productid','itemcode','productcode'],
    'barcode':['barcode','ean','gtin'], 'brand':['brand','brandname'],
    'category':['category'], 'subcategory':['subcategory'],
    'unit':['unit','sellingunit','uom'],
    'packType':['pack','packtype'], 'netContent':['netcontent','packsize'],
    'conversionQty':['conversion','conversionqty'], 'purchaseUnit':['purchaseunit'],
    'sourceType':['source','sourcetype'], 'supplierId':['supplierid'],
    'supplierName':['supplier','suppliername','vendor'],
    'taxCategory':['gstcategory','taxcategory','taxstatus'],
    'gstRate':['gstrate','gstpercent','gst','taxrate'],
    'hsnSac':['hsn','hsnsac'], 'taxInclusive':['gstinclusive','taxinclusive'],
    'mrp':['mrp'], 'sellingPrice':['sellingprice','saleprice','price'],
    'purchasePrice':['purchaseprice','cost','buyprice'],
    'stock':['stock','qty','quantity','openingstock'], 'reorderLevel':['reorderlevel'],
    'expiryDate':['expirydate','expiry','expdate'], 'mfgDate':['mfgdate','mfg'],
    'expiryPolicy':['expirypolicy'],
  };
  List<String> headers = [];
  List<List<String>> rawRows = [];
  Map<String,int> mapping = {};
  String filename = '';
  final Set<String> selected = {};
  String bulkSource = '';
  String bulkSupplier = '';
  String bulkCategory = '';
  String bulkGst = '';
  String bulkExpiry = '';
  bool busy = false;
  static String norm(String v) => v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  static double? number(Object? v) => double.tryParse((v ?? '').toString().trim());
  static String str(Map<String,dynamic> d, String key) => (d[key] ?? '').toString().trim();
  static String cell(CellValue? c) {
    if (c is TextCellValue) return c.value;
    if (c is IntCellValue) return c.value.toString();
    if (c is DoubleCellValue) return c.value.toString();
    if (c is BoolCellValue) return c.value.toString();
    return c?.toString() ?? '';
  }
  static List<List<String>> parseCsv(String content) {
    final out = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (ch == '"') {
        if (quoted && i+1 < content.length && content[i+1] == '"') {
          field.write('"'); i++;
        } else { quoted = !quoted; }
      } else if (ch == ',' && !quoted) {
        row.add(field.toString().trim()); field = StringBuffer();
      } else if ((ch == '\r' || ch == '\n') && !quoted) {
        if (ch == '\r' && i+1 < content.length && content[i+1] == '\n') i++;
        row.add(field.toString().trim()); field = StringBuffer();
        if (row.any((v) => v.isNotEmpty)) out.add(row);
        row = <String>[];
      } else { field.write(ch); }
    }
    row.add(field.toString().trim());
    if (row.any((v) => v.isNotEmpty)) out.add(row);
    return out;
  }
  Future<void> selectFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx','csv'], withData: true);
      if (picked == null || picked.files.isEmpty) return;
      final f = picked.files.single;
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) bytes = await File(f.path!).readAsBytes();
      if (bytes == null) throw const FormatException('Cannot read spreadsheet');
      List<List<String>> sheet;
      if (f.name.toLowerCase().endsWith('.csv')) {
        sheet = parseCsv(utf8.decode(bytes, allowMalformed:true).replaceFirst('\uFEFF',''));
      } else {
        final book = Excel.decodeBytes(bytes);
        if (book.tables.isEmpty) throw const FormatException('Empty workbook');
        sheet = book.tables.values.first.rows
            .map((r) => r.map((c) => cell(c?.value).trim()).toList()).toList();
        sheet.removeWhere((r) => r.every((v) => v.isEmpty));
      }
      if (sheet.length < 2) throw const FormatException('Spreadsheet needs a header and product rows');
      final m = <String,int>{};
      for (final entry in aliases.entries) {
        final hit = sheet.first.indexWhere((h) => entry.value.contains(norm(h)));
        if (hit >= 0) m[entry.key] = hit;
      }
      setState(() {
        filename = f.name;
        headers = sheet.first;
        rawRows = sheet.skip(1).toList();
        mapping = m;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot open: ' + e.toString())));
    }
  }
  Future<void> stage() async {
    if (!mapping.containsKey('name')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Map Product name before staging.')));
      return;
    }
    final app = AppScope.of(context);
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    var count = 0;
    for (var row = 0; row < rawRows.length; row++) {
      final d = <String,dynamic>{
        '_id':stamp + '_' + row.toString(),
        '_source':filename, '_row':row+2,
      };
      for (final entry in mapping.entries) {
        final index = entry.value;
        d[entry.key] = index >= 0 && index < rawRows[row].length ? rawRows[row][index] : '';
      }
      if (str(d,'name').isEmpty) continue;
      app.data!.pendingInventory.add(d); count++;
    }
    await app.persist();
    if (!mounted) return;
    setState(() {headers=[];rawRows=[];mapping={};filename='';});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$count rows staged. None are billable until verified.')));
  }
  List<String> issues(Map<String,dynamic> d, List<Product> products, List<Supplier> suppliers) {
    final errors = <String>[];
    for (final f in ['name','category','unit']) {
      if (str(d,f).isEmpty) errors.add(fields[f]!);
    }
    if ((number(d['sellingPrice']) ?? 0) <= 0) errors.add('Selling price');
    if (str(d,'stock').isEmpty || (number(d['stock']) ?? -1) < 0) errors.add('Stock (0 accepted)');
    final tax = str(d,'taxCategory');
    if (!['Taxable','Nil rated','Exempt','Non-GST'].contains(tax)) errors.add('GST category');
    if (tax == 'Taxable' && (number(d['gstRate']) ?? 0) <= 0) errors.add('GST rate');
    if (tax == 'Taxable' && str(d,'hsnSac').isEmpty) errors.add('HSN / SAC');
    if (tax != 'Taxable' && str(d,'gstRate').isNotEmpty && number(d['gstRate']) != 0) errors.add('GST rate must be zero');
    final source = str(d,'sourceType');
    if (!['Supplier','Local/Farmer','Own'].contains(source)) errors.add('Source type');
    if (source == 'Supplier' && !suppliers.any((s) => s.active && s.id == str(d,'supplierId'))) errors.add('Select supplier from master');
    if (str(d,'packType').isNotEmpty && str(d,'netContent').isEmpty) errors.add('Net content');
    if (str(d,'packType').isNotEmpty && (number(d['conversionQty']) ?? 0) <= 0) errors.add('Unit conversion');
    if (str(d,'expiryDate').isEmpty && !['No expiry','Only MFG date'].contains(str(d,'expiryPolicy'))) errors.add('Expiry option');
    if (str(d,'productCode').isNotEmpty && products.any((p) => p.productCode == str(d,'productCode'))) errors.add('SKU already exists; edit existing product');
    if (str(d,'barcode').isNotEmpty && products.any((p) => p.barcode == str(d,'barcode'))) errors.add('Barcode already exists; edit existing product');
    return errors;
  }
  Widget chooser(String label, TextEditingController c, List<String> values, {Map<String,String> titles = const {}}) {
    return Padding(padding:const EdgeInsets.symmetric(vertical:4),
      child: StatefulBuilder(builder:(context, local) => DropdownButtonFormField<String>(
        isExpanded:true,
        value:values.contains(c.text) ? c.text : null,
        decoration:InputDecoration(labelText:label, border:const OutlineInputBorder(), isDense:true),
        items:[for(final v in values) DropdownMenuItem(value:v,child:Text(titles[v]??v,overflow:TextOverflow.ellipsis))],
        onChanged:(v)=>local(()=>c.text=v??''))));
  }
  Future<void> edit(Map<String,dynamic> draft) async {
    final app = AppScope.of(context);
    final c = <String,TextEditingController>{for(final k in fields.keys)
      k:TextEditingController(text:str(draft,k))};
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Review • Row '+(draft['_row']??'').toString()),
      content:SizedBox(width:550,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        for(final entry in fields.entries)
          if(entry.key=='sourceType') chooser(entry.value,c[entry.key]!,const ['Supplier','Local/Farmer','Own'])
          else if(entry.key=='taxCategory') chooser(entry.value,c[entry.key]!,const ['Taxable','Nil rated','Exempt','Non-GST'])
          else if(entry.key=='expiryPolicy') chooser(entry.value,c[entry.key]!,const ['No expiry','Only MFG date','Expiry date provided'])
          else if(entry.key=='supplierId') chooser('Supplier master',c[entry.key]!,
            [for(final s in app.data!.suppliers.where((s)=>s.active)) s.id],
            titles:{for(final s in app.data!.suppliers.where((s)=>s.active))s.id:s.name})
          else Padding(padding:const EdgeInsets.symmetric(vertical:4),child:TextField(
            controller:c[entry.key],decoration:InputDecoration(labelText:entry.value,border:const OutlineInputBorder(),isDense:true))),
        TextButton.icon(onPressed:() async {
          Navigator.of(ctx).pop();
          await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const SuppliersScreen()));
        },icon:const Icon(Icons.person_add_alt_rounded),label:const Text('Open supplier master / Add supplier')),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.of(ctx).pop(),child:const Text('Cancel')),
        FilledButton(onPressed:() async {
          final target=app.data!.pendingInventory.indexWhere((d)=>d['_id']==draft['_id']);
          if(target>=0){
            final copy=Map<String,dynamic>.from(app.data!.pendingInventory[target]);
            for(final entry in c.entries) copy[entry.key]=entry.value.text.trim();
            app.data!.pendingInventory[target]=copy;
            await app.persist();
          }
          if(ctx.mounted) Navigator.of(ctx).pop();
          if(mounted) setState((){});
        },child:const Text('Save review')),
      ]));
    for(final controller in c.values)controller.dispose();
  }
  Future<void> bulkEdit() async {
    if(selected.isEmpty)return;
    final app=AppScope.of(context);
    for(final d in app.data!.pendingInventory) {
      if(!selected.contains(d['_id']))continue;
      if(bulkSource.isNotEmpty)d['sourceType']=bulkSource;
      if(bulkSupplier.isNotEmpty)d['supplierId']=bulkSupplier;
      if(bulkCategory.isNotEmpty)d['taxCategory']=bulkCategory;
      if(bulkGst.isNotEmpty)d['gstRate']=bulkGst;
      if(bulkExpiry.isNotEmpty)d['expiryPolicy']=bulkExpiry;
    }
    await app.persist();
    if(mounted)setState(()=>selected.clear());
  }
  Future<void> approve() async {
    final app=AppScope.of(context);
    final data=app.data!;
    var done=0;
    for(final d in List<Map<String,dynamic>>.from(data.pendingInventory)) {
      if(!selected.contains(d['_id']) || issues(d,data.products,data.suppliers).isNotEmpty)continue;
      final supplier=data.suppliers.where((s)=>s.id==str(d,'supplierId')).firstOrNull;
      final unit=str(d,'unit');
      final isTax=str(d,'taxCategory')=='Taxable';
      data.products.add(Product(
        id:const Uuid().v4(),name:str(d,'name'),barcode:str(d,'barcode'),
        category:str(d,'category'),productCode:str(d,'productCode'),
        purchasePrice:number(d['purchasePrice'])??0,sellingPrice:number(d['sellingPrice'])??0,
        gstRate:isTax?(number(d['gstRate'])??0):0,stock:number(d['stock'])??0,
        reorderLevel:number(d['reorderLevel'])??0,mrp:number(d['mrp'])??0,
        gstApplicable:isTax,taxCategory:str(d,'taxCategory'),
        taxInclusive:['yes','true','1','inclusive'].contains(str(d,'taxInclusive').toLowerCase()),
        hsnSac:str(d,'hsnSac'),brand:str(d,'brand'),subcategory:str(d,'subcategory'),unit:unit,
        weighted:const ['kg','g','l','ml','metre','meter'].contains(unit.toLowerCase()),
        supplierId:str(d,'sourceType')=='Supplier'?str(d,'supplierId'):'',
        supplier:supplier?.name??str(d,'sourceType'),
        packageSize:[str(d,'packType'),str(d,'netContent')].where((x)=>x.isNotEmpty).join(' • '),
        purchaseUnit:str(d,'purchaseUnit').isNotEmpty?str(d,'purchaseUnit'):unit,
        packConversionQty:str(d,'packType').isNotEmpty?(number(d['conversionQty'])??1):1,
        expiryDate:DateTime.tryParse(str(d,'expiryDate')),
        customAttributes:{
          'sourceType':str(d,'sourceType'),'packType':str(d,'packType'),
          'netContent':str(d,'netContent'),'mfgDate':str(d,'mfgDate'),
          'expiryPolicy':str(d,'expiryPolicy'),
        },
      ));
      data.pendingInventory.removeWhere((entry)=>entry['_id']==d['_id']);
      done++;
    }
    await app.persist();
    if(!mounted)return;
    setState(()=>selected.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$done verified products activated. Pending rows stay blocked.')));
  }
  Widget bulkSelect(String label,String value,List<String> options,ValueChanged<String> onChange,{Map<String,String> titles=const {}}) =>
      Padding(padding:const EdgeInsets.only(top:8),child:DropdownButtonFormField<String>(
        isExpanded:true,value:value.isEmpty?null:value,
        decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true),
        items:[for(final v in options)DropdownMenuItem(value:v,child:Text(titles[v]??v,overflow:TextOverflow.ellipsis))],
        onChanged:(v)=>onChange(v??'')));
  @override
  Widget build(BuildContext context) {
    final data=AppScope.of(context).data!;
    final pending=data.pendingInventory;
    final ready=pending.where((d)=>issues(d,data.products,data.suppliers).isEmpty).length;
    return ListView(padding:const EdgeInsets.all(12),children:[
      const Text('Universal Inventory Import',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),
      const SizedBox(height:5),
      const Text('Excel / CSV → Map columns → Pending review → Approve verified products only.'),
      const SizedBox(height:9),
      FilledButton.icon(onPressed:busy?null:selectFile,icon:const Icon(Icons.upload_file),label:const Text('Choose Excel (.xlsx) or CSV')),
      if(headers.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
        Text(filename+' • '+rawRows.length.toString()+' rows',style:const TextStyle(fontWeight:FontWeight.w900)),
        const Text('Confirm column mapping. Unprovided tax or supplier fields remain blank.'),
        for(final f in fields.entries)Padding(padding:const EdgeInsets.only(top:6),child:DropdownButtonFormField<int>(
          isExpanded:true,value:mapping[f.key]??-1,
          decoration:InputDecoration(labelText:f.value,border:const OutlineInputBorder(),isDense:true),
          items:[const DropdownMenuItem(value:-1,child:Text('Not mapped')),
            for(var i=0;i<headers.length;i++)DropdownMenuItem(value:i,child:Text(headers[i],overflow:TextOverflow.ellipsis))],
          onChanged:(v)=>setState((){if(v==null||v<0){mapping.remove(f.key);}else{mapping[f.key]=v;}}))),
        const SizedBox(height:10),
        FilledButton.icon(onPressed:stage,icon:const Icon(Icons.playlist_add_check),label:const Text('Stage records for review')),
      ]))),
      const Divider(height:24),
      Text('Pending: '+pending.length.toString()+'    Ready: '+ready.toString(),style:const TextStyle(fontWeight:FontWeight.w900,fontSize:15)),
      if(pending.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Bulk edit selected products',style:TextStyle(fontWeight:FontWeight.w900)),
        bulkSelect('Source type',bulkSource,const ['Supplier','Local/Farmer','Own'],(v)=>setState(()=>bulkSource=v)),
        bulkSelect('Supplier master',bulkSupplier,[for(final s in data.suppliers.where((s)=>s.active))s.id],
          (v)=>setState(()=>bulkSupplier=v),titles:{for(final s in data.suppliers.where((s)=>s.active))s.id:s.name}),
        bulkSelect('GST category',bulkCategory,const ['Taxable','Nil rated','Exempt','Non-GST'],(v)=>setState(()=>bulkCategory=v)),
        TextField(decoration:const InputDecoration(labelText:'GST % for selected rows (optional)'),onChanged:(v)=>bulkGst=v,
          keyboardType:const TextInputType.numberWithOptions(decimal:true)),
        bulkSelect('Expiry option',bulkExpiry,const ['No expiry','Only MFG date','Expiry date provided'],
          (v)=>setState(()=>bulkExpiry=v)),
        const SizedBox(height:8),
        Wrap(spacing:7,runSpacing:7,children:[
          OutlinedButton(onPressed:selected.isEmpty?null:bulkEdit,child:const Text('Apply bulk fields')),
          FilledButton(onPressed:selected.isEmpty?null:approve,child:const Text('Approve verified')),
          TextButton(onPressed:()=>setState((){
            if(selected.length==pending.length){selected.clear();}
            else{selected.addAll(pending.map((d)=>str(d,'_id')));}
          }),child:const Text('Select all / clear')),
        ]),
      ]))),
      for(final d in pending)Builder(builder:(_){
        final missing=issues(d,data.products,data.suppliers);
        final id=str(d,'_id');
        return Card(child:ListTile(
          leading:Checkbox(value:selected.contains(id),onChanged:(v)=>setState((){
            if(v==true){selected.add(id);}else{selected.remove(id);}
          })),
          title:Text(str(d,'name')),
          subtitle:Text(missing.isEmpty?'Ready to approve':'Missing: '+missing.join(', '),maxLines:4,overflow:TextOverflow.ellipsis,
            style:TextStyle(color:missing.isEmpty?Colors.green[700]:Colors.deepOrange[700])),
          trailing:IconButton(onPressed:()=>edit(d),icon:const Icon(Icons.edit_note)),
          onTap:()=>edit(d),
        ));
      }),
    ]);
  }
}
