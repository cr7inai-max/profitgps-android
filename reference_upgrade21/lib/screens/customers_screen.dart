import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../widgets/common.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final data = app.data!;
    final q = query.trim().toLowerCase();
    final customers = data.customers.where((c) {
      return q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.id.toLowerCase().contains(q) ||
          c.gstin.toLowerCase().contains(q);
    }).toList();
    final receivable =
        data.customers.fold<double>(0, (a, b) => a + b.creditBalance);
    final advances =
        data.customers.fold<double>(0, (a, b) => a + b.advanceBalance);

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SectionTitle(
          'Customers & Ledger',
          subtitle:
              'Current customer dues, customer advances and account details. Full historical records are also available under Records.',
        ),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: c.maxWidth > 800 ? (c.maxWidth - 20) / 3 : c.maxWidth,
                child: MetricCard(
                  label: 'Customers',
                  value: '${data.customers.length}',
                  icon: Icons.people_alt_outlined,
                ),
              ),
              SizedBox(
                width: c.maxWidth > 800 ? (c.maxWidth - 20) / 3 : c.maxWidth,
                child: MetricCard(
                  label: 'Customer dues',
                  value: money(receivable),
                  icon: Icons.account_balance_wallet_outlined,
                  accent: AppTheme.amber,
                ),
              ),
              SizedBox(
                width: c.maxWidth > 800 ? (c.maxWidth - 20) / 3 : c.maxWidth,
                child: MetricCard(
                  label: 'Customer advance held',
                  value: money(advances),
                  icon: Icons.savings_outlined,
                  accent: AppTheme.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search customer ID / name / mobile / GSTIN',
          ),
        ),
        const SizedBox(height: 12),
        ...customers.map(
          (customer) => Card(
            child: ExpansionTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                '${customer.name} • ${customer.id}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${customer.phone.isEmpty ? 'No mobile' : customer.phone} • '
                'Owes us ${money(customer.creditBalance)} • '
                'Advance available ${money(customer.advanceBalance)}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _kv('GSTIN', customer.gstin.isEmpty ? 'Not set' : customer.gstin),
                          _kv(
                            'Business',
                            customer.businessName.isEmpty
                                ? 'Personal'
                                : customer.businessName,
                          ),
                          _kv('State code', customer.stateCode),
                          _kv(
                            'Default discount',
                            '${customer.discountPercent.toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: customer.creditBalance <= 0
                                ? null
                                : () => _collectDue(context, customer),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Collect customer due'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _ledger(
                              context,
                              customer,
                              data.ledger
                                  .where((e) => e.customerId == customer.id)
                                  .toList(),
                            ),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('View ledger'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String key, String value) => SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key,
              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Future<void> _collectDue(BuildContext context, Customer customer) async {
    final amount = TextEditingController(
      text: customer.creditBalance.toStringAsFixed(2),
    );
    final reference = TextEditingController();
    String mode = 'Cash';

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Collect customer due • ${customer.name}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10151C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'Customer currently owes us ${money(customer.creditBalance)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount received',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: mode,
                    items: const [
                      'Cash',
                      'UPI',
                      'Card',
                      'Bank Transfer',
                      'Cheque',
                    ]
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text(e)),
                        )
                        .toList(),
                    onChanged: (v) => update(() => mode = v ?? 'Cash'),
                    decoration: const InputDecoration(
                      labelText: 'Payment mode received',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Transaction / UTR / cheque reference',
                      hintText: 'Recommended for UPI, card, bank and cheque',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'If the customer pays more than the due, the excess is stored as customer advance and is not counted as extra sales profit.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
                  ),
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (proceed != true) return;

    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (value <= 0) return;
    final applied = value.clamp(0.0, customer.creditBalance).toDouble();
    final excess = (value - applied).clamp(0.0, double.infinity).toDouble();
    final remaining =
        (customer.creditBalance - applied).clamp(0.0, double.infinity).toDouble();

    final confirmed = await confirmAction(
      context,
      title: 'Confirm customer payment',
      message:
          'Customer: ${customer.name}\n'
          'Received: ${money(value)}\n'
          'Mode: $mode\n'
          '${reference.text.trim().isEmpty ? '' : 'Reference: ${reference.text.trim()}\n'}'
          'Customer amount owed reduced by: ${money(applied)}\n'
          'Amount customer still owes us: ${money(remaining)}\n'
          '${excess > 0 ? 'Customer advance created: ${money(excess)}' : ''}',
      confirmLabel: 'Confirm payment',
      icon: Icons.payments_outlined,
    );
    if (!confirmed) return;

    await AppScope.of(context).receiveCustomerPayment(
      customer,
      value,
      paymentMode: mode,
      reference: reference.text.trim(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _ledger(
    BuildContext context,
    Customer customer,
    List<CustomerLedgerEntry> entries,
  ) {
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${customer.name} • Ledger'),
        content: SizedBox(
          width: 680,
          height: 460,
          child: entries.isEmpty
              ? const EmptyState(
                  'No ledger entries yet.',
                  icon: Icons.receipt_long_outlined,
                )
              : ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _ledgerIcon(e.type),
                        color: _ledgerColor(e.type),
                      ),
                      title: Text(
                        '${_ledgerLabel(e.type)} • ${money(e.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year} '
                        '• ${e.paymentMode.isEmpty ? 'Mode not recorded' : e.paymentMode}'
                        '${e.reference.isEmpty ? '' : ' • Ref ${e.reference}'}\n'
                        '${e.note}',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _ledgerLabel(String type) => switch (type) {
        'RECEIVABLE' => 'Amount customer owes us',
        'PAYMENT' => 'Customer due collected',
        'ADVANCE' => 'Customer advance received',
        'ADVANCE_USED' => 'Customer advance used',
        _ => type,
      };

  IconData _ledgerIcon(String type) => switch (type) {
        'PAYMENT' => Icons.south_west_rounded,
        'ADVANCE' => Icons.savings_outlined,
        'ADVANCE_USED' => Icons.account_balance_wallet_outlined,
        _ => Icons.receipt_long_outlined,
      };

  Color _ledgerColor(String type) => switch (type) {
        'PAYMENT' => AppTheme.green,
        'ADVANCE' => AppTheme.cyan,
        'ADVANCE_USED' => AppTheme.purple,
        _ => AppTheme.amber,
      };
}
