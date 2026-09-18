import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../widgets/barcode_input_dialog.dart';

class MobileBillingScreen extends StatefulWidget {
  const MobileBillingScreen({super.key});
  @override
  State<MobileBillingScreen> createState() => _MobileBillingScreenState();
}

class _MobileBillingScreenState extends State<MobileBillingScreen> {
  final search = TextEditingController();
  final Map<String, double> cart = {};
  Customer? customer;
  String billType = 'Retail Bill';
  String category = 'All';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final data = app.data!;
    final q = search.text.trim().toLowerCase();
    final products = data.products.where((p) {
      final hit = q.isEmpty || p.name.toLowerCase().contains(q) || p.barcode.toLowerCase().contains(q) || p.productCode.toLowerCase().contains(q);
      return hit && (category == 'All' || p.category == category);
    }).toList();
    final categories = <String>{'All', ...data.products.map((e) => e.category)}.toList();
    final lines = <SaleLine>[];
    for (final e in cart.entries) {
      final p = data.products.where((x) => x.id == e.key).firstOrNull;
      if (p == null) continue;
      lines.add(SaleLine(productId: p.id, name: p.name, qty: e.value, unitPrice: p.sellingPrice, unitCost: p.purchasePrice, gstRate: p.gstRate, unit: p.unit, hsnSac: p.hsnSac, gstApplicable: p.gstApplicable, taxCategory: p.taxCategory, taxInclusive: p.taxInclusive, imageUrl: p.imageUrl));
    }
    final subtotal = lines.fold<double>(0, (s, l) => s + l.net);
    final gst = lines.fold<double>(0, (s, l) => s + l.gst);
    final total = subtotal;

    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
          children: [
            Row(children: [
              Expanded(child: _SelectBox(icon: Icons.person_outline_rounded, title: customer == null ? 'Walk-in Customer' : customer!.name, subtitle: customer == null ? 'Tap to select customer' : customer!.mobile, onTap: () => _chooseCustomer(data.customers))),
              const SizedBox(width: 8),
              Expanded(child: _SelectBox(icon: Icons.receipt_long_outlined, title: billType, subtitle: data.business.activeRole, onTap: _chooseBillType)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Scan barcode or search product...'))),
              const SizedBox(width: 8),
              SizedBox(width: 52, height: 50, child: FilledButton(onPressed: _scan, style: FilledButton.styleFrom(padding: EdgeInsets.zero), child: const Icon(Icons.qr_code_scanner_rounded))),
            ]),
            const SizedBox(height: 10),
            SizedBox(height: 68, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: categories.length, separatorBuilder: (_, __) => const SizedBox(width: 7), itemBuilder: (_, i) {
              final c = categories[i];
              final active = c == category;
              return InkWell(onTap: () => setState(() => category = c), borderRadius: BorderRadius.circular(12), child: Container(width: 88, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), decoration: BoxDecoration(color: active ? AppTheme.primarySoft : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? AppTheme.primary : AppTheme.lightBorder)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_categoryIcon(c), size: 20, color: active ? AppTheme.primary : AppTheme.ink), const SizedBox(height: 4), Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? AppTheme.primary : AppTheme.ink))])));
            })),
            const SizedBox(height: 10),
            if (lines.isEmpty) _BeforeBilling(products: products, onAdd: _addProduct, onScan: _scan, onSearch: () => FocusScope.of(context).requestFocus(FocusNode())) else ...[
              _BillLines(lines: lines, onMinus: (l) => _changeQty(l.productId, -1), onPlus: (l) => _changeQty(l.productId, 1), onRemove: (l) => setState(() => cart.remove(l.productId))),
              const SizedBox(height: 10),
              _Summary(subtotal: subtotal, gst: gst, total: total),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => setState(cart.clear), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Clear Bill'))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: FilledButton.icon(onPressed: () => _payment(lines, total), icon: const Icon(Icons.payments_outlined), label: const Text('Pay & Complete'))),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String c) {
    final s = c.toLowerCase();
    if (s.contains('grocery')) return Icons.shopping_basket_outlined;
    if (s.contains('veget')) return Icons.eco_outlined;
    if (s.contains('dairy')) return Icons.local_drink_outlined;
    if (s.contains('pharmacy')) return Icons.medical_services_outlined;
    return c == 'All' ? Icons.star_outline_rounded : Icons.category_outlined;
  }

  void _addProduct(Product p) {
    if (p.stock <= 0) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.name} is out of stock.'))); return; }
    setState(() => cart[p.id] = ((cart[p.id] ?? 0) + 1).clamp(0, p.stock));
  }

  void _changeQty(String id, double delta) {
    final data = AppScope.of(context).data!;
    final p = data.products.where((e) => e.id == id).firstOrNull;
    if (p == null) return;
    final next = (cart[id] ?? 0) + delta;
    setState(() { if (next <= 0) cart.remove(id); else cart[id] = next.clamp(0, p.stock); });
  }

  Future<void> _scan() async {
    final code = await showBarcodeInputDialog(context, title: 'Scan product', subtitle: 'Local Product Master is checked first.', actionLabel: 'Use code');
    if (code == null || !mounted) return;
    final products = AppScope.of(context).data!.products;
    final c = code.trim().toLowerCase();
    final p = products.where((e) => e.barcode.trim().toLowerCase() == c || e.productCode.trim().toLowerCase() == c).firstOrNull;
    if (p != null) { _addProduct(p); return; }
    setState(() => search.text = code.trim());
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not in local master. Use Product Onboarding for a new item.')));
  }

  Future<void> _chooseCustomer(List<Customer> customers) async {
    final selected = await showModalBottomSheet<Customer?>(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)), title: const Text('Walk-in Customer'), onTap: () => Navigator.pop(ctx, null)),
      for (final c in customers.take(20)) ListTile(leading: const CircleAvatar(child: Icon(Icons.person_rounded)), title: Text(c.name), subtitle: Text(c.mobile), onTap: () => Navigator.pop(ctx, c)),
    ]))));
    if (mounted) setState(() => customer = selected);
  }

  Future<void> _chooseBillType() async {
    final v = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final t in const ['Retail Bill','Tax Invoice','Bill of Supply','Quotation']) ListTile(title: Text(t), trailing: billType == t ? const Icon(Icons.check_rounded, color: AppTheme.primary) : null, onTap: () => Navigator.pop(ctx, t)),
    ]))));
    if (v != null && mounted) setState(() => billType = v);
  }

  Future<void> _payment(List<SaleLine> lines, double total) async {
    if (billType == 'Quotation') {
      await AppScope.of(context).saveQuotation(lines: lines, customerId: customer?.id ?? '', customerName: customer?.name ?? 'Walk-in');
      if (!mounted) return;
      setState(cart.clear);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quotation saved.')));
      return;
    }
    final method = await showModalBottomSheet<String>(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => _PaymentSheet(total: total));
    if (method == null || !mounted) return;
    final credit = method == 'Credit / Pay Later';
    await AppScope.of(context).completeSale(lines: lines, payment: method, customer: customer?.name ?? 'Walk-in', customerId: customer?.id ?? '', customerGstin: customer?.gstin ?? '', documentType: billType, placeOfSupplyStateCode: customer?.stateCode ?? AppScope.of(context).data!.business.stateCode, discount: 0, amountPaid: credit ? 0 : total, status: credit ? 'Credit' : 'Paid', paymentBreakdown: credit ? const {} : {method: total});
    if (!mounted) return;
    setState(cart.clear);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill completed and stock updated.')));
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(11), decoration: AppTheme.lightCardDecoration(radius: 12), child: Row(children: [Icon(icon, size: 20, color: AppTheme.primary), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppTheme.lightMuted))])), const Icon(Icons.keyboard_arrow_down_rounded, size: 18)])));
}

