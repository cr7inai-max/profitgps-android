import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../widgets/common.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String query = '';
  Supplier? selected;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final suppliers = app.data!.suppliers.where((s) {
      final q = query.trim().toLowerCase();
      return q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          s.mobile.contains(q) ||
          s.gstin.toLowerCase().contains(q);
    }).toList();
    if (selected == null && suppliers.isNotEmpty) selected = suppliers.first;

    final payable =
        app.data!.suppliers.fold<double>(0, (a, b) => a + b.openingPayable);
    final advances = app.data!.suppliers
        .fold<double>(0, (a, b) => a + b.supplierCreditBalance);

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        SectionTitle(
          'Suppliers',
          subtitle:
              'Supplier master details and current account balances. Historical purchases, payments and documents are also available under Records.',
          trailing: FilledButton.icon(
            onPressed: () => _addSupplier(context),
            icon: const Icon(Icons.add),
            label: const Text('Add supplier'),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpi(
              'Total suppliers',
              '${app.data!.suppliers.length}',
              Icons.groups_2_rounded,
              AppTheme.cyan,
            ),
            _kpi(
              'Active suppliers',
              '${app.data!.suppliers.where((e) => e.active).length}',
              Icons.verified_rounded,
              AppTheme.green,
            ),
            _kpi(
              'Amount payable to suppliers',
              money(payable),
              Icons.account_balance_wallet_rounded,
              AppTheme.amber,
            ),
            _kpi(
              'Advance already paid to suppliers',
              money(advances),
              Icons.savings_outlined,
              AppTheme.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 980;
            final directory = Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supplier directory',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search supplier / code / GSTIN / mobile',
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...suppliers.map(
                      (s) => ListTile(
                        selected: selected?.id == s.id,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () => setState(() => selected = s),
                        leading: CircleAvatar(
                          child: Text(
                            s.name.isEmpty ? 'S' : s.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(
                          '${s.code} • ${s.name}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${s.category}${s.city.isEmpty ? '' : ' • ${s.city}'}',
                        ),
                        trailing: StatusPill(
                          text: s.active ? 'Active' : 'Inactive',
                          color: s.active ? AppTheme.green : AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final details = selected == null
                ? const EmptyState(
                    'Add a supplier to begin.',
                    icon: Icons.local_shipping_outlined,
                  )
                : _SupplierDetails(
                    supplier: selected!,
                    onSaved: () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Save supplier details?',
                        message:
                            'Save the current details for ${selected!.name}?',
                        confirmLabel: 'Save supplier',
                      );
                      if (!ok) return;
                      await app.persist();
                      if (mounted) setState(() {});
                    },
                    onPayment: (amount, mode, reference) async {
                      await app.recordSupplierPayment(
                        selected!,
                        amount,
                        paymentMode: mode,
                        reference: reference,
                      );
                      if (mounted) setState(() {});
                    },
                  );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 430, child: directory),
                  const SizedBox(width: 12),
                  Expanded(child: details),
                ],
              );
            }
            return Column(
              children: [directory, const SizedBox(height: 12), details],
            );
          },
        ),
      ],
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) =>
      SizedBox(
        width: 260,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _addSupplier(BuildContext context) async {
    final app = AppScope.of(context);
    final next =
        'SUP${(app.data!.suppliers.length + 1).toString().padLeft(3, '0')}';
    final ok = await confirmAction(
      context,
      title: 'Create supplier?',
      message:
          'Create a new supplier master record with code $next? You can enter the supplier details after creation.',
      confirmLabel: 'Create supplier',
      icon: Icons.local_shipping_outlined,
    );
    if (!ok) return;
    final supplier = Supplier(
      id: const Uuid().v4(),
      code: next,
      name: 'New Supplier',
    );
    await app.addSupplier(supplier);
    if (mounted) setState(() => selected = supplier);
  }
}

class _SupplierDetails extends StatefulWidget {
  const _SupplierDetails({
    required this.supplier,
    required this.onSaved,
    required this.onPayment,
  });

  final Supplier supplier;
  final Future<void> Function() onSaved;
  final Future<void> Function(double, String, String) onPayment;

  @override
  State<_SupplierDetails> createState() => _SupplierDetailsState();
}

class _SupplierDetailsState extends State<_SupplierDetails> {
  late Supplier supplier;

  @override
  void initState() {
    super.initState();
    supplier = widget.supplier;
  }

