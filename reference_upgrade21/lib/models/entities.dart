import 'dart:convert';

class BusinessProfile {
  BusinessProfile({
    this.businessName = '',
    this.businessType = 'General Retail',
    this.customBusinessType = '',
    List<String>? enabledRetailModules,
    this.gstin = '',
    this.gstRegistrationType = 'Not Registered',
    this.defaultSaleTaxInclusive = true,
    this.financialYearStartMonth = 4,
    this.invoicePrefix = 'INV',
    this.billOfSupplyPrefix = 'BOS',
    this.billPrefix = 'BILL',
    this.quotationPrefix = 'QTN',
    this.gstOnlineLookupEnabled = true,
    this.gstLookupProvider = 'GSTVerify',
    this.gstLookupApiKey = '',
    this.address = '',
    this.state = 'Tamil Nadu',
    this.stateCode = '33',
    this.upiId = '',
    this.upiQrPath = '',
    this.upiTestMode = false,
    this.wifiPhoneScannerEnabled = false,
    this.scannerPort = 8765,
    this.phone = '',
    this.showProfitInBilling = true,
    this.activeRole = 'Owner',
  }) : enabledRetailModules = enabledRetailModules ?? <String>[
          'Grocery / FMCG',
          'Fruits / Vegetables',
          'Dairy',
          'Bakery',
          'Household',
          'Personal Care',
          'Stationery',
          'General',
        ];
  String businessName;
  String businessType;
  String customBusinessType;
  List<String> enabledRetailModules;
  String gstin;
  String gstRegistrationType;
  bool defaultSaleTaxInclusive;
  int financialYearStartMonth;
  String invoicePrefix;
  String billOfSupplyPrefix;
  String billPrefix;
  String quotationPrefix;
  bool gstOnlineLookupEnabled;
  String gstLookupProvider;
  String gstLookupApiKey;
  String address;
  String state;
  String stateCode;
  String upiId;
  String upiQrPath;
  bool upiTestMode;
  bool wifiPhoneScannerEnabled;
  int scannerPort;
  String phone;
  bool showProfitInBilling;
  String activeRole;
  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'businessType': businessType,
        'customBusinessType': customBusinessType,
        'enabledRetailModules': enabledRetailModules,
        'gstin': gstin,
        'gstRegistrationType': gstRegistrationType,
        'defaultSaleTaxInclusive': defaultSaleTaxInclusive,
        'financialYearStartMonth': financialYearStartMonth,
        'invoicePrefix': invoicePrefix,
        'billOfSupplyPrefix': billOfSupplyPrefix,
        'billPrefix': billPrefix,
        'quotationPrefix': quotationPrefix,
        'gstOnlineLookupEnabled': gstOnlineLookupEnabled,
        'gstLookupProvider': gstLookupProvider,
        'gstLookupApiKey': gstLookupApiKey,
        'address': address,
        'state': state,
        'stateCode': stateCode,
        'upiId': upiId,
        'upiQrPath': upiQrPath,
        'upiTestMode': upiTestMode,
        'wifiPhoneScannerEnabled': wifiPhoneScannerEnabled,
        'scannerPort': scannerPort,
        'phone': phone,
        'showProfitInBilling': showProfitInBilling,
        'activeRole': activeRole,
      };
  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
        businessName: j['businessName'] as String? ?? '',
        businessType: j['businessType'] as String? ?? 'General Retail',
        customBusinessType: j['customBusinessType'] as String? ?? '',
        enabledRetailModules: j['enabledRetailModules'] is List
            ? (j['enabledRetailModules'] as List).map((e) => e.toString()).toList()
            : null,
        gstin: j['gstin'] as String? ?? '',
        gstRegistrationType: j['gstRegistrationType'] as String? ??
            (((j['gstin'] as String? ?? '').isNotEmpty) ? 'Regular GST' : 'Not Registered'),
        defaultSaleTaxInclusive: j['defaultSaleTaxInclusive'] as bool? ?? true,
        financialYearStartMonth: (j['financialYearStartMonth'] as num?)?.toInt() ?? 4,
        invoicePrefix: j['invoicePrefix'] as String? ?? 'INV',
        billOfSupplyPrefix: j['billOfSupplyPrefix'] as String? ?? 'BOS',
        billPrefix: j['billPrefix'] as String? ?? 'BILL',
        quotationPrefix: j['quotationPrefix'] as String? ?? 'QTN',
        gstOnlineLookupEnabled: j['gstOnlineLookupEnabled'] as bool? ?? true,
        gstLookupProvider: j['gstLookupProvider'] as String? ?? 'GSTVerify',
        gstLookupApiKey: j['gstLookupApiKey'] as String? ?? '',
        address: j['address'] as String? ?? '',
        state: j['state'] as String? ?? 'Tamil Nadu',
        stateCode: j['stateCode'] as String? ?? '33',
        upiId: j['upiId'] as String? ?? '',
        upiQrPath: j['upiQrPath'] as String? ?? '',
        upiTestMode: j['upiTestMode'] as bool? ?? false,
        wifiPhoneScannerEnabled:
            j['wifiPhoneScannerEnabled'] as bool? ?? false,
        scannerPort: (j['scannerPort'] as num?)?.toInt() ?? 8765,
        phone: j['phone'] as String? ?? '',
        showProfitInBilling: j['showProfitInBilling'] as bool? ?? true,
        activeRole: j['activeRole'] as String? ?? 'Owner',
      );

  String get businessTypeLabel =>
      businessType == 'Other / Custom' && customBusinessType.trim().isNotEmpty
          ? customBusinessType.trim()
          : businessType;

  bool get isRegularGst => gstRegistrationType == 'Regular GST';
  bool get isCompositionGst => gstRegistrationType == 'Composition Scheme';
  bool get isGstRegistered => isRegularGst || isCompositionGst;
  bool get canClaimItc => isRegularGst;
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.gstRate,
    required this.stock,
    required this.reorderLevel,
    this.productCode = '',
    this.hsnSac = '',
    this.gstApplicable = true,
    this.taxCategory = 'Taxable',
    this.taxInclusive = true,
    this.defaultDiscountPercent = 0,
    this.defaultDiscountAmount = 0,
    this.expiryDate,
    this.ingredients = '',
    this.nutrition = '',
    this.allergens = '',
    this.supplier = 'Local Supplier',
    this.unit = 'pcs',
    this.weighted = false,
    this.brand = '',
    this.manufacturer = '',
    this.supplierId = '',
    this.packageSize = '',
    this.purchaseUnit = 'unit',
    this.purchaseQuantity = 1,
    this.purchaseInvoicePrice = 0,
    this.purchasePriceIncludesTax = false,
    this.packConversionQty = 1,
    this.supplierDiscountPercent = 0,
    this.freightCost = 0,
    this.itcEligible = false,
    this.imageUrl = '',
    this.mrp = 0,
    this.rackLocation = '',
    this.businessType = '',
    this.subcategory = '',
    Map<String, bool>? trackingFlags,
    List<String>? serialNumbers,
    Map<String, String>? customAttributes,
  })  : trackingFlags = trackingFlags ?? <String, bool>{},
        serialNumbers = serialNumbers ?? <String>[],
        customAttributes = customAttributes ?? <String, String>{};

  String id;
  String name;
  String barcode;
  String productCode;
  String category;
  double purchasePrice;
  double sellingPrice;
  double gstRate;
  bool gstApplicable;
  String taxCategory;
  bool taxInclusive;
  String hsnSac;
  double defaultDiscountPercent;
  double defaultDiscountAmount;
  double stock;
  double reorderLevel;
  DateTime? expiryDate;
  String ingredients;
  String nutrition;
  String allergens;
  String supplier;
  String unit;
  bool weighted;
  String brand;
  String manufacturer;
  String supplierId;
  String packageSize;
  String purchaseUnit;
  double purchaseQuantity;
  double purchaseInvoicePrice;
  bool purchasePriceIncludesTax;
  double packConversionQty;
  double supplierDiscountPercent;
  double freightCost;
  bool itcEligible;
  String imageUrl;
  double mrp;
  String rackLocation;
  String businessType;
  String subcategory;
  Map<String, bool> trackingFlags;
  List<String> serialNumbers;
  Map<String, String> customAttributes;

  double get margin => sellingPrice - purchasePrice;
  double get marginPercent => sellingPrice <= 0 ? 0 : margin / sellingPrice * 100;
  double get defaultDiscountValue => defaultDiscountAmount + (sellingPrice * defaultDiscountPercent / 100);
  double get defaultNetPrice => (sellingPrice - defaultDiscountValue).clamp(0.0, double.infinity).toDouble();
  double get defaultProfit => defaultNetPrice - purchasePrice;
  String get stockLabel => '${stock % 1 == 0 ? stock.toInt() : stock.toStringAsFixed(2)} $unit';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'productCode': productCode,
        'category': category,
        'purchasePrice': purchasePrice,
        'sellingPrice': sellingPrice,
        'gstRate': gstRate,
        'gstApplicable': gstApplicable,
        'taxCategory': taxCategory,
        'taxInclusive': taxInclusive,
        'hsnSac': hsnSac,
        'defaultDiscountPercent': defaultDiscountPercent,
        'defaultDiscountAmount': defaultDiscountAmount,
        'stock': stock,
        'reorderLevel': reorderLevel,
        'expiryDate': expiryDate?.toIso8601String(),
        'ingredients': ingredients,
        'nutrition': nutrition,
        'allergens': allergens,
        'supplier': supplier,
        'unit': unit,
        'weighted': weighted,
        'brand': brand,
        'manufacturer': manufacturer,
        'supplierId': supplierId,
        'packageSize': packageSize,
        'purchaseUnit': purchaseUnit,
        'purchaseQuantity': purchaseQuantity,
        'purchaseInvoicePrice': purchaseInvoicePrice,
        'purchasePriceIncludesTax': purchasePriceIncludesTax,
        'packConversionQty': packConversionQty,
        'supplierDiscountPercent': supplierDiscountPercent,
        'freightCost': freightCost,
        'itcEligible': itcEligible,
        'imageUrl': imageUrl,
        'mrp': mrp,
        'rackLocation': rackLocation,
        'businessType': businessType,
        'subcategory': subcategory,
        'trackingFlags': trackingFlags,
        'serialNumbers': serialNumbers,
        'customAttributes': customAttributes,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as String,
        name: j['name'] as String,
        barcode: j['barcode'] as String? ?? '',
        productCode: j['productCode'] as String? ?? '',
        category: j['category'] as String? ?? 'General',
        purchasePrice: (j['purchasePrice'] as num?)?.toDouble() ?? 0,
        sellingPrice: (j['sellingPrice'] as num?)?.toDouble() ?? 0,
        gstRate: (j['gstRate'] as num?)?.toDouble() ?? 0,
        gstApplicable: j['gstApplicable'] as bool? ?? ((j['gstRate'] as num?)?.toDouble() ?? 0) > 0,
        taxCategory: j['taxCategory'] as String? ??
            (((j['gstRate'] as num?)?.toDouble() ?? 0) > 0 ? 'Taxable' : 'Non-GST'),
        taxInclusive: j['taxInclusive'] as bool? ?? true,
        hsnSac: j['hsnSac'] as String? ?? '',
        defaultDiscountPercent: (j['defaultDiscountPercent'] as num?)?.toDouble() ?? 0,
        defaultDiscountAmount: (j['defaultDiscountAmount'] as num?)?.toDouble() ?? 0,
        stock: (j['stock'] as num?)?.toDouble() ?? 0,
        reorderLevel: (j['reorderLevel'] as num?)?.toDouble() ?? 5,
        expiryDate: j['expiryDate'] == null ? null : DateTime.tryParse(j['expiryDate'] as String),
        ingredients: j['ingredients'] as String? ?? '',
        nutrition: j['nutrition'] as String? ?? '',
        allergens: j['allergens'] as String? ?? '',
        supplier: j['supplier'] as String? ?? 'Local Supplier',
        unit: j['unit'] as String? ?? 'pcs',
        weighted: j['weighted'] as bool? ?? false,
        brand: j['brand'] as String? ?? '',
        manufacturer: j['manufacturer'] as String? ?? '',
        supplierId: j['supplierId'] as String? ?? '',
        packageSize: j['packageSize'] as String? ?? '',
        purchaseUnit: j['purchaseUnit'] as String? ?? 'unit',
        purchaseQuantity: (j['purchaseQuantity'] as num?)?.toDouble() ?? 1,
        purchaseInvoicePrice: (j['purchaseInvoicePrice'] as num?)?.toDouble() ?? 0,
        purchasePriceIncludesTax: j['purchasePriceIncludesTax'] as bool? ?? false,
        packConversionQty: (j['packConversionQty'] as num?)?.toDouble() ?? 1,
        supplierDiscountPercent: (j['supplierDiscountPercent'] as num?)?.toDouble() ?? 0,
        freightCost: (j['freightCost'] as num?)?.toDouble() ?? 0,
        itcEligible: j['itcEligible'] as bool? ?? false,
        imageUrl: j['imageUrl'] as String? ?? '',
        mrp: (j['mrp'] as num?)?.toDouble() ?? 0,
        rackLocation: j['rackLocation'] as String? ?? '',
        businessType: j['businessType'] as String? ?? '',
        subcategory: j['subcategory'] as String? ?? '',
        trackingFlags: j['trackingFlags'] is Map
            ? Map<String, bool>.from((j['trackingFlags'] as Map).map((key, value) => MapEntry(key.toString(), value == true)))
            : <String, bool>{},
        serialNumbers: j['serialNumbers'] is List
            ? (j['serialNumbers'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
            : <String>[],
        customAttributes: j['customAttributes'] is Map
            ? Map<String, String>.from((j['customAttributes'] as Map).map((key, value) => MapEntry(key.toString(), value?.toString() ?? '')))
            : <String, String>{},
      );
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.discountPercent = 0,
    this.creditBalance = 0,
    this.advanceBalance = 0,
    this.gstin = '',
    this.businessName = '',
    this.address = '',
    this.state = 'Tamil Nadu',
    this.stateCode = '33',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
  String id;
  String name;
  String phone;
  double discountPercent;
  double creditBalance; // amount customer owes shop
  double advanceBalance; // amount shop holds for customer
  String gstin;
  String businessName;
  String address;
  String state;
  String stateCode;
  DateTime createdAt;
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'discountPercent': discountPercent,
        'creditBalance': creditBalance,
        'advanceBalance': advanceBalance,
        'gstin': gstin,
        'businessName': businessName,
        'address': address,
        'state': state,
        'stateCode': stateCode,
        'createdAt': createdAt.toIso8601String(),
      };
  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0,
        creditBalance: (j['creditBalance'] as num?)?.toDouble() ?? 0,
        advanceBalance: (j['advanceBalance'] as num?)?.toDouble() ?? 0,
        gstin: j['gstin'] as String? ?? '',
        businessName: j['businessName'] as String? ?? '',
        address: j['address'] as String? ?? '',
        state: j['state'] as String? ?? 'Tamil Nadu',
        stateCode: j['stateCode'] as String? ?? '33',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class CustomerLedgerEntry {
  CustomerLedgerEntry({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.type,
    required this.amount,
    this.paymentMode = '',
    this.reference = '',
    this.documentReference = '',
    this.note = '',
  });
  String id;
  String customerId;
  DateTime createdAt;
  String type; // RECEIVABLE, PAYMENT, ADVANCE, ADVANCE_USED
  double amount;
  String paymentMode;
  String reference;
  String documentReference;
  String note;
  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'createdAt': createdAt.toIso8601String(),
        'type': type,
        'amount': amount,
        'paymentMode': paymentMode,
        'reference': reference,
        'documentReference': documentReference,
        'note': note,
      };
  factory CustomerLedgerEntry.fromJson(Map<String, dynamic> j) => CustomerLedgerEntry(
        id: j['id'] as String,
        customerId: j['customerId'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        type: j['type'] as String? ?? 'PAYMENT',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        paymentMode: j['paymentMode'] as String? ?? '',
        reference: j['reference'] as String? ?? '',
        documentReference: j['documentReference'] as String? ?? '',
        note: j['note'] as String? ?? '',
      );
}

