import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';

class CorrectionsScreen extends StatefulWidget {
  const CorrectionsScreen({super.key});
  @override
  State<CorrectionsScreen> createState() => _CorrectionsScreenState();
}

class _CorrectionsScreenState extends State<CorrectionsScreen> {
  String type = 'Product details';
  String? targetId;

  final name = TextEditingController();
  final brand = TextEditingController();
  final barcode = TextEditingController();
  final sku = TextEditingController();
  final category = TextEditingController();
  final subcategory = TextEditingController();
  final unit = TextEditingController();
  final hsn = TextEditingController();
  final gst = TextEditingController();
  final stock = TextEditingController();
  final purchaseCost = TextEditingController();
  final sellingPrice = TextEditingController();
  final mrp = TextEditingController();
  final reorder = TextEditingController();
  final rack = TextEditingController();
  final reason = TextEditingController();
  final phone = TextEditingController();
  final gstin = TextEditingController();
  final address = TextEditingController();

  static const types = <String>[
    'Product details',
    'Inventory / Stock',
    'Customer details',
    'Supplier details',
  ];

  @override
  void dispose() {
    for (final c in [name, brand, barcode, sku, category, subcategory, unit, hsn, gst, stock, purchaseCost, sellingPrice, mrp, reorder, rack, reason, phone, gstin, address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clearFields() {
    for (final c in [name, brand, barcode, sku, category, subcategory, unit, hsn, gst, stock, purchaseCost, sellingPrice, mrp, reorder, rack, reason, phone, gstin, address]) {
      c.clear();
    }
  }

  void _loadTarget() {
    _clearFields();
    final data = AppScope.of(context).data!;
    if (targetId == null) return;
    if (type == 'Product details' || type == 'Inventory / Stock') {
      final p = data.products.where((e) => e.id == targetId).firstOrNull;
      if (p == null) return;
      name.text = p.name;
      brand.text = p.brand;
      barcode.text = p.barcode;
      sku.text = p.productCode;
      category.text = p.category;
      subcategory.text = p.subcategory;
      unit.text = p.unit;
      hsn.text = p.hsnSac;
      gst.text = p.gstRate.toStringAsFixed(p.gstRate % 1 == 0 ? 0 : 2);
      stock.text = p.stock.toStringAsFixed(p.stock % 1 == 0 ? 0 : 2);
      purchaseCost.text = p.purchasePrice.toStringAsFixed(2);
      sellingPrice.text = p.sellingPrice.toStringAsFixed(2);
      mrp.text = p.mrp.toStringAsFixed(2);
      reorder.text = p.reorderLevel.toStringAsFixed(p.reorderLevel % 1 == 0 ? 0 : 2);
      rack.text = p.rackLocation;
    } else if (type == 'Customer details') {
      final c = data.customers.where((e) => e.id == targetId).firstOrNull;
      if (c == null) return;
      name.text = c.name;
      phone.text = c.phone;
      gstin.text = c.gstin;
      address.text = c.address;
    } else {
      final s = data.suppliers.where((e) => e.id == targetId).firstOrNull;
      if (s == null) return;
      name.text = s.name;
      phone.text = s.mobile;
      gstin.text = s.gstin;
      address.text = s.address;
    }
  }

  List<DropdownMenuItem<String>> _targets() {
    final data = AppScope.of(context).data!;
    if (type == 'Product details' || type == 'Inventory / Stock') {
      return data.products.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name}${p.productCode.isEmpty ? '' : ' • ${p.productCode}'}', overflow: TextOverflow.ellipsis))).toList();
    }
    if (type == 'Customer details') {
      return data.customers.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name}${c.phone.isEmpty ? '' : ' • ${c.phone}'}', overflow: TextOverflow.ellipsis))).toList();
    }
    return data.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name}${s.mobile.isEmpty ? '' : ' • ${s.mobile}'}', overflow: TextOverflow.ellipsis))).toList();
  }

  bool _productUsed(String id) {
    final data = AppScope.of(context).data!;
    return data.sales.any((sale) => sale.lines.any((l) => l.productId == id)) ||
        data.purchases.any((purchase) => purchase.lines.any((l) => l.productId == id)) ||
        data.purchaseReturns.any((r) => r.lines.any((l) => l.productId == id));
  }

