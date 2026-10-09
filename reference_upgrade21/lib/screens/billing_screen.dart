import 'dart:io';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../services/product_lookup_service.dart';
import '../services/gs1_scan_parser.dart';
import '../services/document_rules.dart';
import '../services/business_type_rules.dart';
import '../services/gst_lookup_service.dart';
import '../widgets/common.dart';
import '../widgets/barcode_input_dialog.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key, this.onExit});
  final VoidCallback? onExit;
  @override State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final search = TextEditingController();
  final cart = <String, double>{};
  final lineDiscountPct = <String, double>{};
  final lineDiscountAmt = <String, double>{};
  final lineNotes = <String, String>{};
  final selectedSerials = <String, List<String>>{};
  String category = 'All';
  bool customerMode = false;
  Customer? selectedCustomer;
  String documentMode = 'Auto';
  double billDiscountPct = 0;
  double billDiscountAmt = 0;
  bool quotationMode = false;
  bool gstBillRequired = false;
  String requestedByName = '';
  String requestedByContact = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final data = app.data!;
    final q = search.text.trim().toLowerCase();
    final categories = <String>{'All', ...data.products.map((e) => e.category)}.toList();
    final filtered = data.products.where((p) {
      final extra = [
        p.brand,
        p.manufacturer,
        p.packageSize,
        p.subcategory,
        ...p.serialNumbers,
        ...p.customAttributes.values,
      ].join(' ').toLowerCase();
      final hit = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q) ||
          p.productCode.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          extra.contains(q);
      return hit && (category == 'All' || p.category == category);
    }).toList();
    final lines = _buildLines(data.products, data.business);
    final subtotal = lines.fold<double>(0, (a, b) => a + b.net);
    final billDisc = billDiscountAmt + subtotal * billDiscountPct / 100;
    final total = (subtotal - billDisc).clamp(0.0, double.infinity).toDouble();
    final profit = lines.fold<double>(0, (a, b) => a + b.profit) - billDisc;
    final docType = _effectiveDocumentType(data.business, lines);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          OutlinedButton.icon(onPressed: widget.onExit ?? _clearCart, icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back')),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Billing', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), Text('Search, scan or add items, then complete payment.', style: TextStyle(color: AppTheme.muted, fontSize: 12))])),
          if (cart.isNotEmpty) TextButton.icon(onPressed: () { _confirmClearCart(); }, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Clear bill')),
        ]),
        const SizedBox(height: 12),
        Expanded(child: LayoutBuilder(builder: (context, c) {
        final sideBySide = c.maxWidth >= 1080;
        final catalog = _Catalog(
          products: filtered,
          categories: categories,
          selectedCategory: category,
          search: search,
          onSearch: () => setState(() {}),
          onCategory: (v) => setState(() => category = v),
          onProduct: _addProduct,
          onLookup: () => _lookupProduct(context, data.products),
          onManualLine: () => _manualLine(context),
        );
        final bill = _BillPanel(
          lines: lines,
          total: total,
          profit: profit,
          billDiscountPct: billDiscountPct,
          billDiscountAmt: billDiscountAmt,
          customerMode: customerMode,
          customer: selectedCustomer,
          documentMode: documentMode,
          effectiveDocumentType: docType,
          quotationMode: quotationMode,
          gstBillRequired: gstBillRequired,
          canRequestGstBill: data.business.isRegularGst,
          gstRecipientLabel: gstBillRequired && selectedCustomer != null
              ? '${selectedCustomer!.businessName.trim().isNotEmpty ? selectedCustomer!.businessName : selectedCustomer!.name} • ${selectedCustomer!.gstin}'
              : 'Enter GSTIN and fetch billing details',
          showProfit: data.business.showProfitInBilling && data.business.activeRole == 'Owner',
          allowDocumentOverride: data.business.activeRole == 'Owner',
          onGstBillChanged: (v) async {
            if (!v) {
              setState(() {
                gstBillRequired = false;
                requestedByName = '';
                requestedByContact = '';
              });
              return;
            }
            if (!data.business.isRegularGst) {
              if (!mounted) return;
              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('GST invoice not available'),
                  content: Text(
                    data.business.isCompositionGst
                        ? 'This business is configured under the Composition Scheme. ProfitGPS will issue a Bill of Supply and cannot issue a regular GST Tax Invoice.'
                        : 'This business is not configured as a Regular GST taxpayer. Set the correct GST registration type in Settings first.',
                  ),
                  actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                ),
              );
              return;
            }
            final ok = await _selectGstInvoiceRecipient(context);
            if (ok && mounted) setState(() => gstBillRequired = true);
          },
          onGstRecipientTap: () async {
            final ok = await _selectGstInvoiceRecipient(context);
            if (ok && mounted) setState(() => gstBillRequired = true);
          },
          onCustomerMode: (v) async {
            setState(() {
              customerMode = v;
              if (!v) {
                selectedCustomer = null;
                gstBillRequired = false;
                requestedByName = '';
                requestedByContact = '';
              }
            });
            if (v && selectedCustomer == null) await _chooseCustomer(context);
          },
          onCustomerTap: () => _chooseCustomer(context),
          onDocumentMode: (v) => setState(() => documentMode = v),
          onQuotationMode: (v) => setState(() {
            quotationMode = v;
            if (v) {
              gstBillRequired = false;
              requestedByName = '';
              requestedByContact = '';
            }
          }),
          onBillDiscountPct: (v) => setState(() => billDiscountPct = v),
          onBillDiscountAmt: (v) => setState(() => billDiscountAmt = v),
          onMinus: _decrease,
          onPlus: _increase,
          onEditQty: _editQty,
          onEditDiscount: _editLineDiscount,
          onEditNote: _editLineNote,
          onRemove: (line) => setState(() { cart.remove(line.productId); lineNotes.remove(line.productId); selectedSerials.remove(line.productId); }),
          onClearBill: () { _confirmClearCart(); },
          onComplete: lines.isEmpty ? null : () => quotationMode ? _saveQuotation(lines) : _openPayment(lines, total, billDisc, docType),
        );

        if (sideBySide) {
          return Row(children: [Expanded(flex: 7, child: catalog), const SizedBox(width: 12), SizedBox(width: c.maxWidth < 1250 ? 390 : 430, child: bill)]);
        }
        return DefaultTabController(length: 2, child: Column(children: [
          Container(decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)), child: const TabBar(tabs: [Tab(icon: Icon(Icons.storefront_rounded), text: 'Products'), Tab(icon: Icon(Icons.shopping_cart_rounded), text: 'Current Bill')])),
          const SizedBox(height: 10),
          Expanded(child: TabBarView(children: [catalog, bill])),
        ]));
      })),
      ]),
    );
  }

  List<SaleLine> _buildLines(List<Product> products, BusinessProfile business) {
    final result = <SaleLine>[];
    for (final e in cart.entries) {
      final p = products.where((x) => x.id == e.key).firstOrNull;
      if (p == null) continue;
      final outputGst = business.isRegularGst &&
          p.taxCategory == 'Taxable' &&
          p.gstApplicable &&
          p.gstRate > 0;
      result.add(
        SaleLine(
          productId: p.id,
          name: p.name,
          qty: e.value,
          unitPrice: p.sellingPrice,
          unitCost: p.purchasePrice,
          gstRate: p.gstRate,
          unit: p.unit,
          discountPercent: lineDiscountPct[p.id] ?? p.defaultDiscountPercent,
          discountAmount: lineDiscountAmt[p.id] ?? p.defaultDiscountAmount,
          hsnSac: p.hsnSac,
          gstApplicable: outputGst,
          taxCategory: p.taxCategory,
          taxInclusive: p.taxInclusive,
          imageUrl: p.imageUrl,
          note: lineNotes[p.id] ?? '',
          serialNumbers: List<String>.from(selectedSerials[p.id] ?? const <String>[]),
        ),
      );
    }
    return result;
  }

  String _effectiveDocumentType(BusinessProfile b, List<SaleLine> lines) {
    return DocumentRules.resolveSaleDocument(
      b,
      lines,
      override: documentMode,
    );
  }


  Map<String, bool> _productTracking(Product p) {
    final currentType = AppScope.of(context).data!.business.businessType;
    final type = p.businessType.trim().isEmpty ? currentType : p.businessType;
    return BusinessTypeRules.resolvedTracking(type, p.category, p.subcategory, p.trackingFlags);
  }

  bool _tracksSerial(Product p) => _productTracking(p)['serial'] == true;

  Future<void> _addSerializedProduct(Product p, {String preferredSerial = ''}) async {
    final already = selectedSerials[p.id] ?? <String>[];
    final available = p.serialNumbers.where((e) => !already.contains(e)).toList();
    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.name} is serial/IMEI tracked, but no unused serial is available in inventory.')),
      );
      return;
    }

    String? chosen;
    if (preferredSerial.isNotEmpty && available.contains(preferredSerial)) {
      chosen = preferredSerial;
    } else if (available.length == 1) {
      chosen = available.first;
    } else {
      chosen = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Select serial / IMEI • ${p.name}'),
          content: SizedBox(
            width: 460,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: available.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.qr_code_2_rounded),
                title: Text(available[i], style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(ctx, available[i]),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
        ),
      );
    }
    if (chosen == null || chosen.isEmpty) return;
    setState(() {
      selectedSerials.putIfAbsent(p.id, () => <String>[]).add(chosen!);
      cart[p.id] = (cart[p.id] ?? 0) + 1;
      lineDiscountPct.putIfAbsent(p.id, () => p.defaultDiscountPercent);
      lineDiscountAmt.putIfAbsent(p.id, () => p.defaultDiscountAmount);
    });
  }

  Future<void> _addProduct(Product p) async {
    if (p.stock <= 0) return;
    if (_tracksSerial(p)) {
      await _addSerializedProduct(p);
      return;
    }
    if (!p.weighted) {
      setState(() { cart[p.id] = (cart[p.id] ?? 0) + 1; lineDiscountPct.putIfAbsent(p.id, () => p.defaultDiscountPercent); lineDiscountAmt.putIfAbsent(p.id, () => p.defaultDiscountAmount); });
      return;
    }
    final ctl = TextEditingController(text: '1.00');
    final qty = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
      title: Text('${p.name} • ${money(p.sellingPrice)}/${p.unit}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Available: ${p.stockLabel}', style: const TextStyle(color: AppTheme.muted)), const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [0.25,0.5,1.0,1.25,2.0,2.25,2.5].map((v) => ActionChip(label: Text(v.toStringAsFixed(v % 1 == 0 ? 0 : 2)), onPressed: () { ctl.text = v.toString(); })).toList()),
        const SizedBox(height: 10), TextField(controller: ctl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Quantity / weight (${p.unit})', prefixIcon: const Icon(Icons.scale_rounded))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(ctl.text)), child: const Text('Add'))],
    ));
    if (qty == null || qty <= 0) return;
    setState(() { cart[p.id] = ((cart[p.id] ?? 0) + qty).clamp(0.0, p.stock).toDouble(); lineDiscountPct.putIfAbsent(p.id, () => p.defaultDiscountPercent); lineDiscountAmt.putIfAbsent(p.id, () => p.defaultDiscountAmount); });
  }

  void _decrease(SaleLine line) {
    final p = AppScope.of(context).data!.products.firstWhere((x) => x.id == line.productId);
    if (_tracksSerial(p)) {
      setState(() {
        final serials = selectedSerials[line.productId];
        if (serials != null && serials.isNotEmpty) serials.removeLast();
        final n = (cart[line.productId] ?? 1) - 1;
        if (n <= 0) {
          cart.remove(line.productId);
          selectedSerials.remove(line.productId);
        } else {
          cart[line.productId] = n;
        }
      });
      return;
    }
    final step = p.weighted ? 0.25 : 1.0;
    setState(() { final n = (cart[line.productId] ?? step) - step; if (n <= 0.001) cart.remove(line.productId); else cart[line.productId] = n; });
  }
  void _increase(SaleLine line) {
    final p = AppScope.of(context).data!.products.firstWhere((x) => x.id == line.productId);
    if (_tracksSerial(p)) {
      _addSerializedProduct(p);
      return;
    }
    final step = p.weighted ? 0.25 : 1.0;
    setState(() => cart[line.productId] = ((cart[line.productId] ?? 0) + step).clamp(0.0, p.stock).toDouble());
  }

  Future<void> _editQty(SaleLine line) async {
    final p = AppScope.of(context).data!.products.firstWhere((x) => x.id == line.productId);
    if (_tracksSerial(p)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serial/IMEI tracked items must be added or removed one unit at a time so every physical unit remains identifiable.')),
      );
      return;
    }
    final ctl = TextEditingController(text: line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 2));
    final v = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(title: Text('Quantity • ${line.name}'), content: TextField(controller: ctl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Quantity (${line.unit})')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(ctl.text)), child: const Text('Apply'))]));
    if (v != null && v > 0) setState(() => cart[line.productId] = v.clamp(0.0, p.stock).toDouble());
  }

  Future<void> _editLineDiscount(SaleLine line) async {
    final pct = TextEditingController(text: line.discountPercent.toStringAsFixed(1));
    final amt = TextEditingController(text: line.discountAmount.toStringAsFixed(2));
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Discount • ${line.name}'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: pct, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Discount %')), const SizedBox(height: 8), TextField(controller: amt, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Discount \u20B9'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply'))]));
    if (ok == true) setState(() { lineDiscountPct[line.productId] = double.tryParse(pct.text) ?? 0; lineDiscountAmt[line.productId] = double.tryParse(amt.text) ?? 0; });
  }

  Future<void> _lookupProduct(
    BuildContext context,
    List<Product> products,
  ) async {
    final code = await _waitForScannerCode();
    if (code == null || !mounted) return;
    await _handleScannedProduct(products, code);
  }

  Future<String?> _waitForScannerCode() {
    return showBarcodeInputDialog(
      context,
      title: 'Product lookup / scanner',
      subtitle:
          'USB/Bluetooth scanners type directly here. Wi-Fi phone scans fill this field safely; then press Find product.',
      actionLabel: 'Find product',
    );
  }

  Future<void> _handleScannedProduct(
    List<Product> products,
    String raw,
  ) async {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return;
    final decoded = Gs1ScanParser.decode(raw);

    // GS1 DataMatrix/QR may contain a GTIN plus batch/expiry/serial. Resolve
    // the product from its GTIN locally first so billing does not depend on
    // internet when the item is already in Product Master.
    if (decoded.gtin.isNotEmpty) {
      final decodedFound = products.where((product) {
        return product.barcode.trim().toLowerCase() == decoded.gtin.toLowerCase();
      }).toList();
      if (decodedFound.isNotEmpty) {
        final matched = decodedFound.first;
        if (decoded.serialNumber.isNotEmpty && _tracksSerial(matched)) {
          await _addSerializedProduct(matched, preferredSerial: decoded.serialNumber);
        } else {
          await _addProduct(matched);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${matched.name} resolved locally from ${decoded.codeType} and added to Current Bill.')),
        );
        return;
      }
    }
    final serialFound = products.where((product) {
      return product.serialNumbers.any((serial) => serial.trim().toLowerCase() == value);
    }).toList();
    if (serialFound.isNotEmpty) {
      await _addSerializedProduct(serialFound.first, preferredSerial: raw.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${serialFound.first.name} identified by serial / IMEI and added to Current Bill.')),
      );
      return;
    }
    final found = products.where((product) {
      return product.barcode.trim().toLowerCase() == value ||
          product.productCode.trim().toLowerCase() == value ||
          product.name.trim().toLowerCase() == value;
    }).toList();

    if (found.isNotEmpty) {
      _addProduct(found.first);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${found.first.name} scanned and added to Current Bill.')),
      );
      return;
    }

    if (!mounted) return;
    final external = await ProductLookupService.instance.lookup(raw.trim());
    if (!mounted) return;

    final resolvedCode = external?.barcode.trim().toLowerCase() ?? '';
    if (resolvedCode.isNotEmpty) {
      final resolvedLocal = products.where((product) {
        return product.barcode.trim().toLowerCase() == resolvedCode;
      }).toList();
      if (resolvedLocal.isNotEmpty) {
        final matched = resolvedLocal.first;
        if (external?.serialNumber.isNotEmpty == true && _tracksSerial(matched)) {
          await _addSerializedProduct(matched, preferredSerial: external!.serialNumber);
        } else {
          await _addProduct(matched);
        }
        return;
      }
    }

    // A genuinely new barcode is not a dead end. Open the professional
    // one-time Product Master form with the identifier and any GS1/device data
    // already captured. After it is saved, future scans are local and instant.
    final created = await _createProductFromScan(raw.trim(), external);
    if (created == null || !mounted) return;
    if (_tracksSerial(created) && created.serialNumbers.isNotEmpty) {
      await _addSerializedProduct(
        created,
        preferredSerial: created.serialNumbers.first,
      );
    } else {
      await _addProduct(created);
    }
  }

  Future<Product?> _createProductFromScan(
    String raw,
    ExternalProductInfo? external,
  ) async {
    final app = AppScope.of(context);
    final business = app.data!.business;
    final businessType = BusinessTypeRules.canonicalType(business.businessType);
    final decoded = Gs1ScanParser.decode(raw);

    final scannedBarcode = external?.barcode.trim().isNotEmpty == true
        ? external!.barcode.trim()
        : decoded.gtin.trim().isNotEmpty
            ? decoded.gtin.trim()
            : (!raw.toLowerCase().startsWith('http://') &&
                    !raw.toLowerCase().startsWith('https://') &&
                    !decoded.isImei)
                ? raw.trim()
                : '';

    final name = TextEditingController(text: external?.name ?? '');
    final sku = TextEditingController();
    final sellingPrice = TextEditingController(
      text: external != null && external.mrp > 0 ? external.mrp.toStringAsFixed(2) : '',
    );
    final purchaseCost = TextEditingController(text: '0');
    final openingStock = TextEditingController(text: '1');
    final reorderLevel = TextEditingController(text: '0');
    final attributeControllers = <String, TextEditingController>{};

    TextEditingController attributeController(String key) =>
        attributeControllers.putIfAbsent(key, () => TextEditingController());

    if (external?.brand.isNotEmpty == true) {
      attributeController('brand').text = external!.brand;
    }
    if (external?.manufacturer.isNotEmpty == true) {
      attributeController('manufacturer').text = external!.manufacturer;
    }
    if (external?.packageSize.isNotEmpty == true) {
      attributeController('packageSize').text = external!.packageSize;
    }
    if (external?.variant.isNotEmpty == true) {
      attributeController('variant').text = external!.variant;
    }
    if (external?.additionalProductId.isNotEmpty == true) {
      attributeController('modelNumber').text = external!.additionalProductId;
    }
    if (external?.customerPartNumber.isNotEmpty == true) {
      attributeController('oemReference').text = external!.customerPartNumber;
    }

    final categories = <String>{
      ...BusinessTypeRules.categoriesFor(
        businessType,
        enabledRetailModules: business.enabledRetailModules,
      ),
      ...app.data!.products
          .map((product) => product.category)
          .where((value) => value.trim().isNotEmpty),
    }.toList();

    var category = BusinessTypeRules.suggestCategory(
      businessType,
      '${external?.name ?? ''} ${external?.category ?? ''} ${external?.brand ?? ''}',
      enabledRetailModules: business.enabledRetailModules,
    );
    if (!categories.contains(category)) {
      category = categories.contains('General') ? 'General' : categories.first;
    }
    var subcategories = BusinessTypeRules.subcategoriesFor(businessType, category);
    var subcategory = subcategories.isEmpty ? 'General' : subcategories.first;
    var tracking = BusinessTypeRules.trackingDefaults(
      businessType,
      category,
      subcategory,
    );
    var units = BusinessTypeRules.unitsFor(
      businessType,
      category: category,
      subcategory: subcategory,
    );
    var unit = BusinessTypeRules.defaultUnitFor(
      businessType,
      category: category,
      subcategory: subcategory,
    );
    String taxCategory = 'Unclassified';
    double gstRate = 0;
    bool taxInclusive = business.defaultSaleTaxInclusive;

    Product? result;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final fields = BusinessTypeRules.fieldsFor(
            businessType,
            category: category,
            subcategory: subcategory,
          );
          final allUnits = <String>{
            ...units,
            unit,
            'pcs', 'kg', 'g', 'L', 'ml', 'pack', 'box', 'carton', 'bag',
            'bottle', 'tray', 'bundle', 'pair', 'set', 'm', 'ft', 'roll',
            'case', 'crate', 'bunch', 'kit', 'mg', 'slice', 'portion',
          }.toList();

          void refreshRules({String? nextCategory, String? nextSubcategory}) {
            update(() {
              if (nextCategory != null) category = nextCategory;
              subcategories = BusinessTypeRules.subcategoriesFor(
                businessType,
                category,
              );
              if (nextSubcategory != null &&
                  subcategories.contains(nextSubcategory)) {
                subcategory = nextSubcategory;
              } else if (!subcategories.contains(subcategory)) {
                subcategory =
                    subcategories.isEmpty ? 'General' : subcategories.first;
              }
              tracking = BusinessTypeRules.trackingDefaults(
                businessType,
                category,
                subcategory,
              );
              units = BusinessTypeRules.unitsFor(
                businessType,
                category: category,
                subcategory: subcategory,
              );
              final preferred = BusinessTypeRules.defaultUnitFor(
                businessType,
                category: category,
                subcategory: subcategory,
              );
              if (!units.contains(unit)) unit = preferred;
            });
          }

          return AlertDialog(
            title: const Text('New product'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Save this item once and future scans will be instant on this computer.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 12),
                    if (scannedBarcode.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151A22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cyan.withValues(alpha: .35)),
                        ),
                        child: Text(
                          'Barcode  $scannedBarcode',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'Product name *'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            isExpanded: true,
                            items: categories
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) refreshRules(nextCategory: value);
                            },
                            decoration: const InputDecoration(labelText: 'Category *'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: subcategories.contains(subcategory)
                                ? subcategory
                                : subcategories.first,
                            isExpanded: true,
                            items: subcategories
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                refreshRules(nextSubcategory: value);
                              }
                            },
                            decoration: const InputDecoration(labelText: 'Subcategory'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: allUnits.contains(unit) ? unit : allUnits.first,
                            isExpanded: true,
                            items: allUnits
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ))
                                .toList(),
                            onChanged: (value) => update(() => unit = value ?? unit),
                            decoration: const InputDecoration(labelText: 'Selling unit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sellingPrice,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Selling price ₹ *'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: purchaseCost,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Purchase cost ₹'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: openingStock,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Available stock *'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sku,
                            decoration: const InputDecoration(labelText: 'Internal SKU / code'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: reorderLevel,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Reorder level'),
                          ),
                        ),
                      ],
                    ),
                    if (fields.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '$category fields',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      ...fields.map((field) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: attributeController(field.key),
                              decoration: InputDecoration(
                                labelText: '${field.label}${field.required ? ' *' : ''}',
                                hintText: field.hint.isEmpty ? null : field.hint,
                              ),
                            ),
                          )),
                    ],
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: taxCategory,
                      items: const [
                        DropdownMenuItem(value: 'Unclassified', child: Text('Select tax classification')),
                        DropdownMenuItem(value: 'Taxable', child: Text('Taxable')),
                        DropdownMenuItem(value: 'Exempt', child: Text('Exempt')),
                        DropdownMenuItem(value: 'Nil-rated', child: Text('Nil-rated')),
                        DropdownMenuItem(value: 'Non-GST', child: Text('Non-GST')),
                      ],
                      onChanged: (value) => update(() {
                        taxCategory = value ?? 'Unclassified';
                        if (taxCategory != 'Taxable') gstRate = 0;
                      }),
                      decoration: const InputDecoration(labelText: 'Tax classification *'),
                    ),
                    if (taxCategory == 'Taxable') ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<double>(
                        value: gstRate,
                        items: const [0.0, 0.25, 3.0, 5.0, 12.0, 18.0, 28.0]
                            .map((value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}%'),
                                ))
                            .toList(),
                        onChanged: (value) => update(() => gstRate = value ?? 0),
                        decoration: const InputDecoration(labelText: 'GST rate *'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: taxInclusive,
                        onChanged: (value) => update(() => taxInclusive = value),
                        title: const Text('Selling price includes GST'),
                      ),
                    ],
                    if (external?.decodedFields.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Barcode details captured',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: external!.decodedFields.entries
                            .map((entry) => StatusPill(
                                  text: '${entry.key}: ${entry.value}',
                                  color: AppTheme.green,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final productName = name.text.trim();
                  final sell = double.tryParse(sellingPrice.text.trim()) ?? 0;
                  final stock = double.tryParse(openingStock.text.trim()) ?? 0;
                  if (productName.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter the product name.')),
                    );
                    return;
                  }
                  if (sell <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter the selling price.')),
                    );
                    return;
                  }
                  if (stock <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter the available stock.')),
                    );
                    return;
                  }
                  if (taxCategory == 'Unclassified') {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Select the tax classification.')),
                    );
                    return;
                  }
                  if (taxCategory == 'Taxable' && gstRate <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Select the GST rate.')),
                    );
                    return;
                  }
                  for (final field in fields.where((field) => field.required)) {
                    if (attributeController(field.key).text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('${field.label} is required for $category / $subcategory.')),
                      );
                      return;
                    }
                  }

                  final custom = <String, String>{};
                  for (final entry in attributeControllers.entries) {
                    final value = entry.value.text.trim();
                    if (value.isNotEmpty &&
                        !const {'brand', 'manufacturer', 'packageSize'}.contains(entry.key)) {
                      custom[entry.key] = value;
                    }
                  }
                  final serials = <String>[];
                  if (external?.serialNumber.trim().isNotEmpty == true &&
                      tracking['serial'] == true) {
                    serials.add(external!.serialNumber.trim());
                  }

                  result = Product(
                    id: 'scan_${DateTime.now().microsecondsSinceEpoch}',
                    name: productName,
                    barcode: scannedBarcode,
                    productCode: sku.text.trim(),
                    category: category,
                    purchasePrice: double.tryParse(purchaseCost.text.trim()) ?? 0,
                    sellingPrice: sell,
                    gstRate: taxCategory == 'Taxable' ? gstRate : 0,
                    gstApplicable: taxCategory == 'Taxable' && gstRate > 0,
                    taxCategory: taxCategory,
                    taxInclusive: taxInclusive,
                    stock: stock,
                    reorderLevel: double.tryParse(reorderLevel.text.trim()) ?? 0,
                    unit: unit,
                    weighted: BusinessTypeRules.shouldDefaultWeighted(
                      businessType,
                      unit,
                      category: category,
                      subcategory: subcategory,
                    ),
                    brand: attributeController('brand').text.trim(),
                    manufacturer: attributeController('manufacturer').text.trim(),
                    packageSize: attributeController('packageSize').text.trim(),
                    mrp: external?.mrp ?? 0,
                    hsnSac: external?.hsnSac ?? '',
                    businessType: businessType,
                    subcategory: subcategory,
                    trackingFlags: tracking,
                    serialNumbers: serials,
                    customAttributes: custom,
                    expiryDate: external?.expiryDate ?? external?.bestBeforeDate,
                  );
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save & add to bill'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || result == null) return null;
    await app.addProduct(result!);
    return result;
  }

  Future<void> _manualLine(BuildContext context) async {
    final business = AppScope.of(context).data!.business;
    final name = TextEditingController();
    final qty = TextEditingController(text: '1');
    final price = TextEditingController();
    final cost = TextEditingController();
    final unit = TextEditingController(text: BusinessTypeRules.defaultUnitFor(business.businessType));
    String taxCategory = 'Unclassified';
    double gstRate = 0;
    bool taxInclusive = business.defaultSaleTaxInclusive;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Manual bill line'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Qty'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit'))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Selling price'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cost (for profit)'))),
                  ]),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: taxCategory,
                    items: const [
                      DropdownMenuItem(value: 'Unclassified', child: Text('Select tax classification')),
                      DropdownMenuItem(value: 'Taxable', child: Text('Taxable')),
                      DropdownMenuItem(value: 'Exempt', child: Text('Exempt')),
                      DropdownMenuItem(value: 'Nil-rated', child: Text('Nil-rated')),
                      DropdownMenuItem(value: 'Non-GST', child: Text('Non-GST')),
                    ],
                    onChanged: (value) => update(() {
                      taxCategory = value ?? 'Unclassified';
                      if (taxCategory != 'Taxable') gstRate = 0;
                    }),
                    decoration: const InputDecoration(labelText: 'Tax classification *'),
                  ),
                  if (taxCategory == 'Taxable') ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<double>(
                      value: gstRate,
                      items: const [0.0, 0.25, 3.0, 5.0, 12.0, 18.0, 28.0]
                          .map((value) => DropdownMenuItem(value: value, child: Text('${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}%')))
                          .toList(),
                      onChanged: (value) => update(() => gstRate = value ?? 0),
                      decoration: const InputDecoration(labelText: 'GST rate'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: taxInclusive,
                      onChanged: (value) => update(() => taxInclusive = value),
                      title: const Text('Selling price includes GST'),
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                    'ProfitGPS will not assume that a manually entered item is non-GST. Select its tax classification before billing.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (taxCategory == 'Unclassified') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select the tax classification first.')));
                  return;
                }
                if (taxCategory == 'Taxable' && gstRate <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose the GST rate, or use Nil-rated / Exempt if applicable.')));
                  return;
                }
                Navigator.pop(ctx, {
                  'name': name.text,
                  'qty': double.tryParse(qty.text) ?? 1,
                  'price': double.tryParse(price.text) ?? 0,
                  'cost': double.tryParse(cost.text) ?? 0,
                  'unit': unit.text,
                  'taxCategory': taxCategory,
                  'gstRate': gstRate,
                  'taxInclusive': taxInclusive,
                });
              },
              child: const Text('Add manual line'),
            ),
          ],
        ),
      ),
    );
    if (result == null || (result['name'] as String).trim().isEmpty) return;
    final id = 'manual_${DateTime.now().microsecondsSinceEpoch}';
    final app = AppScope.of(context);
    final category = result['taxCategory'] as String;
    final rate = result['gstRate'] as double;
    app.data!.products.add(
      Product(
        id: id,
        name: result['name'],
        barcode: '',
        productCode: 'MANUAL',
        category: 'Manual',
        purchasePrice: result['cost'],
        sellingPrice: result['price'],
        gstRate: rate,
        gstApplicable: category == 'Taxable' && rate > 0,
        taxCategory: category,
        taxInclusive: result['taxInclusive'] as bool,
        stock: 999999,
        reorderLevel: 0,
        unit: result['unit'],
        weighted: BusinessTypeRules.shouldDefaultWeighted(
          business.businessType,
          (result['unit'] as String).trim(),
        ),
      ),
    );
    setState(() => cart[id] = result['qty']);
  }


  Future<void> _editLineNote(SaleLine line) async {
    final ctl = TextEditingController(text: line.note);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Item note • ${line.name}'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Optional note',
            hintText: 'Example: gift pack / no carry bag / customer request',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Save note')),
        ],
      ),
    );
    if (value != null) setState(() => lineNotes[line.productId] = value);
  }

  Future<void> _chooseCustomer(BuildContext context) async {
    final app = AppScope.of(context); final data = app.data!; final query = TextEditingController();
    final chosen = await showDialog<Customer?>(context: context, builder: (ctx) => StatefulBuilder(builder: (context, update) {
      final q = query.text.toLowerCase(); final list = data.customers.where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.id.toLowerCase().contains(q) || c.gstin.toLowerCase().contains(q) || c.businessName.toLowerCase().contains(q)).toList();
      return AlertDialog(title: const Text('Customer ID / account'), content: SizedBox(width: 560, height: 430, child: Column(children: [
        TextField(controller: query, onChanged: (_) => update(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search customer ID / name / mobile / GSTIN')), const SizedBox(height: 10),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (_, i) { final c = list[i]; return ListTile(onTap: () => Navigator.pop(ctx, c), leading: const CircleAvatar(child: Icon(Icons.person)), title: Text('${c.name} • ${c.id}'), subtitle: Text('${c.phone.isEmpty ? 'No mobile' : c.phone} • Customer owes us ${money(c.creditBalance)} • Advance available ${money(c.advanceBalance)}')); })),
      ])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton.icon(onPressed: () async { final c = await _newCustomer(context); if (ctx.mounted && c != null) Navigator.pop(ctx, c); }, icon: const Icon(Icons.person_add_alt_1), label: const Text('Create new ID'))]);
    }));
    if (chosen != null) setState(() { selectedCustomer = chosen; customerMode = true; });
  }

  Future<Customer?> _newCustomer(BuildContext context) async {
    final name = TextEditingController(); final phone = TextEditingController(); final gstin = TextEditingController(); final business = TextEditingController(); final address = TextEditingController(); final stateCode = TextEditingController(text: '33');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Create customer ID'), content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name *')), const SizedBox(height: 8), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Mobile number')), const SizedBox(height: 8), TextField(controller: business, decoration: const InputDecoration(labelText: 'Business name (optional)')), const SizedBox(height: 8), TextField(controller: gstin, decoration: const InputDecoration(labelText: 'Customer GSTIN (optional)')), const SizedBox(height: 8), TextField(controller: address, decoration: const InputDecoration(labelText: 'Billing address')), const SizedBox(height: 8), TextField(controller: stateCode, decoration: const InputDecoration(labelText: 'State code'))]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create ID'))]));
    if (ok != true) return null;
    return AppScope.of(context).createCustomer(name: name.text, phone: phone.text, gstin: gstin.text, businessName: business.text, address: address.text, stateCode: stateCode.text.trim().isEmpty ? '33' : stateCode.text.trim());
  }


  bool _validGstin(String value) => GstLookupService.isValidFormat(value);

  Future<bool> _selectGstInvoiceRecipient(BuildContext context) async {
    final app = AppScope.of(context);
    final data = app.data!;
    if (!data.business.isRegularGst) return false;

    final gstin = TextEditingController(text: selectedCustomer?.gstin.toUpperCase() ?? '');
    final name = TextEditingController(
      text: selectedCustomer == null
          ? ''
          : (selectedCustomer!.businessName.trim().isNotEmpty
              ? selectedCustomer!.businessName
              : selectedCustomer!.name),
    );
    final address = TextEditingController(text: selectedCustomer?.address ?? '');
    final state = TextEditingController(text: selectedCustomer?.state ?? '');
    final stateCode = TextEditingController();
    final requestedBy = TextEditingController(text: requestedByName);
    final contact = TextEditingController(
      text: requestedByContact.isNotEmpty ? requestedByContact : (selectedCustomer?.phone ?? ''),
    );

    Customer? matched = selectedCustomer?.gstin.trim().isNotEmpty == true ? selectedCustomer : null;
    bool lookingUp = false;
    bool onlineFetched = false;
    String onlineStatus = '';
    String onlineTaxpayerType = '';
    String lastLookupGstin = '';
    bool dialogAlive = true;
    String lookupNote = matched == null
        ? 'Enter the buyer GSTIN. Saved GSTINs are checked first, then online lookup is attempted.'
        : 'Saved GSTIN matched. Details fetched from ProfitGPS.';

    void applyStateFromGstin(String raw) {
      final code = GstLookupService.stateCodeFromGstin(raw);
      if (code.isEmpty) return;
      stateCode.text = code;
      final stateName = GstLookupService.stateNameForCode(code);
      if (stateName.isNotEmpty) state.text = stateName;
    }

    void fill(Customer c) {
      matched = c;
      gstin.text = c.gstin.toUpperCase();
      name.text = c.businessName.trim().isNotEmpty ? c.businessName : c.name;
      address.text = c.address;
      applyStateFromGstin(c.gstin);
      if (state.text.trim().isEmpty) state.text = c.state;
      if (contact.text.trim().isEmpty) contact.text = c.phone;
      onlineFetched = false;
      onlineStatus = '';
      onlineTaxpayerType = '';
      lookupNote = 'Saved GSTIN matched. Name and billing details fetched automatically.';
    }

    Customer? findByGstin(String raw) {
      final value = raw.trim().toUpperCase();
      for (final c in data.customers) {
        if (c.gstin.trim().toUpperCase() == value && value.isNotEmpty) return c;
      }
      return null;
    }

    if (matched != null) {
      fill(matched!);
    } else if (gstin.text.isNotEmpty) {
      applyStateFromGstin(gstin.text);
    }

    Future<void> lookupOnline(StateSetter update, {bool force = false}) async {
      final normalized = gstin.text.trim().toUpperCase();
      if (!_validGstin(normalized) || findByGstin(normalized) != null) return;
      if (!force && lastLookupGstin == normalized) return;
      lastLookupGstin = normalized;

      applyStateFromGstin(normalized);
      if (!data.business.gstOnlineLookupEnabled || data.business.gstLookupApiKey.trim().isEmpty) {
        update(() {
          lookupNote = 'GSTIN is valid. Live lookup is not configured yet. Add the API key in Settings → Business profile → GSTIN online lookup, or enter the details once manually.';
        });
        return;
      }

      update(() {
        lookingUp = true;
        onlineFetched = false;
        onlineStatus = '';
        onlineTaxpayerType = '';
        lookupNote = 'Checking GST registration online…';
      });

      final result = await GstLookupService.lookup(data.business, normalized);
      if (!mounted || !dialogAlive) return;
      update(() {
        lookingUp = false;
        if (result.success) {
          matched = null;
          onlineFetched = true;
          onlineStatus = result.status;
          onlineTaxpayerType = result.taxpayerType;
          final fetchedName = result.legalName.trim().isNotEmpty ? result.legalName : result.displayName;
          if (fetchedName.trim().isNotEmpty) name.text = fetchedName.trim();
          if (result.address.trim().isNotEmpty) address.text = result.address.trim();
          final canonicalCode = GstLookupService.stateCodeFromGstin(normalized);
          stateCode.text = canonicalCode;
          final mappedState = GstLookupService.stateNameForCode(canonicalCode);
          state.text = result.state.trim().isNotEmpty ? result.state.trim() : mappedState;
          final statusPart = result.status.trim().isEmpty ? '' : ' • ${result.status}';
          final typePart = result.taxpayerType.trim().isEmpty ? '' : ' • ${result.taxpayerType}';
          lookupNote = 'GSTIN verified online via ${result.source}$statusPart$typePart. Details filled automatically.';
        } else {
          onlineFetched = false;
          onlineStatus = '';
          onlineTaxpayerType = '';
          lookupNote = '${result.error} You can still enter the registered name/address manually and save it for future bills.';
        }
      });
    }

    final result = await showDialog<_GstRecipientResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) {
          final valid = _validGstin(gstin.text);
          final nonActive = onlineFetched &&
              onlineStatus.trim().isNotEmpty &&
              onlineStatus.trim().toLowerCase() != 'active';
          return AlertDialog(
            title: const Text('GST bill recipient'),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the GSTIN requested by the buyer. ProfitGPS checks saved records first and then performs online verification when configured.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: gstin,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 15,
                      decoration: InputDecoration(
                        labelText: 'GSTIN *',
                        hintText: 'Example: 33ABCDE1234F1Z5',
                        prefixIcon: const Icon(Icons.confirmation_number_outlined),
                        suffixIcon: lookingUp
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : valid
                                ? const Icon(Icons.verified_rounded, color: AppTheme.green)
                                : null,
                      ),
                      onChanged: (value) async {
                        final normalized = value.toUpperCase();
                        if (gstin.text != normalized) {
                          gstin.value = gstin.value.copyWith(
                            text: normalized,
                            selection: TextSelection.collapsed(offset: normalized.length),
                          );
                        }

                        final found = normalized.length == 15 ? findByGstin(normalized) : null;
                        update(() {
                          if (found != null) {
                            fill(found);
                          } else {
                            matched = null;
                            onlineFetched = false;
                            onlineStatus = '';
                            onlineTaxpayerType = '';
                            name.clear();
                            address.clear();
                            state.clear();
                            stateCode.clear();
                            applyStateFromGstin(normalized);
                            if (normalized.length == 15 && _validGstin(normalized)) {
                              lookupNote = data.business.gstOnlineLookupEnabled &&
                                      data.business.gstLookupApiKey.trim().isNotEmpty
                                  ? 'GSTIN format valid. Fetching registered details…'
                                  : 'GSTIN format valid. State is derived from GSTIN. Configure online lookup in Settings for automatic registered-name/address fetch.';
                            } else {
                              lookupNote = normalized.length == 15
                                  ? 'GSTIN format is not valid.'
                                  : 'Enter the complete 15-character GSTIN.';
                            }
                          }
                        });

                        if (found == null && normalized.length == 15 && _validGstin(normalized)) {
                          await lookupOnline(update);
                        }
                      },
                    ),
                    Text(
                      lookupNote,
                      style: TextStyle(
                        color: nonActive
                            ? AppTheme.red
                            : (matched != null || onlineFetched)
                                ? AppTheme.green
                                : valid
                                    ? AppTheme.cyan
                                    : AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (valid && matched == null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: lookingUp ? null : () => lookupOnline(update, force: true),
                          icon: const Icon(Icons.travel_explore_rounded),
                          label: const Text('Fetch GST details'),
                        ),
                      ),
                    ],
                    if (nonActive) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.red.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          'This GSTIN is reported as $onlineStatus${onlineTaxpayerType.isEmpty ? '' : ' ($onlineTaxpayerType)'}. ProfitGPS will not create a GST-recipient invoice with a non-active GSTIN.',
                          style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      readOnly: matched != null || onlineFetched,
                      onChanged: (_) => update(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Name *',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: address,
                      readOnly: matched != null || onlineFetched,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Billing / registered address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: state,
                            readOnly: true,
                            decoration: const InputDecoration(labelText: 'State'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: stateCode,
                            readOnly: true,
                            maxLength: 2,
                            decoration: const InputDecoration(labelText: 'State code', counterText: ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: requestedBy,
                      decoration: const InputDecoration(
                        labelText: 'Purchased / Requested By (optional)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contact,
                      decoration: const InputDecoration(
                        labelText: 'Contact number (optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton.icon(
                onPressed: !valid || name.text.trim().isEmpty || nonActive
                    ? null
                    : () => Navigator.pop(
                          ctx,
                          _GstRecipientResult(
                            matchedCustomer: matched,
                            gstin: gstin.text.trim().toUpperCase(),
                            name: name.text.trim(),
                            address: address.text.trim(),
                            state: state.text.trim(),
                            stateCode: GstLookupService.stateCodeFromGstin(gstin.text),
                            requestedBy: requestedBy.text.trim(),
                            contact: contact.text.trim(),
                          ),
                        ),
                icon: const Icon(Icons.receipt_long_rounded),
                label: Text(
                  matched != null
                      ? 'Use for GST bill'
                      : onlineFetched
                          ? 'Save verified GST details'
                          : 'Save & use GST details',
                ),
              ),
            ],
          );
        },
      ),
    );
    dialogAlive = false;

    if (result == null) return false;
    final canonicalStateCode = GstLookupService.stateCodeFromGstin(result.gstin);
    final canonicalState = GstLookupService.stateNameForCode(canonicalStateCode);
    Customer customer;
    if (result.matchedCustomer != null) {
      customer = result.matchedCustomer!;
      customer.stateCode = canonicalStateCode;
      if (canonicalState.isNotEmpty) customer.state = canonicalState;
      await app.persist();
    } else {
      customer = await app.createCustomer(
        name: result.name,
        phone: result.contact,
        gstin: result.gstin,
        address: result.address,
        state: canonicalState.isNotEmpty
            ? canonicalState
            : (result.state.isEmpty ? data.business.state : result.state),
        stateCode: canonicalStateCode,
      );
    }

    if (!mounted) return false;
    setState(() {
      selectedCustomer = customer;
      customerMode = true;
      gstBillRequired = true;
      requestedByName = result.requestedBy;
      requestedByContact = result.contact;
    });
    return true;
  }

  Future<void> _saveQuotation(List<SaleLine> lines) async {
    final ok = await confirmAction(
      context,
      title: 'Save quotation?',
      message: 'Save this quotation? Inventory and sales totals will not be changed.',
      confirmLabel: 'Save quotation',
      icon: Icons.request_quote_outlined,
    );
    if (!ok) return;
    final app = AppScope.of(context); final q = await app.saveQuotation(lines: lines, customerId: selectedCustomer?.id ?? '', customerName: selectedCustomer?.name ?? 'Walk-in');
    if (!mounted) return; _clearCart(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quotation ${q.number} saved. Inventory was NOT reduced.')));
  }

  Future<void> _openPayment(List<SaleLine> lines, double total, double discount, String docType) async {
    if (customerMode && selectedCustomer == null) { await _chooseCustomer(context); if (selectedCustomer == null) return; }
    if (gstBillRequired) {
      final business = AppScope.of(context).data!.business;
      if (!business.isRegularGst) {
        setState(() => gstBillRequired = false);
      } else if (selectedCustomer == null || selectedCustomer!.gstin.trim().isEmpty) {
        final ok = await _selectGstInvoiceRecipient(context);
        if (!ok) return;
      }
    }
    final result = await showDialog<_PaymentResult>(
      context: context,
      builder: (ctx) => _PaymentDialog(
        total: total,
        customer: selectedCustomer,
        business: AppScope.of(context).data!.business,
      ),
    );
    if (result == null) return;

    final billingName = gstBillRequired && selectedCustomer != null
        ? (selectedCustomer!.businessName.trim().isNotEmpty
            ? selectedCustomer!.businessName
            : selectedCustomer!.name)
        : (selectedCustomer?.name ?? 'Walk-in');

    final confirmed = await confirmAction(
      context,
      title: 'Confirm final payment',
      message:
          'Document: ${gstBillRequired && docType == DocumentRules.taxInvoice ? 'GST Tax Invoice' : docType}\n'
          'Customer: $billingName\n'
          '${gstBillRequired && selectedCustomer != null ? 'GSTIN: ${selectedCustomer!.gstin}\n' : ''}'
          '${gstBillRequired && requestedByName.isNotEmpty ? 'Requested by: $requestedByName\n' : ''}'
          'Total: ${money(total)}\n'
          'Payment: ${result.method}\n'
          'Paid now: ${money(result.amountPaid)}\n'
          '${result.reference.isEmpty ? '' : 'Reference: ${result.reference}\n'}'
          'This will save the bill and update inventory.',
      confirmLabel: 'Confirm & save bill',
      icon: Icons.verified_rounded,
    );
    if (!confirmed) return;

    final app = AppScope.of(context);
    final sale = await app.completeSale(
      lines: lines,
      payment: result.method,
      customer: billingName,
      customerId: selectedCustomer?.id ?? '',
      customerGstin: gstBillRequired ? (selectedCustomer?.gstin ?? '') : '',
      documentType: docType,
      placeOfSupplyStateCode: selectedCustomer?.stateCode ?? app.data!.business.stateCode,
      gstBillRequested: gstBillRequired,
      requestedByName: requestedByName,
      requestedByContact: requestedByContact,
      discount: discount,
      amountPaid: result.amountPaid,
      status: result.amountPaid >= total ? 'Paid' : result.amountPaid > 0 ? 'Partial' : 'Unpaid',
      paymentBreakdown: result.breakdown,
      cashReceived: result.cashReceived,
      changeReturned: result.changeReturned,
      changeDenominations: result.changeDenominations,
      customerAdvanceCreated: result.advanceToCustomer,
      paymentReference: result.reference,
    );
    if (selectedCustomer != null && result.advanceUsed > 0) await app.useCustomerAdvance(selectedCustomer!, result.advanceUsed, sale.documentNumber);
    if (selectedCustomer != null && result.advanceToCustomer > 0) {
      await app.addCustomerAdvance(
        selectedCustomer!,
        result.advanceToCustomer,
        sale.documentNumber,
        paymentMode: result.method,
        transactionReference: result.reference,
      );
    }
    if (!mounted) return; _clearCart(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${sale.documentType} ${sale.documentNumber} saved • ${sale.status}')));
  }

  Future<void> _confirmClearCart() async {
    if (cart.isEmpty) return;
    final ok = await confirmAction(
      context,
      title: 'Clear current bill?',
      message: 'Remove all items and discounts from the current bill?',
      confirmLabel: 'Clear bill',
      icon: Icons.delete_sweep_outlined,
      confirmColor: AppTheme.red,
    );
    if (ok) _clearCart();
  }

  void _clearCart() => setState(() {
        cart.clear();
        lineDiscountPct.clear();
        lineDiscountAmt.clear();
        lineNotes.clear();
        selectedSerials.clear();
        billDiscountPct = 0;
        billDiscountAmt = 0;
        quotationMode = false;
        gstBillRequired = false;
        requestedByName = '';
        requestedByContact = '';
      });
}


class _Catalog extends StatefulWidget {
  const _Catalog({
    required this.products,
    required this.categories,
    required this.selectedCategory,
    required this.search,
    required this.onSearch,
    required this.onCategory,
    required this.onProduct,
    required this.onLookup,
    required this.onManualLine,
  });

  final List<Product> products;
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController search;
  final VoidCallback onSearch;
  final ValueChanged<String> onCategory;
  final ValueChanged<Product> onProduct;
  final VoidCallback onLookup;
  final VoidCallback onManualLine;

  @override
  State<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<_Catalog> {
  final ScrollController _categoryController = ScrollController();
  final ScrollController _gridController = ScrollController();

  @override
  void dispose() {
    _categoryController.dispose();
    _gridController.dispose();
    super.dispose();
  }

  IconData _icon(Product p) {
    final c = p.category.toLowerCase();
    if (c.contains('fruit')) return Icons.apple_rounded;
    if (c.contains('vegetable')) return Icons.eco_rounded;
    if (c.contains('dairy')) return Icons.local_drink_rounded;
    if (c.contains('beverage')) return Icons.local_cafe_rounded;
    if (c.contains('personal')) return Icons.inventory_2_rounded;
    if (c.contains('staple')) return Icons.rice_bowl_rounded;
    if (c.contains('bakery')) return Icons.bakery_dining_rounded;
    return p.weighted ? Icons.scale_rounded : Icons.inventory_2_rounded;
  }

  Widget _productImage(Product p) {
    final fallback = Center(
      child: Icon(
        _icon(p),
        color: p.weighted ? AppTheme.green : AppTheme.cyan,
        size: 34,
      ),
    );

    Widget image;
    if (p.imageUrl.isEmpty) {
      image = fallback;
    } else if (p.imageUrl.startsWith('assets/')) {
      image = Image.asset(
        p.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else {
      image = Image.network(
        p.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF17212D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF344253)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: image,
      ),
    );
  }

  void _scrollCategories(double offset) {
    if (!_categoryController.hasClients) return;
    final target = (_categoryController.offset + offset)
        .clamp(
          _categoryController.position.minScrollExtent,
          _categoryController.position.maxScrollExtent,
        )
        .toDouble();
    _categoryController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 1000
            ? 3
            : c.maxWidth >= 590
                ? 2
                : 1;
        final ratio = columns == 3 ? 1.78 : columns == 2 ? 2.05 : 2.55;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: c.maxWidth < 720 ? c.maxWidth : c.maxWidth - 275,
                  child: TextField(
                    controller: widget.search,
                    onChanged: (_) => widget.onSearch(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search name / SKU / barcode / part / model / variant',
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: widget.onLookup,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan / Code'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onManualLine,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Manual item'),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous categories',
                    onPressed: () => _scrollCategories(-240),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _categoryController,
                      thumbVisibility: true,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: ListView.separated(
                        controller: _categoryController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(4, 5, 4, 10),
                        itemCount: widget.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 7),
                        itemBuilder: (_, i) {
                          final e = widget.categories[i];
                          return ChoiceChip(
                            label: Text(e),
                            selected: widget.selectedCategory == e,
                            onSelected: (_) => widget.onCategory(e),
                          );
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'More categories',
                    onPressed: () => _scrollCategories(240),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Scrollbar(
                controller: _gridController,
                thumbVisibility: true,
                child: GridView.builder(
                  controller: _gridController,
                  padding: const EdgeInsets.only(right: 8, bottom: 18),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: ratio,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: widget.products.length,
                  itemBuilder: (_, i) {
                    final p = widget.products[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: p.stock <= 0 ? null : () => widget.onProduct(p),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _productImage(p),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${p.productCode.isEmpty ? 'No SKU' : p.productCode} • ${money(p.sellingPrice)}/${p.unit}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    if (p.subcategory.isNotEmpty || p.customAttributes.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        [
                                          if (p.subcategory.isNotEmpty) p.subcategory,
                                          ...p.customAttributes.entries.take(2).map((e) => '${BusinessTypeRules.displayAttributeLabel(p.businessType.isEmpty ? 'General Retail' : p.businessType, e.key, category: p.category, subcategory: p.subcategory)}: ${e.value}'),
                                        ].join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AppTheme.cyan, fontSize: 10.5),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      p.stockLabel,
                                      style: TextStyle(
                                        color: p.stock <= p.reorderLevel
                                            ? AppTheme.red
                                            : AppTheme.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppTheme.green,
                                size: 27,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BillPanel extends StatefulWidget {
  const _BillPanel({
    required this.lines,
    required this.total,
    required this.profit,
    required this.billDiscountPct,
    required this.billDiscountAmt,
    required this.customerMode,
    required this.customer,
    required this.documentMode,
    required this.effectiveDocumentType,
    required this.quotationMode,
    required this.gstBillRequired,
    required this.canRequestGstBill,
    required this.gstRecipientLabel,
    required this.showProfit,
    required this.allowDocumentOverride,
    required this.onGstBillChanged,
    required this.onGstRecipientTap,
    required this.onCustomerMode,
    required this.onCustomerTap,
    required this.onDocumentMode,
    required this.onQuotationMode,
    required this.onBillDiscountPct,
    required this.onBillDiscountAmt,
    required this.onMinus,
    required this.onPlus,
    required this.onEditQty,
    required this.onEditDiscount,
    required this.onEditNote,
    required this.onRemove,
    required this.onClearBill,
    required this.onComplete,
  });

  final List<SaleLine> lines;
  final double total;
  final double profit;
  final double billDiscountPct;
  final double billDiscountAmt;
  final bool customerMode;
  final Customer? customer;
  final String documentMode;
  final String effectiveDocumentType;
  final bool quotationMode;
  final bool gstBillRequired;
  final bool canRequestGstBill;
  final String gstRecipientLabel;
  final bool showProfit;
  final bool allowDocumentOverride;
  final ValueChanged<bool> onGstBillChanged;
  final VoidCallback onGstRecipientTap;
  final ValueChanged<bool> onCustomerMode;
  final VoidCallback onCustomerTap;
  final ValueChanged<String> onDocumentMode;
  final ValueChanged<bool> onQuotationMode;
  final ValueChanged<double> onBillDiscountPct;
  final ValueChanged<double> onBillDiscountAmt;
  final ValueChanged<SaleLine> onMinus;
  final ValueChanged<SaleLine> onPlus;
  final ValueChanged<SaleLine> onEditQty;
  final ValueChanged<SaleLine> onEditDiscount;
  final ValueChanged<SaleLine> onEditNote;
  final ValueChanged<SaleLine> onRemove;
  final VoidCallback onClearBill;
  final VoidCallback? onComplete;

  @override
  State<_BillPanel> createState() => _BillPanelState();
}

class _BillPanelState extends State<_BillPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _lineImage(SaleLine l) {
    final fallback = Container(
      color: AppTheme.surface2,
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_rounded,
        color: AppTheme.cyan,
        size: 28,
      ),
    );

    Widget image;
    if (l.imageUrl.isEmpty) {
      image = fallback;
    } else if (l.imageUrl.startsWith('assets/')) {
      image = Image.asset(
        l.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else {
      image = Image.network(
        l.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Container(
      width: 62,
      height: 62,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF17212D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: image,
      ),
    );
  }

  Widget _toggleTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: strong ? Colors.white : AppTheme.muted,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              fontSize: strong ? 16 : 12.5,
            ),
          ),
          const Spacer(),
          Text(
            money(value),
            style: TextStyle(
              fontSize: strong ? 25 : 14,
              fontWeight: FontWeight.w900,
              color: strong ? Colors.white : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineCard(SaleLine l) {
    final color = l.profit < 0
        ? AppTheme.red
        : l.profitPercent < 10
            ? AppTheme.amber
            : AppTheme.green;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151E),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _lineImage(l),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          money(l.net),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${money(l.unitPrice)}/${l.unit} × ${l.qty.toStringAsFixed(l.qty % 1 == 0 ? 0 : 2)} ${l.unit} • Disc ${l.discountPercent.toStringAsFixed(1)}% + ${money(l.discountAmount)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10.5,
                      ),
                    ),
                    if (l.serialNumbers.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Serial / IMEI: ${l.serialNumbers.join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.cyan,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => widget.onRemove(l),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.showProfit)
                StatusPill(
                  text: l.profit < 0
                      ? 'LOSS ${money(l.profit.abs())}'
                      : 'PROFIT ${money(l.profit)}',
                  color: color,
                  icon: l.profit < 0
                      ? Icons.warning_amber_rounded
                      : Icons.trending_up_rounded,
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Decrease',
                onPressed: () => widget.onMinus(l),
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              TextButton(
                onPressed: () => widget.onEditQty(l),
                child: Text(
                  l.qty.toStringAsFixed(l.qty % 1 == 0 ? 0 : 2),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Increase',
                onPressed: () => widget.onPlus(l),
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
              IconButton(
                tooltip: 'Discount',
                onPressed: () => widget.onEditDiscount(l),
                icon: const Icon(Icons.percent_rounded),
              ),
            ],
          ),
          const Divider(height: 18),
          InkWell(
            onTap: () => widget.onEditNote(l),
            child: Row(
              children: [
                const Icon(
                  Icons.note_alt_outlined,
                  color: AppTheme.red,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    l.note.isEmpty ? 'Add a note (optional)' : l.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: l.note.isEmpty ? AppTheme.red : AppTheme.muted,
                      fontSize: 11,
                      fontWeight:
                          l.note.isEmpty ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.lines.fold<double>(0, (a, b) => a + b.net);
    final discountTotal =
        (subtotal * widget.billDiscountPct / 100) + widget.billDiscountAmt;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF121722), Color(0xFF0B1017)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A3442)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x48000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.quotationMode ? 'Quotation' : 'Current Bill',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                StatusPill(
                  text: widget.effectiveDocumentType,
                  color:
                      widget.quotationMode ? AppTheme.purple : AppTheme.red,
                  icon: widget.quotationMode
                      ? Icons.request_quote_rounded
                      : Icons.receipt_long_rounded,
                ),
                const SizedBox(width: 5),
                IconButton(
                  tooltip: 'Close / clear bill',
                  onPressed:
                      widget.lines.isEmpty ? null : widget.onClearBill,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(18, 8, 10, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10151D),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          _toggleTile(
                            label: 'Bill with\nCustomer ID',
                            value: widget.customerMode,
                            onChanged: widget.onCustomerMode,
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: AppTheme.border,
                          ),
                          _toggleTile(
                            label: 'Quotation',
                            value: widget.quotationMode,
                            onChanged: widget.onQuotationMode,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.customerMode) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.onCustomerTap,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121A25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 22,
                                backgroundColor: Color(0xFF22304A),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: AppTheme.cyan,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.customer == null
                                          ? 'Select / create customer'
                                          : '${widget.customer!.name} • ${widget.customer!.id}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.customer == null
                                          ? 'Search by customer ID, name or mobile'
                                          : '${widget.customer!.phone.isEmpty ? 'No mobile' : widget.customer!.phone}  |  Customer owes us ${money(widget.customer!.creditBalance)}  |  Advance available ${money(widget.customer!.advanceBalance)}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppTheme.muted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10151D),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: widget.gstBillRequired ? AppTheme.green : AppTheme.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'GST bill in requested GSTIN?',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Use when the buyer wants the invoice issued in a specific GST-registered name.',
                                      style: TextStyle(color: AppTheme.muted, fontSize: 10.5),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: widget.gstBillRequired,
                                onChanged: widget.quotationMode
                                    ? null
                                    : (widget.canRequestGstBill
                                        ? widget.onGstBillChanged
                                        : widget.onGstBillChanged),
                              ),
                            ],
                          ),
                          if (!widget.canRequestGstBill)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Available only when Settings → GST Registration is Regular GST.',
                                  style: TextStyle(color: AppTheme.amber, fontSize: 10.5),
                                ),
                              ),
                            ),
                          if (widget.gstBillRequired) ...[
                            const Divider(height: 15),
                            InkWell(
                              onTap: widget.onGstRecipientTap,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.business_rounded, color: AppTheme.green, size: 19),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.gstRecipientLabel,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                                      ),
                                    ),
                                    const Icon(Icons.edit_outlined, size: 17, color: AppTheme.muted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121A25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: widget.allowDocumentOverride
                          ? DropdownButtonFormField<String>(
                              value: widget.documentMode,
                              items: const ['Auto', 'Tax Invoice', 'Bill of Supply', 'Bill / Receipt']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => widget.onDocumentMode(v ?? 'Auto'),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                labelText: 'Document decision • Owner override',
                                prefixIcon: Icon(Icons.description_outlined),
                              ),
                            )
                          : InputDecorator(
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                labelText: 'Document selected automatically',
                                prefixIcon: Icon(Icons.auto_awesome_outlined),
                              ),
                              child: Text(widget.effectiveDocumentType, style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                    ),
                    const SizedBox(height: 14),
                    if (widget.lines.isEmpty)
                      const SizedBox(
                        height: 260,
                        child: EmptyState(
                          'Your bill is empty.\nSearch and add products, scan a code, or add a manual item.',
                          icon: Icons.shopping_cart_outlined,
                        ),
                      )
                    else ...[
                      ...widget.lines.map(
                        (l) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _lineCard(l),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text(
                      'Bill Discount',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: widget.billDiscountPct == 0
                                ? ''
                                : widget.billDiscountPct.toString(),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Bill discount %',
                            ),
                            onChanged: (v) => widget.onBillDiscountPct(
                              double.tryParse(v) ?? 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: TextFormField(
                            initialValue: widget.billDiscountAmt == 0
                                ? ''
                                : widget.billDiscountAmt.toString(),
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Bill discount \u20B9',
                            ),
                            onChanged: (v) => widget.onBillDiscountAmt(
                              double.tryParse(v) ?? 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141C27),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: const Color(0xFF263241)),
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Subtotal', subtotal),
                          _summaryRow(
                            'Bill Discount',
                            -discountTotal,
                          ),
                          const Divider(),
                          _summaryRow(
                            'Total',
                            widget.total,
                            strong: true,
                          ),
                        ],
                      ),
                    ),
                    if (widget.showProfit) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: widget.profit < 0
                              ? const Color(0xFF2A1115)
                              : const Color(0xFF0E2A20),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: widget.profit < 0
                                ? AppTheme.red
                                : AppTheme.green,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.profit < 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.bar_chart_rounded,
                              color: widget.profit < 0
                                  ? AppTheme.red
                                  : AppTheme.green,
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Text(
                                'Estimated profit after discounts',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              money(widget.profit),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: widget.profit < 0
                                    ? AppTheme.red
                                    : AppTheme.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: widget.onComplete,
                icon: Icon(
                  widget.quotationMode
                      ? Icons.request_quote_rounded
                      : Icons.account_balance_wallet_rounded,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.quotationMode
                          ? 'Save quotation'
                          : 'Continue to payment',
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GstRecipientResult {
  _GstRecipientResult({
    required this.matchedCustomer,
    required this.gstin,
    required this.name,
    required this.address,
    required this.state,
    required this.stateCode,
    required this.requestedBy,
    required this.contact,
  });

  final Customer? matchedCustomer;
  final String gstin;
  final String name;
  final String address;
  final String state;
  final String stateCode;
  final String requestedBy;
  final String contact;
}

class _PaymentResult {
  _PaymentResult({
    required this.method,
    required this.amountPaid,
    required this.breakdown,
    this.advanceToCustomer = 0,
    this.advanceUsed = 0,
    this.cashReceived = 0,
    this.changeReturned = 0,
    this.changeDenominations = const {},
    this.reference = '',
  });
  final String method;
  final double amountPaid;
  final Map<String, double> breakdown;
  final double advanceToCustomer;
  final double advanceUsed;
  final double cashReceived;
  final double changeReturned;
  final Map<String, int> changeDenominations;
  final String reference;
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({
    required this.total,
    required this.customer,
    required this.business,
  });
  final double total;
  final Customer? customer;
  final BusinessProfile business;
  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String method = 'Cash';
  bool payFull = false;
  String extraAction = 'Return change';
  String shortAction = 'Take remaining now';

  final manualCash = TextEditingController();
  final upi = TextEditingController();
  final card = TextEditingController();
  final splitCash = TextEditingController();
  final splitUpi = TextEditingController();
  final splitCard = TextEditingController();
  final paymentReference = TextEditingController();
  bool upiTestConfirmed = false;
  bool upiTestRunning = false;

  final counts = <int, int>{
    2000: 0,
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
    5: 0,
    2: 0,
    1: 0,
  };

  final returnCounts = <int, int>{
    2000: 0,
    500: 0,
    200: 0,
    100: 0,
    50: 0,
    20: 0,
    10: 0,
    5: 0,
    2: 0,
    1: 0,
  };

  double get denominationTotal =>
      counts.entries.fold<double>(0, (a, e) => a + e.key * e.value);

  double get returnDenominationTotal =>
      returnCounts.entries.fold<double>(0, (a, e) => a + e.key * e.value);

  double get cashReceived {
    final manual = double.tryParse(manualCash.text);
    return manual != null ? manual : denominationTotal;
  }

  double get received {
    if (method == 'Credit / Pay Later') return 0;
    if (method == 'Customer Advance') {
      return widget.customer == null
          ? 0
          : widget.total
              .clamp(0.0, widget.customer!.advanceBalance)
              .toDouble();
    }
    if (method == 'UPI' || method == 'Debit/Credit Card') {
      if (payFull) return widget.total;
      return double.tryParse(method == 'UPI' ? upi.text : card.text) ?? 0;
    }
    if (method == 'Cash') return payFull ? widget.total : cashReceived;
    return (double.tryParse(splitCash.text) ?? 0) +
        (double.tryParse(splitUpi.text) ?? 0) +
        (double.tryParse(splitCard.text) ?? 0);
  }

  void _autoFillChange(double change) {
    for (final key in returnCounts.keys) {
      returnCounts[key] = 0;
    }
    var remaining = change.round();
    for (final d in returnCounts.keys) {
      if (remaining <= 0) break;
      final count = remaining ~/ d;
      returnCounts[d] = count;
      remaining -= count * d;
    }
    setState(() {});
  }

  Widget _denominationGrid(Map<int, int> source, {required bool returnMode}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: source.keys.map((d) {
        return Container(
          width: 132,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF111720),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              Text('\u20B9$d', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => setState(() =>
                        source[d] = (source[d]! - 1).clamp(0, 999).toInt()),
                    icon: const Icon(Icons.remove_circle_outline),
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${source[d]}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => source[d] = source[d]! + 1),
                    icon: const Icon(Icons.add_circle_outline),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData =
        'upi://pay?pa=${widget.business.upiId}&pn=${Uri.encodeComponent(widget.business.businessName)}&am=${widget.total.toStringAsFixed(2)}&cu=INR';

    final amount = received;
    final excess =
        (amount - widget.total).clamp(0.0, double.infinity).toDouble();
    final due =
        (widget.total - amount).clamp(0.0, double.infinity).toDouble();

    final needsCustomerForExtra = excess > 0 &&
        extraAction == 'Store in customer balance' &&
        widget.customer == null;
    final needsCustomerForDue = due > 0 &&
        shortAction == 'Add as customer debt' &&
        widget.customer == null;
    final underpaidBlocked =
        due > 0 && shortAction == 'Take remaining now' && method != 'Credit / Pay Later';

    final changeMismatch = method == 'Cash' &&
        excess > 0 &&
        extraAction == 'Return change' &&
        (returnDenominationTotal - excess).abs() > 0.01;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: AppTheme.red),
          const SizedBox(width: 8),
          const Text('Payment'),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Amount payable',
                  style: TextStyle(color: AppTheme.muted, fontSize: 11)),
              Text(
                money(widget.total),
                style:
                    const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  'Cash',
                  'UPI',
                  'Debit/Credit Card',
                  'Customer Advance',
                  'Credit / Pay Later',
                  'Split'
                ]
                    .map(
                      (e) => ChoiceChip(
                        label: Text(e),
                        selected: method == e,
                        onSelected: (_) => setState(() {
                          method = e;
                          payFull = false;
                          upiTestConfirmed = false;
                          upiTestRunning = false;
                          paymentReference.clear();
                        }),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: payFull,
                title: Text(
                  'Pay full amount (${money(widget.total)})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle:
                    const Text('Automatically uses the exact payable amount.'),
                onChanged: (v) => setState(() => payFull = v ?? false),
              ),
              if (method == 'Cash') ...[
                const Divider(),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cash received',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                          Text(
                            'Tap + / − for notes and coins, or enter the total cash manually.',
                            style:
                                TextStyle(color: AppTheme.muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        for (final d in counts.keys) {
                          counts[d] = 0;
                        }
                        manualCash.clear();
                      }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear all cash'),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _denominationGrid(counts, returnMode: false),
                const SizedBox(height: 9),
                TextField(
                  controller: manualCash,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Manual total cash received',
                    hintText: denominationTotal > 0
                        ? 'Denominations total ${money(denominationTotal)}'
                        : 'Enter amount manually',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    suffixIcon: manualCash.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              manualCash.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ],
              if (method == 'UPI') ...[
                const Divider(),
                const Text(
                  'UPI payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                if (widget.business.upiQrPath.isNotEmpty &&
                    File(widget.business.upiQrPath).existsSync())
                  Center(
                    child: Container(
                      width: 210,
                      height: 210,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.file(
                        File(widget.business.upiQrPath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else if (widget.business.upiId.isNotEmpty)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: BarcodeWidget(
                        barcode: Barcode.qrCode(),
                        data: qrData,
                        width: 190,
                        height: 190,
                        drawText: false,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF211A0F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF5C4520)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AppTheme.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No UPI QR or UPI ID is configured. Open Settings → UPI payment setup.',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                if (widget.business.upiId.isNotEmpty)
                  Text(
                    'UPI ID: ${widget.business.upiId}',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: upi,
                  onChanged: (_) => setState(() => upiTestConfirmed = false),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'UPI amount received',
                    helperText: widget.business.upiTestMode
                        ? 'Test mode can simulate automatic confirmation. Real bank auto-confirm requires a payment-provider/API connection.'
                        : 'Enter the amount after confirming payment in your bank/merchant app.',
                    suffixIcon: upiTestConfirmed
                        ? const Icon(Icons.verified_rounded, color: AppTheme.green)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: paymentReference,
                  decoration: const InputDecoration(
                    labelText: 'UPI transaction / UTR reference',
                    hintText: 'Optional for test mode; recommended for real payments',
                  ),
                ),
                if (widget.business.upiTestMode) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1C18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF24483A)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TEST MODE — no bank call is made. This only verifies the ProfitGPS auto-confirm workflow.',
                            style: TextStyle(
                              color: AppTheme.green,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: upiTestRunning
                              ? null
                              : () async {
                                  setState(() => upiTestRunning = true);
                                  await Future<void>.delayed(
                                    const Duration(milliseconds: 900),
                                  );
                                  if (!mounted) return;
                                  upi.text = widget.total.toStringAsFixed(2);
                                  paymentReference.text =
                                      'TEST-${DateTime.now().millisecondsSinceEpoch}';
                                  setState(() {
                                    upiTestConfirmed = true;
                                    upiTestRunning = false;
                                  });
                                },
                          icon: upiTestRunning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.science_outlined),
                          label: Text(
                            upiTestRunning
                                ? 'Checking...'
                                : 'Test auto-confirm',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (method == 'Debit/Credit Card') ...[
                const Divider(),
                TextField(
                  controller: card,
                  onChanged: (_) => setState(() {}),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Card amount received',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: paymentReference,
                  decoration: const InputDecoration(
                    labelText: 'Card transaction / approval reference',
                  ),
                ),
              ],
              if (method == 'Customer Advance')
                Text(
                  widget.customer == null
                      ? 'Select a Customer ID first.'
                      : 'Customer advance available: ${money(widget.customer!.advanceBalance)}',
                  style: TextStyle(
                    color:
                        widget.customer == null ? AppTheme.red : AppTheme.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (method == 'Credit / Pay Later')
                Text(
                  widget.customer == null
                      ? 'Customer ID is required for a credit sale.'
                      : 'Full amount will be stored as customer receivable.',
                  style: TextStyle(
                    color:
                        widget.customer == null ? AppTheme.red : AppTheme.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (method == 'Split') ...[
                const Divider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: splitCash,
                        onChanged: (_) => setState(() {}),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Cash'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: splitUpi,
                        onChanged: (_) => setState(() {}),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'UPI'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: splitCard,
                        onChanged: (_) => setState(() {}),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Card'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: paymentReference,
                  decoration: const InputDecoration(
                    labelText: 'Payment reference / UTR (optional)',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF10151C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _sum('Received', money(amount), AppTheme.green),
                    _sum(
                      'Change / extra',
                      money(excess),
                      excess > 0 ? AppTheme.green : AppTheme.muted,
                    ),
                    _sum(
                      'Remaining to settle',
                      money(due),
                      due > 0 ? AppTheme.red : AppTheme.muted,
                    ),
                  ],
                ),
              ),
              if (excess > 0) ...[
                const SizedBox(height: 12),
                const Text(
                  'Extra amount detected',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: AppTheme.green),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'Return change',
                  groupValue: extraAction,
                  title: Text('Return ${money(excess)} as change'),
                  onChanged: (v) => setState(() => extraAction = v!),
                ),
                if (method == 'Cash' && extraAction == 'Return change') ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Record change returned by denomination',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _autoFillChange(excess),
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        label: const Text('Auto fill'),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          for (final d in returnCounts.keys) {
                            returnCounts[d] = 0;
                          }
                        }),
                        icon: const Icon(Icons.clear_all_rounded),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _denominationGrid(returnCounts, returnMode: true),
                  const SizedBox(height: 8),
                  _sum(
                    'Change denomination total',
                    money(returnDenominationTotal),
                    changeMismatch ? AppTheme.red : AppTheme.green,
                  ),
                  if (changeMismatch)
                    Text(
                      'Returned denomination total must equal ${money(excess)}.',
                      style: const TextStyle(
                          color: AppTheme.red, fontWeight: FontWeight.w800),
                    ),
                ],
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'Store in customer balance',
                  groupValue: extraAction,
                  title: Text('Store ${money(excess)} as customer advance'),
                  subtitle: Text(
                    widget.customer == null
                        ? 'Customer ID required. Select/create the customer in Current Bill.'
                        : 'Stored as customer advance / liability, not profit.',
                  ),
                  onChanged: (v) => setState(() => extraAction = v!),
                ),
              ],
              if (due > 0) ...[
                const SizedBox(height: 12),
                const Text(
                  'Amount is less than bill',
                  style:
                      TextStyle(fontWeight: FontWeight.w900, color: AppTheme.red),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'Take remaining now',
                  groupValue: shortAction,
                  title: Text('Take remaining ${money(due)} now'),
                  onChanged: (v) => setState(() => shortAction = v!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'Add as customer debt',
                  groupValue: shortAction,
                  title: Text('Add ${money(due)} as customer debt / credit'),
                  subtitle: Text(
                    widget.customer == null
                        ? 'Customer ID required. Walk-in debt is not allowed because it cannot be recovered safely.'
                        : 'Saved in the customer ledger and Accounts Receivable.',
                  ),
                  onChanged: (v) => setState(() => shortAction = v!),
                ),
              ],
              if (needsCustomerForExtra || needsCustomerForDue)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Select or create a Customer ID in Current Bill before storing an advance or debt.',
                    style: TextStyle(
                        color: AppTheme.red, fontWeight: FontWeight.w800),
                  ),
                ),
              if (widget.customer == null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101721),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF24425F)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.cyan),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Walk-in bills are saved normally. Only customer-specific advance or debt requires a Customer ID. Returned change does not require a Customer ID.',
                          style: TextStyle(color: AppTheme.muted),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: ((method == 'Credit / Pay Later' ||
                          method == 'Customer Advance') &&
                      widget.customer == null) ||
                  needsCustomerForExtra ||
                  needsCustomerForDue ||
                  underpaidBlocked ||
                  changeMismatch
              ? null
              : () {
                  final breakdown = <String, double>{};
                  var advanceUsed = 0.0;
                  var amountPaid = 0.0;
                  var cashIn = 0.0;
                  var changeOut = 0.0;
                  var returnedDenoms = <String, int>{};

                  if (method == 'Credit / Pay Later') {
                    amountPaid = 0;
                    breakdown['Credit'] = widget.total;
                  } else if (method == 'Customer Advance') {
                    advanceUsed = widget.customer == null
                        ? 0
                        : widget.total
                            .clamp(0.0, widget.customer!.advanceBalance)
                            .toDouble();
                    amountPaid = advanceUsed;
                    breakdown['Customer Advance'] = advanceUsed;
                    if (due > 0 && shortAction == 'Add as customer debt') {
                      breakdown['Credit'] = due;
                    }
                  } else if (method == 'Split') {
                    final cash = double.tryParse(splitCash.text) ?? 0;
                    final upiValue = double.tryParse(splitUpi.text) ?? 0;
                    final cardValue = double.tryParse(splitCard.text) ?? 0;
                    breakdown['Cash'] = cash;
                    breakdown['UPI'] = upiValue;
                    breakdown['Card'] = cardValue;
                    cashIn = cash;
                    amountPaid = amount.clamp(0.0, widget.total).toDouble();
                    if (due > 0 && shortAction == 'Add as customer debt') {
                      breakdown['Credit'] = due;
                    }
                  } else {
                    amountPaid = amount.clamp(0.0, widget.total).toDouble();
                    breakdown[method] = amountPaid;
                    if (method == 'Cash') cashIn = amount;
                  }

                  if (method == 'Cash' &&
                      excess > 0 &&
                      extraAction == 'Return change') {
                    changeOut = excess;
                    returnedDenoms = {
                      for (final e in returnCounts.entries)
                        if (e.value > 0) '${e.key}': e.value
                    };
                  }

                  Navigator.pop(
                    context,
                    _PaymentResult(
                      method: method,
                      amountPaid: amountPaid,
                      breakdown: breakdown,
                      advanceToCustomer:
                          excess > 0 && extraAction == 'Store in customer balance'
                              ? excess
                              : 0,
                      advanceUsed: advanceUsed,
                      cashReceived: cashIn,
                      changeReturned: changeOut,
                      changeDenominations: returnedDenoms,
                      reference: paymentReference.text.trim(),
                    ),
                  );
                },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Confirm payment'),
        ),
      ],
    );
  }

  Widget _sum(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppTheme.muted)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      );
}

extension FirstOrNullBilling<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