class Employee {
  Employee({required this.id, required this.name, required this.role, required this.salary, this.rating = 4, this.attendance = 100, this.salesHandled = 0});
  String id;
  String name;
  String role;
  double salary;
  double rating;
  double attendance;
  double salesHandled;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role, 'salary': salary, 'rating': rating, 'attendance': attendance, 'salesHandled': salesHandled};
  factory Employee.fromJson(Map<String, dynamic> j) => Employee(id: j['id'] as String, name: j['name'] as String, role: j['role'] as String? ?? 'Staff', salary: (j['salary'] as num?)?.toDouble() ?? 0, rating: (j['rating'] as num?)?.toDouble() ?? 4, attendance: (j['attendance'] as num?)?.toDouble() ?? 100, salesHandled: (j['salesHandled'] as num?)?.toDouble() ?? 0);
}

class Branch {
  Branch({required this.id, required this.name, required this.city, this.sales = 0, this.profit = 0, this.inventoryValue = 0, this.expiryLoss = 0});
  String id;
  String name;
  String city;
  double sales;
  double profit;
  double inventoryValue;
  double expiryLoss;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'city': city, 'sales': sales, 'profit': profit, 'inventoryValue': inventoryValue, 'expiryLoss': expiryLoss};
  factory Branch.fromJson(Map<String, dynamic> j) => Branch(id: j['id'] as String, name: j['name'] as String, city: j['city'] as String? ?? '', sales: (j['sales'] as num?)?.toDouble() ?? 0, profit: (j['profit'] as num?)?.toDouble() ?? 0, inventoryValue: (j['inventoryValue'] as num?)?.toDouble() ?? 0, expiryLoss: (j['expiryLoss'] as num?)?.toDouble() ?? 0);
}