  @override
  void didUpdateWidget(covariant _SupplierDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supplier.id != widget.supplier.id) {
      supplier = widget.supplier;
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${supplier.code} • ${supplier.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Switch(
                    value: supplier.active,
                    onChanged: (v) => setState(() => supplier.active = v),
                  ),
                ],
              ),
              const Divider(),
              const Text(
                'Basic information',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _field('Supplier code', supplier.code,
                      (v) => supplier.code = v),
                  _field('Supplier name', supplier.name,
                      (v) => supplier.name = v),
                  _field('Contact person', supplier.contactPerson,
                      (v) => supplier.contactPerson = v),
                  _field('Mobile number', supplier.mobile,
                      (v) => supplier.mobile = v),
                  _field('Alternate number', supplier.alternateMobile,
                      (v) => supplier.alternateMobile = v),
                  _field('WhatsApp', supplier.whatsapp,
                      (v) => supplier.whatsapp = v),
                  _field('Email', supplier.email, (v) => supplier.email = v),
                  _field('GSTIN', supplier.gstin, (v) => supplier.gstin = v),
                  _field('PAN', supplier.pan, (v) => supplier.pan = v),
                  _field('Category', supplier.category,
                      (v) => supplier.category = v),
                  _field(
                    'Brand / supplied items',
                    supplier.suppliedItems,
                    (v) => supplier.suppliedItems = v,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Address & default terms',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _field(
                    'Billing address',
                    supplier.address,
                    (v) => supplier.address = v,
                    width: 360,
                  ),
                  _field('City', supplier.city, (v) => supplier.city = v),
                  _field('State', supplier.state, (v) => supplier.state = v),
                  _field(
                    'Pincode',
                    supplier.pincode,
                    (v) => supplier.pincode = v,
                  ),
                  _field(
                    'Default payment terms',
                    supplier.paymentTerms,
                    (v) => supplier.paymentTerms = v,
                  ),
                  _field(
                    'Credit days',
                    '${supplier.creditDays}',
                    (v) => supplier.creditDays = int.tryParse(v) ?? 0,
                  ),
                  _field(
                    'Opening amount payable',
                    '${supplier.openingPayable}',
                    (v) => supplier.openingPayable = double.tryParse(v) ?? 0,
                  ),
                  _field(
                    'Bank / UPI details',
                    supplier.bankUpi,
                    (v) => supplier.bankUpi = v,
                    width: 300,
                  ),
                  _field(
                    'Notes',
                    supplier.notes,
                    (v) => supplier.notes = v,
                    width: 360,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10151C),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppTheme.border),
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final account = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supplier account',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Amount payable to supplier: ${money(supplier.openingPayable)}',
                          style: const TextStyle(color: AppTheme.amber),
                        ),
                        Text(
                          'Advance already paid to supplier: ${money(supplier.supplierCreditBalance)}',
                          style: const TextStyle(color: AppTheme.green),
                        ),
                      ],
                    );
                    final button = OutlinedButton.icon(
                      onPressed: supplier.openingPayable <= 0
                          ? null
                          : () => _recordPayment(context),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Pay supplier'),
                    );
                    if (c.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          account,
                          const SizedBox(height: 10),
                          button,
                        ],
                      );
                    }
                    return Row(
                      children: [Expanded(child: account), button],
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: widget.onSaved,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save supplier'),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _recordPayment(BuildContext context) async {
    final amount = TextEditingController(
      text: supplier.openingPayable.toStringAsFixed(2),
    );
    final reference = TextEditingController();
    String mode = 'Bank Transfer';

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text('Pay supplier • ${supplier.name}'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Amount currently payable: ${money(supplier.openingPayable)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount paid'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: mode,
                  items: const [
                    'Cash',
                    'UPI',
                    'Bank Transfer',
                    'Cheque',
                  ]
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => update(() => mode = v ?? 'Bank Transfer'),
                  decoration: const InputDecoration(labelText: 'Payment mode'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'UTR / cheque / transaction reference',
                  ),
                ),
              ],
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

    final value = double.tryParse(amount.text) ?? 0;
    if (value <= 0) return;
    final applied = value.clamp(0.0, supplier.openingPayable).toDouble();
    final excess = (value - applied).clamp(0.0, double.infinity).toDouble();
    final confirmed = await confirmAction(
      context,
      title: 'Confirm supplier payment',
      message:
          'Supplier: ${supplier.name}\n'
          'Pay now: ${money(value)}\n'
          'Mode: $mode\n'
          '${reference.text.trim().isEmpty ? '' : 'Reference: ${reference.text.trim()}\n'}'
          'Amount payable reduced by: ${money(applied)}\n'
          '${excess > 0 ? 'Extra amount becomes supplier advance: ${money(excess)}' : ''}',
      confirmLabel: 'Confirm payment',
      icon: Icons.payments_outlined,
    );
    if (!confirmed) return;

    await widget.onPayment(value, mode, reference.text.trim());
    if (mounted) setState(() {});
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    double width = 220,
  }) =>
      SizedBox(
        width: width,
        child: TextFormField(
          key: ValueKey('${supplier.id}-$label'),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          onChanged: onChanged,
        ),
      );
}
