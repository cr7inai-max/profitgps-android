import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/local_repository.dart';
import '../models/entities.dart';
import '../services/document_rules.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository);
  final LocalRepository repository;
  final _uuid = const Uuid();
  AppData? data;
  bool loading = true;

  Future<void> init() async {
    data = await repository.load();
    final repaired = _repairMissingPurchaseProducts();
    if (repaired) await repository.save(data!);
    loading = false;
    notifyListeners();
  }
  Future<void> persist() async { if (data != null) await repository.save(data!); notifyListeners(); }
  Future<void> addProduct(Product p) async { data!.products.add(p); await persist(); }
  Future<void> addCustomer(Customer c) async { data!.customers.add(c); await persist(); }
  Future<void> addSupplier(Supplier s) async { data!.suppliers.add(s); await persist(); }
  Future<void> addCashClosing(CashClosing c) async { data!.cashClosings.insert(0, c); await persist(); }

  /// Repairs the specific legacy condition where a purchase document exists
  /// but its Product record was never committed. This runs only for missing
  /// product IDs, so normal existing inventory is never re-counted.
  bool _repairMissingPurchaseProducts() {
    if (data == null) return false;
    final existingIds = data!.products.map((p) => p.id).toSet();
    final missingIds = <String>{};
    for (final purchase in data!.purchases) {
      for (final line in purchase.lines) {
        if (line.productId.trim().isNotEmpty && !existingIds.contains(line.productId)) {
          missingIds.add(line.productId);
        }
      }
    }
    if (missingIds.isEmpty) return false;

    for (final id in missingIds) {
      PurchaseRecord? latestPurchase;
      PurchaseLine? latestLine;
      var received = 0.0;
      var costPool = 0.0;

      for (final purchase in data!.purchases) {
        for (final line in purchase.lines) {
          if (line.productId != id) continue;
          received += line.stockReceived;
          costPool += line.inventoryCostPool;
          if (latestPurchase == null || purchase.createdAt.isAfter(latestPurchase.createdAt)) {
            latestPurchase = purchase;
            latestLine = line;
          }
        }
      }
      if (latestPurchase == null || latestLine == null) continue;

      final returned = data!.purchaseReturns
          .expand((r) => r.lines)
          .where((r) => r.productId == id)
          .fold<double>(0, (sum, r) => sum + r.quantity);
      final sold = data!.sales
          .expand((sale) => sale.lines)
          .where((saleLine) => saleLine.productId == id)
          .fold<double>(0, (sum, saleLine) => sum + saleLine.qty);
      final reconstructedStock =
          (received - returned - sold).clamp(0.0, double.infinity).toDouble();
      final avgCost = received <= 0
          ? latestLine.effectiveCostPerSellingUnit
          : costPool / received;
      final sellingUnit =
          latestLine.sellingUnit.trim().isEmpty ? 'pcs' : latestLine.sellingUnit.trim();

      data!.products.add(Product(
        id: id,
        name: latestLine.productName.trim().isEmpty
            ? 'Purchased item'
            : latestLine.productName.trim(),
        barcode: '',
        productCode: '',
        category: 'General',
        purchasePrice: avgCost,
        sellingPrice: latestLine.sellingPrice,
        gstRate: latestLine.taxCategory == 'Taxable' ? latestLine.saleGstRate : 0,
        gstApplicable:
            latestLine.taxCategory == 'Taxable' && latestLine.saleGstRate > 0,
        taxCategory: latestLine.taxCategory,
        taxInclusive: latestLine.saleTaxInclusive,
        hsnSac: latestLine.hsnSac,
        stock: reconstructedStock,
        reorderLevel: latestLine.reorderLevel,
        expiryDate: latestLine.expiryDate,
        supplierId: latestPurchase.sourceType == 'SUPPLIER'
            ? latestPurchase.supplierId
            : '',
        supplier: latestPurchase.sourceName,
        unit: sellingUnit,
        weighted: const {'kg', 'g', 'gram', 'grams', 'l', 'litre', 'liter', 'ml'}
            .contains(sellingUnit.toLowerCase()),
        purchaseUnit: latestLine.purchaseUnit,
        purchaseInvoicePrice: latestLine.purchasePricePerUnit,
        purchasePriceIncludesTax: latestLine.purchasePriceIncludesTax,
        packConversionQty:
            latestLine.conversionQty <= 0 ? 1 : latestLine.conversionQty,
        supplierDiscountPercent: latestLine.supplierDiscountPercent,
        freightCost: latestLine.freightCost,
        itcEligible: latestPurchase.sourceType == 'SUPPLIER' &&
            data!.business.canClaimItc &&
            latestLine.itcEligible,
        mrp: latestLine.mrp,
        rackLocation: latestLine.rackLocation,
      ));
    }
    return true;
  }

  String nextPurchaseNumber() {
    final now = DateTime.now();
    final day = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final count = data!.purchases.length + 1;
    return 'PUR-$day-${count.toString().padLeft(4, '0')}';
  }

  String nextPurchaseOrderNumber() {
    final now = DateTime.now();
    final day = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final count = data!.purchases.length + 1;
    return 'PO-$day-${count.toString().padLeft(4, '0')}';
  }

  Future<PurchaseRecord> addPurchase(PurchaseRecord purchase) async {
    data!.purchases.insert(0, purchase);

    for (final line in purchase.lines) {
      // A saved purchase must always have a corresponding Product record.
      // Earlier builds silently skipped a line when the product link was
      // missing, which could leave the purchase visible in Records while the
      // item never appeared in Products/Billing. Repair the link instead.
      var p = data!.products.where((e) => e.id == line.productId).firstOrNull;
      if (p == null) {
        final fallbackId = line.productId.trim().isEmpty ? _uuid.v4() : line.productId;
        line.productId = fallbackId;
        p = Product(
          id: fallbackId,
          name: line.productName.trim().isEmpty ? 'Purchased item' : line.productName.trim(),
          barcode: '',
          productCode: '',
          category: 'General',
          purchasePrice: line.effectiveCostPerSellingUnit,
          sellingPrice: line.sellingPrice,
          gstRate: line.taxCategory == 'Taxable' ? line.saleGstRate : 0,
          gstApplicable: line.taxCategory == 'Taxable' && line.saleGstRate > 0,
          taxCategory: line.taxCategory,
          taxInclusive: line.saleTaxInclusive,
          hsnSac: line.hsnSac,
          stock: 0,
          reorderLevel: line.reorderLevel,
          expiryDate: line.expiryDate,
          supplierId: purchase.sourceType == 'SUPPLIER' ? purchase.supplierId : '',
          supplier: purchase.sourceName,
          unit: line.sellingUnit.trim().isEmpty ? 'pcs' : line.sellingUnit,
          weighted: const {'kg', 'g', 'gram', 'grams', 'l', 'litre', 'liter', 'ml'}
              .contains(line.sellingUnit.trim().toLowerCase()),
          purchaseUnit: line.purchaseUnit,
          purchaseInvoicePrice: line.purchasePricePerUnit,
          purchasePriceIncludesTax: line.purchasePriceIncludesTax,
          packConversionQty: line.conversionQty <= 0 ? 1 : line.conversionQty,
          supplierDiscountPercent: line.supplierDiscountPercent,
          freightCost: line.freightCost,
          itcEligible: purchase.sourceType == 'SUPPLIER' && data!.business.canClaimItc && line.itcEligible,
          mrp: line.mrp,
          rackLocation: line.rackLocation,
        );
        data!.products.add(p);
      }
      final oldStock = p.stock;
      final received = line.stockReceived;
      final oldPool = oldStock * p.purchasePrice;
      final newPool = received * line.effectiveCostPerSellingUnit;
      final totalStock = oldStock + received;
      if (totalStock > 0) {
        p.purchasePrice = (oldPool + newPool) / totalStock;
      }
      p.stock = totalStock;
      p.unit = line.sellingUnit.trim().isEmpty ? p.unit : line.sellingUnit;
      p.supplierId = purchase.sourceType == 'SUPPLIER' ? purchase.supplierId : p.supplierId;
      p.supplier = purchase.sourceName.trim().isEmpty ? p.supplier : purchase.sourceName;
      p.purchaseUnit = line.purchaseUnit;
      p.packConversionQty = line.conversionQty;
      p.purchaseInvoicePrice = line.purchasePricePerUnit;
      p.supplierDiscountPercent = line.supplierDiscountPercent;
      p.freightCost = line.freightCost;
      p.taxCategory = line.taxCategory;
      p.gstRate = line.taxCategory == 'Taxable' ? line.saleGstRate : 0;
      p.gstApplicable = line.taxCategory == 'Taxable' && line.saleGstRate > 0;
      p.taxInclusive = line.saleTaxInclusive;
      if (purchase.sourceType == 'SUPPLIER') {
        p.purchasePriceIncludesTax = line.purchasePriceIncludesTax;
        p.itcEligible = data!.business.canClaimItc && line.itcEligible;
      }
      if (line.hsnSac.isNotEmpty) p.hsnSac = line.hsnSac;
      if (line.expiryDate != null) p.expiryDate = line.expiryDate;
      if (line.serialNumbers.trim().isNotEmpty) {
        final serials = line.serialNumbers
            .split(RegExp(r'[,;\n]+'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        for (final serial in serials) {
          if (!p.serialNumbers.contains(serial)) p.serialNumbers.add(serial);
        }
      }
      if (line.sellingPrice > 0) p.sellingPrice = line.sellingPrice;
      if (line.mrp > 0) p.mrp = line.mrp;
      if (line.defaultDiscountPercent >= 0) {
        p.defaultDiscountPercent = line.defaultDiscountPercent;
      }
      if (line.reorderLevel > 0) p.reorderLevel = line.reorderLevel;
      if (line.rackLocation.isNotEmpty) p.rackLocation = line.rackLocation;
    }

    final supplier = data!.suppliers.where((e) => e.id == purchase.supplierId).firstOrNull;
    if (supplier != null) {
      final advanceUsed = purchase.supplierAdvanceUsed
          .clamp(0.0, supplier.supplierCreditBalance)
          .toDouble();
      purchase.supplierAdvanceUsed = advanceUsed;
      if (advanceUsed > 0) {
        supplier.supplierCreditBalance =
            (supplier.supplierCreditBalance - advanceUsed).clamp(0.0, double.infinity).toDouble();
        data!.supplierLedger.insert(0, SupplierLedgerEntry(
          id: _uuid.v4(),
          supplierId: supplier.id,
          createdAt: DateTime.now(),
          type: 'ADVANCE_USED',
          amount: advanceUsed,
          reference: '',
          documentReference: purchase.number,
          note: 'Existing supplier advance adjusted against ${purchase.invoiceNumber}',
        ));
      }

      final invoiceAfterAdvance =
          (purchase.total - advanceUsed).clamp(0.0, double.infinity).toDouble();
      final paidAgainstInvoice =
          purchase.amountPaid.clamp(0.0, invoiceAfterAdvance).toDouble();
      if (paidAgainstInvoice > 0) {
        data!.supplierLedger.insert(0, SupplierLedgerEntry(
          id: _uuid.v4(),
          supplierId: supplier.id,
          createdAt: DateTime.now(),
          type: 'PAYMENT',
          amount: paidAgainstInvoice,
          paymentMode: purchase.paymentMode,
          reference: purchase.referenceNumber,
          documentReference: purchase.number,
          note: 'Payment with purchase invoice ${purchase.invoiceNumber}',
        ));
      }

      final due =
          (invoiceAfterAdvance - paidAgainstInvoice).clamp(0.0, double.infinity).toDouble();
      if (due > 0) {
        supplier.openingPayable += due;
        data!.supplierLedger.insert(0, SupplierLedgerEntry(
          id: _uuid.v4(),
          supplierId: supplier.id,
          createdAt: DateTime.now(),
          type: 'PAYABLE',
          amount: due,
          reference: '',
          documentReference: purchase.number,
          note: 'Purchase invoice ${purchase.invoiceNumber} pending payment',
        ));
      }

      final overpayment =
          (purchase.amountPaid - invoiceAfterAdvance).clamp(0.0, double.infinity).toDouble();
      if (overpayment > 0) {
        supplier.supplierCreditBalance += overpayment;
        data!.supplierLedger.insert(0, SupplierLedgerEntry(
          id: _uuid.v4(),
          supplierId: supplier.id,
          createdAt: DateTime.now(),
          type: 'ADVANCE',
          amount: overpayment,
          reference: purchase.referenceNumber,
          documentReference: purchase.number,
          note: 'Excess purchase payment held as supplier advance',
        ));
      }
    }

    await persist();
    return purchase;
  }

  Future<void> recordPurchasePayment(
    PurchaseRecord purchase,
    Supplier supplier,
    double amount, {
    String paymentMode = '',
    String reference = '',
    String note = '',
  }) async {
    if (amount <= 0) return;

    final currentDue = purchase.balanceDue;
    final applied = amount.clamp(0.0, currentDue).toDouble();
    if (applied > 0) {
      purchase.laterPaid += applied;
      supplier.openingPayable =
          (supplier.openingPayable - applied).clamp(0.0, double.infinity).toDouble();
      data!.supplierLedger.insert(0, SupplierLedgerEntry(
        id: _uuid.v4(),
        supplierId: supplier.id,
        createdAt: DateTime.now(),
        type: 'PAYMENT',
        amount: applied,
        paymentMode: paymentMode,
        reference: reference,
        documentReference: purchase.number,
        note: note.isEmpty ? 'Later payment for ${purchase.invoiceNumber}' : note,
      ));
    }

    final excess = amount - applied;
    if (excess > 0) {
      supplier.supplierCreditBalance += excess;
      data!.supplierLedger.insert(0, SupplierLedgerEntry(
        id: _uuid.v4(),
        supplierId: supplier.id,
        createdAt: DateTime.now(),
        type: 'ADVANCE',
        amount: excess,
        paymentMode: paymentMode,
        reference: reference,
        documentReference: purchase.number,
        note: note.isEmpty ? 'Excess later payment held as supplier advance' : note,
      ));
    }

    await persist();
  }


  Future<void> recordSupplierPayment(
    Supplier supplier,
    double amount, {
    String paymentMode = '',
    String reference = '',
    String note = '',
  }) async {
    if (amount <= 0) return;

    final originalPayable = supplier.openingPayable;
    final applied =
        amount.clamp(0.0, originalPayable).toDouble();
    supplier.openingPayable =
        (supplier.openingPayable - applied).clamp(0.0, double.infinity).toDouble();

    var remainingToAllocate = applied;
    final allocatedDocuments = <String>[];
    final outstanding = data!.purchases
        .where(
          (purchase) =>
              purchase.supplierId == supplier.id && purchase.balanceDue > 0.005,
        )
        .toList()
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    for (final purchase in outstanding) {
      if (remainingToAllocate <= 0.005) break;
      final allocation =
          remainingToAllocate.clamp(0.0, purchase.balanceDue).toDouble();
      if (allocation <= 0) continue;
      purchase.laterPaid += allocation;
      remainingToAllocate -= allocation;
      allocatedDocuments.add(purchase.number);
    }

    if (applied > 0) {
      data!.supplierLedger.insert(
        0,
        SupplierLedgerEntry(
          id: _uuid.v4(),
          supplierId: supplier.id,
          createdAt: DateTime.now(),
          type: 'PAYMENT',
          amount: applied,
          paymentMode: paymentMode,
          reference: reference,
          documentReference: allocatedDocuments.join(', '),
          note: note.isEmpty
              ? allocatedDocuments.isEmpty
                  ? 'Supplier payment'
                  : 'Supplier payment allocated to ${allocatedDocuments.join(', ')}'
              : note,
        ),
      );
    }

    final excess = amount - applied;
    if (excess > 0) {
      supplier.supplierCreditBalance += excess;
      data!.supplierLedger.insert(
        0,
        SupplierLedgerEntry(
          id: _uuid.v4(),
          supplierId: supplier.id,
          createdAt: DateTime.now(),
          type: 'ADVANCE',
          amount: excess,
          paymentMode: paymentMode,
          reference: reference,
          note: note.isEmpty
              ? 'Supplier advance / excess payment'
              : note,
        ),
      );
    }
    await persist();
  }


  String nextPurchaseReturnNumber() {
    final now = DateTime.now();
    final day = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final count = data!.purchaseReturns.length + 1;
    return 'PRN-$day-${count.toString().padLeft(4, '0')}';
  }

  Future<PurchaseReturnRecord> processPurchaseReturn(PurchaseReturnRecord record) async {
    data!.purchaseReturns.insert(0, record);
    for (final line in record.lines) {
      final product = data!.products.where((e) => e.id == line.productId).firstOrNull;
      if (product != null) {
        product.stock = (product.stock - line.quantity).clamp(0.0, double.infinity).toDouble();
      }
    }
    final supplier = data!.suppliers.where((e) => e.id == record.supplierId).firstOrNull;
    if (supplier != null) {
      final amount = record.total;
      final reducePayable = amount.clamp(0.0, supplier.openingPayable).toDouble();
      supplier.openingPayable = (supplier.openingPayable - reducePayable).clamp(0.0, double.infinity).toDouble();
      final residualCredit = amount - reducePayable;
      if (residualCredit > 0) supplier.supplierCreditBalance += residualCredit;
      data!.supplierLedger.insert(0, SupplierLedgerEntry(
        id: _uuid.v4(),
        supplierId: supplier.id,
        createdAt: DateTime.now(),
        type: 'RETURN',
        amount: amount,
        reference: '',
        documentReference: record.number,
        note: record.reason.isEmpty ? 'Purchase return' : record.reason,
      ));
    }
    await persist();
    return record;
  }

  String nextCustomerId() {
    final now = DateTime.now();
    final prefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final count = data!.customers.where((c) => c.id.startsWith(prefix)).length + 1;
    return '$prefix/${count.toString().padLeft(3, '0')}';
  }

  String nextDocumentNumber(String prefix) {
    final business = data!.business;
    final now = DateTime.now();
    final fy = DocumentRules.financialYearLabel(business, now);
    final normalized = prefix.trim().toUpperCase();
    final existing = <String>[
      ...data!.sales.map((e) => e.documentNumber),
      ...data!.quotations.map((e) => e.number),
    ].where((number) => number.toUpperCase().startsWith('$normalized/')).length;
    return '$normalized/$fy/${(existing + 1).toString().padLeft(6, '0')}';
  }


  Future<Customer> createCustomer({required String name, required String phone, String gstin = '', String businessName = '', String address = '', String state = 'Tamil Nadu', String stateCode = '33'}) async {
    final c = Customer(id: nextCustomerId(), name: name.trim().isEmpty ? 'Customer' : name.trim(), phone: phone.trim(), gstin: gstin.trim(), businessName: businessName.trim(), address: address.trim(), state: state, stateCode: stateCode);
    data!.customers.add(c); await persist(); return c;
  }

  Future<void> addFeedback(int rating, String category, String comment) async {
    data!.feedback.insert(0, FeedbackEntry(id: _uuid.v4(), createdAt: DateTime.now(), rating: rating, category: category, comment: comment)); await persist();
  }

  Future<Sale> completeSale({
    required List<SaleLine> lines,
    required String payment,
    required String customer,
    String customerId = '',
    String customerGstin = '',
    String documentType = 'Retail Bill',
    String placeOfSupplyStateCode = '33',
    bool gstBillRequested = false,
    String requestedByName = '',
    String requestedByContact = '',
    required double discount,
    required double amountPaid,
    required String status,
    Map<String, double> paymentBreakdown = const {},
    double cashReceived = 0,
    double changeReturned = 0,
    Map<String, int> changeDenominations = const {},
    double customerAdvanceCreated = 0,
    String paymentReference = '',
  }) async {
    final business = data!.business;
    final cust = data!.customers.where((e) => e.id == customerId).firstOrNull;
    final normalizedType = DocumentRules.normalizeDocumentType(documentType);
    final prefix = DocumentRules.prefixFor(business, normalizedType);
    final sale = Sale(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      lines: lines,
      paymentMethod: payment,
      amountPaid: amountPaid,
      customerName: customer,
      customerId: customerId,
      customerGstin: customerGstin,
      documentType: normalizedType,
      documentNumber: nextDocumentNumber(prefix),
      placeOfSupplyStateCode: placeOfSupplyStateCode,
      discount: discount,
      status: status,
      paymentBreakdown: paymentBreakdown,
      cashReceived: cashReceived,
      changeReturned: changeReturned,
      changeDenominations: changeDenominations,
      customerAdvanceCreated: customerAdvanceCreated,
      paymentReference: paymentReference,
      businessNameSnapshot: business.businessName,
      businessGstinSnapshot: business.gstin,
      businessAddressSnapshot: business.address,
      businessStateSnapshot: business.state,
      businessStateCodeSnapshot: business.stateCode,
      gstRegistrationTypeSnapshot: business.gstRegistrationType,
      customerAddressSnapshot: cust?.address ?? '',
      customerStateSnapshot: cust?.state ?? '',
      customerStateCodeSnapshot: cust?.stateCode ?? placeOfSupplyStateCode,
      gstBillRequested: gstBillRequested,
      requestedByName: requestedByName.trim(),
      requestedByContact: requestedByContact.trim(),
    );
    data!.sales.insert(0, sale);
    for (final line in lines) {
      final p = data!.products.where((e) => e.id == line.productId).firstOrNull;
      if (p != null) {
        p.stock = (p.stock - line.qty).clamp(0.0, 999999.0).toDouble();
        for (final serial in line.serialNumbers) {
          p.serialNumbers.remove(serial);
        }
      }
    }
    if (cust != null) {
      final due = sale.balanceDue;
      if (due > 0) {
        cust.creditBalance += due;
        data!.ledger.insert(
          0,
          CustomerLedgerEntry(
            id: _uuid.v4(),
            customerId: cust.id,
            createdAt: DateTime.now(),
            type: 'RECEIVABLE',
            amount: due,
            documentReference: sale.documentNumber,
            note: 'Credit / unpaid sale',
          ),
        );
      }
    }
    await persist(); return sale;
  }

  Future<void> addCustomerAdvance(
    Customer customer,
    double amount,
    String documentReference, {
    String paymentMode = '',
    String transactionReference = '',
  }) async {
    if (amount <= 0) return;
    customer.advanceBalance += amount;
    data!.ledger.insert(
      0,
      CustomerLedgerEntry(
        id: _uuid.v4(),
        customerId: customer.id,
        createdAt: DateTime.now(),
        type: 'ADVANCE',
        amount: amount,
        paymentMode: paymentMode,
        reference: transactionReference,
        documentReference: documentReference,
        note: 'Excess payment stored as customer advance',
      ),
    );
    await persist();
  }

  Future<void> useCustomerAdvance(
    Customer customer,
    double amount,
    String documentReference,
  ) async {
    if (amount <= 0) return;
    final used = amount.clamp(0.0, customer.advanceBalance).toDouble();
    customer.advanceBalance =
        (customer.advanceBalance - used).clamp(0.0, double.infinity).toDouble();
    data!.ledger.insert(
      0,
      CustomerLedgerEntry(
        id: _uuid.v4(),
        customerId: customer.id,
        createdAt: DateTime.now(),
        type: 'ADVANCE_USED',
        amount: used,
        paymentMode: 'Customer Advance',
        documentReference: documentReference,
        note: 'Customer advance used against sale',
      ),
    );
    await persist();
  }

  Future<void> receiveCustomerPayment(
    Customer customer,
    double amount, {
    String paymentMode = 'Cash',
    String reference = '',
  }) async {
    if (amount <= 0) return;

    final applied =
        amount.clamp(0.0, customer.creditBalance).toDouble();
    customer.creditBalance =
        (customer.creditBalance - applied).clamp(0.0, double.infinity).toDouble();

    var remainingToAllocate = applied;
    final allocatedDocuments = <String>[];
    final outstandingSales = data!.sales
        .where(
          (sale) =>
              sale.customerId == customer.id && sale.balanceDue > 0.005,
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final sale in outstandingSales) {
      if (remainingToAllocate <= 0.005) break;
      final allocation =
          remainingToAllocate.clamp(0.0, sale.balanceDue).toDouble();
      if (allocation <= 0) continue;
      sale.laterPaid += allocation;
      remainingToAllocate -= allocation;
      allocatedDocuments.add(sale.documentNumber);
      sale.status = sale.balanceDue <= 0.005
          ? 'Paid'
          : sale.settledAmount > 0
              ? 'Partial'
              : 'Unpaid';
    }

    if (applied > 0) {
      data!.ledger.insert(
        0,
        CustomerLedgerEntry(
          id: _uuid.v4(),
          customerId: customer.id,
          createdAt: DateTime.now(),
          type: 'PAYMENT',
          amount: applied,
          paymentMode: paymentMode,
          reference: reference,
          documentReference: allocatedDocuments.join(', '),
          note: allocatedDocuments.isEmpty
              ? 'Customer due collected'
              : 'Customer due collected • Applied to ${allocatedDocuments.join(', ')}',
        ),
      );
    }

    final excess = amount - applied;
    if (excess > 0) {
      customer.advanceBalance += excess;
      data!.ledger.insert(
        0,
        CustomerLedgerEntry(
          id: _uuid.v4(),
          customerId: customer.id,
          createdAt: DateTime.now(),
          type: 'ADVANCE',
          amount: excess,
          paymentMode: paymentMode,
          reference: reference,
          note: 'Excess payment stored as customer advance',
        ),
      );
    }
    await persist();
  }


  Future<Quotation> saveQuotation({required List<SaleLine> lines, String customerId = '', String customerName = 'Walk-in', String notes = ''}) async {
    final business = data!.business;
    final customer = data!.customers.where((e) => e.id == customerId).firstOrNull;
    final q = Quotation(
      id: _uuid.v4(),
      number: nextDocumentNumber(DocumentRules.prefixFor(business, 'Quotation')),
      createdAt: DateTime.now(),
      lines: lines,
      customerId: customerId,
      customerName: customerName,
      customerGstin: customer?.gstin ?? '',
      customerAddress: customer?.address ?? '',
      customerState: customer?.state ?? '',
      customerStateCode: customer?.stateCode ?? '',
      validUntil: DateTime.now().add(const Duration(days: 15)),
      status: 'Draft',
      notes: notes,
      businessNameSnapshot: business.businessName,
      businessGstinSnapshot: business.gstin,
      businessAddressSnapshot: business.address,
      businessStateSnapshot: business.state,
      businessStateCodeSnapshot: business.stateCode,
      gstRegistrationTypeSnapshot: business.gstRegistrationType,
    );
    data!.quotations.insert(0, q);
    await persist();
    return q;
  }
}

extension FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