class SaleLine {
  SaleLine({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.unitCost,
    required this.gstRate,
    this.unit = 'pcs',
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.hsnSac = '',
    this.gstApplicable = true,
    this.taxCategory = 'Taxable',
    this.taxInclusive = true,
    this.imageUrl = '',
    this.note = '',
    List<String>? serialNumbers,
  }) : serialNumbers = serialNumbers ?? <String>[];
  String productId;
  String name;
  double qty;
  double unitPrice;
  double unitCost;
  double gstRate;
  String unit;
  double discountPercent;
  double discountAmount;
  String hsnSac;
  bool gstApplicable;
  String taxCategory;
  bool taxInclusive;
  String imageUrl;
  String note;
  List<String> serialNumbers;
  double get gross => unitPrice * qty;
  double get discountValue => (gross * discountPercent / 100) + discountAmount;
  double get discountedValue => (gross - discountValue).clamp(0.0, double.infinity).toDouble();
  bool get isOutputTaxable => gstApplicable && taxCategory == 'Taxable' && gstRate > 0;
  double get taxableValue => !isOutputTaxable
      ? discountedValue
      : (taxInclusive ? discountedValue / (1 + gstRate / 100) : discountedValue);
  double get gst => !isOutputTaxable
      ? 0
      : (taxInclusive ? discountedValue - taxableValue : taxableValue * gstRate / 100);
  double get net => !isOutputTaxable ? discountedValue : taxableValue + gst;
  double get profit => (isOutputTaxable ? taxableValue : net) - (unitCost * qty);
  double get profitPercent {
    final revenue = isOutputTaxable ? taxableValue : net;
    return revenue <= 0 ? 0 : profit / revenue * 100;
  }
  Map<String, dynamic> toJson() => {'productId': productId, 'name': name, 'qty': qty, 'unitPrice': unitPrice, 'unitCost': unitCost, 'gstRate': gstRate, 'unit': unit, 'discountPercent': discountPercent, 'discountAmount': discountAmount, 'hsnSac': hsnSac, 'gstApplicable': gstApplicable, 'taxCategory': taxCategory, 'taxInclusive': taxInclusive, 'imageUrl': imageUrl, 'note': note, 'serialNumbers': serialNumbers};
  factory SaleLine.fromJson(Map<String, dynamic> j) => SaleLine(productId: j['productId'] as String, name: j['name'] as String, qty: (j['qty'] as num?)?.toDouble() ?? 0, unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0, unitCost: (j['unitCost'] as num?)?.toDouble() ?? 0, gstRate: (j['gstRate'] as num?)?.toDouble() ?? 0, unit: j['unit'] as String? ?? 'pcs', discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0, discountAmount: (j['discountAmount'] as num?)?.toDouble() ?? 0, hsnSac: j['hsnSac'] as String? ?? '', gstApplicable: j['gstApplicable'] as bool? ?? true, taxCategory: j['taxCategory'] as String? ?? ((j['gstApplicable'] as bool? ?? true) ? 'Taxable' : 'Non-GST'), taxInclusive: j['taxInclusive'] as bool? ?? true, imageUrl: j['imageUrl'] as String? ?? '', note: j['note'] as String? ?? '', serialNumbers: j['serialNumbers'] is List ? (j['serialNumbers'] as List).map((e) => e.toString()).toList() : <String>[]);
}

