
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../services/product_lookup_service.dart';
import '../services/gs1_scan_parser.dart';
import '../services/business_type_rules.dart';
import '../widgets/common.dart';
import '../widgets/barcode_input_dialog.dart';

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});
  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      'New Purchase',
      'Purchase History',
      'Purchase Returns',
      'Stock List',
      'Low Stock',
      'Expiry Alerts',
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          child: SectionTitle(
            'Purchases & Inventory Flow',
            subtitle:
                'Supplier invoice → tax/discount/free quantity → landed cost → stock → payable.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(labels[i]),
                selected: tab == i,
                onSelected: (_) => setState(() => tab = i),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: switch (tab) {
            0 => const _NewPurchaseView(),
            1 => const _PurchaseHistoryView(),
            2 => const _PurchaseReturnsView(),
            3 => const _StockListView(),
            4 => const _LowStockView(),
            _ => const _ExpiryView(),
          },
        ),
      ],
    );
  }
}

class _NewPurchaseView extends StatefulWidget {
  const _NewPurchaseView();
  @override
  State<_NewPurchaseView> createState() => _NewPurchaseViewState();
}

enum _StockInMode { supplier, local, production }

class _NewPurchaseViewState extends State<_NewPurchaseView> {
  _StockInMode sourceMode = _StockInMode.supplier;
  Supplier? supplier;
  Product? product;
  final sourceName = TextEditingController();
  final invoiceNo = TextEditingController();
  final poNo = TextEditingController();
  DateTime invoiceDate = DateTime.now();
  String paymentMode = 'Bank Transfer';
  String paymentTiming = 'Credit / pay later';
  bool useSupplierAdvance = true;
  final paid = TextEditingController(text: '0');
  final reference = TextEditingController();
  final invoiceFreight = TextEditingController(text: '0');

  final qty = TextEditingController(text: '1');
  final freeQty = TextEditingController(text: '0');
  final conversion = TextEditingController(text: '1');
  final purchasePrice = TextEditingController(text: '0');
  final supplierDiscount = TextEditingController(text: '0');
  final lineFreight = TextEditingController(text: '0');
  final batch = TextEditingController();
  final serialReference = TextEditingController();
  final mrp = TextEditingController(text: '0');
  final selling = TextEditingController(text: '0');
  final defaultDiscount = TextEditingController(text: '0');
  final reorder = TextEditingController(text: '0');
  final rack = TextEditingController();
  final note = TextEditingController();
  final hsn = TextEditingController();
  final pendingProducts = <String, Product>{};
  bool poInitialized = false;
  DateTime? manufactureDate;
  DateTime? expiryDate;
  String taxCategory = 'Unclassified';
  double saleGstRate = 5;
  bool saleTaxInclusive = true;
  bool gstApplicable = true;
  double purchaseGstRate = 5;
  bool itcEligible = true;
  bool purchaseIncludesTax = false;
  String purchaseUnit = 'Carton';
  String sellingUnit = 'pcs';