class _BeforeBilling extends StatelessWidget {
  const _BeforeBilling({required this.products, required this.onAdd, required this.onScan, required this.onSearch});
  final List<Product> products; final ValueChanged<Product> onAdd; final VoidCallback onScan; final VoidCallback onSearch;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(16, 26, 16, 18), decoration: AppTheme.lightCardDecoration(), child: Column(children: [
    const Icon(Icons.shopping_cart_outlined, size: 54, color: Color(0xFFA8BDD2)), const SizedBox(height: 10),
    const Text('Ready to Start Billing', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 4),
    const Text('Scan a barcode, search for a product or select from the list.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.lightMuted, fontSize: 11.5)), const SizedBox(height: 18),
    Row(children: [Expanded(child: FilledButton.icon(onPressed: onScan, icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan Barcode'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: onSearch, icon: const Icon(Icons.search_rounded), label: const Text('Search Product')))]),
    const SizedBox(height: 8),
    Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _showProducts(context, products, onAdd), icon: const Icon(Icons.list_alt_rounded), label: const Text('Select from List'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => _showProducts(context, products.take(12).toList(), onAdd), icon: const Icon(Icons.grid_view_rounded), label: const Text('Quick Item / PLU')))]),
  ]));
  static Future<void> _showProducts(BuildContext context, List<Product> products, ValueChanged<Product> onAdd) => showModalBottomSheet<void>(context: context, showDragHandle: true, isScrollControlled: true, builder: (ctx) => DraggableScrollableSheet(expand: false, initialChildSize: .72, builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(12), children: [const Text('Select Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), for (final p in products) ListTile(title: Text(p.name), subtitle: Text('${p.barcode.isEmpty ? p.productCode : p.barcode} • Stock ${p.stockLabel}'), trailing: Text('₹${p.sellingPrice.toStringAsFixed(2)}'), onTap: () { onAdd(p); Navigator.pop(ctx); })])));
}

class _BillLines extends StatelessWidget {
  const _BillLines({required this.lines, required this.onMinus, required this.onPlus, required this.onRemove});
  final List<SaleLine> lines; final ValueChanged<SaleLine> onMinus; final ValueChanged<SaleLine> onPlus; final ValueChanged<SaleLine> onRemove;
  @override Widget build(BuildContext context) => Container(decoration: AppTheme.lightCardDecoration(), child: Column(children: [
    const Padding(padding: EdgeInsets.fromLTRB(12, 12, 12, 8), child: Row(children: [Expanded(flex: 4, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))), Expanded(child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))), Expanded(child: Text('GST', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900))), Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)))])),
    const Divider(height: 1),
    for (final l in lines) Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: Row(children: [Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)), Text('₹${l.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 9.5, color: AppTheme.lightMuted))])), Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [GestureDetector(onTap: () => onMinus(l), child: const Icon(Icons.remove_circle_outline, size: 17)), Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: Text('${l.qty % 1 == 0 ? l.qty.toInt() : l.qty}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))), GestureDetector(onTap: () => onPlus(l), child: const Icon(Icons.add_circle_outline, size: 17))])), Expanded(child: Text('${l.gstRate.toStringAsFixed(0)}%', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5))), Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('₹${l.net.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)), const SizedBox(width: 5), GestureDetector(onTap: () => onRemove(l), child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.danger))]))])),
  ]));
}