class Sale {
  Sale({
    required this.id,
    required this.createdAt,
    required this.lines,
    required this.paymentMethod,
    required this.amountPaid,
    this.customerName = 'Walk-in',
    this.customerId = '',
    this.discount = 0,
    this.status = 'Paid',
    this.documentType = 'Retail Bill',
    this.documentNumber = '',
    this.customerGstin = '',
    this.placeOfSupplyStateCode = '33',
    this.paymentBreakdown = const {},
    this.cashReceived = 0,
    this.changeReturned = 0,
    this.changeDenominations = const {},
    this.customerAdvanceCreated = 0,
    this.paymentReference = '',
    this.laterPaid = 0,
    this.businessNameSnapshot = '',
    this.businessGstinSnapshot = '',
    this.businessAddressSnapshot = '',
    this.businessStateSnapshot = '',
    this.businessStateCodeSnapshot = '',
    this.gstRegistrationTypeSnapshot = '',
    this.customerAddressSnapshot = '',
    this.customerStateSnapshot = '',
    this.customerStateCodeSnapshot = '',
    this.gstBillRequested = false,
    this.requestedByName = '',
    this.requestedByContact = '',
  });
  String id;
  DateTime createdAt;
  List<SaleLine> lines;
  String paymentMethod;
  double amountPaid;
  String customerName;
  String customerId;
  double discount;
  String status;
  String documentType;
  String documentNumber;
  String customerGstin;
  String placeOfSupplyStateCode;
  Map<String, double> paymentBreakdown;
  double cashReceived;
  double changeReturned;
  Map<String, int> changeDenominations;
  double customerAdvanceCreated;
  String paymentReference;
  double laterPaid;
  String businessNameSnapshot;
  String businessGstinSnapshot;
  String businessAddressSnapshot;
  String businessStateSnapshot;
  String businessStateCodeSnapshot;
  String gstRegistrationTypeSnapshot;
  String customerAddressSnapshot;
  String customerStateSnapshot;
  String customerStateCodeSnapshot;
  bool gstBillRequested;
  String requestedByName;
  String requestedByContact;
  double get subtotal => lines.fold<double>(0.0, (a, b) => a + b.net);
  double get total => (subtotal - discount).clamp(0.0, double.infinity).toDouble();
  double get discountFactor => subtotal <= 0 ? 1 : (total / subtotal).clamp(0.0, 1.0).toDouble();
  double get profit => lines.fold<double>(0.0, (a, b) => a + b.profit) - discount;
  double get taxableValue => lines.fold<double>(0.0, (a, b) => a + b.taxableValue) * discountFactor;
  double get gst => lines.fold<double>(0.0, (a, b) => a + b.gst) * discountFactor;
  double get settledAmount => amountPaid + laterPaid;
  double get balanceDue =>
      (total - settledAmount).clamp(0.0, double.infinity).toDouble();
  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'lines': lines.map((e) => e.toJson()).toList(),
        'paymentMethod': paymentMethod,
        'amountPaid': amountPaid,
        'customerName': customerName,
        'customerId': customerId,
        'discount': discount,
        'status': status,
        'documentType': documentType,
        'documentNumber': documentNumber,
        'customerGstin': customerGstin,
        'placeOfSupplyStateCode': placeOfSupplyStateCode,
        'paymentBreakdown': paymentBreakdown,
        'cashReceived': cashReceived,
        'changeReturned': changeReturned,
        'changeDenominations': changeDenominations,
        'customerAdvanceCreated': customerAdvanceCreated,
        'paymentReference': paymentReference,
        'laterPaid': laterPaid,
        'businessNameSnapshot': businessNameSnapshot,
        'businessGstinSnapshot': businessGstinSnapshot,
        'businessAddressSnapshot': businessAddressSnapshot,
        'businessStateSnapshot': businessStateSnapshot,
        'businessStateCodeSnapshot': businessStateCodeSnapshot,
        'gstRegistrationTypeSnapshot': gstRegistrationTypeSnapshot,
        'customerAddressSnapshot': customerAddressSnapshot,
        'customerStateSnapshot': customerStateSnapshot,
        'customerStateCodeSnapshot': customerStateCodeSnapshot,
        'gstBillRequested': gstBillRequested,
        'requestedByName': requestedByName,
        'requestedByContact': requestedByContact,
      };
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        lines: (j['lines'] as List? ?? []).map((e) => SaleLine.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        paymentMethod: j['paymentMethod'] as String? ?? 'Cash',
        amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
        customerName: j['customerName'] as String? ?? 'Walk-in',
        customerId: j['customerId'] as String? ?? '',
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? 'Paid',
        documentType: j['documentType'] as String? ?? 'Retail Bill',
        documentNumber: j['documentNumber'] as String? ?? '',
        customerGstin: j['customerGstin'] as String? ?? '',
        placeOfSupplyStateCode: j['placeOfSupplyStateCode'] as String? ?? '33',
        paymentBreakdown: Map<String, double>.from((j['paymentBreakdown'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
        cashReceived: (j['cashReceived'] as num?)?.toDouble() ?? 0,
        changeReturned: (j['changeReturned'] as num?)?.toDouble() ?? 0,
        changeDenominations: Map<String, int>.from((j['changeDenominations'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))),
        customerAdvanceCreated: (j['customerAdvanceCreated'] as num?)?.toDouble() ?? 0,
        paymentReference: j['paymentReference'] as String? ?? '',
        laterPaid: (j['laterPaid'] as num?)?.toDouble() ?? 0,
        businessNameSnapshot: j['businessNameSnapshot'] as String? ?? '',
        businessGstinSnapshot: j['businessGstinSnapshot'] as String? ?? '',
        businessAddressSnapshot: j['businessAddressSnapshot'] as String? ?? '',
        businessStateSnapshot: j['businessStateSnapshot'] as String? ?? '',
        businessStateCodeSnapshot: j['businessStateCodeSnapshot'] as String? ?? '',
        gstRegistrationTypeSnapshot: j['gstRegistrationTypeSnapshot'] as String? ?? '',
        customerAddressSnapshot: j['customerAddressSnapshot'] as String? ?? '',
        customerStateSnapshot: j['customerStateSnapshot'] as String? ?? '',
        customerStateCodeSnapshot: j['customerStateCodeSnapshot'] as String? ?? '',
        gstBillRequested: j['gstBillRequested'] as bool? ?? false,
        requestedByName: j['requestedByName'] as String? ?? '',
        requestedByContact: j['requestedByContact'] as String? ?? '',
      );
}

class Quotation {
  Quotation({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.lines,
    this.customerId = '',
    this.customerName = 'Walk-in',
    this.customerGstin = '',
    this.customerAddress = '',
    this.customerState = '',
    this.customerStateCode = '',
    this.validUntil,
    this.status = 'Draft',
    this.notes = '',
    this.businessNameSnapshot = '',
    this.businessGstinSnapshot = '',
    this.businessAddressSnapshot = '',
    this.businessStateSnapshot = '',
    this.businessStateCodeSnapshot = '',
    this.gstRegistrationTypeSnapshot = '',
    this.linkedSaleId = '',
  });
  String id;
  String number;
  DateTime createdAt;
  List<SaleLine> lines;
  String customerId;
  String customerName;
  String customerGstin;
  String customerAddress;
  String customerState;
  String customerStateCode;
  DateTime? validUntil;
  String status;
  String notes;
  String businessNameSnapshot;
  String businessGstinSnapshot;
  String businessAddressSnapshot;
  String businessStateSnapshot;
  String businessStateCodeSnapshot;
  String gstRegistrationTypeSnapshot;
  String linkedSaleId;
  double get total => lines.fold<double>(0, (a, b) => a + b.net);
  double get gst => lines.fold<double>(0, (a, b) => a + b.gst);
  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'createdAt': createdAt.toIso8601String(),
        'lines': lines.map((e) => e.toJson()).toList(),
        'customerId': customerId,
        'customerName': customerName,
        'customerGstin': customerGstin,
        'customerAddress': customerAddress,
        'customerState': customerState,
        'customerStateCode': customerStateCode,
        'validUntil': validUntil?.toIso8601String(),
        'status': status,
        'notes': notes,
        'businessNameSnapshot': businessNameSnapshot,
        'businessGstinSnapshot': businessGstinSnapshot,
        'businessAddressSnapshot': businessAddressSnapshot,
        'businessStateSnapshot': businessStateSnapshot,
        'businessStateCodeSnapshot': businessStateCodeSnapshot,
        'gstRegistrationTypeSnapshot': gstRegistrationTypeSnapshot,
        'linkedSaleId': linkedSaleId,
      };
  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        id: j['id'] as String,
        number: j['number'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        lines: (j['lines'] as List? ?? [])
            .map((e) => SaleLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        customerId: j['customerId'] as String? ?? '',
        customerName: j['customerName'] as String? ?? 'Walk-in',
        customerGstin: j['customerGstin'] as String? ?? '',
        customerAddress: j['customerAddress'] as String? ?? '',
        customerState: j['customerState'] as String? ?? '',
        customerStateCode: j['customerStateCode'] as String? ?? '',
        validUntil: j['validUntil'] == null ? null : DateTime.tryParse(j['validUntil'] as String),
        status: j['status'] as String? ?? 'Draft',
        notes: j['notes'] as String? ?? '',
        businessNameSnapshot: j['businessNameSnapshot'] as String? ?? '',
        businessGstinSnapshot: j['businessGstinSnapshot'] as String? ?? '',
        businessAddressSnapshot: j['businessAddressSnapshot'] as String? ?? '',
        businessStateSnapshot: j['businessStateSnapshot'] as String? ?? '',
        businessStateCodeSnapshot: j['businessStateCodeSnapshot'] as String? ?? '',
        gstRegistrationTypeSnapshot: j['gstRegistrationTypeSnapshot'] as String? ?? '',
        linkedSaleId: j['linkedSaleId'] as String? ?? '',
      );
}


class PurchaseLine {
  PurchaseLine({
    required this.productId,
    required this.productName,
    required this.purchaseUnit,
    required this.sellingUnit,
    required this.quantity,
    this.freeQuantity = 0,
    this.conversionQty = 1,
    required this.purchasePricePerUnit,
    this.supplierDiscountPercent = 0,
    this.freightCost = 0,
    this.gstApplicable = false,
    this.gstRate = 0,
    this.taxCategory = 'Taxable',
    this.saleGstRate = 0,
    this.saleTaxInclusive = true,
    this.hsnSac = '',
    this.itcEligible = false,
    this.purchasePriceIncludesTax = false,
    this.batchNo = '',
    this.serialNumbers = '',
    this.manufactureDate,
    this.expiryDate,
    this.mrp = 0,
    this.sellingPrice = 0,
    this.defaultDiscountPercent = 0,
    this.reorderLevel = 0,
    this.rackLocation = '',
    this.note = '',
  });

  String productId;
  String productName;
  String purchaseUnit;
  String sellingUnit;
  double quantity;
  double freeQuantity;
  double conversionQty;
  double purchasePricePerUnit;
  double supplierDiscountPercent;
  double freightCost;
  bool gstApplicable;
  double gstRate;
  String taxCategory;
  double saleGstRate;
  bool saleTaxInclusive;
  String hsnSac;
  bool itcEligible;
  bool purchasePriceIncludesTax;
  String batchNo;
  String serialNumbers;
  DateTime? manufactureDate;
  DateTime? expiryDate;
  double mrp;
  double sellingPrice;
  double defaultDiscountPercent;
  double reorderLevel;
  String rackLocation;
  String note;

  double get paidUnits => quantity;
  double get totalPurchaseUnits => quantity + freeQuantity;
  double get stockReceived => totalPurchaseUnits * conversionQty;
  double get grossBeforeDiscount => quantity * purchasePricePerUnit;
  double get supplierDiscountValue => grossBeforeDiscount * supplierDiscountPercent / 100;
  double get invoiceLineBeforeTax => (grossBeforeDiscount - supplierDiscountValue).clamp(0.0, double.infinity).toDouble();
  double get taxableBase {
    if (!gstApplicable || gstRate <= 0) return invoiceLineBeforeTax;
    if (!purchasePriceIncludesTax) return invoiceLineBeforeTax;
    return invoiceLineBeforeTax / (1 + gstRate / 100);
  }
  double get inputGst => gstApplicable && gstRate > 0 ? (purchasePriceIncludesTax ? invoiceLineBeforeTax - taxableBase : taxableBase * gstRate / 100) : 0;
  double get supplierInvoiceLineTotal => purchasePriceIncludesTax ? invoiceLineBeforeTax + freightCost : invoiceLineBeforeTax + inputGst + freightCost;
  double get inventoryCostPool => taxableBase + freightCost + (itcEligible ? 0 : inputGst);
  double get effectiveCostPerSellingUnit => stockReceived <= 0 ? 0 : inventoryCostPool / stockReceived;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'purchaseUnit': purchaseUnit,
    'sellingUnit': sellingUnit,
    'quantity': quantity,
    'freeQuantity': freeQuantity,
    'conversionQty': conversionQty,
    'purchasePricePerUnit': purchasePricePerUnit,
    'supplierDiscountPercent': supplierDiscountPercent,
    'freightCost': freightCost,
    'gstApplicable': gstApplicable,
    'gstRate': gstRate,
    'taxCategory': taxCategory,
    'saleGstRate': saleGstRate,
    'saleTaxInclusive': saleTaxInclusive,
    'hsnSac': hsnSac,
    'itcEligible': itcEligible,
    'purchasePriceIncludesTax': purchasePriceIncludesTax,
    'batchNo': batchNo,
    'serialNumbers': serialNumbers,
    'manufactureDate': manufactureDate?.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'mrp': mrp,
    'sellingPrice': sellingPrice,
    'defaultDiscountPercent': defaultDiscountPercent,
    'reorderLevel': reorderLevel,
    'rackLocation': rackLocation,
    'note': note,
  };

  factory PurchaseLine.fromJson(Map<String, dynamic> j) => PurchaseLine(
    productId: j['productId'] as String? ?? '',
    productName: j['productName'] as String? ?? '',
    purchaseUnit: j['purchaseUnit'] as String? ?? 'unit',
    sellingUnit: j['sellingUnit'] as String? ?? 'pcs',
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
    freeQuantity: (j['freeQuantity'] as num?)?.toDouble() ?? 0,
    conversionQty: (j['conversionQty'] as num?)?.toDouble() ?? 1,
    purchasePricePerUnit: (j['purchasePricePerUnit'] as num?)?.toDouble() ?? 0,
    supplierDiscountPercent: (j['supplierDiscountPercent'] as num?)?.toDouble() ?? 0,
    freightCost: (j['freightCost'] as num?)?.toDouble() ?? 0,
    gstApplicable: j['gstApplicable'] as bool? ?? false,
    gstRate: (j['gstRate'] as num?)?.toDouble() ?? 0,
    taxCategory: j['taxCategory'] as String? ?? ((j['gstApplicable'] as bool? ?? false) ? 'Taxable' : 'Non-GST'),
    saleGstRate: (j['saleGstRate'] as num?)?.toDouble() ?? (j['gstRate'] as num?)?.toDouble() ?? 0,
    saleTaxInclusive: j['saleTaxInclusive'] as bool? ?? true,
    hsnSac: j['hsnSac'] as String? ?? '',
    itcEligible: j['itcEligible'] as bool? ?? false,
    purchasePriceIncludesTax: j['purchasePriceIncludesTax'] as bool? ?? false,
    batchNo: j['batchNo'] as String? ?? '',
    serialNumbers: j['serialNumbers'] as String? ?? '',
    manufactureDate: j['manufactureDate'] == null ? null : DateTime.tryParse(j['manufactureDate'] as String),
    expiryDate: j['expiryDate'] == null ? null : DateTime.tryParse(j['expiryDate'] as String),
    mrp: (j['mrp'] as num?)?.toDouble() ?? 0,
    sellingPrice: (j['sellingPrice'] as num?)?.toDouble() ?? 0,
    defaultDiscountPercent: (j['defaultDiscountPercent'] as num?)?.toDouble() ?? 0,
    reorderLevel: (j['reorderLevel'] as num?)?.toDouble() ?? 0,
    rackLocation: j['rackLocation'] as String? ?? '',
    note: j['note'] as String? ?? '',
  );
}

class PurchaseRecord {
  PurchaseRecord({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.supplierId,
    required this.supplierCode,
    required this.supplierName,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.lines,
    this.sourceType = 'SUPPLIER',
    this.sourceName = '',
    this.purchaseOrderNumber = '',
    this.paymentTerms = 'Cash',
    this.paymentMode = 'Cash',
    this.amountPaid = 0,
    this.supplierAdvanceUsed = 0,
    this.laterPaid = 0,
    this.referenceNumber = '',
    this.status = 'Received',
    this.note = '',
  });

  String id;
  String number;
  DateTime createdAt;
  String supplierId;
  String supplierCode;
  String supplierName;
  String invoiceNumber;
  DateTime invoiceDate;
  String sourceType; // SUPPLIER, LOCAL, PRODUCTION
  String sourceName;
  String purchaseOrderNumber;
  String paymentTerms;
  List<PurchaseLine> lines;
  String paymentMode;
  double amountPaid;
  double supplierAdvanceUsed;
  double laterPaid;
  String referenceNumber;
  String status;
  String note;

  double get subtotal => lines.fold<double>(0, (a, b) => a + b.taxableBase);
  double get totalInputGst => lines.fold<double>(0, (a, b) => a + b.inputGst);
  double get freightTotal => lines.fold<double>(0, (a, b) => a + b.freightCost);
  double get supplierDiscountTotal => lines.fold<double>(0, (a, b) => a + b.supplierDiscountValue);
  double get total => lines.fold<double>(0, (a, b) => a + b.supplierInvoiceLineTotal);
  double get settledAmount => amountPaid + supplierAdvanceUsed + laterPaid;
  double get balanceDue => (total - settledAmount).clamp(0.0, double.infinity).toDouble();
  double get excessPaid => (settledAmount - total).clamp(0.0, double.infinity).toDouble();

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'createdAt': createdAt.toIso8601String(),
    'supplierId': supplierId,
    'supplierCode': supplierCode,
    'supplierName': supplierName,
    'invoiceNumber': invoiceNumber,
    'invoiceDate': invoiceDate.toIso8601String(),
    'sourceType': sourceType,
    'sourceName': sourceName,
    'purchaseOrderNumber': purchaseOrderNumber,
    'paymentTerms': paymentTerms,
    'lines': lines.map((e) => e.toJson()).toList(),
    'paymentMode': paymentMode,
    'amountPaid': amountPaid,
    'supplierAdvanceUsed': supplierAdvanceUsed,
    'laterPaid': laterPaid,
    'referenceNumber': referenceNumber,
    'status': status,
    'note': note,
  };

  factory PurchaseRecord.fromJson(Map<String, dynamic> j) => PurchaseRecord(
    id: j['id'] as String? ?? '',
    number: j['number'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    supplierId: j['supplierId'] as String? ?? '',
    supplierCode: j['supplierCode'] as String? ?? '',
    supplierName: j['supplierName'] as String? ?? '',
    invoiceNumber: j['invoiceNumber'] as String? ?? '',
    invoiceDate: DateTime.tryParse(j['invoiceDate'] as String? ?? '') ?? DateTime.now(),
    sourceType: j['sourceType'] as String? ?? 'SUPPLIER',
    sourceName: j['sourceName'] as String? ?? '',
    purchaseOrderNumber: j['purchaseOrderNumber'] as String? ?? '',
    paymentTerms: j['paymentTerms'] as String? ?? 'Cash',
    lines: (j['lines'] as List? ?? []).map((e) => PurchaseLine.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    paymentMode: j['paymentMode'] as String? ?? 'Cash',
    amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
    supplierAdvanceUsed: (j['supplierAdvanceUsed'] as num?)?.toDouble() ?? 0,
    laterPaid: (j['laterPaid'] as num?)?.toDouble() ?? 0,
    referenceNumber: j['referenceNumber'] as String? ?? '',
    status: j['status'] as String? ?? 'Received',
    note: j['note'] as String? ?? '',
  );
}


class PurchaseReturnLine {
  PurchaseReturnLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitCost,
  });
  String productId;
  String productName;
  double quantity;
  String unit;
  double unitCost;
  double get amount => quantity * unitCost;
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'quantity': quantity,
    'unit': unit,
    'unitCost': unitCost,
  };
  factory PurchaseReturnLine.fromJson(Map<String, dynamic> j) => PurchaseReturnLine(
    productId: j['productId'] as String? ?? '',
    productName: j['productName'] as String? ?? '',
    quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
    unit: j['unit'] as String? ?? 'pcs',
    unitCost: (j['unitCost'] as num?)?.toDouble() ?? 0,
  );
}