  final lines = <PurchaseLine>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!poInitialized) {
      poNo.text = AppScope.of(context).nextPurchaseOrderNumber();
      poInitialized = true;
    }
  }

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  PurchaseLine? get previewLine {
    if (product == null) return null;
    final business = AppScope.of(context).data!.business;
    return PurchaseLine(
      productId: product!.id,
      productName: product!.name,
      purchaseUnit: purchaseUnit,
      sellingUnit: sellingUnit,
      quantity: _d(qty),
      freeQuantity: sourceMode == _StockInMode.production ? 0 : _d(freeQty),
      conversionQty: _d(conversion) <= 0 ? 1 : _d(conversion),
      purchasePricePerUnit: _d(purchasePrice),
      supplierDiscountPercent:
          sourceMode == _StockInMode.supplier ? _d(supplierDiscount) : 0,
      freightCost: _d(lineFreight),
      gstApplicable: sourceMode == _StockInMode.supplier &&
          taxCategory == 'Taxable' && gstApplicable,
      gstRate: sourceMode == _StockInMode.supplier &&
              taxCategory == 'Taxable' && gstApplicable
          ? purchaseGstRate
          : 0,
      taxCategory: taxCategory,
      saleGstRate: taxCategory == 'Taxable' ? saleGstRate : 0,
      saleTaxInclusive: saleTaxInclusive,
      hsnSac: hsn.text.trim(),
      itcEligible: sourceMode == _StockInMode.supplier && business.canClaimItc
          ? itcEligible
          : false,
      purchasePriceIncludesTax:
          sourceMode == _StockInMode.supplier ? purchaseIncludesTax : false,
      batchNo: batch.text.trim(),
      serialNumbers: serialReference.text.trim(),
      manufactureDate: manufactureDate,
      expiryDate: expiryDate,
      mrp: _d(mrp),
      sellingPrice: _d(selling),
      defaultDiscountPercent: _d(defaultDiscount),
      reorderLevel: _d(reorder),
      rackLocation: rack.text.trim(),
      note: note.text.trim(),
    );
  }

  void _selectProduct(Product p) {
    setState(() {
      product = p;
      sellingUnit = p.unit;
      purchaseUnit = p.purchaseUnit.isEmpty ? 'unit' : p.purchaseUnit;
      conversion.text = p.packConversionQty <= 0 ? '1' : p.packConversionQty.toStringAsFixed(p.packConversionQty % 1 == 0 ? 0 : 2);
      purchasePrice.text = (p.purchaseInvoicePrice > 0 ? p.purchaseInvoicePrice : p.purchasePrice).toStringAsFixed(2);
      supplierDiscount.text = p.supplierDiscountPercent.toStringAsFixed(2);
      lineFreight.text = p.freightCost.toStringAsFixed(2);
      selling.text = p.sellingPrice.toStringAsFixed(2);
      defaultDiscount.text = p.defaultDiscountPercent.toStringAsFixed(2);
      reorder.text = p.reorderLevel.toStringAsFixed(p.reorderLevel % 1 == 0 ? 0 : 2);
      taxCategory = p.taxCategory;
      saleGstRate = p.gstRate;
      saleTaxInclusive = p.taxInclusive;
      gstApplicable = p.gstApplicable;
      purchaseGstRate = p.gstRate;
      itcEligible = p.itcEligible;
      purchaseIncludesTax = p.purchasePriceIncludesTax;
      mrp.text = p.mrp.toStringAsFixed(2);
      rack.text = p.rackLocation;
      hsn.text = p.hsnSac;
    });
  }

  Future<void> _changeSourceMode(_StockInMode next) async {
    if (next == sourceMode) return;
    if (lines.isNotEmpty || pendingProducts.isNotEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Change stock-in type?',
        message:
            'Changing the stock-in type will clear the current unsaved items so supplier/local/production accounting is not mixed.',
        confirmLabel: 'Change & clear',
        icon: Icons.swap_horiz_rounded,
        confirmColor: AppTheme.amber,
      );
      if (!ok || !mounted) return;
    }

    setState(() {
      sourceMode = next;
      lines.clear();
      pendingProducts.clear();
      product = null;
      supplier = null;
      sourceName.clear();
      invoiceNo.clear();
      qty.text = '1';
      freeQty.text = '0';
      supplierDiscount.text = '0';
      invoiceFreight.text = '0';
      paid.text = '0';
      reference.clear();
      useSupplierAdvance = false;
      if (next == _StockInMode.supplier) {
        paymentTiming = 'Credit / pay later';
        paymentMode = 'Bank Transfer';
      } else if (next == _StockInMode.local) {
        paymentTiming = 'Pay full now';
        paymentMode = 'Cash';
      } else {
        paymentTiming = 'Pay full now';
        paymentMode = 'Own Production';
      }
    });
  }

  Widget _sourceModeCard({
    required _StockInMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = sourceMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _changeSourceMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10231E) : const Color(0xFF11161D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.green : AppTheme.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.green.withValues(alpha: 0.14)
                    : AppTheme.surface2,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: selected ? AppTheme.green : AppTheme.muted),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: selected ? Colors.white : null,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.green,
                          size: 18,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAndSelectSupplier() async {
    final app = AppScope.of(context);
    final suggestedCode =
        'SUP${(app.data!.suppliers.length + 1).toString().padLeft(3, '0')}';
    final code = TextEditingController(text: suggestedCode);
    final name = TextEditingController();
    final contact = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    final gstin = TextEditingController();
    final pan = TextEditingController();
    final category = TextEditingController(text: 'General');
    final items = TextEditingController();
    final address = TextEditingController();
    final city = TextEditingController();
    final state = TextEditingController(text: 'Tamil Nadu');
    final pincode = TextEditingController();
    final terms = TextEditingController(text: 'Cash');
    final creditDays = TextEditingController(text: '0');
    final bankUpi = TextEditingController();
    final notes = TextEditingController();
    final openingPayable = TextEditingController(text: '0');
    final openingAdvance = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New supplier'),
        content: SizedBox(
          width: 820,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _supplierInput('Supplier code *', code, 180),
                _supplierInput('Supplier name *', name, 260),
                _supplierInput('Contact person', contact, 220),
                _supplierInput('Mobile number', mobile, 200),
                _supplierInput('Email', email, 260),
                _supplierInput('GSTIN', gstin, 230),
                _supplierInput('PAN', pan, 190),
                _supplierInput('Category', category, 200),
                _supplierInput('Brand / supplied items', items, 300),
                _supplierInput('City', city, 200),
                _supplierInput('State', state, 200),
                _supplierInput('Pincode', pincode, 160),
                _supplierInput('Payment terms', terms, 210),
                _supplierInput('Credit days', creditDays, 150,
                    keyboardType: TextInputType.number),
                _supplierInput('Bank / UPI details', bankUpi, 300),
                _supplierInput('Opening amount payable', openingPayable, 220,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _supplierInput('Opening supplier advance', openingAdvance, 220,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _supplierInput('Billing address', address, 500, maxLines: 2),
                _supplierInput('Notes', notes, 500, maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Create & select supplier'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier code and name are required.')),
      );
      return;
    }
    final duplicate = app.data!.suppliers.any(
      (s) => s.code.trim().toLowerCase() == code.text.trim().toLowerCase(),
    );
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier code already exists.')),
      );
      return;
    }

    final payable = (double.tryParse(openingPayable.text.trim()) ?? 0)
        .clamp(0.0, double.infinity)
        .toDouble();
    final advance = (double.tryParse(openingAdvance.text.trim()) ?? 0)
        .clamp(0.0, double.infinity)
        .toDouble();
    final created = Supplier(
      id: const Uuid().v4(),
      code: code.text.trim(),
      name: name.text.trim(),
      contactPerson: contact.text.trim(),
      mobile: mobile.text.trim(),
      email: email.text.trim(),
      gstin: gstin.text.trim(),
      pan: pan.text.trim(),
      category: category.text.trim().isEmpty ? 'General' : category.text.trim(),
      suppliedItems: items.text.trim(),
      address: address.text.trim(),
      city: city.text.trim(),
      state: state.text.trim().isEmpty ? 'Tamil Nadu' : state.text.trim(),
      pincode: pincode.text.trim(),
      paymentTerms: terms.text.trim().isEmpty ? 'Cash' : terms.text.trim(),
      creditDays: int.tryParse(creditDays.text.trim()) ?? 0,
      openingPayable: payable,
      supplierCreditBalance: advance,
      bankUpi: bankUpi.text.trim(),
      notes: notes.text.trim(),
    );
    await app.addSupplier(created);
    if (payable > 0) {
      app.data!.supplierLedger.insert(
        0,
        SupplierLedgerEntry(
          id: const Uuid().v4(),
          supplierId: created.id,
          createdAt: DateTime.now(),
          type: 'PAYABLE',
          amount: payable,
          note: 'Opening supplier payable',
        ),
      );
    }
    if (advance > 0) {
      app.data!.supplierLedger.insert(
        0,
        SupplierLedgerEntry(
          id: const Uuid().v4(),
          supplierId: created.id,
          createdAt: DateTime.now(),
          type: 'ADVANCE',
          amount: advance,
          note: 'Opening supplier advance',
        ),
      );
    }
    await app.persist();
    if (!mounted) return;
    setState(() {
      supplier = created;
      final credit = created.paymentTerms.toLowerCase().contains('credit');
      paymentTiming = credit ? 'Credit / pay later' : 'Pay full now';
      paymentMode = credit ? 'Bank Transfer' : 'Cash';
      paid.text = '0';
      useSupplierAdvance = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${created.name} created and selected.')),
    );
  }

  Widget _supplierInput(
    String label,
    TextEditingController controller,
    double width, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<String?> _waitForBarcode({
    required String title,
    required String subtitle,
  }) {
    return showBarcodeInputDialog(
      context,
      title: title,
      subtitle: subtitle,
      actionLabel: 'Use barcode',
    );
  }

  Future<void> _scanProductForPurchase() async {
    final code = await _waitForBarcode(
      title: 'Scan product for purchase',
      subtitle:
          'Existing barcode → select the product and update its stock. New barcode → open New Product with the barcode prefilled.',
    );
    if (code == null || !mounted) return;

    final normalized = code.toLowerCase();
    final app = AppScope.of(context);
    final options = <Product>[
      ...app.data!.products,
      ...pendingProducts.values,
    ];
    final decoded = Gs1ScanParser.decode(code);

    // Decode GS1/IMEI locally before any internet request. This keeps repeat
    // scans instant and offline-first even when the scanner supplies a GS1
    // DataMatrix/QR element string instead of the plain retail GTIN.
    if (decoded.gtin.isNotEmpty) {
      final decodedMatch = options.where((candidate) {
        return candidate.barcode.trim().toLowerCase() == decoded.gtin.toLowerCase();
      }).toList();
      if (decodedMatch.isNotEmpty) {
        final matched = decodedMatch.first;
        _selectProduct(matched);
        final tracking = _trackingFor(matched);
        if (decoded.batchNo.isNotEmpty && tracking['batch'] == true) batch.text = decoded.batchNo;
        if ((decoded.productionDate != null || decoded.packagingDate != null) &&
            (tracking['batch'] == true || tracking['production'] == true)) {
          manufactureDate = decoded.productionDate ?? decoded.packagingDate;
        }
        if ((decoded.expiryDate != null || decoded.bestBeforeDate != null) && tracking['expiry'] == true) {
          expiryDate = decoded.expiryDate ?? decoded.bestBeforeDate;
        }
        if (decoded.serialNumber.isNotEmpty && tracking['serial'] == true) {
          serialReference.text = decoded.serialNumber;
        }
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${matched.name} identified locally from ${decoded.codeType}. Encoded batch/date/serial data was applied where this product tracks it.')),
        );
        return;
      }
    }
    final serialMatches = options.where((candidate) {
      return candidate.serialNumbers.any((serial) => serial.trim().toLowerCase() == normalized);
    }).toList();
    if (serialMatches.isNotEmpty) {
      _selectProduct(serialMatches.first);
      serialReference.text = code.trim();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${serialMatches.first.name} identified by serial / IMEI. Existing product selected.')),
      );
      return;
    }

    final matches = options.where((candidate) {
      return candidate.barcode.trim().toLowerCase() == normalized ||
          candidate.productCode.trim().toLowerCase() == normalized;
    }).toList();

    if (matches.isNotEmpty) {
      _selectProduct(matches.first);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${matches.first.name} found. This purchase will update the existing inventory item — no duplicate will be created.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final external = await ProductLookupService.instance.lookup(code);
    if (!mounted) return;

    if (external?.codeType == 'IMEI' && external!.serialNumber.isNotEmpty) {
      serialReference.text = external.serialNumber;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IMEI captured. Now select the matching phone/device product, or scan its retail GTIN/barcode to identify the model.')),
      );
      return;
    }

    final resolvedCode = external?.barcode.trim() ?? '';
    if (resolvedCode.isNotEmpty) {
      final resolvedMatch = options.where((candidate) {
        return candidate.barcode.trim().toLowerCase() ==
            resolvedCode.toLowerCase();
      }).toList();
      if (resolvedMatch.isNotEmpty) {
        _selectProduct(resolvedMatch.first);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${resolvedMatch.first.name} found from the scanned QR/link. Existing inventory selected — no duplicate will be created.',
            ),
          ),
        );
        return;
      }
    }

    final numericInput = RegExp(r'^\d{8,14}$').hasMatch(code.trim());
    await _createProductInsidePurchase(
      initialBarcode: resolvedCode.isNotEmpty
          ? resolvedCode
          : numericInput
              ? code.trim()
              : '',
      external: external,
      scannedValue: code.trim(),
    );
  }

  Future<void> _createProductInsidePurchase({
    String initialBarcode = '',
    ExternalProductInfo? external,
    String scannedValue = '',
  }) async {
    final app = AppScope.of(context);
    final business = app.data!.business;
    final businessType = BusinessTypeRules.canonicalType(business.businessType);
    var catalogProduct = external;
    final name = TextEditingController(text: catalogProduct?.name ?? '');
    final barcode = TextEditingController(text: initialBarcode);
    final sku = TextEditingController();
    final sellingPriceCtl = TextEditingController(text: '0');
    final attributeControllers = <String, TextEditingController>{};

    TextEditingController attributeController(String key) {
      return attributeControllers.putIfAbsent(key, () => TextEditingController());
    }

    final categories = <String>{
      ...BusinessTypeRules.categoriesFor(
        businessType,
        enabledRetailModules: business.enabledRetailModules,
      ),
      ...app.data!.products.map((e) => e.category).where((e) => e.trim().isNotEmpty),
    }.toList();

    var category = BusinessTypeRules.suggestCategory(
      businessType,
      '${catalogProduct?.name ?? ''} ${catalogProduct?.category ?? ''}',
      enabledRetailModules: business.enabledRetailModules,
    );
    if (!categories.contains(category)) {
      category = categories.contains('General') ? 'General' : categories.first;
    }
    var subcategories = BusinessTypeRules.subcategoriesFor(businessType, category);
    var subcategory = subcategories.isEmpty ? 'General' : subcategories.first;
    var tracking = BusinessTypeRules.trackingDefaults(businessType, category, subcategory);
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

    void prefillCatalogFields(ExternalProductInfo? info) {
      if (info == null) return;
      if (info.brand.isNotEmpty && attributeController('brand').text.trim().isEmpty) {
        attributeController('brand').text = info.brand;
      }
      if (info.manufacturer.isNotEmpty && attributeController('manufacturer').text.trim().isEmpty) {
        attributeController('manufacturer').text = info.manufacturer;
      }
      if (info.packageSize.isNotEmpty && attributeController('packageSize').text.trim().isEmpty) {
        attributeController('packageSize').text = info.packageSize;
      }
      if (info.mrp > 0 &&
          (sellingPriceCtl.text.trim().isEmpty ||
              (double.tryParse(sellingPriceCtl.text.trim()) ?? 0) <= 0)) {
        sellingPriceCtl.text = info.mrp.toStringAsFixed(2);
      }
      if (info.variant.isNotEmpty) {
        for (final key in const ['variant', 'styleVariant', 'flavourVariant', 'shadeVariant', 'specification']) {
          if (attributeController(key).text.trim().isEmpty) {
            attributeController(key).text = info.variant;
            break;
          }
        }
      }
      if (info.additionalProductId.isNotEmpty) {
        for (final key in const ['partNumber', 'catalogNumber', 'modelNumber']) {
          if (attributeController(key).text.trim().isEmpty) {
            attributeController(key).text = info.additionalProductId;
            break;
          }
        }
      }
      if (info.customerPartNumber.isNotEmpty && attributeController('oemReference').text.trim().isEmpty) {
        attributeController('oemReference').text = info.customerPartNumber;
      }
    }

    prefillCatalogFields(catalogProduct);

    String barcodeStatus = '';

    void refreshRule(StateSetter update, {String? nextCategory, String? nextSubcategory}) {
      update(() {
        if (nextCategory != null) category = nextCategory;
        subcategories = BusinessTypeRules.subcategoriesFor(businessType, category);
        if (nextSubcategory != null && subcategories.contains(nextSubcategory)) {
          subcategory = nextSubcategory;
        } else if (!subcategories.contains(subcategory)) {
          subcategory = subcategories.isEmpty ? 'General' : subcategories.first;
        }
        tracking = BusinessTypeRules.trackingDefaults(businessType, category, subcategory);
        units = BusinessTypeRules.unitsFor(
          businessType,
          category: category,
          subcategory: subcategory,
        );
        final suggestedUnit = BusinessTypeRules.defaultUnitFor(
          businessType,
          category: category,
          subcategory: subcategory,
        );
        if (!units.contains(unit)) unit = suggestedUnit;
      });
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final profileFields = BusinessTypeRules.fieldsFor(
            businessType,
            category: category,
            subcategory: subcategory,
          );
          final rule = BusinessTypeRules.ruleFor(businessType, category, subcategory);
          final requiredTracking = rule.requiredTracking;
          final allUnits = <String>{
            ...units,
            unit,
            'pcs', 'kg', 'g', 'L', 'ml', 'pack', 'box', 'carton', 'bag', 'bottle',
            'tray', 'bundle', 'pair', 'set', 'm', 'ft', 'roll', 'case', 'crate',
            'bunch', 'kit', 'mg', 'slice', 'portion',
          }.toList();

          return AlertDialog(
            title: Text('New product • $businessType'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add the product once. ProfitGPS will remember this barcode locally for instant future purchase and billing scans. Category and subcategory automatically control the fields and inventory rules.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Product name *'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: barcode,
                            decoration: InputDecoration(
                              labelText: 'Barcode / GTIN / QR',
                              suffixIcon: IconButton(
                                tooltip: 'Scan barcode',
                                onPressed: () async {
                                  final scanned = await _waitForBarcode(
                                    title: 'Scan product',
                                    subtitle: 'Scan the product barcode or QR code.',
                                  );
                                  if (scanned == null) return;
                                  final decodedScan = Gs1ScanParser.decode(scanned);
                                  final result = await ProductLookupService.instance.lookup(scanned);
                                  if (!ctx.mounted) return;
                                  catalogProduct = result;

                                  final capturedCode = (result?.barcode.trim().isNotEmpty ?? false)
                                      ? result!.barcode.trim()
                                      : decodedScan.gtin.trim().isNotEmpty
                                          ? decodedScan.gtin.trim()
                                          : scanned.trim();
                                  if (capturedCode.isNotEmpty &&
                                      !capturedCode.toLowerCase().startsWith('http://') &&
                                      !capturedCode.toLowerCase().startsWith('https://')) {
                                    barcode.text = capturedCode;
                                  }

                                  if (result != null) {
                                    if (result.name.isNotEmpty && name.text.trim().isEmpty) name.text = result.name;
                                    prefillCatalogFields(result);
                                    final suggested = BusinessTypeRules.suggestCategory(
                                      businessType,
                                      '${result.name} ${result.category} ${result.brand}',
                                      enabledRetailModules: business.enabledRetailModules,
                                    );
                                    if (categories.contains(suggested) &&
                                        (result.name.isNotEmpty || result.category.isNotEmpty || result.brand.isNotEmpty)) {
                                      category = suggested;
                                      subcategories = BusinessTypeRules.subcategoriesFor(businessType, category);
                                      subcategory = subcategories.isEmpty ? 'General' : subcategories.first;
                                      tracking = BusinessTypeRules.trackingDefaults(businessType, category, subcategory);
                                      units = BusinessTypeRules.unitsFor(businessType, category: category, subcategory: subcategory);
                                      unit = BusinessTypeRules.defaultUnitFor(businessType, category: category, subcategory: subcategory);
                                    }
                                    if (result.serialNumber.isNotEmpty && tracking['serial'] == true) {
                                      serialReference.text = result.serialNumber;
                                    }
                                    if (result.batchNo.isNotEmpty) batch.text = result.batchNo;
                                    if (result.productionDate != null || result.packagingDate != null) {
                                      manufactureDate = result.productionDate ?? result.packagingDate;
                                    }
                                    expiryDate = result.expiryDate ?? result.bestBeforeDate ?? expiryDate;
                                    update(() {
                                      barcodeStatus = result.name.trim().isNotEmpty
                                          ? 'Verified product details found.'
                                          : (result.decodedFields.length > 1 ||
                                                  result.batchNo.isNotEmpty ||
                                                  result.serialNumber.isNotEmpty ||
                                                  result.expiryDate != null
                                              ? 'Barcode details captured.'
                                              : '');
                                    });
                                  } else {
                                    update(() => barcodeStatus = ProductLookupService.instance.lastMessage);
                                  }
                                },
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: sku,
                            decoration: const InputDecoration(labelText: 'Internal SKU / code'),
                          ),
                        ),
                      ],
                    ),
                    if (barcodeStatus.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        barcodeStatus,
                        style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                    if (catalogProduct != null && catalogProduct!.decodedFields.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101A17),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.green.withValues(alpha: .45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Encoded barcode data', style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: catalogProduct!.decodedFields.entries
                                  .map((e) => StatusPill(text: '${e.key}: ${e.value}', color: AppTheme.green))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: category,
                            isExpanded: true,
                            items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              refreshRule(update, nextCategory: v);
                            },
                            decoration: const InputDecoration(labelText: 'Category *'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: subcategories.contains(subcategory) ? subcategory : null,
                            isExpanded: true,
                            items: subcategories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              refreshRule(update, nextSubcategory: v);
                            },
                            decoration: const InputDecoration(labelText: 'Subcategory'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: allUnits.contains(unit) ? unit : allUnits.first,
                            isExpanded: true,
                            items: allUnits.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => update(() => unit = v ?? unit),
                            decoration: const InputDecoration(labelText: 'Selling unit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: sellingPriceCtl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Default selling price ₹'),
                    ),
                    if (profileFields.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101720),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$category${subcategory == 'General' ? '' : ' • $subcategory'} fields', style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(rule.note.isEmpty ? 'Only fields relevant to this category are shown.' : rule.note, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: profileFields.map((field) {
                                final ctl = attributeController(field.key);
                                if (field.key == 'brand' && ctl.text.isEmpty && catalogProduct?.brand.isNotEmpty == true) ctl.text = catalogProduct!.brand;
                                if (field.key == 'manufacturer' && ctl.text.isEmpty && catalogProduct?.manufacturer.isNotEmpty == true) ctl.text = catalogProduct!.manufacturer;
                                if (field.key == 'packageSize' && ctl.text.isEmpty && catalogProduct?.packageSize.isNotEmpty == true) ctl.text = catalogProduct!.packageSize;
                                return SizedBox(
                                  width: 350,
                                  child: TextField(
                                    controller: ctl,
                                    decoration: InputDecoration(
                                      labelText: '${field.label}${field.required ? ' *' : ''}',
                                      hintText: field.hint.isEmpty ? null : field.hint,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111820),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Inventory tracking for this product', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          const Text('Defaults come from category logic. You can override optional tracking for unusual products.', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: const {
                              'batch': 'Batch / lot',
                              'expiry': 'Expiry',
                              'serial': 'Serial / IMEI',
                              'variant': 'Size / colour / variant',
                              'weight': 'Weight',
                              'wastage': 'Wastage',
                              'production': 'Production date',
                              'unitConversion': 'Unit conversion',
                            }.entries.map((entry) {
                              final required = requiredTracking.contains(entry.key);
                              return FilterChip(
                                label: Text('${entry.value}${required ? ' • required' : ''}'),
                                selected: tracking[entry.key] == true,
                                onSelected: required
                                    ? null
                                    : (value) => update(() => tracking[entry.key] = value),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 7),
                          Text(BusinessTypeRules.trackingSummary(tracking), style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    if (catalogProduct != null &&
                        (catalogProduct!.brand.isNotEmpty ||
                            catalogProduct!.manufacturer.isNotEmpty ||
                            catalogProduct!.packageSize.isNotEmpty ||
                            catalogProduct!.mrp > 0)) ...[
                      const SizedBox(height: 10),
                      Text(
                        [
                          if (catalogProduct!.brand.isNotEmpty) 'Brand: ${catalogProduct!.brand}',
                          if (catalogProduct!.manufacturer.isNotEmpty) 'Manufacturer: ${catalogProduct!.manufacturer}',
                          if (catalogProduct!.packageSize.isNotEmpty) 'Pack: ${catalogProduct!.packageSize}',
                          if (catalogProduct!.mrp > 0) 'MRP: ₹${catalogProduct!.mrp.toStringAsFixed(2)}',
                          'Verified product data',
                        ].join(' • '),
                        style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) {
                    update(() => barcodeStatus = 'Product name is required.');
                    return;
                  }
                  for (final field in profileFields) {
                    if (field.required && attributeController(field.key).text.trim().isEmpty) {
                      update(() => barcodeStatus = '${field.label} is required for $category / $subcategory.');
                      return;
                    }
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Use in purchase'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    final code = sku.text.trim();
    final gtin = barcode.text.trim();
    final existing = app.data!.products.where((candidate) {
      final sameBarcode = gtin.isNotEmpty && candidate.barcode.trim().toLowerCase() == gtin.toLowerCase();
      final sameCode = code.isNotEmpty && candidate.productCode.trim().toLowerCase() == code.toLowerCase();
      return sameBarcode || sameCode;
    }).firstOrNull;

    if (existing != null) {
      if (!mounted) return;
      _selectProduct(existing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${existing.name} already exists. Existing inventory will be updated instead of creating a duplicate.')),
      );
      return;
    }

    final profileFields = BusinessTypeRules.fieldsFor(
      businessType,
      category: category,
      subcategory: subcategory,
    );
    final newProduct = Product(
      id: const Uuid().v4(),
      name: name.text.trim(),
      barcode: gtin,
      productCode: code,
      businessType: businessType,
      category: category,
      subcategory: subcategory,
      purchasePrice: 0,
      sellingPrice: double.tryParse(sellingPriceCtl.text.trim()) ?? 0,
      gstRate: 0,
      gstApplicable: false,
      taxCategory: 'Unclassified',
      taxInclusive: business.defaultSaleTaxInclusive,
      stock: 0,
      reorderLevel: 0,
      unit: unit,
      weighted: BusinessTypeRules.shouldDefaultWeighted(
        businessType,
        unit,
        category: category,
        subcategory: subcategory,
      ),
      trackingFlags: Map<String, bool>.from(tracking),
      supplierId: supplier?.id ?? '',
      supplier: supplier?.name ?? '',
      brand: (attributeControllers['brand']?.text.trim().isNotEmpty ?? false)
          ? attributeControllers['brand']!.text.trim()
          : (catalogProduct?.brand ?? ''),
      manufacturer: (attributeControllers['manufacturer']?.text.trim().isNotEmpty ?? false)
          ? attributeControllers['manufacturer']!.text.trim()
          : (catalogProduct?.manufacturer ?? ''),
      packageSize: (attributeControllers['packageSize']?.text.trim().isNotEmpty ?? false)
          ? attributeControllers['packageSize']!.text.trim()
          : (catalogProduct?.packageSize ?? ''),
      imageUrl: catalogProduct?.imageUrl ?? '',
      mrp: catalogProduct?.mrp ?? 0,
      hsnSac: catalogProduct?.hsnSac ?? '',
      customAttributes: {
        for (final field in profileFields)
          if (!const {'brand', 'manufacturer', 'packageSize'}.contains(field.key) &&
              (attributeControllers[field.key]?.text.trim().isNotEmpty ?? false))
            field.key: attributeControllers[field.key]!.text.trim(),
      },
    );

    pendingProducts[newProduct.id] = newProduct;
    if (!mounted) return;
    _selectProduct(newProduct);
    if (catalogProduct != null) {
      if (catalogProduct!.batchNo.isNotEmpty) batch.text = catalogProduct!.batchNo;
      if (catalogProduct!.serialNumber.isNotEmpty && tracking['serial'] == true) {
        serialReference.text = catalogProduct!.serialNumber;
      }
      if (catalogProduct!.productionDate != null || catalogProduct!.packagingDate != null) {
        manufactureDate = catalogProduct!.productionDate ?? catalogProduct!.packagingDate;
      }
      expiryDate = catalogProduct!.expiryDate ?? catalogProduct!.bestBeforeDate ?? expiryDate;
    }
  }

  Map<String, bool> _trackingFor(Product p) {
    final currentBusinessType = AppScope.of(context).data!.business.businessType;
    final type = p.businessType.trim().isEmpty ? currentBusinessType : p.businessType;
    return BusinessTypeRules.resolvedTracking(
      type,
      p.category,
      p.subcategory,
      p.trackingFlags,
    );
  }

  Set<String> _requiredTrackingFor(Product p) {
    final currentBusinessType = AppScope.of(context).data!.business.businessType;
    final type = p.businessType.trim().isEmpty ? currentBusinessType : p.businessType;
    return BusinessTypeRules.requiredTracking(type, p.category, p.subcategory);
  }

  List<String> _serialList(String raw) => raw
      .split(RegExp(r'[,;\n]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  void _addLine() {
    final line = previewLine;
    if (taxCategory == 'Unclassified') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Taxable / Exempt / Nil-rated / Non-GST for this product before adding it.')),
      );
      return;
    }
    if (line == null || line.quantity <= 0 || line.purchasePricePerUnit < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product and enter purchase quantity/price.')),
      );
      return;
    }
    final selectedProduct = product!;
    final tracking = _trackingFor(selectedProduct);
    final requiredTracking = _requiredTrackingFor(selectedProduct);
    if (tracking['batch'] == true && requiredTracking.contains('batch') && batch.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch / lot number is required for this product category.')),
      );
      return;
    }
    if (tracking['expiry'] == true && requiredTracking.contains('expiry') && expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiry date is required for this product category.')),
      );
      return;
    }
    if (tracking['serial'] == true && serialReference.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(requiredTracking.contains('serial')
            ? 'Serial / IMEI is required for this product category.'
            : 'Serial / IMEI tracking is enabled for this product. Enter the unit serial(s), or disable serial tracking in the product rule.')),
      );
      return;
    }
    if (tracking['serial'] == true && serialReference.text.trim().isNotEmpty) {
      final serials = _serialList(serialReference.text);
      final expected = line.stockReceived.round();
      if (expected >= 1 && serials.length != expected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter one serial / IMEI per received unit. Expected $expected, found ${serials.length}. Separate values with comma or new line.')),
        );
        return;
      }
    }
    setState(() {
      lines.add(line);
      product = null;
      taxCategory = 'Unclassified';
      qty.text = '1';
      freeQty.text = '0';
      batch.clear();
      serialReference.clear();
      manufactureDate = null;
      expiryDate = null;
      note.clear();
    });
  }

  Future<void> _savePurchase() async {
    final app = AppScope.of(context);
    final isSupplier = sourceMode == _StockInMode.supplier;
    final isLocal = sourceMode == _StockInMode.local;

    if (isSupplier && supplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a supplier.')),
      );
      return;
    }
    if (isSupplier && invoiceNo.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter supplier invoice number.')),
      );
      return;
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one stock item.')),
      );
      return;
    }

    if (isSupplier) {
      final invoiceKey = invoiceNo.text.trim().toLowerCase();
      final duplicateInvoice = app.data!.purchases.where(
        (purchase) =>
            purchase.sourceType == 'SUPPLIER' &&
            purchase.supplierId == supplier!.id &&
            purchase.invoiceNumber.trim().toLowerCase() == invoiceKey,
      ).firstOrNull;
      if (duplicateInvoice != null) {
        final saveAnyway = await confirmAction(
          context,
          title: 'Duplicate supplier invoice number',
          message:
              'Invoice ${invoiceNo.text.trim()} is already recorded for ${supplier!.name} as ${duplicateInvoice.number}.\n\nSave another purchase with the same supplier invoice number?',
          confirmLabel: 'Save anyway',
          icon: Icons.warning_amber_rounded,
          confirmColor: AppTheme.amber,
        );
        if (!saveAnyway) return;
      }
    }

    final freight = _d(invoiceFreight);
    final base = lines.fold<double>(0, (a, b) => a + b.taxableBase);
    final allocated = <PurchaseLine>[];
    for (final l in lines) {
      final share = base <= 0
          ? freight / lines.length
          : freight * (l.taxableBase / base);
      allocated.add(
        PurchaseLine(
          productId: l.productId,
          productName: l.productName,
          purchaseUnit: l.purchaseUnit,
          sellingUnit: l.sellingUnit,
          quantity: l.quantity,
          freeQuantity: l.freeQuantity,
          conversionQty: l.conversionQty,
          purchasePricePerUnit: l.purchasePricePerUnit,
          supplierDiscountPercent: l.supplierDiscountPercent,
          freightCost: l.freightCost + share,
          gstApplicable: l.gstApplicable,
          gstRate: l.gstRate,
          taxCategory: l.taxCategory,
          saleGstRate: l.saleGstRate,
          saleTaxInclusive: l.saleTaxInclusive,
          hsnSac: l.hsnSac,
          itcEligible: l.itcEligible,
          purchasePriceIncludesTax: l.purchasePriceIncludesTax,
          batchNo: l.batchNo,
          serialNumbers: l.serialNumbers,
          manufactureDate: l.manufactureDate,
          expiryDate: l.expiryDate,
          mrp: l.mrp,
          sellingPrice: l.sellingPrice,
          defaultDiscountPercent: l.defaultDiscountPercent,
          reorderLevel: l.reorderLevel,
          rackLocation: l.rackLocation,
          note: l.note,
        ),
      );
    }

    final invoiceGrand =
        allocated.fold<double>(0, (a, b) => a + b.supplierInvoiceLineTotal);
    final availableAdvance = isSupplier ? supplier!.supplierCreditBalance : 0.0;
    final advanceUsed = isSupplier && useSupplierAdvance
        ? availableAdvance.clamp(0.0, invoiceGrand).toDouble()
        : 0.0;
    final remainingAfterAdvance =
        (invoiceGrand - advanceUsed).clamp(0.0, double.infinity).toDouble();
    final paidNow = !isSupplier
        ? invoiceGrand
        : paymentTiming == 'Credit / pay later'
            ? 0.0
            : paymentTiming == 'Pay full now'
                ? remainingAfterAdvance
                : _d(paid).clamp(0.0, double.infinity).toDouble();
    final pending = isSupplier
        ? (invoiceGrand - advanceUsed - paidNow)
            .clamp(0.0, double.infinity)
            .toDouble()
        : 0.0;
    final extra = isSupplier
        ? (paidNow - (invoiceGrand - advanceUsed))
            .clamp(0.0, double.infinity)
            .toDouble()
        : 0.0;

    final sourceLabel = switch (sourceMode) {
      _StockInMode.supplier => supplier!.name,
      _StockInMode.local => sourceName.text.trim().isEmpty
          ? 'Local / Cash Purchase'
          : sourceName.text.trim(),
      _StockInMode.production => sourceName.text.trim().isEmpty
          ? 'Own Production'
          : sourceName.text.trim(),
    };

    final confirmationMessage = isSupplier
        ? 'Supplier: ${supplier!.name}\n'
            'Invoice: ${invoiceNo.text.trim()}\n'
            'Purchase total: ${money(invoiceGrand)}\n'
            'Supplier advance used: ${money(advanceUsed)}\n'
            'Paid now: ${money(paidNow)}\n'
            'Amount payable after this purchase: ${money(pending)}\n'
            '${extra > 0 ? 'New supplier advance: ${money(extra)}\n' : ''}'
            'Saving will update stock, cost/GST history and the supplier ledger.'
        : isLocal
            ? 'Source: $sourceLabel\n'
                'Stock-in cost: ${money(invoiceGrand)}\n'
                'Payment: $paymentMode\n'
                'No supplier ledger or ITC will be created in Local / Cash Purchase mode.'
            : 'Production source: $sourceLabel\n'
                'Finished-stock cost: ${money(invoiceGrand)}\n'
                'Saving will increase finished stock at the calculated effective cost.\n'
                'This mode does not consume raw-material/BOM stock automatically.';

    final confirmed = await confirmAction(
      context,
      title: isSupplier
          ? 'Confirm supplier purchase'
          : isLocal
              ? 'Confirm local purchase'
              : 'Confirm own production',
      message: confirmationMessage,
      confirmLabel: 'Confirm & save',
      icon: isSupplier
          ? Icons.shopping_cart_checkout_rounded
          : isLocal
              ? Icons.shopping_basket_outlined
              : Icons.precision_manufacturing_outlined,
    );
    if (!confirmed) return;

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final effectiveInvoice = invoiceNo.text.trim().isNotEmpty
        ? invoiceNo.text.trim()
        : isLocal
            ? 'LOCAL-$stamp'
            : 'PROD-$stamp';

    final draft = PurchaseRecord(
      id: const Uuid().v4(),
      number: app.nextPurchaseNumber(),
      createdAt: DateTime.now(),
      sourceType: isSupplier
          ? 'SUPPLIER'
          : isLocal
              ? 'LOCAL'
              : 'PRODUCTION',
      sourceName: sourceLabel,
      supplierId: isSupplier ? supplier!.id : '',
      supplierCode: isSupplier ? supplier!.code : '',
      supplierName: sourceLabel,
      invoiceNumber: effectiveInvoice,
      invoiceDate: invoiceDate,
      purchaseOrderNumber: isSupplier ? poNo.text.trim() : '',
      paymentTerms: isSupplier
          ? paymentTiming == 'Credit / pay later'
              ? 'Credit'
              : paymentTiming == 'Partial payment'
                  ? 'Partial'
                  : 'Paid'
          : isLocal
              ? 'Paid'
              : 'Internal',
      lines: allocated,
      paymentMode: isSupplier
          ? paymentTiming == 'Credit / pay later'
              ? 'Credit'
              : paymentMode
          : isLocal
              ? paymentMode
              : 'Own Production',
      amountPaid: paidNow,
      supplierAdvanceUsed: advanceUsed,
      referenceNumber: reference.text.trim(),
      status: isSupplier
          ? 'Received'
          : isLocal
              ? 'Local purchase received'
              : 'Produced',
      note: isSupplier
          ? ''
          : isLocal
              ? 'Local / cash purchase'
              : 'Own production stock-in',
    );

    for (final pendingProduct in pendingProducts.values.toList()) {
      final usedByPurchase =
          draft.lines.any((line) => line.productId == pendingProduct.id);
      if (!usedByPurchase) continue;

      final existing = app.data!.products.where((candidate) {
        final sameBarcode = pendingProduct.barcode.isNotEmpty &&
            candidate.barcode.trim().toLowerCase() ==
                pendingProduct.barcode.trim().toLowerCase();
        final sameCode = pendingProduct.productCode.isNotEmpty &&
            candidate.productCode.trim().toLowerCase() ==
                pendingProduct.productCode.trim().toLowerCase();
        return sameBarcode || sameCode;
      }).firstOrNull;

      if (existing != null) {
        for (final line
            in draft.lines.where((line) => line.productId == pendingProduct.id)) {
          line.productId = existing.id;
          line.productName = existing.name;
        }
      } else {
        app.data!.products.add(pendingProduct);
      }
    }

    await app.addPurchase(draft);
    if (!mounted) return;
    setState(() {
      lines.clear();
      invoiceNo.clear();
      sourceName.clear();
      poNo.text = app.nextPurchaseOrderNumber();
      pendingProducts.clear();
      product = null;
      hsn.clear();
      paid.text = '0';
      reference.clear();
      invoiceFreight.text = '0';
    });
    final syncedProducts = draft.lines
        .map((line) => line.productId)
        .where((id) => app.data!.products.any((p) => p.id == id))
        .toSet()
        .length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sourceMode == _StockInMode.production
              ? '${draft.number} saved • $syncedProducts product(s) synced to Products & Billing.'
              : '${draft.number} saved • stock updated • $syncedProducts product(s) available in Products & Billing.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = previewLine;
    final activeTracking = product == null ? <String, bool>{} : _trackingFor(product!);
    final sameState = supplier == null || supplier!.state.trim().toLowerCase() == app.data!.business.state.trim().toLowerCase();
    final halfTax = (p?.gstRate ?? 0) / 2;
    final subtotal = lines.fold<double>(0, (a, b) => a + b.taxableBase);
    final gst = lines.fold<double>(0, (a, b) => a + b.inputGst);
    final discounts = lines.fold<double>(0, (a, b) => a + b.supplierDiscountValue);
    final lineFreightTotal = lines.fold<double>(0, (a, b) => a + b.freightCost);
    final invoiceFreightValue = _d(invoiceFreight);
    final grand = lines.fold<double>(0, (a, b) => a + b.supplierInvoiceLineTotal) + invoiceFreightValue;
    final supplierAdvanceAvailable = supplier?.supplierCreditBalance ?? 0;
    final advanceToUse = useSupplierAdvance ? supplierAdvanceAvailable.clamp(0.0, grand).toDouble() : 0.0;
    final remainingAfterAdvance =
        (grand - advanceToUse).clamp(0.0, double.infinity).toDouble();
    final paidNowValue = paymentTiming == 'Credit / pay later'
        ? 0.0
        : paymentTiming == 'Pay full now'
            ? remainingAfterAdvance
            : _d(paid).clamp(0.0, double.infinity).toDouble();
    final due =
        (grand - advanceToUse - paidNowValue).clamp(0.0, double.infinity).toDouble();
    final newSupplierAdvance = (paidNowValue - (grand - advanceToUse)).clamp(0.0, double.infinity).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      children: [
        SectionTitle(
          'Stock In / Purchase',
          subtitle: sourceMode == _StockInMode.supplier
              ? 'Registered/known supplier purchase • GST, ITC, stock and payable flow.'
              : sourceMode == _StockInMode.local
                  ? 'Market / cash purchase • supplier master not required.'
                  : 'Own production • add finished stock at its actual production cost.',
          trailing: OutlinedButton.icon(
            onPressed: lines.isEmpty && pendingProducts.isEmpty
                ? null
                : () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Clear purchase items?',
                      message:
                          'Remove all purchase items and pending new products from this unsaved purchase?',
                      confirmLabel: 'Clear items',
                      icon: Icons.clear_all_rounded,
                      confirmColor: AppTheme.red,
                    );
                    if (!ok || !mounted) return;
                    setState(() {
                      lines.clear();
                      pendingProducts.clear();
                      product = null;
                      hsn.clear();
                    });
                  },
            icon: const Icon(Icons.clear_all_rounded),
            label: const Text('Clear purchase items'),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final supplierCard = _sourceModeCard(
              mode: _StockInMode.supplier,
              title: 'Supplier Purchase',
              subtitle: 'Registered / known supplier • GST / payable',
              icon: Icons.local_shipping_outlined,
            );
            final localCard = _sourceModeCard(
              mode: _StockInMode.local,
              title: 'Local / Cash Purchase',
              subtitle: 'Market / cash buy • no supplier required',
              icon: Icons.shopping_basket_outlined,
            );
            final productionCard = _sourceModeCard(
              mode: _StockInMode.production,
              title: 'Own Production',
              subtitle: 'Your own finished goods / prepared items',
              icon: Icons.precision_manufacturing_outlined,
            );
            if (c.maxWidth >= 900) {
              return Row(
                children: [
                  Expanded(child: supplierCard),
                  const SizedBox(width: 8),
                  Expanded(child: localCard),
                  const SizedBox(width: 8),
                  Expanded(child: productionCard),
                ],
              );
            }
            return Column(
              children: [
                supplierCard,
                const SizedBox(height: 8),
                localCard,
                const SizedBox(height: 8),
                productionCard,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 1120;
            final sourceBox = sourceMode == _StockInMode.supplier
                ? _panel(
                    'Supplier & invoice details',
                    Icons.local_shipping_outlined,
                    Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _createAndSelectSupplier,
                            icon: const Icon(Icons.add_business_rounded),
                            label: const Text('New supplier'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Autocomplete<Supplier>(
                          displayStringForOption: (s) => '${s.code} • ${s.name}',
                          optionsBuilder: (v) {
                            final q = v.text.trim().toLowerCase();
                            return app.data!.suppliers
                                .where(
                                  (s) =>
                                      q.isEmpty ||
                                      s.code.toLowerCase().contains(q) ||
                                      s.name.toLowerCase().contains(q) ||
                                      s.mobile.contains(q),
                                )
                                .take(5);
                          },
                          onSelected: (s) => setState(() {
                            supplier = s;
                            final defaultCredit =
                                s.paymentTerms.toLowerCase().contains('credit');
                            paymentTiming = defaultCredit
                                ? 'Credit / pay later'
                                : 'Pay full now';
                            paymentMode =
                                defaultCredit ? 'Bank Transfer' : 'Cash';
                            paid.text = '0';
                            useSupplierAdvance = true;
                          }),
                          fieldViewBuilder:
                              (context, ctl, focus, submit) => TextField(
                            controller: ctl,
                            focusNode: focus,
                            decoration: InputDecoration(
                              labelText: 'Supplier code / name *',
                              hintText: supplier == null
                                  ? 'SUP001 or start typing supplier name'
                                  : '${supplier!.code} • ${supplier!.name}',
                              prefixIcon: const Icon(Icons.search),
                            ),
                          ),
                        ),
                        if (supplier != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111720),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    supplier!.name.isEmpty
                                        ? 'S'
                                        : supplier!.name[0].toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${supplier!.code} • ${supplier!.name}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        '${supplier!.mobile}${supplier!.gstin.isEmpty ? '' : ' • GSTIN ${supplier!.gstin}'}',
                                        style: const TextStyle(
                                          color: AppTheme.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        '${supplier!.city}${supplier!.state.isEmpty ? '' : ', ${supplier!.state}'}',
                                        style: const TextStyle(
                                          color: AppTheme.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        'Amount payable to supplier: ${money(supplier!.openingPayable)}',
                                        style: const TextStyle(
                                          color: AppTheme.amber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Advance already paid to supplier: ${money(supplier!.supplierCreditBalance)}',
                                        style: const TextStyle(
                                          color: AppTheme.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(
                              width: 220,
                              child: TextField(
                                controller: invoiceNo,
                                decoration: const InputDecoration(
                                  labelText: 'Supplier invoice no. *',
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 200,
                              child: _dateField(
                                'Invoice date *',
                                invoiceDate,
                                (d) => setState(() => invoiceDate = d),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: TextField(
                                controller: poNo,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'ProfitGPS PO number',
                                  helperText: 'Generated automatically',
                                  prefixIcon: Icon(Icons.tag_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : sourceMode == _StockInMode.local
                    ? _panel(
                        'Local / cash purchase details',
                        Icons.shopping_basket_outlined,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: TextField(
                                    controller: sourceName,
                                    decoration: const InputDecoration(
                                      labelText: 'Market / vendor name (optional)',
                                      hintText: 'Example: Hosur Vegetable Market',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: TextField(
                                    controller: invoiceNo,
                                    decoration: const InputDecoration(
                                      labelText: 'Bill / receipt no. (optional)',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 200,
                                  child: _dateField(
                                    'Purchase date',
                                    invoiceDate,
                                    (d) => setState(() => invoiceDate = d),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use this when stock is bought directly from a market/local vendor and there is no supplier account to maintain.',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _panel(
                        'Own production details',
                        Icons.precision_manufacturing_outlined,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: TextField(
                                    controller: sourceName,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Production source / kitchen / unit (optional)',
                                      hintText: 'Example: In-house Kitchen',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 220,
                                  child: TextField(
                                    controller: invoiceNo,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Production reference (optional)',
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 200,
                                  child: _dateField(
                                    'Production date',
                                    invoiceDate,
                                    (d) => setState(() => invoiceDate = d),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use this for finished goods you make/prepare yourself. Enter the actual finished-unit production cost below.',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );

            final infoBox = sourceMode == _StockInMode.supplier
                ? _panel(
                    'GST Purchase Tax Treatment',
                    Icons.account_balance_outlined,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _logicRow(
                          'Our business',
                          app.data!.business.businessName,
                          app.data!.business.gstin.isEmpty
                              ? 'GSTIN not set'
                              : app.data!.business.gstin,
                        ),
                        const SizedBox(height: 8),
                        _logicRow(
                          'Supplier',
                          supplier?.name ?? 'Select supplier',
                          (supplier?.gstin.isEmpty ?? true)
                              ? 'GSTIN not available'
                              : supplier!.gstin,
                        ),
                        const Divider(),
                        Text(
                          supplier == null
                              ? 'Select supplier to determine intra-state/inter-state tax split.'
                              : sameState
                                  ? 'Same state purchase → CGST + SGST when GST applies.'
                                  : 'Inter-state purchase → IGST when GST applies.',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'GST/HSN and ITC must be verified against the supplier invoice and current official rules.',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                : sourceMode == _StockInMode.local
                    ? _panel(
                        'Local purchase treatment',
                        Icons.receipt_long_outlined,
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• Supplier Master is not required.\n'
                              '• No supplier payable/advance ledger is created.\n'
                              '• No purchase GST / ITC is claimed in this mode.\n'
                              '• If you have a valid GST tax invoice and want ITC, use Supplier Purchase instead.',
                              style: TextStyle(
                                color: AppTheme.muted,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _panel(
                        'Own production treatment',
                        Icons.factory_outlined,
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• No supplier is required.\n'
                              '• No purchase GST / ITC is created.\n'
                              '• Finished stock is increased at the effective production cost.\n'
                              '• Raw-material/BOM consumption is not posted automatically in this version.',
                              style: TextStyle(
                                color: AppTheme.muted,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: sourceBox),
                  const SizedBox(width: 12),
                  Expanded(child: infoBox),
                ],
              );
            }
            return Column(
              children: [
                sourceBox,
                const SizedBox(height: 12),
                infoBox,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _panel(
          'Product details',
          Icons.inventory_2_outlined,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Autocomplete<Product>(
                displayStringForOption: (p) => '${p.productCode} • ${p.name}',
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  final options = <Product>[
                    ...app.data!.products,
                    ...pendingProducts.values,
                  ];
                  return options
                      .where((p) {
                        final extra = [
                          p.brand,
                          p.manufacturer,
                          p.packageSize,
                          ...p.customAttributes.values,
                        ].join(' ').toLowerCase();
                        return q.isEmpty ||
                            p.name.toLowerCase().contains(q) ||
                            p.productCode.toLowerCase().contains(q) ||
                            p.barcode.toLowerCase().contains(q) ||
                            p.category.toLowerCase().contains(q) ||
                            extra.contains(q);
                      })
                      .take(8);
                },
                onSelected: _selectProduct,
                fieldViewBuilder: (context, ctl, focus, submit) => TextField(
                  controller: ctl,
                  focusNode: focus,
                  decoration: InputDecoration(
                    labelText: 'Search name / SKU / barcode / part / model / variant',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Scan product barcode',
                      onPressed: _scanProductForPurchase,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ),
                ),
              )),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _createProductInsidePurchase(),
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('New product'),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Text('Not found? Create it here once. Saving this purchase will then add its stock automatically.', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
              if (product != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF111720), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                  child: Row(children: [
                    _productImage(product!),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(product!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), Text('${product!.productCode} • ${product!.brand.isEmpty ? product!.category : product!.brand}${product!.subcategory.isEmpty ? '' : ' / ${product!.subcategory}'} • ${product!.stockLabel}', style: const TextStyle(color: AppTheme.muted)), Text(BusinessTypeRules.trackingSummary(activeTracking), style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w800)), Text('Current weighted cost ${money(product!.purchasePrice)}/${product!.unit}', style: const TextStyle(color: AppTheme.green, fontSize: 11, fontWeight: FontWeight.w800))])),
                    StatusPill(
                      text: pendingProducts.containsKey(product!.id)
                          ? 'New • pending purchase save'
                          : 'Existing product • stock will update',
                      color: pendingProducts.containsKey(product!.id)
                          ? AppTheme.amber
                          : AppTheme.green,
                      icon: pendingProducts.containsKey(product!.id)
                          ? Icons.hourglass_top_rounded
                          : Icons.verified_outlined,
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: purchaseUnit,
                    items: const [
                      'unit',
                      'Piece',
                      'Pack',
                      'Box',
                      'Carton',
                      'Bag',
                      'Bottle',
                      'Tray',
                      'Bundle',
                      'Kg',
                      'L',
                      'Other',
                    ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => purchaseUnit = v ?? 'unit'),
                    decoration: InputDecoration(
                      labelText: sourceMode == _StockInMode.production
                          ? 'Production unit'
                          : 'Purchase unit',
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: qty,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: sourceMode == _StockInMode.production
                          ? 'Produced quantity *'
                          : sourceMode == _StockInMode.local
                              ? 'Purchased quantity *'
                              : 'Paid quantity *',
                    ),
                  ),
                ),
                if (sourceMode != _StockInMode.production)
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: freeQty,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Free / bonus qty'),
                    ),
                  ),
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: conversion,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '1 $purchaseUnit = how many $sellingUnit',
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: purchasePrice,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: sourceMode == _StockInMode.production
                          ? 'Production cost / $purchaseUnit \u20B9'
                          : sourceMode == _StockInMode.local
                              ? 'Market price / $purchaseUnit \u20B9'
                              : 'Purchase price / $purchaseUnit \u20B9',
                    ),
                  ),
                ),
                if (sourceMode == _StockInMode.supplier)
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: supplierDiscount,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Supplier discount %',
                      ),
                    ),
                  ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: lineFreight,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: sourceMode == _StockInMode.production
                          ? 'Packaging / other cost \u20B9'
                          : sourceMode == _StockInMode.local
                              ? 'Transport / other cost \u20B9'
                              : 'Line freight / cost \u20B9',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (activeTracking['batch'] == true)
                  SizedBox(width: 190, child: TextField(controller: batch, decoration: InputDecoration(labelText: _requiredTrackingFor(product!).contains('batch') ? 'Batch / lot no. *' : 'Batch / lot no.'))),
                if (activeTracking['batch'] == true || activeTracking['production'] == true)
                  SizedBox(width: 190, child: _nullableDateField(activeTracking['production'] == true ? 'Production / manufacture date' : 'Manufacture date', manufactureDate, (d) => setState(() => manufactureDate = d))),
                if (activeTracking['expiry'] == true)
                  SizedBox(width: 190, child: _nullableDateField(_requiredTrackingFor(product!).contains('expiry') ? 'Expiry date *' : 'Expiry date', expiryDate, (d) => setState(() => expiryDate = d))),
                if (activeTracking['serial'] == true)
                  SizedBox(width: 300, child: TextField(controller: serialReference, maxLines: 2, decoration: InputDecoration(labelText: _requiredTrackingFor(product!).contains('serial') ? 'Serial / IMEI *' : 'Serial / IMEI', hintText: 'One per unit; comma or new line for multiple'))),
                SizedBox(width: 170, child: TextField(controller: mrp, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'MRP \u20B9'))),
                SizedBox(width: 180, child: TextField(controller: selling, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Selling price \u20B9'))),
                SizedBox(width: 180, child: TextField(controller: defaultDiscount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Default bill discount %'))),
                SizedBox(width: 170, child: TextField(controller: reorder, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Reorder level'))),
                SizedBox(width: 190, child: TextField(controller: rack, decoration: const InputDecoration(labelText: 'Rack / location'))),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      value: taxCategory,
                      items: const [
                        DropdownMenuItem(value: 'Unclassified', child: Text('Select tax class')),
                        DropdownMenuItem(value: 'Taxable', child: Text('Taxable')),
                        DropdownMenuItem(value: 'Exempt', child: Text('Exempt')),
                        DropdownMenuItem(value: 'Nil-rated', child: Text('Nil-rated')),
                        DropdownMenuItem(value: 'Non-GST', child: Text('Non-GST')),
                      ],
                      onChanged: (value) => setState(() {
                        taxCategory = value ?? 'Unclassified';
                        if (taxCategory != 'Taxable') {
                          saleGstRate = 0;
                          purchaseGstRate = 0;
                          gstApplicable = false;
                          itcEligible = false;
                        } else {
                          if (saleGstRate <= 0) saleGstRate = 5;
                          if (purchaseGstRate <= 0) purchaseGstRate = saleGstRate;
                          if (sourceMode == _StockInMode.supplier) gstApplicable = true;
                        }
                      }),
                      decoration: const InputDecoration(labelText: 'Sale tax classification'),
                    ),
                  ),
                  if (taxCategory == 'Taxable')
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<double>(
                        value: saleGstRate,
                        items: const [0.25, 3.0, 5.0, 12.0, 18.0, 28.0]
                            .map((e) => DropdownMenuItem(value: e, child: Text('${e.toStringAsFixed(e % 1 == 0 ? 0 : 2)}%')))
                            .toList(),
                        onChanged: (v) => setState(() => saleGstRate = v ?? 0),
                        decoration: const InputDecoration(labelText: 'Sale GST rate'),
                      ),
                    ),
                  if (taxCategory == 'Taxable')
                    FilterChip(
                      label: const Text('Selling price includes GST'),
                      selected: saleTaxInclusive,
                      onSelected: (v) => setState(() => saleTaxInclusive = v),
                    ),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: hsn,
                      decoration: const InputDecoration(labelText: 'HSN / SAC'),
                    ),
                  ),
                  if (sourceMode == _StockInMode.supplier && taxCategory == 'Taxable') ...[
                    FilterChip(
                      label: const Text('Supplier charged GST'),
                      selected: gstApplicable,
                      onSelected: (v) => setState(() => gstApplicable = v),
                    ),
                    if (gstApplicable)
                      SizedBox(
                        width: 150,
                        child: DropdownButtonFormField<double>(
                          value: purchaseGstRate,
                          items: const [0.0, 0.25, 3.0, 5.0, 12.0, 18.0, 28.0]
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    '${e.toStringAsFixed(e % 1 == 0 ? 0 : 2)}%',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => purchaseGstRate = v ?? 0),
                          decoration: const InputDecoration(labelText: 'Purchase GST rate'),
                        ),
                      ),
                    FilterChip(
                      label: const Text('Price includes GST'),
                      selected: purchaseIncludesTax,
                      onSelected: gstApplicable
                          ? (v) => setState(() => purchaseIncludesTax = v)
                          : null,
                    ),
                    FilterChip(
                      label: Text(AppScope.of(context).data!.business.canClaimItc
                          ? 'ITC eligible'
                          : 'ITC unavailable for business GST type'),
                      selected: AppScope.of(context).data!.business.canClaimItc && itcEligible,
                      onSelected: gstApplicable && AppScope.of(context).data!.business.canClaimItc
                          ? (v) => setState(() => itcEligible = v)
                          : null,
                    ),
                    if (gstApplicable && p != null)
                      StatusPill(
                        text: sameState
                            ? 'CGST ${halfTax.toStringAsFixed(2)}% + SGST ${halfTax.toStringAsFixed(2)}%'
                            : 'IGST ${purchaseGstRate.toStringAsFixed(2)}%',
                        color: AppTheme.cyan,
                      ),
                  ] else
                    StatusPill(
                      text: sourceMode == _StockInMode.supplier
                          ? '$taxCategory sale classification • no supplier GST entered'
                          : sourceMode == _StockInMode.local
                              ? '$taxCategory sale classification • no purchase GST / ITC in Local mode'
                              : '$taxCategory sale classification • no purchase GST / ITC in Production mode',
                      color: AppTheme.cyan,
                      icon: Icons.info_outline_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (p != null)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: sourceMode == _StockInMode.supplier
                      ? [
                          _metric(
                            'Stock received',
                            '${p.stockReceived.toStringAsFixed(p.stockReceived % 1 == 0 ? 0 : 2)} $sellingUnit',
                            AppTheme.cyan,
                          ),
                          _metric('Taxable value', money(p.taxableBase), AppTheme.muted),
                          _metric('Input GST', money(p.inputGst), AppTheme.amber),
                          _metric(
                            'Supplier total',
                            money(p.supplierInvoiceLineTotal),
                            AppTheme.purple,
                          ),
                          _metric(
                            'Effective cost / $sellingUnit',
                            money(p.effectiveCostPerSellingUnit),
                            AppTheme.green,
                          ),
                        ]
                      : [
                          _metric(
                            sourceMode == _StockInMode.production
                                ? 'Finished stock'
                                : 'Stock received',
                            '${p.stockReceived.toStringAsFixed(p.stockReceived % 1 == 0 ? 0 : 2)} $sellingUnit',
                            AppTheme.cyan,
                          ),
                          _metric(
                            sourceMode == _StockInMode.production
                                ? 'Production base cost'
                                : 'Purchase base cost',
                            money(p.invoiceLineBeforeTax),
                            AppTheme.muted,
                          ),
                          _metric(
                            sourceMode == _StockInMode.production
                                ? 'Packaging / other'
                                : 'Transport / other',
                            money(p.freightCost),
                            AppTheme.amber,
                          ),
                          _metric(
                            'Total stock-in cost',
                            money(p.supplierInvoiceLineTotal),
                            AppTheme.purple,
                          ),
                          _metric(
                            'Effective cost / $sellingUnit',
                            money(p.effectiveCostPerSellingUnit),
                            AppTheme.green,
                          ),
                        ],
                ),
              const SizedBox(height: 10),
              TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Item note / quality / expiry note')),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _addLine, icon: const Icon(Icons.playlist_add_rounded), label: Text(
                  sourceMode == _StockInMode.production
                      ? 'Add produced item'
                      : sourceMode == _StockInMode.local
                          ? 'Add local purchase item'
                          : 'Add item to purchase',
                ))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 1080;
            final itemList = _panel(
              'Item list (${lines.length})',
              Icons.list_alt_rounded,
              lines.isEmpty
                  ? const Padding(padding: EdgeInsets.all(14), child: Text('No purchase items added yet.', style: TextStyle(color: AppTheme.muted)))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [DataColumn(label: Text('Product')), DataColumn(label: Text('Qty')), DataColumn(label: Text('Free')), DataColumn(label: Text('Stock')), DataColumn(label: Text('GST')), DataColumn(label: Text('Eff. cost')), DataColumn(label: Text('Amount')), DataColumn(label: Text(''))],
                        rows: List.generate(lines.length, (i) {
                          final l = lines[i];
                          return DataRow(cells: [
                            DataCell(SizedBox(
                              width: 210,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (l.batchNo.isNotEmpty || l.serialNumbers.isNotEmpty)
                                    Text(
                                      [
                                        if (l.batchNo.isNotEmpty) 'Batch ${l.batchNo}',
                                        if (l.serialNumbers.isNotEmpty) 'Serial ${l.serialNumbers}',
                                      ].join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppTheme.cyan, fontSize: 10),
                                    ),
                                ],
                              ),
                            )),
                            DataCell(Text('${l.quantity.toStringAsFixed(2)} ${l.purchaseUnit}')),
                            DataCell(Text(l.freeQuantity.toStringAsFixed(2))),
                            DataCell(Text('${l.stockReceived.toStringAsFixed(2)} ${l.sellingUnit}')),
                            DataCell(Text(l.gstApplicable ? '${l.gstRate.toStringAsFixed(1)}%' : 'NA')),
                            DataCell(Text(money(l.effectiveCostPerSellingUnit))),
                            DataCell(Text(money(l.supplierInvoiceLineTotal))),
                            DataCell(IconButton(onPressed: () => setState(() => lines.removeAt(i)), icon: const Icon(Icons.delete_outline, color: AppTheme.red))),
                          ]);
                        }),
                      ),
                    ),
            );

            final summary = _panel(
              sourceMode == _StockInMode.supplier
                  ? 'Purchase summary & payment'
                  : sourceMode == _StockInMode.local
                      ? 'Local purchase summary'
                      : 'Production summary',
              Icons.calculate_outlined,
              Column(
                children: [
                  TextField(
                    controller: invoiceFreight,
                    onChanged: (_) => setState(() {}),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: sourceMode == _StockInMode.production
                          ? 'Batch overhead / other cost \u20B9'
                          : sourceMode == _StockInMode.local
                              ? 'Overall transport / other charges \u20B9'
                              : 'Invoice freight / other charges \u20B9',
                      helperText:
                          'Automatically allocated across items by cost value.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _sum(
                    sourceMode == _StockInMode.production
                        ? 'Production subtotal'
                        : sourceMode == _StockInMode.local
                            ? 'Purchase subtotal'
                            : 'Taxable subtotal',
                    subtotal,
                  ),
                  if (sourceMode == _StockInMode.supplier)
                    _sum('Supplier discounts', -discounts),
                  _sum(
                    sourceMode == _StockInMode.production
                        ? 'Item packaging / other'
                        : sourceMode == _StockInMode.local
                            ? 'Item transport / other'
                            : 'Line freight',
                    lineFreightTotal,
                  ),
                  if (sourceMode == _StockInMode.supplier)
                    _sum('Input GST', gst),
                  _sum(
                    sourceMode == _StockInMode.production
                        ? 'Batch overhead'
                        : sourceMode == _StockInMode.local
                            ? 'Overall charges'
                            : 'Invoice freight',
                    invoiceFreightValue,
                  ),
                  const Divider(),
                  _sum(
                    sourceMode == _StockInMode.production
                        ? 'Total production cost'
                        : sourceMode == _StockInMode.local
                            ? 'Total cash purchase cost'
                            : 'Grand total',
                    grand,
                    strong: true,
                  ),
                  const SizedBox(height: 10),
                  if (sourceMode == _StockInMode.supplier) ...[
                    DropdownButtonFormField<String>(
                      value: paymentTiming,
                      items: const [
                        'Pay full now',
                        'Partial payment',
                        'Credit / pay later',
                      ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        paymentTiming = v ?? 'Credit / pay later';
                        if (paymentTiming == 'Credit / pay later') {
                          paid.text = '0';
                          paymentMode = 'Credit';
                        } else if (paymentMode == 'Credit') {
                          paymentMode = 'Cash';
                        }
                      }),
                      decoration: const InputDecoration(
                        labelText: 'How will this purchase be settled?',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (supplier != null && supplier!.supplierCreditBalance > 0)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: useSupplierAdvance,
                        title: Text(
                          'Use existing supplier advance (${money(supplier!.supplierCreditBalance)})',
                        ),
                        subtitle:
                            Text('Apply ${money(advanceToUse)} before paying more.'),
                        onChanged: (v) =>
                            setState(() => useSupplierAdvance = v),
                      ),
                    if (paymentTiming != 'Credit / pay later') ...[
                      DropdownButtonFormField<String>(
                        value: paymentMode == 'Credit' || paymentMode == 'Partial'
                            ? 'Cash'
                            : paymentMode,
                        items: const ['Cash', 'UPI', 'Bank Transfer', 'Cheque']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => paymentMode = v ?? 'Cash'),
                        decoration:
                            const InputDecoration(labelText: 'Payment mode'),
                      ),
                      const SizedBox(height: 8),
                      if (paymentTiming == 'Partial payment')
                        TextField(
                          controller: paid,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount paid now \u20B9',
                            helperText:
                                'Remaining amount becomes supplier payable. Any excess becomes supplier advance.',
                          ),
                        )
                      else
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Amount to pay now',
                          ),
                          child: Text(
                            money(remainingAfterAdvance),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reference,
                        decoration: const InputDecoration(
                          labelText: 'UTR / cheque / transaction reference',
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (supplier != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151A21),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            _sum(
                              'Amount already payable to supplier',
                              supplier!.openingPayable,
                            ),
                            _sum(
                              'Advance already paid to supplier',
                              supplier!.supplierCreditBalance,
                              color: AppTheme.cyan,
                            ),
                            _sum(
                              'Supplier advance used now',
                              -advanceToUse,
                              color: AppTheme.cyan,
                            ),
                            _sum(
                              'Paid now',
                              paidNowValue,
                              color: AppTheme.green,
                            ),
                            const Divider(),
                            _sum(
                              'Amount payable from this purchase',
                              due,
                              strong: true,
                              color: due > 0 ? AppTheme.red : AppTheme.green,
                            ),
                            if (newSupplierAdvance > 0)
                              _sum(
                                'New supplier advance created',
                                newSupplierAdvance,
                                strong: true,
                                color: AppTheme.cyan,
                              ),
                            _sum(
                              'Total amount payable after save',
                              supplier!.openingPayable + due,
                              color: (supplier!.openingPayable + due) > 0
                                  ? AppTheme.amber
                                  : AppTheme.green,
                            ),
                          ],
                        ),
                      ),
                  ] else if (sourceMode == _StockInMode.local) ...[
                    DropdownButtonFormField<String>(
                      value: paymentMode == 'Own Production' ? 'Cash' : paymentMode,
                      items: const ['Cash', 'UPI', 'Bank Transfer']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => paymentMode = v ?? 'Cash'),
                      decoration:
                          const InputDecoration(labelText: 'Paid using'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reference,
                      decoration: const InputDecoration(
                        labelText: 'Payment / receipt reference (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Local purchase is treated as fully paid. No supplier payable is created.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111820),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Text(
                        'Own Production records finished stock and its cost only. No supplier payment is created.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: lines.isEmpty ||
                              (sourceMode == _StockInMode.supplier &&
                                  supplier == null)
                          ? null
                          : _savePurchase,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        sourceMode == _StockInMode.supplier
                            ? 'Review & confirm purchase'
                            : sourceMode == _StockInMode.local
                                ? 'Review & save local purchase'
                                : 'Review & save production',
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: itemList), const SizedBox(width: 12), Expanded(flex: 2, child: summary)]);
            return Column(children: [itemList, const SizedBox(height: 12), summary]);
          },
        ),
      ],
    );
  }

  Widget _productImage(Product p) {
    final fallback = Icon(Icons.inventory_2_outlined, color: p.weighted ? AppTheme.green : AppTheme.cyan, size: 30);
    if (p.imageUrl.isEmpty) return Container(width: 62, height: 62, alignment: Alignment.center, decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(12)), child: fallback);
    final image = p.imageUrl.startsWith('assets/') ? Image.asset(p.imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback) : Image.network(p.imageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback);
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 62, height: 62, child: image));
  }

  Widget _logicRow(String title, String name, String detail) => Row(children: [SizedBox(width: 130, child: Text(title, style: const TextStyle(color: AppTheme.muted, fontSize: 11))), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: AppTheme.muted, fontSize: 11))]))]);

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onChanged) => InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: value, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) onChanged(d); }, child: InputDecorator(decoration: InputDecoration(labelText: label), child: Text('${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}')));

  Widget _nullableDateField(String label, DateTime? value, ValueChanged<DateTime?> onChanged) => InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) onChanged(d); }, child: InputDecorator(decoration: InputDecoration(labelText: label, suffixIcon: value == null ? null : IconButton(onPressed: () => onChanged(null), icon: const Icon(Icons.clear, size: 17))), child: Text(value == null ? 'Not set' : '${value.day.toString().padLeft(2, '0')}-${value.month.toString().padLeft(2, '0')}-${value.year}')));

  Widget _metric(String label, String value, Color color) => Container(width: 190, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF10151C), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 10.5)), const SizedBox(height: 4), Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color))]));

  Widget _sum(String label, double value, {bool strong = false, Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text(label, style: TextStyle(color: strong ? Colors.white : AppTheme.muted, fontWeight: strong ? FontWeight.w900 : FontWeight.w500)), const Spacer(), Text(money(value), style: TextStyle(fontSize: strong ? 19 : 13, fontWeight: FontWeight.w900, color: color))]));

  Widget _panel(String title, IconData icon, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: AppTheme.red), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]), const SizedBox(height: 12), child])));
}