class _Summary extends StatelessWidget {
  const _Summary({required this.subtotal, required this.gst, required this.total}); final double subtotal, gst, total;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: AppTheme.lightCardDecoration(), child: Column(children: [
    _row('Subtotal', subtotal), _row('GST included', gst), const Divider(height: 18), Row(children: [const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const Spacer(), Text('₹ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink))]),
  ]));
  Widget _row(String label, double v) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Text(label, style: const TextStyle(color: AppTheme.lightMuted, fontSize: 11.5)), const Spacer(), Text('₹ ${v.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))]));
}

class _PaymentSheet extends StatefulWidget { const _PaymentSheet({required this.total}); final double total; @override State<_PaymentSheet> createState() => _PaymentSheetState(); }
class _PaymentSheetState extends State<_PaymentSheet> {
  String selected = 'Cash';
  @override Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 18), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Text('Payment', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const Spacer(), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Amount payable', style: TextStyle(fontSize: 10.5, color: AppTheme.lightMuted)), Text('₹ ${widget.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))])]), const SizedBox(height: 14),
    Wrap(spacing: 8, runSpacing: 8, children: [for (final m in const ['Cash','UPI','Debit/Credit Card','Credit / Pay Later','Split','Bank Transfer']) ChoiceChip(label: Text(m), selected: selected == m, onSelected: (_) => setState(() => selected = m))]),
    if (selected == 'Cash') ...[const SizedBox(height: 14), const Text('Cash received', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), TextField(keyboardType: TextInputType.number, decoration: InputDecoration(hintText: '₹ ${widget.total.toStringAsFixed(2)}', suffixIcon: const Icon(Icons.payments_outlined))), const SizedBox(height: 6), const Text('Cash denomination details are available under More Details when needed.', style: TextStyle(fontSize: 10.5, color: AppTheme.lightMuted))],
    const SizedBox(height: 18), Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))), const SizedBox(width: 8), Expanded(flex: 2, child: FilledButton.icon(onPressed: () => Navigator.pop(context, selected), icon: const Icon(Icons.check_circle_outline_rounded), label: const Text('Confirm Payment')))]),
  ])));
}