class PurchaseReturnRecord {
  PurchaseReturnRecord({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.purchaseId,
    required this.supplierId,
    required this.supplierName,
    required this.lines,
    this.reason = '',
    this.refundMode = 'Supplier Credit',
    this.reference = '',
  });
  String id;
  String number;
  DateTime createdAt;
  String purchaseId;
  String supplierId;
  String supplierName;
  List<PurchaseReturnLine> lines;
  String reason;
  String refundMode;
  String reference;
  double get total => lines.fold<double>(0, (a, b) => a + b.amount);
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'createdAt': createdAt.toIso8601String(),
    'purchaseId': purchaseId,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'lines': lines.map((e) => e.toJson()).toList(),
    'reason': reason,
    'refundMode': refundMode,
    'reference': reference,
  };
  factory PurchaseReturnRecord.fromJson(Map<String, dynamic> j) => PurchaseReturnRecord(
    id: j['id'] as String? ?? '',
    number: j['number'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    purchaseId: j['purchaseId'] as String? ?? '',
    supplierId: j['supplierId'] as String? ?? '',
    supplierName: j['supplierName'] as String? ?? '',
    lines: (j['lines'] as List? ?? []).map((e) => PurchaseReturnLine.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    reason: j['reason'] as String? ?? '',
    refundMode: j['refundMode'] as String? ?? 'Supplier Credit',
    reference: j['reference'] as String? ?? '',
  );
}

class SupplierLedgerEntry {
  SupplierLedgerEntry({
    required this.id,
    required this.supplierId,
    required this.createdAt,
    required this.type,
    required this.amount,
    this.paymentMode = '',
    this.reference = '',
    this.documentReference = '',
    this.note = '',
  });
  String id;
  String supplierId;
  DateTime createdAt;
  String type; // PAYABLE, PAYMENT, RETURN, CREDIT_NOTE, DEBIT_NOTE
  double amount;
  String paymentMode;
  String reference;
  String documentReference;
  String note;
  Map<String, dynamic> toJson() => {
    'id': id,
    'supplierId': supplierId,
    'createdAt': createdAt.toIso8601String(),
    'type': type,
    'amount': amount,
    'paymentMode': paymentMode,
    'reference': reference,
    'documentReference': documentReference,
    'note': note,
  };
  factory SupplierLedgerEntry.fromJson(Map<String, dynamic> j) => SupplierLedgerEntry(
    id: j['id'] as String? ?? '',
    supplierId: j['supplierId'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    type: j['type'] as String? ?? 'PAYABLE',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    paymentMode: j['paymentMode'] as String? ?? '',
    reference: j['reference'] as String? ?? '',
    documentReference: j['documentReference'] as String? ?? '',
    note: j['note'] as String? ?? '',
  );
}

class Supplier {
  Supplier({
    required this.id,
    required this.code,
    required this.name,
    this.contactPerson = '',
    this.mobile = '',
    this.alternateMobile = '',
    this.whatsapp = '',
    this.email = '',
    this.gstin = '',
    this.pan = '',
    this.category = 'General',
    this.suppliedItems = '',
    this.address = '',
    this.city = '',
    this.state = 'Tamil Nadu',
    this.pincode = '',
    this.paymentTerms = 'Cash',
    this.creditDays = 0,
    this.openingPayable = 0,
    this.supplierCreditBalance = 0,
    this.bankUpi = '',
    this.notes = '',
    this.active = true,
  });
  String id;
  String code;
  String name;
  String contactPerson;
  String mobile;
  String alternateMobile;
  String whatsapp;
  String email;
  String gstin;
  String pan;
  String category;
  String suppliedItems;
  String address;
  String city;
  String state;
  String pincode;
  String paymentTerms;
  int creditDays;
  double openingPayable;
  double supplierCreditBalance;
  String bankUpi;
  String notes;
  bool active;
  Map<String, dynamic> toJson() => {
        'id': id, 'code': code, 'name': name, 'contactPerson': contactPerson,
        'mobile': mobile, 'alternateMobile': alternateMobile, 'whatsapp': whatsapp,
        'email': email, 'gstin': gstin, 'pan': pan, 'category': category,
        'suppliedItems': suppliedItems, 'address': address, 'city': city,
        'state': state, 'pincode': pincode, 'paymentTerms': paymentTerms,
        'creditDays': creditDays, 'openingPayable': openingPayable,
        'supplierCreditBalance': supplierCreditBalance,
        'bankUpi': bankUpi, 'notes': notes, 'active': active,
      };
  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'] as String? ?? '', code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? 'Supplier', contactPerson: j['contactPerson'] as String? ?? '',
        mobile: j['mobile'] as String? ?? '', alternateMobile: j['alternateMobile'] as String? ?? '',
        whatsapp: j['whatsapp'] as String? ?? '', email: j['email'] as String? ?? '',
        gstin: j['gstin'] as String? ?? '', pan: j['pan'] as String? ?? '',
        category: j['category'] as String? ?? 'General', suppliedItems: j['suppliedItems'] as String? ?? '',
        address: j['address'] as String? ?? '', city: j['city'] as String? ?? '',
        state: j['state'] as String? ?? 'Tamil Nadu', pincode: j['pincode'] as String? ?? '',
        paymentTerms: j['paymentTerms'] as String? ?? 'Cash', creditDays: (j['creditDays'] as num?)?.toInt() ?? 0,
        openingPayable: (j['openingPayable'] as num?)?.toDouble() ?? 0,
        supplierCreditBalance: (j['supplierCreditBalance'] as num?)?.toDouble() ?? 0,
        bankUpi: j['bankUpi'] as String? ?? '', notes: j['notes'] as String? ?? '', active: j['active'] as bool? ?? true,
      );
}

class CashClosing {
  CashClosing({
    required this.id,
    required this.createdAt,
    required this.cashier,
    required this.openingCash,
    required this.expectedCash,
    required this.actualCash,
    required this.variance,
    this.branch = 'Main Store',
    this.register = 'Front Counter',
    this.cashSales = 0,
    this.cashRefunds = 0,
    this.creditCollections = 0,
    this.customerAdvances = 0,
    this.pettyCash = 0,
    this.note = '',
    this.discrepancyReason = '',
    this.status = 'Closed',
    this.managerApproved = false,
    this.denominations = const {},
  });
  String id;
  DateTime createdAt;
  String cashier;
  String branch;
  String register;
  double openingCash;
  double cashSales;
  double cashRefunds;
  double creditCollections;
  double customerAdvances;
  double pettyCash;
  double expectedCash;
  double actualCash;
  double variance;
  String note;
  String discrepancyReason;
  String status;
  bool managerApproved;
  Map<String, int> denominations;
  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'cashier': cashier,
    'branch': branch,
    'register': register,
    'openingCash': openingCash,
    'cashSales': cashSales,
    'cashRefunds': cashRefunds,
    'creditCollections': creditCollections,
    'customerAdvances': customerAdvances,
    'pettyCash': pettyCash,
    'expectedCash': expectedCash,
    'actualCash': actualCash,
    'variance': variance,
    'note': note,
    'discrepancyReason': discrepancyReason,
    'status': status,
    'managerApproved': managerApproved,
    'denominations': denominations,
  };
  factory CashClosing.fromJson(Map<String, dynamic> j) => CashClosing(
    id: j['id'] as String? ?? '',
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    cashier: j['cashier'] as String? ?? 'Cashier',
    branch: j['branch'] as String? ?? 'Main Store',
    register: j['register'] as String? ?? 'Front Counter',
    openingCash: (j['openingCash'] as num?)?.toDouble() ?? 0,
    cashSales: (j['cashSales'] as num?)?.toDouble() ?? 0,
    cashRefunds: (j['cashRefunds'] as num?)?.toDouble() ?? 0,
    creditCollections: (j['creditCollections'] as num?)?.toDouble() ?? 0,
    customerAdvances: (j['customerAdvances'] as num?)?.toDouble() ?? 0,
    pettyCash: (j['pettyCash'] as num?)?.toDouble() ?? 0,
    expectedCash: (j['expectedCash'] as num?)?.toDouble() ?? 0,
    actualCash: (j['actualCash'] as num?)?.toDouble() ?? 0,
    variance: (j['variance'] as num?)?.toDouble() ?? 0,
    note: j['note'] as String? ?? '',
    discrepancyReason: j['discrepancyReason'] as String? ?? '',
    status: j['status'] as String? ?? 'Closed',
    managerApproved: j['managerApproved'] as bool? ?? false,
    denominations: Map<String, int>.from((j['denominations'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt()))),
  );
}