class _PurchaseHistoryView extends StatefulWidget {
  const _PurchaseHistoryView();
  @override
  State<_PurchaseHistoryView> createState() => _PurchaseHistoryViewState();
}

class _PurchaseHistoryViewState extends State<_PurchaseHistoryView> {
  Future<void> _payPurchase(BuildContext context, PurchaseRecord purchase) async {
    final app = AppScope.of(context);
    final matches = app.data!.suppliers.where((s) => s.id == purchase.supplierId).toList();
    if (matches.isEmpty) return;
    final supplier = matches.first;
    final amount = TextEditingController(text: purchase.balanceDue.toStringAsFixed(2));
    final reference = TextEditingController();
    String mode = 'Cash';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Pay supplier • ${supplier.name}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Invoice ${purchase.invoiceNumber} • Amount still payable ${money(purchase.balanceDue)}'),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount to pay \u20B9')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: mode,
                  items: const ['Cash', 'UPI', 'Bank Transfer', 'Cheque'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => update(() => mode = v ?? 'Cash'),
                  decoration: const InputDecoration(labelText: 'Payment mode'),
                ),
                const SizedBox(height: 8),
                TextField(controller: reference, decoration: const InputDecoration(labelText: 'UTR / cheque / reference no.')),
                const SizedBox(height: 8),
                const Text('Pay less = remaining stays pending. Pay extra = excess becomes supplier advance for a future purchase.', style: TextStyle(color: AppTheme.muted, fontSize: 11)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final pay = double.tryParse(amount.text.trim()) ?? 0;
    if (pay <= 0) return;
    final confirmed = await confirmAction(
      context,
      title: 'Confirm supplier payment',
      message:
          'Supplier: ${supplier.name}\n'
          'Invoice: ${purchase.invoiceNumber}\n'
          'Amount still payable: ${money(purchase.balanceDue)}\n'
          'Pay now: ${money(pay)}\n'
          'Mode: $mode\n'
          '${pay > purchase.balanceDue ? 'Extra ${money(pay - purchase.balanceDue)} becomes supplier advance.' : ''}',
      confirmLabel: 'Confirm payment',
      icon: Icons.payments_outlined,
    );
    if (!confirmed) return;

    await app.recordPurchasePayment(
      purchase,
      supplier,
      pay,
      paymentMode: mode,
      reference: reference.text.trim().isEmpty ? purchase.number : reference.text.trim(),
      note: 'Supplier payment',
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rows = app.data!.purchases;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      children: [
        SectionTitle(
          'Purchase / Stock-In History',
          subtitle:
              'Supplier purchases, local cash purchases and own-production stock-ins remain available for stock and cost audit.',
        ),
        if (rows.isEmpty) const EmptyState('No purchases recorded yet.', icon: Icons.shopping_bag_outlined),
        ...rows.map((p) => Card(child: ExpansionTile(
              title: Text('${p.number} • ${p.supplierName}', style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                '${p.sourceType == 'SUPPLIER' ? 'Invoice' : p.sourceType == 'LOCAL' ? 'Local ref' : 'Production ref'} ${p.invoiceNumber} • ${money(p.total)} • '
                '${p.sourceType == 'SUPPLIER' ? (p.balanceDue > 0 ? 'Amount payable ${money(p.balanceDue)}' : 'Fully settled') : p.sourceType == 'LOCAL' ? 'Cash/local stock-in' : 'Finished stock produced'}',
              ),
              trailing: StatusPill(
                text: p.sourceType == 'SUPPLIER'
                    ? (p.balanceDue > 0 ? 'PAYABLE' : 'PAID')
                    : p.sourceType == 'LOCAL'
                        ? 'LOCAL'
                        : 'PRODUCED',
                color: p.sourceType == 'SUPPLIER' && p.balanceDue > 0
                    ? AppTheme.amber
                    : AppTheme.green,
              ),
              children: [
                if (p.sourceType == 'SUPPLIER' && p.balanceDue > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('Amount we still need to pay supplier: ${money(p.balanceDue)}', style: const TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w800))),
                        FilledButton.icon(
                          onPressed: () => _payPurchase(context, p),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Pay supplier'),
                        ),
                      ],
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [DataColumn(label: Text('Product')), DataColumn(label: Text('Qty')), DataColumn(label: Text('Free')), DataColumn(label: Text('Stock received')), DataColumn(label: Text('GST')), DataColumn(label: Text('Effective cost'))],
                    rows: p.lines.map((l) => DataRow(cells: [DataCell(Text(l.productName)), DataCell(Text('${l.quantity} ${l.purchaseUnit}')), DataCell(Text('${l.freeQuantity}')), DataCell(Text('${l.stockReceived.toStringAsFixed(2)} ${l.sellingUnit}')), DataCell(Text(money(l.inputGst))), DataCell(Text(money(l.effectiveCostPerSellingUnit)))])).toList(),
                  ),
                ),
              ],
            ))),
      ],
    );
  }
}

