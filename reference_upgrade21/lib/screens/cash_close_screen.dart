import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../widgets/common.dart';

class CashCloseScreen extends StatefulWidget {
  const CashCloseScreen({super.key});
  @override
  State<CashCloseScreen> createState() => _CashCloseScreenState();
}

class _CashCloseScreenState extends State<CashCloseScreen> {
  final counts = <int, int>{2000: 0, 500: 0, 200: 0, 100: 0, 50: 0, 20: 0, 10: 0, 5: 0, 2: 0, 1: 0};
  final opening = TextEditingController(text: '0');
  final refunds = TextEditingController(text: '0');
  final creditCollections = TextEditingController(text: '0');
  final petty = TextEditingController(text: '0');
  final discrepancy = TextEditingController();
  final note = TextEditingController();
  String branch = 'Main Store';
  String register = 'Front Counter 01';
  String cashier = 'Current cashier';
  bool managerApproval = false;
  bool pendingReview = false;

  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  double get actual => counts.entries.fold<double>(0, (a, e) => a + e.key * e.value);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final branchOptions = <String>{
      'Main Store',
      ...app.data!.branches.map((b) => b.name.trim()).where((name) => name.isNotEmpty),
    }.toList();
    final selectedBranch = branchOptions.contains(branch) ? branch : branchOptions.first;
    final now = DateTime.now();
    final todays = app.data!.sales.where((s) => s.createdAt.year == now.year && s.createdAt.month == now.month && s.createdAt.day == now.day);
    final physicalCashFromSales = todays.fold<double>(0, (a, s) {
      if (s.cashReceived > 0) return a + s.cashReceived - s.changeReturned;
      return a + (s.paymentBreakdown['Cash'] ?? (s.paymentMethod == 'Cash' ? s.amountPaid : 0));
    });
    final advances = todays.fold<double>(0, (a, s) => a + s.customerAdvanceCreated);
    final normalCashSales = (physicalCashFromSales - advances).clamp(0.0, double.infinity).toDouble();
    final open = _d(opening);
    final refundValue = _d(refunds);
    final debtCollections = _d(creditCollections);
    final paidOut = _d(petty);
    final expected = open + normalCashSales + advances + debtCollections - refundValue - paidOut;
    final variance = actual - expected;
    final matched = variance.abs() < 0.01;

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        SectionTitle(
          'Cash Close & Till Tally',
          subtitle: 'Bank-style register reconciliation with denomination audit, variance reasons and shift history.',
          trailing: Wrap(spacing: 8, runSpacing: 8, children: [
            StatusPill(text: matched ? 'TALLY MATCHED' : 'REVIEW REQUIRED', color: matched ? AppTheme.green : AppTheme.red, icon: matched ? Icons.verified_rounded : Icons.warning_amber_rounded),
            OutlinedButton.icon(onPressed: () => _showHistory(context), icon: const Icon(Icons.history_rounded), label: const Text('History')),
          ]),
        ),
        Wrap(spacing: 9, runSpacing: 9, children: [
          _kpi('Opening Cash', money(open), Icons.account_balance_wallet_outlined, AppTheme.amber),
          _kpi('Cash Sales', money(normalCashSales), Icons.trending_up_rounded, AppTheme.green),
          _kpi('Credit Collections', money(debtCollections), Icons.payments_outlined, AppTheme.cyan),
          _kpi('Customer Advances', money(advances), Icons.person_add_alt_1_rounded, AppTheme.purple),
          _kpi('Cash Refunds', money(refundValue), Icons.keyboard_return_rounded, AppTheme.red),
          _kpi('Petty Cash / Paid Out', money(paidOut), Icons.remove_circle_outline, AppTheme.red),
          _kpi('Expected Drawer', money(expected), Icons.calculate_outlined, AppTheme.amber),
          _kpi('Actual Counted', money(actual), Icons.price_check_rounded, AppTheme.cyan),
          _kpi('Variance', money(variance), Icons.balance_rounded, matched ? AppTheme.green : AppTheme.red),
        ]),
        const SizedBox(height: 12),
        _panel('Shift identity', Icons.badge_outlined, Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(width: 220, child: DropdownButtonFormField<String>(value: selectedBranch, items: branchOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => branch = v ?? selectedBranch), decoration: const InputDecoration(labelText: 'Branch'))),
          SizedBox(width: 220, child: TextFormField(initialValue: register, decoration: const InputDecoration(labelText: 'Register / counter'), onChanged: (v) => register = v)),
          SizedBox(width: 220, child: TextFormField(initialValue: cashier, decoration: const InputDecoration(labelText: 'Cashier'), onChanged: (v) => cashier = v)),
          SizedBox(width: 180, child: TextField(controller: opening, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening cash \u20B9'))),
        ])),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 1050;
          final countPanel = _panel('1. Count Physical Cash', Icons.payments_rounded, Column(children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Enter number of notes/coins in the drawer.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ),
                TextButton.icon(
                  onPressed: actual <= 0
                      ? null
                      : () => setState(() {
                            for (final denomination in counts.keys) {
                              counts[denomination] = 0;
                            }
                          }),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Clear denominations'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...counts.keys.map((d) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
              Container(width: 72, padding: const EdgeInsets.symmetric(vertical: 7), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF171D26), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)), child: Text('\u20B9$d', style: const TextStyle(fontWeight: FontWeight.w900))),
              const SizedBox(width: 10),
              IconButton(onPressed: () => setState(() => counts[d] = (counts[d]! - 1).clamp(0, 999).toInt()), icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(width: 44, child: Text('${counts[d]}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => setState(() => counts[d] = counts[d]! + 1), icon: const Icon(Icons.add_circle_outline)),
              const Spacer(),
              Text(money(d * counts[d]!), style: const TextStyle(fontWeight: FontWeight.w900)),
            ]))),
            const Divider(),
            Row(children: [const Text('Total Counted Cash', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text(money(actual), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.amber))]),
          ]));

          final recon = _panel('2. Reconciliation & Controls', Icons.fact_check_outlined, Column(children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(width: 210, child: TextField(controller: creditCollections, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cash debt collections \u20B9', helperText: 'Customer old dues collected in cash'))),
              SizedBox(width: 210, child: TextField(controller: refunds, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cash refunds \u20B9'))),
              SizedBox(width: 210, child: TextField(controller: petty, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Petty cash / paid out \u20B9'))),
            ]),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: matched ? const Color(0x1729D888) : const Color(0x17FF5A5F), borderRadius: BorderRadius.circular(14), border: Border.all(color: matched ? AppTheme.green : AppTheme.red)), child: Column(children: [
              Row(children: [Icon(matched ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: matched ? AppTheme.green : AppTheme.red), const SizedBox(width: 9), Expanded(child: Text(matched ? 'Tally matched. Actual drawer equals expected drawer.' : 'Variance ${money(variance)} requires a reason and review.', style: const TextStyle(fontWeight: FontWeight.w900)))]),
              const SizedBox(height: 8),
              _sum('Expected drawer', expected),
              _sum('Actual drawer', actual),
              _sum('Variance', variance, color: matched ? AppTheme.green : AppTheme.red, strong: true),
            ])),
            if (!matched) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: discrepancy.text.isEmpty ? null : discrepancy.text, items: const ['Counting difference', 'Unrecorded petty cash', 'Refund mismatch', 'Opening float mismatch', 'Suspected cash leakage', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => discrepancy.text = v ?? ''), decoration: const InputDecoration(labelText: 'Discrepancy reason *')),
            ],
            const SizedBox(height: 8),
            TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Close note / evidence / handover note')),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: managerApproval, title: const Text('Manager / owner approval confirmed'), subtitle: const Text('Recommended whenever the shift has a variance.'), onChanged: (v) => setState(() => managerApproval = v ?? false)),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: pendingReview, title: const Text('Hold as pending review'), onChanged: (v) => setState(() => pendingReview = v ?? false)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: !matched && discrepancy.text.isEmpty ? null : () => _closeShift(context, expected, variance, normalCashSales, refundValue, debtCollections, advances, paidOut), icon: const Icon(Icons.lock_clock_outlined), label: Text(pendingReview ? 'Save pending close' : 'Close shift'))),
          ]));
          if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: countPanel), const SizedBox(width: 12), Expanded(child: recon)]);
          return Column(children: [countPanel, const SizedBox(height: 12), recon]);
        }),
        const SizedBox(height: 12),
        _panel('Shift Insights', Icons.auto_graph_rounded, Wrap(spacing: 10, runSpacing: 10, children: [
          _insight('Cash Health', matched ? 'Looks good' : 'Needs review', matched ? 'Drawer matches expected amount.' : 'Variance is outside the exact tally.', matched ? AppTheme.green : AppTheme.red),
          _insight('Denomination Mix', counts[500]! > 10 ? 'High \u20B9500 concentration' : 'Balanced mix', 'Keep smaller denominations available for customer change.', AppTheme.cyan),
          _insight('Trend Watch', app.data!.cashClosings.where((e) => e.variance.abs() > 0.01).length >= 3 ? 'Repeated variances detected' : 'No repeated issue', 'Profit GPS can flag repeated shortages/excesses by cashier.', AppTheme.purple),
        ])),
      ],
    );
  }

  Future<void> _closeShift(BuildContext context, double expected, double variance, double cashSales, double refundValue, double debtCollections, double advances, double paidOut) async {
    if (!await confirmAction(context, title: 'Confirm shift close', message: 'Close this till/shift and save the counted cash, variance and audit record?', confirmLabel: 'Close shift', icon: Icons.lock_clock_outlined)) return;

    final app = AppScope.of(context);
    await app.addCashClosing(CashClosing(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      cashier: cashier,
      branch: branch,
      register: register,
      openingCash: _d(opening),
      cashSales: cashSales,
      cashRefunds: refundValue,
      creditCollections: debtCollections,
      customerAdvances: advances,
      pettyCash: paidOut,
      expectedCash: expected,
      actualCash: actual,
      variance: variance,
      note: note.text.trim(),
      discrepancyReason: discrepancy.text.trim(),
      status: pendingReview ? 'Pending Review' : 'Closed',
      managerApproved: managerApproval,
      denominations: {for (final e in counts.entries) '${e.key}': e.value},
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pendingReview ? 'Cash close saved for review.' : 'Shift closed and audit record saved.')));
  }

  void _showHistory(BuildContext context) {
    final rows = AppScope.of(context).data!.cashClosings;
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Cash close history'), content: SizedBox(width: 720, height: 440, child: rows.isEmpty ? const EmptyState('No cash close records yet.', icon: Icons.history) : ListView.separated(itemCount: rows.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (_, i) { final r = rows[i]; return ListTile(leading: Icon(r.variance.abs() < 0.01 ? Icons.verified_rounded : Icons.warning_amber_rounded, color: r.variance.abs() < 0.01 ? AppTheme.green : AppTheme.red), title: Text('${r.branch} • ${r.cashier}', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year} • Expected ${money(r.expectedCash)} • Actual ${money(r.actualCash)}'), trailing: Text(money(r.variance), style: TextStyle(fontWeight: FontWeight.w900, color: r.variance.abs() < 0.01 ? AppTheme.green : AppTheme.red))); })), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
  }

  Widget _kpi(String label, String value, IconData icon, Color color) => SizedBox(width: 190, child: Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 7), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 10.5))]))));
  Widget _panel(String title, IconData icon, Widget child) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: AppTheme.red), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]), const SizedBox(height: 12), child])));
  Widget _sum(String label, double value, {Color? color, bool strong = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text(label, style: TextStyle(color: strong ? Colors.white : AppTheme.muted, fontWeight: strong ? FontWeight.w900 : FontWeight.w500)), const Spacer(), Text(money(value), style: TextStyle(fontSize: strong ? 18 : 13, fontWeight: FontWeight.w900, color: color))]));
  Widget _insight(String title, String status, String body, Color color) => Container(width: 300, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Color.fromARGB(18, color.red, color.green, color.blue), borderRadius: BorderRadius.circular(14), border: Border.all(color: Color.fromARGB(70, color.red, color.green, color.blue))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(status, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(body, style: const TextStyle(color: AppTheme.muted, fontSize: 11))]));
}