class FeedbackEntry {
  FeedbackEntry({required this.id, required this.createdAt, required this.rating, required this.category, required this.comment, this.branch = 'Main Store'});
  String id;
  DateTime createdAt;
  int rating;
  String category;
  String comment;
  String branch;
  Map<String, dynamic> toJson() => {'id': id, 'createdAt': createdAt.toIso8601String(), 'rating': rating, 'category': category, 'comment': comment, 'branch': branch};
  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(id: j['id'] as String, createdAt: DateTime.parse(j['createdAt'] as String), rating: (j['rating'] as num).toInt(), category: j['category'] as String? ?? 'General', comment: j['comment'] as String? ?? '', branch: j['branch'] as String? ?? 'Main Store');
}

class AppData {
  AppData({
    required this.products,
    required this.customers,
    required this.employees,
    required this.branches,
    required this.sales,
    required this.feedback,
    List<CustomerLedgerEntry>? ledger,
    List<Quotation>? quotations,
    List<Supplier>? suppliers,
    List<CashClosing>? cashClosings,
    List<PurchaseRecord>? purchases,
    List<PurchaseReturnRecord>? purchaseReturns,
    List<SupplierLedgerEntry>? supplierLedger,
    BusinessProfile? business,
    this.dataVersion = 16,
  })  : ledger = ledger ?? [],
        quotations = quotations ?? [],
        suppliers = suppliers ?? [],
        cashClosings = cashClosings ?? [],
        purchases = purchases ?? [],
        purchaseReturns = purchaseReturns ?? [],
        supplierLedger = supplierLedger ?? [],
        business = business ?? BusinessProfile();