class _PurchaseReturnsView extends StatefulWidget {
  const _PurchaseReturnsView();
  @override
  State<_PurchaseReturnsView> createState() => _PurchaseReturnsViewState();
}

class _PurchaseReturnsViewState extends State<_PurchaseReturnsView> {
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      children: [
        SectionTitle('Purchase Returns', subtitle: 'Return damaged/expired/excess stock to supplier and adjust payable or supplier credit.', trailing: FilledButton.icon(onPressed: () => _createReturn(context), icon: const Icon(Icons.keyboard_return_rounded), label: const Text('New return'))),
        if (app.data!.purchaseReturns.isEmpty) const EmptyState('No purchase returns recorded.', icon: Icons.assignment_return_outlined),
        ...app.data!.purchaseReturns.map((r) => Card(child: ListTile(leading: const Icon(Icons.assignment_return_outlined, color: AppTheme.amber), title: Text('${r.number} • ${r.supplierName}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${r.reason.isEmpty ? 'Purchase return' : r.reason} • ${r.lines.length} item(s)'), trailing: Text(money(r.total), style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.green))))),
      ],
    );
  }

  Future<void> _createReturn(BuildContext context) async {
    final app = AppScope.of(context);
    final supplierPurchases = app.data!.purchases
        .where((p) => p.sourceType == 'SUPPLIER' && p.supplierId.isNotEmpty)
        .toList();
    if (supplierPurchases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record a supplier purchase before creating a supplier return.'),
        ),
      );
      return;
    }
    PurchaseRecord purchase = supplierPurchases.first;
    PurchaseLine line = purchase.lines.first;
    final qty = TextEditingController(text: '1');
    final reason = TextEditingController(text: 'Damaged / excess stock');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
          title: const Text('New purchase return'),
          content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(children: [
            DropdownButtonFormField<PurchaseRecord>(value: purchase, items: supplierPurchases.map((p) => DropdownMenuItem(value: p, child: Text('${p.number} • ${p.supplierName}'))).toList(), onChanged: (v) => update(() { purchase = v ?? purchase; line = purchase.lines.first; }), decoration: const InputDecoration(labelText: 'Original purchase')),
            const SizedBox(height: 8),
            DropdownButtonFormField<PurchaseLine>(value: line, items: purchase.lines.map((l) => DropdownMenuItem(value: l, child: Text(l.productName))).toList(), onChanged: (v) => update(() => line = v ?? line), decoration: const InputDecoration(labelText: 'Product')),
            const SizedBox(height: 8),
            TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Return quantity (${line.sellingUnit})')),
            const SizedBox(height: 8),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
          ]))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save return'))],
        )));
    if (ok != true) return;
    final amountQty = (double.tryParse(qty.text) ?? 0).clamp(0.0, double.infinity).toDouble();
    if (amountQty <= 0) return;
    final product = app.data!.products.where((p) => p.id == line.productId).firstOrNull;
    final maxQty = product?.stock ?? amountQty;
    final finalQty = amountQty.clamp(0.0, maxQty).toDouble();
    final record = PurchaseReturnRecord(
      id: const Uuid().v4(),
      number: app.nextPurchaseReturnNumber(),
      createdAt: DateTime.now(),
      purchaseId: purchase.id,
      supplierId: purchase.supplierId,
      supplierName: purchase.supplierName,
      lines: [PurchaseReturnLine(productId: line.productId, productName: line.productName, quantity: finalQty, unit: line.sellingUnit, unitCost: line.effectiveCostPerSellingUnit)],
      reason: reason.text.trim(),
    );
    final confirmed = await confirmAction(
      context,
      title: 'Confirm purchase return',
      message:
          'Return ${money(record.total)} of ${line.productName} to ${purchase.supplierName}?\n'
          'Stock and the supplier account will be adjusted.',
      confirmLabel: 'Confirm return',
      icon: Icons.assignment_return_outlined,
    );
    if (!confirmed) return;
    await app.processPurchaseReturn(record);
    if (mounted) setState(() {});
  }
}

