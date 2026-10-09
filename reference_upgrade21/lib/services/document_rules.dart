import '../models/entities.dart';

/// Centralized GST/document decision rules used by Billing, Records and PDFs.
/// This keeps cashiers out of tax-document decisions while still allowing an
/// owner override for a genuine correction.
class DocumentRules {
  static const regularGst = 'Regular GST';
  static const composition = 'Composition Scheme';
  static const notRegistered = 'Not Registered';

  static const taxInvoice = 'Tax Invoice';
  static const billOfSupply = 'Bill of Supply';
  static const billReceipt = 'Bill / Receipt';

  static String resolveSaleDocument(
    BusinessProfile business,
    List<SaleLine> lines, {
    String override = 'Auto',
  }) {
    if (override != 'Auto') return normalizeDocumentType(override);

    switch (business.gstRegistrationType) {
      case composition:
        return billOfSupply;
      case regularGst:
        final hasTaxable = lines.any(
          (line) => line.taxCategory == 'Taxable' && line.gstRate > 0,
        );
        return hasTaxable ? taxInvoice : billOfSupply;
      default:
        return billReceipt;
    }
  }

  static String normalizeDocumentType(String value) {
    if (value == 'Retail Bill') return billReceipt;
    return value;
  }

  static bool canChargeOutputGst(BusinessProfile business) =>
      business.gstRegistrationType == regularGst;

  static bool canClaimItc(BusinessProfile business) =>
      business.gstRegistrationType == regularGst;

  static String prefixFor(BusinessProfile business, String documentType) {
    switch (normalizeDocumentType(documentType)) {
      case taxInvoice:
        return _cleanPrefix(business.invoicePrefix, 'INV');
      case billOfSupply:
        return _cleanPrefix(business.billOfSupplyPrefix, 'BOS');
      case 'Quotation':
        return _cleanPrefix(business.quotationPrefix, 'QTN');
      default:
        return _cleanPrefix(business.billPrefix, 'BILL');
    }
  }

  static String financialYearLabel(BusinessProfile business, DateTime date) {
    final startMonth = business.financialYearStartMonth.clamp(1, 12);
    final startYear = date.month >= startMonth ? date.year : date.year - 1;
    final endYear = startYear + 1;
    return '${(startYear % 100).toString().padLeft(2, '0')}-${(endYear % 100).toString().padLeft(2, '0')}';
  }

  static String taxTreatmentLabel(BusinessProfile business) {
    switch (business.gstRegistrationType) {
      case regularGst:
        return 'Regular GST • output GST + eligible ITC';
      case composition:
        return 'Composition • no GST collected separately • no ITC';
      default:
        return 'Not GST registered • no GST collection';
    }
  }

  static String _cleanPrefix(String value, String fallback) {
    final cleaned = value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }
}