  List<Product> products;
  List<Customer> customers;
  List<Employee> employees;
  List<Branch> branches;
  List<Sale> sales;
  List<FeedbackEntry> feedback;
  List<CustomerLedgerEntry> ledger;
  List<Quotation> quotations;
  List<Supplier> suppliers;
  List<CashClosing> cashClosings;
  List<PurchaseRecord> purchases;
  List<PurchaseReturnRecord> purchaseReturns;
  List<SupplierLedgerEntry> supplierLedger;
  BusinessProfile business;
  int dataVersion;

  Map<String, dynamic> toJson() => {
    'products': products.map((e) => e.toJson()).toList(),
    'customers': customers.map((e) => e.toJson()).toList(),
    'employees': employees.map((e) => e.toJson()).toList(),
    'branches': branches.map((e) => e.toJson()).toList(),
    'sales': sales.map((e) => e.toJson()).toList(),
    'feedback': feedback.map((e) => e.toJson()).toList(),
    'ledger': ledger.map((e) => e.toJson()).toList(),
    'quotations': quotations.map((e) => e.toJson()).toList(),
    'suppliers': suppliers.map((e) => e.toJson()).toList(),
    'cashClosings': cashClosings.map((e) => e.toJson()).toList(),
    'purchases': purchases.map((e) => e.toJson()).toList(),
    'purchaseReturns': purchaseReturns.map((e) => e.toJson()).toList(),
    'supplierLedger': supplierLedger.map((e) => e.toJson()).toList(),
    'business': business.toJson(),
    'dataVersion': dataVersion,
  };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
    products: (j['products'] as List? ?? []).map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    customers: (j['customers'] as List? ?? []).map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    employees: (j['employees'] as List? ?? []).map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    branches: (j['branches'] as List? ?? []).map((e) => Branch.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    sales: (j['sales'] as List? ?? []).map((e) => Sale.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    feedback: (j['feedback'] as List? ?? []).map((e) => FeedbackEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    ledger: (j['ledger'] as List? ?? []).map((e) => CustomerLedgerEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    quotations: (j['quotations'] as List? ?? []).map((e) => Quotation.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    suppliers: (j['suppliers'] as List? ?? []).map((e) => Supplier.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    cashClosings: (j['cashClosings'] as List? ?? []).map((e) => CashClosing.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    purchases: (j['purchases'] as List? ?? []).map((e) => PurchaseRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    purchaseReturns: (j['purchaseReturns'] as List? ?? []).map((e) => PurchaseReturnRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    supplierLedger: (j['supplierLedger'] as List? ?? []).map((e) => SupplierLedgerEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    business: j['business'] is Map ? BusinessProfile.fromJson(Map<String, dynamic>.from(j['business'] as Map)) : BusinessProfile(),
    dataVersion: (j['dataVersion'] as num?)?.toInt() ?? 0,
  );

  String prettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