class _StockListView extends StatelessWidget {
  const _StockListView();
  @override
  Widget build(BuildContext context) {
    final products = AppScope.of(context).data!.products;
    return ListView(padding: const EdgeInsets.fromLTRB(22, 0, 22, 24), children: [
      const SectionTitle('Stock List', subtitle: 'Current sellable stock after purchases, billing and purchase returns.'),
      ...products.map((p) => Card(child: ListTile(leading: Icon(p.weighted ? Icons.scale_rounded : Icons.inventory_2_outlined, color: p.stock <= p.reorderLevel ? AppTheme.red : AppTheme.green), title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${p.productCode} • Avg cost ${money(p.purchasePrice)}/${p.unit} • Rack ${p.rackLocation.isEmpty ? 'Not set' : p.rackLocation}'), trailing: Text(p.stockLabel, style: const TextStyle(fontWeight: FontWeight.w900))))),
    ]);
  }
}

class _LowStockView extends StatelessWidget {
  const _LowStockView();
  @override
  Widget build(BuildContext context) {
    final products = AppScope.of(context).data!.products.where((p) => p.stock <= p.reorderLevel).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(22, 0, 22, 24), children: [
      const SectionTitle('Low Stock', subtitle: 'Products at or below reorder level.'),
      if (products.isEmpty) const EmptyState('No low-stock products.', icon: Icons.verified_outlined),
      ...products.map((p) => Card(child: ListTile(leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.red), title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Stock ${p.stockLabel} • Reorder ${p.reorderLevel.toStringAsFixed(2)} ${p.unit}'), trailing: const StatusPill(text: 'REORDER', color: AppTheme.red)))),
    ]);
  }
}

class _ExpiryView extends StatelessWidget {
  const _ExpiryView();
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final products = AppScope.of(context).data!.products.where((p) => p.expiryDate != null).toList()..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    return ListView(padding: const EdgeInsets.fromLTRB(22, 0, 22, 24), children: [
      const SectionTitle('Expiry Alerts', subtitle: 'Expiry retained from purchase/batch information for operational alerts.'),
      if (products.isEmpty) const EmptyState('No expiry-tracked products.', icon: Icons.event_available_outlined),
      ...products.map((p) { final days = p.expiryDate!.difference(now).inDays; return Card(child: ListTile(leading: Icon(Icons.event_busy_outlined, color: days <= 7 ? AppTheme.red : AppTheme.amber), title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('Expiry ${p.expiryDate!.day}/${p.expiryDate!.month}/${p.expiryDate!.year} • ${p.stockLabel}'), trailing: StatusPill(text: days < 0 ? 'EXPIRED' : '$days DAYS', color: days <= 7 ? AppTheme.red : AppTheme.amber))); }),
    ]);
  }
}

extension _FirstOrNullPurchase<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
