import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/entities.dart';
import 'document_rules.dart';

class InvoiceService {
  static String _saleItemLabel(SaleLine line) {
    if (line.serialNumbers.isEmpty) return line.name;
    return '${line.name}\nSerial / IMEI: ${line.serialNumbers.join(', ')}';
  }

  static Future<String> salePdf(AppData data, Sale sale) async {
    final pdf = pw.Document();
    final currentBusiness = data.business;
    final documentType = DocumentRules.normalizeDocumentType(sale.documentType);
    final isTaxInvoice = documentType == DocumentRules.taxInvoice;
    final isBillOfSupply = documentType == DocumentRules.billOfSupply;
    final fullGstRecipient = sale.gstBillRequested || sale.customerGstin.trim().isNotEmpty;
    final displayDocumentType =
        isTaxInvoice && !fullGstRecipient ? 'Retail Tax Invoice' : documentType;

    final businessName = sale.businessNameSnapshot.isNotEmpty
        ? sale.businessNameSnapshot
        : currentBusiness.businessName;
    final businessAddress = sale.businessAddressSnapshot.isNotEmpty
        ? sale.businessAddressSnapshot
        : currentBusiness.address;
    final businessGstin = sale.businessGstinSnapshot.isNotEmpty
        ? sale.businessGstinSnapshot
        : currentBusiness.gstin;
    final businessState = sale.businessStateSnapshot.isNotEmpty
        ? sale.businessStateSnapshot
        : currentBusiness.state;
    final businessStateCode = sale.businessStateCodeSnapshot.isNotEmpty
        ? sale.businessStateCodeSnapshot
        : currentBusiness.stateCode;
    final gstProfile = sale.gstRegistrationTypeSnapshot.isNotEmpty
        ? sale.gstRegistrationTypeSnapshot
        : currentBusiness.gstRegistrationType;

    final interstate = sale.placeOfSupplyStateCode.isNotEmpty &&
        sale.placeOfSupplyStateCode != businessStateCode;
    final gst = isTaxInvoice ? sale.gst : 0.0;
    final cgst = interstate ? 0.0 : gst / 2;
    final sgst = interstate ? 0.0 : gst / 2;
    final igst = interstate ? gst : 0.0;

    List<String> headers;
    List<List<String>> rows;
    if (isTaxInvoice) {
      headers = const ['Item', 'HSN/SAC', 'Qty', 'Rate', 'Discount', 'Taxable', 'GST', 'Amount'];
      rows = sale.lines.map((l) => [
        _saleItemLabel(l),
        l.hsnSac.isEmpty ? '-' : l.hsnSac,
        '${l.qty.toStringAsFixed(l.qty % 1 == 0 ? 0 : 2)} ${l.unit}',
        l.unitPrice.toStringAsFixed(2),
        '${l.discountPercent.toStringAsFixed(1)}% + ${l.discountAmount.toStringAsFixed(2)}',
        l.taxableValue.toStringAsFixed(2),
        l.isOutputTaxable ? '${l.gstRate.toStringAsFixed(1)}%' : l.taxCategory,
        l.net.toStringAsFixed(2),
      ]).toList();
    } else if (isBillOfSupply) {
      headers = const ['Item', 'HSN/SAC', 'Qty', 'Rate', 'Discount', 'Tax class', 'Amount'];
      rows = sale.lines.map((l) => [
        _saleItemLabel(l),
        l.hsnSac.isEmpty ? '-' : l.hsnSac,
        '${l.qty.toStringAsFixed(l.qty % 1 == 0 ? 0 : 2)} ${l.unit}',
        l.unitPrice.toStringAsFixed(2),
        '${l.discountPercent.toStringAsFixed(1)}% + ${l.discountAmount.toStringAsFixed(2)}',
        l.taxCategory,
        l.net.toStringAsFixed(2),
      ]).toList();
    } else {
      headers = const ['Item', 'Qty', 'Rate', 'Discount', 'Amount'];
      rows = sale.lines.map((l) => [
        _saleItemLabel(l),
        '${l.qty.toStringAsFixed(l.qty % 1 == 0 ? 0 : 2)} ${l.unit}',
        l.unitPrice.toStringAsFixed(2),
        '${l.discountPercent.toStringAsFixed(1)}% + ${l.discountAmount.toStringAsFixed(2)}',
        l.net.toStringAsFixed(2),
      ]).toList();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    if (businessAddress.isNotEmpty) pw.Text(businessAddress),
                    if (businessState.isNotEmpty) pw.Text('$businessState • State code $businessStateCode'),
                    if (businessGstin.isNotEmpty) pw.Text('GSTIN: $businessGstin'),
                    if (currentBusiness.phone.isNotEmpty) pw.Text('Phone: ${currentBusiness.phone}'),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(displayDocumentType.toUpperCase(), style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
                  pw.Text(sale.documentNumber.isEmpty ? sale.id : sale.documentNumber),
                  pw.Text(DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt)),
                  pw.Text('Status: ${sale.status}'),
                ],
              ),
            ],
          ),
          if (isBillOfSupply) ...[
            pw.SizedBox(height: 7),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(7),
              color: PdfColors.grey100,
              child: pw.Text(
                gstProfile == DocumentRules.composition
                    ? 'Composition scheme: GST is not collected separately from the customer.'
                    : 'GST is not collected separately on this Bill of Supply.',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
          ],
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${fullGstRecipient ? 'Name' : 'Customer'}: ${sale.customerName}'),
                if (sale.customerId.isNotEmpty) pw.Text('Customer ID: ${sale.customerId}'),
                if (sale.customerGstin.isNotEmpty) pw.Text('GSTIN: ${sale.customerGstin}'),
                if (fullGstRecipient && sale.customerAddressSnapshot.isNotEmpty)
                  pw.Text(sale.customerAddressSnapshot),
                if (fullGstRecipient && sale.customerStateSnapshot.isNotEmpty)
                  pw.Text('${sale.customerStateSnapshot} • State code ${sale.customerStateCodeSnapshot}'),
                if (sale.requestedByName.isNotEmpty)
                  pw.Text('Purchased / Requested By: ${sale.requestedByName}'),
                if (sale.requestedByContact.isNotEmpty)
                  pw.Text('Contact: ${sale.requestedByContact}'),
                if (isTaxInvoice) pw.Text('Place of supply state code: ${sale.placeOfSupplyStateCode}'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 280,
              child: pw.Column(
                children: [
                  _row('Items total', sale.subtotal),
                  if (sale.discount > 0) _row('Bill discount', -sale.discount),
                  if (isTaxInvoice) ...[
                    _row('Taxable value', sale.taxableValue),
                    if (!interstate) _row('CGST', cgst),
                    if (!interstate) _row('SGST', sgst),
                    if (interstate) _row('IGST', igst),
                  ],
                  pw.Divider(),
                  _row('Grand total', sale.total, bold: true),
                  _row('Paid at sale', sale.amountPaid),
                  if (sale.laterPaid > 0) _row('Paid later', sale.laterPaid),
                  _row('Total settled', sale.settledAmount),
                  _row('Balance due', sale.balanceDue, bold: true),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text('Payment: ${sale.paymentMethod}'),
          if (sale.paymentReference.isNotEmpty) pw.Text('Payment reference: ${sale.paymentReference}'),
          if (sale.paymentBreakdown.isNotEmpty)
            pw.Text(sale.paymentBreakdown.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}').join(' | ')),
          if (fullGstRecipient) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              'Invoice issued in the requested name.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 22),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Customer acknowledgement', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.Text('Authorized signatory', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Saved historical document generated by ProfitGPS. Tax treatment is based on the business/document snapshot stored when the transaction was finalized.',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final safe = (sale.documentNumber.isEmpty ? sale.id : sale.documentNumber)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path = '${dir.path}${Platform.pathSeparator}$safe.pdf';
    await File(path).writeAsBytes(await pdf.save(), flush: true);
    return path;
  }

  static Future<String> quotationPdf(AppData data, Quotation q) async {
    final pdf = pw.Document();
    final currentBusiness = data.business;
    final businessName = q.businessNameSnapshot.isNotEmpty ? q.businessNameSnapshot : currentBusiness.businessName;
    final businessAddress = q.businessAddressSnapshot.isNotEmpty ? q.businessAddressSnapshot : currentBusiness.address;
    final businessGstin = q.businessGstinSnapshot.isNotEmpty ? q.businessGstinSnapshot : currentBusiness.gstin;
    final businessState = q.businessStateSnapshot.isNotEmpty ? q.businessStateSnapshot : currentBusiness.state;
    final businessStateCode = q.businessStateCodeSnapshot.isNotEmpty ? q.businessStateCodeSnapshot : currentBusiness.stateCode;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    if (businessAddress.isNotEmpty) pw.Text(businessAddress),
                    if (businessState.isNotEmpty) pw.Text('$businessState • State code $businessStateCode'),
                    if (businessGstin.isNotEmpty) pw.Text('GSTIN: $businessGstin'),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('QUOTATION', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('NOT A TAX INVOICE', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text(q.number),
                  pw.Text(DateFormat('dd MMM yyyy').format(q.createdAt)),
                  pw.Text('Status: ${q.status}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Customer: ${q.customerName}${q.customerId.isEmpty ? '' : ' • ${q.customerId}'}'),
                if (q.customerGstin.isNotEmpty) pw.Text('GSTIN: ${q.customerGstin}'),
                if (q.customerAddress.isNotEmpty) pw.Text(q.customerAddress),
                if (q.customerState.isNotEmpty) pw.Text('${q.customerState} • State code ${q.customerStateCode}'),
                if (q.validUntil != null) pw.Text('Valid until: ${DateFormat('dd MMM yyyy').format(q.validUntil!)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'HSN/SAC', 'Qty', 'Rate', 'Discount', 'Estimated GST', 'Amount'],
            data: q.lines.map((l) => [
              l.name,
              l.hsnSac.isEmpty ? '-' : l.hsnSac,
              '${l.qty.toStringAsFixed(l.qty % 1 == 0 ? 0 : 2)} ${l.unit}',
              l.unitPrice.toStringAsFixed(2),
              '${l.discountPercent.toStringAsFixed(1)}%',
              l.isOutputTaxable ? '${l.gstRate.toStringAsFixed(1)}%' : l.taxCategory,
              l.net.toStringAsFixed(2),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('QUOTED TOTAL: INR ${q.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          if (q.notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Notes / terms', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(q.notes),
          ],
          pw.SizedBox(height: 18),
          pw.Text(
            'Quotation only — not a completed sale. No inventory reduction, receivable or GST liability is created until it is converted into a finalized sale.',
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Customer acceptance', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.Text('Authorized signatory', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}${Platform.pathSeparator}${q.number.replaceAll('/', '_')}.pdf';
    await File(path).writeAsBytes(await pdf.save(), flush: true);
    return path;
  }


  static Future<String> purchasePdf(AppData data, PurchaseRecord purchase) async {
    final pdf = pw.Document();
    final supplier = data.suppliers.where((s) => s.id == purchase.supplierId).firstOrNull;
    final business = data.business;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      business.businessName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (business.address.isNotEmpty) pw.Text(business.address),
                    if (business.gstin.isNotEmpty)
                      pw.Text('Our GSTIN: ${business.gstin}'),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'PURCHASE RECORD',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(purchase.number),
                  pw.Text('PO: ${purchase.purchaseOrderNumber}'),
                  pw.Text(
                    DateFormat('dd MMM yyyy').format(purchase.invoiceDate),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Supplier: ${purchase.supplierName}'),
                if (purchase.supplierCode.isNotEmpty)
                  pw.Text('Supplier code: ${purchase.supplierCode}'),
                if (supplier != null && supplier.gstin.isNotEmpty)
                  pw.Text('Supplier GSTIN: ${supplier.gstin}'),
                pw.Text('Supplier invoice: ${purchase.invoiceNumber}'),
                pw.Text('Settlement: ${purchase.paymentTerms}'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Product',
              'Qty',
              'Free',
              'Stock received',
              'GST',
              'Effective cost',
              'Amount'
            ],
            data: purchase.lines
                .map(
                  (line) => [
                    line.productName,
                    '${line.quantity.toStringAsFixed(2)} ${line.purchaseUnit}',
                    line.freeQuantity.toStringAsFixed(2),
                    '${line.stockReceived.toStringAsFixed(2)} ${line.sellingUnit}',
                    line.gstApplicable
                        ? '${line.gstRate.toStringAsFixed(1)}%'
                        : 'NA',
                    line.effectiveCostPerSellingUnit.toStringAsFixed(2),
                    line.supplierInvoiceLineTotal.toStringAsFixed(2),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 280,
              child: pw.Column(
                children: [
                  _row('Taxable subtotal', purchase.subtotal),
                  _row('Supplier discount', -purchase.supplierDiscountTotal),
                  _row('Input GST', purchase.totalInputGst),
                  _row('Freight / landed charges', purchase.freightTotal),
                  pw.Divider(),
                  _row('Purchase total', purchase.total, bold: true),
                  _row('Paid with purchase', purchase.amountPaid),
                  _row('Supplier advance used', purchase.supplierAdvanceUsed),
                  _row('Paid later', purchase.laterPaid),
                  _row('Amount still payable', purchase.balanceDue, bold: true),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('Payment mode: ${purchase.paymentMode}'),
          if (purchase.referenceNumber.isNotEmpty)
            pw.Text('Payment reference: ${purchase.referenceNumber}'),
          pw.SizedBox(height: 20),
          pw.Text(
            'Generated by ProfitGPS from the saved purchase record. Supplier invoice number remains the number printed by the supplier.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final safe = purchase.number.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final path =
        '${dir.path}${Platform.pathSeparator}${safe}_purchase.pdf';
    await File(path).writeAsBytes(await pdf.save(), flush: true);
    return path;
  }

  static pw.Widget _row(String label, double value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(children: [pw.Expanded(child: pw.Text(label, style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null)), pw.Text('INR ${value.toStringAsFixed(2)}', style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null)]),
  );
}

extension _InvoiceFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
