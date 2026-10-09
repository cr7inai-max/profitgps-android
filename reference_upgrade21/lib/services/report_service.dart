import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/entities.dart';
import 'analytics_engine.dart';

class ReportService {
  static Future<String> dailyPdf(AppData data) async {
    final pdf = pw.Document();
    final today = AnalyticsEngine.salesInDays(data, 1);
    final sales = AnalyticsEngine.salesTotal(today);
    final profit = AnalyticsEngine.profitTotal(today);
    final insights = AnalyticsEngine.profitGps(data);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text('Profit GPS - Daily Business Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
        pw.SizedBox(height: 16),
        pw.Row(children: [pw.Expanded(child: _metric('Sales', 'INR ${sales.toStringAsFixed(0)}')), pw.SizedBox(width: 10), pw.Expanded(child: _metric('Estimated Profit', 'INR ${profit.toStringAsFixed(0)}'))]),
        pw.SizedBox(height: 16),
        pw.Text('Profit GPS actions', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ...insights.map((i) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text('${i.title}: ${i.detail} ${i.action.isEmpty ? '' : 'Action: ${i.action}'}'))),
        pw.SizedBox(height: 16),
        pw.Text('Branch comparison', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(headers: ['Branch', 'Sales', 'Profit', 'Expiry loss'], data: data.branches.map((b) => [b.name, b.sales.toStringAsFixed(0), b.profit.toStringAsFixed(0), b.expiryLoss.toStringAsFixed(0)]).toList()),
      ],
    ));
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}${Platform.pathSeparator}profitgps_daily_report.pdf';
    await File(path).writeAsBytes(await pdf.save(), flush: true);
    return path;
  }

  static pw.Widget _metric(String title, String value) => pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(title), pw.SizedBox(height: 4), pw.Text(value, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))]),
      );
}