  bool _customerUsed(String id) {
    final data = AppScope.of(context).data!;
    return data.sales.any((s) => s.customerId == id) || data.ledger.any((e) => e.customerId == id);
  }

  bool _supplierUsed(String id) {
    final data = AppScope.of(context).data!;
    return data.purchases.any((p) => p.supplierId == id) || data.supplierLedger.any((e) => e.supplierId == id);
  }

  Future<bool> _confirm(String title, String message, {String action = 'Confirm'}) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (targetId == null) return;
    final app = AppScope.of(context);
    final data = app.data!;
    if (type == 'Product details') {
      final p = data.products.firstWhere((e) => e.id == targetId);
      p.name = name.text.trim();
      p.brand = brand.text.trim();
      p.barcode = barcode.text.trim();
      p.productCode = sku.text.trim();
      p.category = category.text.trim().isEmpty ? p.category : category.text.trim();
      p.subcategory = subcategory.text.trim();
      p.unit = unit.text.trim().isEmpty ? p.unit : unit.text.trim();
      p.hsnSac = hsn.text.trim();
      p.gstRate = double.tryParse(gst.text.trim()) ?? p.gstRate;
      p.gstApplicable = p.taxCategory == 'Taxable' && p.gstRate > 0;
    } else if (type == 'Inventory / Stock') {
      final p = data.products.firstWhere((e) => e.id == targetId);
      if (reason.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a correction reason.')));
        return;
      }
      final oldStock = p.stock;
      final newStock = double.tryParse(stock.text.trim()) ?? p.stock;
      final oldCost = p.purchasePrice;
      final oldSell = p.sellingPrice;
      p.stock = newStock.clamp(0, double.infinity).toDouble();
      p.purchasePrice = double.tryParse(purchaseCost.text.trim()) ?? p.purchasePrice;
      p.sellingPrice = double.tryParse(sellingPrice.text.trim()) ?? p.sellingPrice;
      p.mrp = double.tryParse(mrp.text.trim()) ?? p.mrp;
      p.reorderLevel = double.tryParse(reorder.text.trim()) ?? p.reorderLevel;
      p.rackLocation = rack.text.trim();
      final raw = p.customAttributes['stockAdjustmentAudit'];
      final list = <dynamic>[];
      if (raw != null && raw.isNotEmpty) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is List) list.addAll(parsed);
        } catch (_) {}
      }
      list.add({
        'at': DateTime.now().toIso8601String(),
        'reason': reason.text.trim(),
        'stockFrom': oldStock,
        'stockTo': p.stock,
        'costFrom': oldCost,
        'costTo': p.purchasePrice,
        'sellFrom': oldSell,
        'sellTo': p.sellingPrice,
      });
      p.customAttributes['stockAdjustmentAudit'] = jsonEncode(list.length > 50 ? list.sublist(list.length - 50) : list);
    } else if (type == 'Customer details') {
      final c = data.customers.firstWhere((e) => e.id == targetId);
      c.name = name.text.trim();
      c.phone = phone.text.trim();
      c.gstin = gstin.text.trim();
      c.address = address.text.trim();
    } else {
      final s = data.suppliers.firstWhere((e) => e.id == targetId);
      s.name = name.text.trim();
      s.mobile = phone.text.trim();
      s.gstin = gstin.text.trim();
      s.address = address.text.trim();
    }
    await app.persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correction saved. Historical documents were not changed.')));
    setState(() {});
  }

  Future<void> _deleteOrDeactivate() async {
    if (targetId == null) return;
    final app = AppScope.of(context);
    final data = app.data!;
    if (type == 'Product details' || type == 'Inventory / Stock') {
      if (_productUsed(targetId!)) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Cannot delete this product'), content: const Text('This product already appears in purchase/sales history. ProfitGPS keeps historical records intact. Correct the current master/stock data instead.'), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
        return;
      }
      final ok = await _confirm('Delete unused product?', 'This product has no purchase/sales history and can be removed safely.', action: 'Delete');
      if (!ok) return;
      data.products.removeWhere((e) => e.id == targetId);
    } else if (type == 'Customer details') {
      if (_customerUsed(targetId!)) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Cannot delete this customer'), content: const Text('Transaction or ledger history exists. Edit the customer details instead so old records remain traceable.'), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
        return;
      }
      final ok = await _confirm('Delete unused customer?', 'No transaction history exists for this customer.', action: 'Delete');
      if (!ok) return;
      data.customers.removeWhere((e) => e.id == targetId);
    } else {
      final s = data.suppliers.firstWhere((e) => e.id == targetId);
      if (_supplierUsed(targetId!)) {
        final ok = await _confirm('Deactivate supplier?', 'Supplier history exists, so ProfitGPS will deactivate instead of deleting it.', action: 'Deactivate');
        if (!ok) return;
        s.active = false;
      } else {
        final ok = await _confirm('Delete unused supplier?', 'No purchase/ledger history exists for this supplier.', action: 'Delete');
        if (!ok) return;
        data.suppliers.removeWhere((e) => e.id == targetId);
      }
    }
    await app.persist();
    if (!mounted) return;
    setState(() {
      targetId = null;
      _clearFields();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Change completed safely.')));
  }

  @override
  Widget build(BuildContext context) {
    final selected = targetId != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const Text('Edit / Correct Data', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.ink)),
        const SizedBox(height: 4),
        const Text('Choose what is wrong. ProfitGPS shows only the fields needed for that correction.', style: TextStyle(color: AppTheme.lightMuted, fontSize: 12)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.lightCardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'What do you want to correct?', prefixIcon: Icon(Icons.tune_rounded)),
              items: types.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() {
                type = v ?? types.first;
                targetId = null;
                _clearFields();
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: targetId,
              isExpanded: true,
              decoration: InputDecoration(labelText: type.startsWith('Product') || type.startsWith('Inventory') ? 'Select product' : type.startsWith('Customer') ? 'Select customer' : 'Select supplier', prefixIcon: const Icon(Icons.search_rounded)),
              items: _targets(),
              onChanged: (v) {
                setState(() => targetId = v);
                _loadTarget();
              },
            ),
          ]),
        ),
        if (selected) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.lightCardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.ink)),
              const SizedBox(height: 12),
              if (type == 'Product details') ...[
                _field(name, 'Product name'),
                _field(brand, 'Brand'),
                Row(children: [Expanded(child: _field(barcode, 'Barcode / GTIN')), const SizedBox(width: 8), Expanded(child: _field(sku, 'SKU / item code'))]),
                Row(children: [Expanded(child: _field(category, 'Category')), const SizedBox(width: 8), Expanded(child: _field(subcategory, 'Subcategory'))]),
                Row(children: [Expanded(child: _field(unit, 'Pack / unit')), const SizedBox(width: 8), Expanded(child: _field(hsn, 'HSN / SAC'))]),
                _field(gst, 'GST %', number: true),
              ] else if (type == 'Inventory / Stock') ...[
                _field(stock, 'Current stock quantity', number: true),
                Row(children: [Expanded(child: _field(purchaseCost, 'Purchase cost', number: true)), const SizedBox(width: 8), Expanded(child: _field(sellingPrice, 'Selling price', number: true))]),
                Row(children: [Expanded(child: _field(mrp, 'MRP', number: true)), const SizedBox(width: 8), Expanded(child: _field(reorder, 'Reorder level', number: true))]),
                _field(rack, 'Rack / location'),
                _field(reason, 'Reason for correction', hint: 'Example: physical stock count correction'),
                const Text('Stock corrections update the current inventory only. Finalized invoices and purchase history are not rewritten.', style: TextStyle(color: AppTheme.lightMuted, fontSize: 11)),
              ] else ...[
                _field(name, type == 'Customer details' ? 'Customer name' : 'Supplier name'),
                _field(phone, 'Mobile'),
                _field(gstin, 'GSTIN'),
                _field(address, 'Address'),
              ],
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save correction'))),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _deleteOrDeactivate, icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger), label: const Text('Delete / Deactivate safely', style: TextStyle(color: AppTheme.danger)))),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, {bool number = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TextField(
        controller: controller,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

extension _FirstOrNullCorrection<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
