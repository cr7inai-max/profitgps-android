import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../services/gs1_scan_parser.dart';
import '../services/product_lookup_service.dart';
import '../widgets/barcode_input_dialog.dart';
import 'purchase_screen.dart';

class ProductOnboardingScreen extends StatefulWidget {
  const ProductOnboardingScreen({super.key});
  @override
  State<ProductOnboardingScreen> createState() => _ProductOnboardingScreenState();
}

class _ProductOnboardingScreenState extends State<ProductOnboardingScreen> {
  final queue = <Map<String, dynamic>>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<File> _queueFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/profitgps_product_onboarding_queue.json');
  }

  Future<void> _loadQueue() async {
    try {
      final file = await _queueFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) queue.addAll(raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _saveQueue() async {
    final file = await _queueFile();
    await file.writeAsString(jsonEncode(queue));
  }

  Future<void> _stageFile(String sourceType, List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: extensions, withData: false);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    var rows = 0;
    if ((picked.extension ?? '').toLowerCase() == 'csv' && picked.path != null) {
      try {
        final lines = await File(picked.path!).readAsLines();
        rows = lines.length > 1 ? lines.length - 1 : lines.length;
      } catch (_) {}
    }
    setState(() {
      queue.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'sourceType': sourceType,
        'fileName': picked.name,
        'extension': picked.extension ?? '',
        'rowCount': rows,
        'status': 'Needs Review',
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    await _saveQueue();
  }

  Future<void> _scan() async {
    final code = await showBarcodeInputDialog(
      context,
      title: 'Scan product',
      subtitle: 'ProfitGPS checks the local Product Master first. Trusted external lookup is used only when the product is not already saved.',
      actionLabel: 'Use code',
    );
    if (code == null || !mounted) return;
    final data = AppScope.of(context).data!;
    final parsed = Gs1ScanParser.decode(code);
    final values = <String>{code.trim(), if (parsed.gtin.isNotEmpty) parsed.gtin.trim()};
    final local = data.products.where((p) => values.any((value) => value.isNotEmpty && (p.barcode.trim().toLowerCase() == value.toLowerCase() || p.productCode.trim().toLowerCase() == value.toLowerCase()))).firstOrNull;
    if (local != null) {
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Already in Product Master'), content: Text('${local.name}\n${local.barcode.isEmpty ? local.productCode : local.barcode}\n\nBilling and purchase entry will use this local record instantly.'), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
      return;
    }
    final trusted = await ProductLookupService.instance.lookup(code.trim());
    if (!mounted) return;
    final details = trusted == null
        ? 'No trusted product record was resolved. ProfitGPS will not invent product details. Continue to purchase entry and enter only details you can verify.'
        : [if (trusted.name.isNotEmpty) trusted.name, if (trusted.brand.isNotEmpty) trusted.brand, if (trusted.manufacturer.isNotEmpty) trusted.manufacturer, if (trusted.packageSize.isNotEmpty) trusted.packageSize].join(' • ');
    final go = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('New product onboarding'), content: Text(details), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue to Purchase'))]));
    if (go == true && mounted) await _openPurchase();
  }

  Future<void> _openPurchase() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: PurchaseScreen()))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(backgroundColor: AppTheme.midnight, foregroundColor: Colors.white, title: const Text('Product Onboarding', style: TextStyle(fontWeight: FontWeight.w900))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: AppTheme.lightCardDecoration(), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Multiple ways in — one Product Master', style: TextStyle(color: AppTheme.ink, fontSize: 18, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('Supplier / Purchase Invoice / Catalogue / Barcode / Existing Data → Product Matching → Product Master → Supplier Mapping → Purchase → Inventory.', style: TextStyle(color: AppTheme.lightMuted, height: 1.35)),
                ])),
                const SizedBox(height: 14),
                GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.25, children: [
                  _Method(icon: Icons.qr_code_scanner_rounded, title: 'Barcode / QR', subtitle: 'Local first, trusted lookup if new', onTap: _scan),
                  _Method(icon: Icons.local_shipping_outlined, title: 'Supplier Purchase', subtitle: 'Create/select supplier then inward stock', onTap: _openPurchase),
                  _Method(icon: Icons.edit_note_rounded, title: 'Manual / Local', subtitle: 'Own or locally purchased product', onTap: _openPurchase),
                  _Method(icon: Icons.table_view_rounded, title: 'Excel / CSV', subtitle: 'Stage file for matching & review', onTap: () => _stageFile('Excel / CSV Import', ['csv', 'xlsx', 'xls'])),
                  _Method(icon: Icons.description_outlined, title: 'Purchase Invoice', subtitle: 'Stage invoice; verify before stock posting', onTap: () => _stageFile('Purchase Invoice Import', ['pdf', 'csv', 'xlsx', 'xls'])),
                  _Method(icon: Icons.move_to_inbox_outlined, title: 'Catalogue / Migration', subtitle: 'Supplier catalogue or old software export', onTap: () => _stageFile('Catalogue / Migration', ['csv', 'xlsx', 'xls', 'json'])),
                ]),
                const SizedBox(height: 20),
                Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Needs Review', style: TextStyle(color: AppTheme.ink, fontSize: 18, fontWeight: FontWeight.w900)), Text('Nothing posts to Product Master or stock until reviewed.', style: TextStyle(color: AppTheme.lightMuted, fontSize: 11.5))])), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text('${queue.length}', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w900)))]),
                const SizedBox(height: 10),
                if (queue.isEmpty)
                  Container(padding: const EdgeInsets.all(18), decoration: AppTheme.lightCardDecoration(), child: const Row(children: [Icon(Icons.inbox_outlined, color: AppTheme.lightMuted), SizedBox(width: 10), Expanded(child: Text('No files waiting for review.', style: TextStyle(color: AppTheme.lightMuted)))]))
                else
                  ...queue.map((item) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13), decoration: AppTheme.lightCardDecoration(), child: Row(children: [
                    Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.gold.withValues(alpha: .10), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.pending_actions_rounded, color: AppTheme.gold)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['fileName']?.toString() ?? 'Import file', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900)), Text('${item['sourceType']} • ${item['rowCount'] ?? 0} detected rows', style: const TextStyle(color: AppTheme.lightMuted, fontSize: 10.5))])),
                    Text(item['status']?.toString() ?? 'Needs Review', style: const TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.w800)),
                    IconButton(onPressed: () async { setState(() => queue.remove(item)); await _saveQueue(); }, icon: const Icon(Icons.close_rounded, color: AppTheme.lightMuted)),
                  ]))),
                const SizedBox(height: 14),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: .06), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primary.withValues(alpha: .18))), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.verified_user_outlined, color: AppTheme.primary), SizedBox(width: 10), Expanded(child: Text('Safety rule: ProfitGPS never invents product details when a barcode or imported source cannot be trusted. Unresolved data stays in Needs Review.', style: TextStyle(color: AppTheme.ink, fontSize: 11.5, height: 1.35)))])),
              ],
            ),
    );
  }
}

class _Method extends StatelessWidget {
  const _Method({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.all(13), decoration: AppTheme.lightCardDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppTheme.primary)), const Spacer(), Text(title, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.lightMuted, fontSize: 10.5))])))));
}
