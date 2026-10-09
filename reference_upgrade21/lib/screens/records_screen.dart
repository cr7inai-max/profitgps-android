import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../services/invoice_service.dart';
import '../services/document_rules.dart';
import '../widgets/common.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  int section = 0;
  String query = '';
  String documentType = 'All';

  // Records filters. Date filters are intentionally shared within Records so
  // users can move between Documents / Payments / Purchases using the same
  // reporting window. Section-specific filters remain independent.
  String datePreset = 'All time';
  String monthFilter = 'All';
  String yearFilter = 'All';
  DateTimeRange? customDateRange;

  String customerAccountFilter = 'All';
  String customerGstFilter = 'All';
  String customerSort = 'Name A-Z';

  String supplierStatusFilter = 'All';
  String supplierAccountFilter = 'All';
  String supplierGstFilter = 'All';
  String supplierSort = 'Name A-Z';

  String documentPartyFilter = 'All';
  String documentStatusFilter = 'All';
  String documentPaymentModeFilter = 'All';
  String documentSort = 'Newest';

  String paymentDirectionFilter = 'All';
  String paymentPartyFilter = 'All';
  String paymentModeFilter = 'All';
  String paymentSort = 'Newest';

  String purchaseSourceFilter = 'All';
  String purchaseSettlementFilter = 'All';
  String purchasePaymentModeFilter = 'All';
  String purchaseDateBasis = 'Recorded date';
  String purchaseSort = 'Newest';

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data!;
    final sections = const [
      'Customers',
      'Suppliers',
      'Documents',
      'Payments',
      'Purchases',
    ];

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 20, 22, 4),
          child: SectionTitle(
            'Records',
            subtitle:
                'One business archive for customer and supplier master details, corrections, transactions, documents, payments and ledgers.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => ChoiceChip(
                selected: section == index,
                label: Text(sections[index]),
                onSelected: (_) => setState(() {
                  section = index;
                  query = '';
                  _resetDateFilters();
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (section) {
            0 => _customerRecords(data),
            1 => _supplierRecords(data),
            2 => _salesDocuments(data),
            3 => _payments(data),
            4 => _purchaseRecords(data),
            5 => _inventoryRecords(data), // retained internally for migration compatibility
            6 => _cashCloseRecords(data), // retained internally for migration compatibility
            _ => _purchaseRecords(data),
          },
        ),
      ],
    );
  }

  Widget _search({
    required String hint,
    Widget? trailing,
  }) {
    final field = TextField(
      onChanged: (value) => setState(() => query = value),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: hint,
      ),
    );
    if (trailing == null) return field;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: [
              field,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            SizedBox(width: 210, child: trailing),
          ],
        );
      },
    );
  }


  static const _monthNames = <String>[
    'All',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  void _resetDateFilters() {
    datePreset = 'All time';
    monthFilter = 'All';
    yearFilter = 'All';
    customDateRange = null;
  }

  bool _matchesDate(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    var presetMatch = true;

    if (datePreset == 'Today') {
      presetMatch = date == today;
    } else if (datePreset == 'Yesterday') {
      presetMatch = date == today.subtract(const Duration(days: 1));
    } else if (datePreset == 'Last 7 days') {
      presetMatch = !date.isBefore(today.subtract(const Duration(days: 6))) &&
          !date.isAfter(today);
    } else if (datePreset == 'Last 30 days') {
      presetMatch = !date.isBefore(today.subtract(const Duration(days: 29))) &&
          !date.isAfter(today);
    } else if (datePreset == 'This month') {
      presetMatch = value.year == now.year && value.month == now.month;
    } else if (datePreset == 'Last month') {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      presetMatch =
          value.year == lastMonth.year && value.month == lastMonth.month;
    } else if (datePreset == 'This year') {
      presetMatch = value.year == now.year;
    } else if (datePreset == 'Custom range') {
      final range = customDateRange;
      if (range != null) {
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        presetMatch = !date.isBefore(start) && !date.isAfter(end);
      }
    }
    if (!presetMatch) return false;

    if (monthFilter != 'All') {
      final month = _monthNames.indexOf(monthFilter);
      if (month <= 0 || value.month != month) return false;
    }
    if (yearFilter != 'All' && value.year.toString() != yearFilter) {
      return false;
    }
    return true;
  }

  List<String> _yearOptions(Iterable<DateTime> dates) {
    final years = dates.map((e) => e.year).toSet().toList()..sort((a, b) => b.compareTo(a));
    if (yearFilter != 'All') {
      final selected = int.tryParse(yearFilter);
      if (selected != null && !years.contains(selected)) years.add(selected);
      years.sort((a, b) => b.compareTo(a));
    }
    return ['All', ...years.map((e) => e.toString())];
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    double width = 180,
  }) {
    final normalized = options.contains(value) ? value : options.first;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: normalized,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: options
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  Widget _dateFilters(
    Iterable<DateTime> dates, {
    VoidCallback? onResetExtra,
    List<Widget> leading = const [],
    List<Widget> trailing = const [],
  }) {
    final years = _yearOptions(dates);
    final rangeLabel = customDateRange == null
        ? 'Choose dates'
        : '${_dateOnly(customDateRange!.start)} → ${_dateOnly(customDateRange!.end)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.filter_alt_outlined, color: AppTheme.cyan),
            ),
            ...leading,
            _filterDropdown(
              label: 'Date',
              value: datePreset,
              options: const [
                'All time',
                'Today',
                'Yesterday',
                'Last 7 days',
                'Last 30 days',
                'This month',
                'Last month',
                'This year',
                'Custom range',
              ],
              onChanged: (value) async {
                setState(() => datePreset = value);
                if (value == 'Custom range') {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(DateTime.now().year + 10, 12, 31),
                    initialDateRange: customDateRange,
                  );
                  if (picked != null && mounted) {
                    setState(() => customDateRange = picked);
                  }
                }
              },
              width: 175,
            ),
            _filterDropdown(
              label: 'Month',
              value: monthFilter,
              options: _monthNames,
              onChanged: (value) => setState(() => monthFilter = value),
              width: 125,
            ),
            _filterDropdown(
              label: 'Year',
              value: yearFilter,
              options: years,
              onChanged: (value) => setState(() => yearFilter = value),
              width: 120,
            ),
            if (datePreset == 'Custom range')
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(DateTime.now().year + 10, 12, 31),
                    initialDateRange: customDateRange,
                  );
                  if (picked != null && mounted) {
                    setState(() => customDateRange = picked);
                  }
                },
                icon: const Icon(Icons.date_range_outlined),
                label: Text(rangeLabel),
              ),
            ...trailing,
            TextButton.icon(
              onPressed: () => setState(() {
                _resetDateFilters();
                onResetExtra?.call();
              }),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }

  static String _dateOnly(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day-$month-${value.year}';
  }

  static String _saleSettlementStatus(Sale sale) {
    if (sale.balanceDue <= 0.005) return 'Paid';
    if (sale.settledAmount <= 0.005) return 'Unpaid';
    return 'Partial';
  }

  static String _saleDisplayType(Sale sale) {
    final normalized = sale.documentType == 'Retail Bill' ? 'Bill / Receipt' : sale.documentType;
    if (normalized == DocumentRules.taxInvoice &&
        !sale.gstBillRequested &&
        sale.customerGstin.trim().isEmpty) {
      return 'Retail Tax Invoice';
    }
    return normalized;
  }

  static String _purchaseSettlementStatus(PurchaseRecord purchase) {
    if (purchase.sourceType == 'PRODUCTION') return 'N/A';
    if (purchase.balanceDue <= 0.005) return 'Paid';
    if (purchase.settledAmount <= 0.005) return 'Unpaid';
    return 'Partial';
  }

  static String _purchaseSourceLabel(String sourceType) => switch (sourceType) {
        'LOCAL' => 'Local / Cash',
        'PRODUCTION' => 'Own Production',
        _ => 'Supplier',
      };

  List<String> _paymentModeOptions(AppData data) {
    final modes = <String>{};
    for (final sale in data.sales) {
      if (sale.paymentMethod.trim().isNotEmpty) modes.add(sale.paymentMethod.trim());
    }
    for (final purchase in data.purchases) {
      if (purchase.paymentMode.trim().isNotEmpty) modes.add(purchase.paymentMode.trim());
    }
    for (final entry in data.ledger) {
      if (entry.paymentMode.trim().isNotEmpty) modes.add(entry.paymentMode.trim());
    }
    for (final entry in data.supplierLedger) {
      if (entry.paymentMode.trim().isNotEmpty) modes.add(entry.paymentMode.trim());
    }
    final list = modes.toList()..sort();
    return ['All', ...list];
  }

  Widget _filterRecordTile(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 230,
      child: Card(
        color: selected ? color.withOpacity(.09) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? color : AppTheme.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle_rounded, color: color, size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerRecords(AppData data) {
    final q = query.trim().toLowerCase();
    final customers = data.customers.where((customer) {
      final textMatch = q.isEmpty ||
          customer.id.toLowerCase().contains(q) ||
          customer.name.toLowerCase().contains(q) ||
          customer.phone.toLowerCase().contains(q) ||
          customer.gstin.toLowerCase().contains(q);
      if (!textMatch || !_matchesDate(customer.createdAt)) return false;
      final accountMatch = switch (customerAccountFilter) {
        'Has due' => customer.creditBalance > 0.005,
        'Has advance' => customer.advanceBalance > 0.005,
        'Clear balance' => customer.creditBalance <= 0.005 && customer.advanceBalance <= 0.005,
        _ => true,
      };
      final gstMatch = switch (customerGstFilter) {
        'GSTIN available' => customer.gstin.trim().isNotEmpty,
        'No GSTIN' => customer.gstin.trim().isEmpty,
        _ => true,
      };
      return accountMatch && gstMatch;
    }).toList();
    customers.sort((a, b) => switch (customerSort) {
      'Newest' => b.createdAt.compareTo(a.createdAt),
      'Highest due' => b.creditBalance.compareTo(a.creditBalance),
      'Highest advance' => b.advanceBalance.compareTo(a.advanceBalance),
      _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    });
    final receivable =
        data.customers.fold<double>(0, (sum, c) => sum + c.creditBalance);
    final advances =
        data.customers.fold<double>(0, (sum, c) => sum + c.advanceBalance);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _recordTile(
              'Customers',
              '${data.customers.length}',
              Icons.people_alt_outlined,
              AppTheme.cyan,
            ),
            _recordTile(
              'Customer owes us',
              money(receivable),
              Icons.request_quote_outlined,
              receivable > 0 ? AppTheme.amber : AppTheme.green,
            ),
            _recordTile(
              'Customer advance held',
              money(advances),
              Icons.savings_outlined,
              AppTheme.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _search(
          hint: 'Search customer ID / name / mobile / GSTIN',
          trailing: FilledButton.icon(
            onPressed: () => _customerMasterDialog(),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('New customer'),
          ),
        ),
        const SizedBox(height: 8),
        _dateFilters(
          data.customers.map((c) => c.createdAt),
          leading: [
            _filterDropdown(
              label: 'Account',
              value: customerAccountFilter,
              options: const ['All', 'Has due', 'Has advance', 'Clear balance'],
              onChanged: (value) => setState(() => customerAccountFilter = value),
              width: 155,
            ),
            _filterDropdown(
              label: 'GST',
              value: customerGstFilter,
              options: const ['All', 'GSTIN available', 'No GSTIN'],
              onChanged: (value) => setState(() => customerGstFilter = value),
              width: 160,
            ),
            _filterDropdown(
              label: 'Sort',
              value: customerSort,
              options: const ['Name A-Z', 'Newest', 'Highest due', 'Highest advance'],
              onChanged: (value) => setState(() => customerSort = value),
              width: 165,
            ),
          ],
          onResetExtra: () {
            customerAccountFilter = 'All';
            customerGstFilter = 'All';
            customerSort = 'Name A-Z';
          },
        ),
        const SizedBox(height: 12),
        if (customers.isEmpty)
          const EmptyState(
            'No matching customer records.',
            icon: Icons.person_search_outlined,
          ),
        ...customers.map((customer) {
          final sales = data.sales.where((s) => s.customerId == customer.id);
          final paid =
              sales.fold<double>(0, (sum, sale) => sum + sale.amountPaid);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppTheme.redSoft,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: AppTheme.red,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${customer.name} • ${customer.id}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  customer.phone.isEmpty
                                      ? 'No mobile number'
                                      : customer.phone,
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _plainMetric(
                            'Customer owes us',
                            money(customer.creditBalance),
                            customer.creditBalance > 0
                                ? AppTheme.amber
                                : AppTheme.green,
                          ),
                          _plainMetric(
                            'Customer advance available',
                            money(customer.advanceBalance),
                            AppTheme.cyan,
                          ),
                          _plainMetric(
                            'Documents',
                            '${sales.length}',
                            AppTheme.muted,
                          ),
                          _plainMetric(
                            'Paid on sales',
                            money(paid),
                            AppTheme.green,
                          ),
                        ],
                      ),
                    ],
                  );

                  final actions = Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _customerMasterDialog(customer),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit details'),
                      ),
                      OutlinedButton.icon(
                        onPressed: customer.creditBalance <= 0
                            ? null
                            : () => _collectCustomerDue(customer),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Collect due'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showCustomerRecord(data, customer),
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Open record'),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        details,
                        const SizedBox(height: 12),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 12),
                      Flexible(child: actions),
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _supplierRecords(AppData data) {
    final q = query.trim().toLowerCase();
    final suppliers = data.suppliers.where((supplier) {
      final textMatch = q.isEmpty ||
          supplier.code.toLowerCase().contains(q) ||
          supplier.name.toLowerCase().contains(q) ||
          supplier.mobile.toLowerCase().contains(q) ||
          supplier.gstin.toLowerCase().contains(q);
      if (!textMatch) return false;
      final statusMatch = switch (supplierStatusFilter) {
        'Active' => supplier.active,
        'Inactive' => !supplier.active,
        _ => true,
      };
      final accountMatch = switch (supplierAccountFilter) {
        'Has payable' => supplier.openingPayable > 0.005,
        'Has advance' => supplier.supplierCreditBalance > 0.005,
        'Clear balance' => supplier.openingPayable <= 0.005 && supplier.supplierCreditBalance <= 0.005,
        _ => true,
      };
      final gstMatch = switch (supplierGstFilter) {
        'GSTIN available' => supplier.gstin.trim().isNotEmpty,
        'No GSTIN' => supplier.gstin.trim().isEmpty,
        _ => true,
      };
      return statusMatch && accountMatch && gstMatch;
    }).toList();
    suppliers.sort((a, b) => switch (supplierSort) {
      'Highest payable' => b.openingPayable.compareTo(a.openingPayable),
      'Highest advance' => b.supplierCreditBalance.compareTo(a.supplierCreditBalance),
      _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    });
    final payable =
        data.suppliers.fold<double>(0, (sum, s) => sum + s.openingPayable);
    final advances = data.suppliers
        .fold<double>(0, (sum, s) => sum + s.supplierCreditBalance);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _recordTile(
              'Suppliers',
              '${data.suppliers.length}',
              Icons.local_shipping_outlined,
              AppTheme.cyan,
            ),
            _recordTile(
              'Amount payable to suppliers',
              money(payable),
              Icons.account_balance_wallet_outlined,
              payable > 0 ? AppTheme.amber : AppTheme.green,
            ),
            _recordTile(
              'Advance already paid',
              money(advances),
              Icons.savings_outlined,
              AppTheme.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _search(
          hint: 'Search supplier code / name / mobile / GSTIN',
          trailing: FilledButton.icon(
            onPressed: () => _supplierMasterDialog(),
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('New supplier'),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.filter_alt_outlined, color: AppTheme.cyan),
                _filterDropdown(
                  label: 'Status',
                  value: supplierStatusFilter,
                  options: const ['All', 'Active', 'Inactive'],
                  onChanged: (value) => setState(() => supplierStatusFilter = value),
                  width: 135,
                ),
                _filterDropdown(
                  label: 'Account',
                  value: supplierAccountFilter,
                  options: const ['All', 'Has payable', 'Has advance', 'Clear balance'],
                  onChanged: (value) => setState(() => supplierAccountFilter = value),
                  width: 155,
                ),
                _filterDropdown(
                  label: 'GST',
                  value: supplierGstFilter,
                  options: const ['All', 'GSTIN available', 'No GSTIN'],
                  onChanged: (value) => setState(() => supplierGstFilter = value),
                  width: 160,
                ),
                _filterDropdown(
                  label: 'Sort',
                  value: supplierSort,
                  options: const ['Name A-Z', 'Highest payable', 'Highest advance'],
                  onChanged: (value) => setState(() => supplierSort = value),
                  width: 165,
                ),
                TextButton.icon(
                  onPressed: () => setState(() {
                    supplierStatusFilter = 'All';
                    supplierAccountFilter = 'All';
                    supplierGstFilter = 'All';
                    supplierSort = 'Name A-Z';
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Reset filters'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (suppliers.isEmpty)
          const EmptyState(
            'No matching supplier records.',
            icon: Icons.local_shipping_outlined,
          ),
        ...suppliers.map((supplier) {
          final purchases =
              data.purchases.where((p) => p.supplierId == supplier.id);
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF14212B),
                            child: Icon(
                              Icons.local_shipping_outlined,
                              color: AppTheme.cyan,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${supplier.code} • ${supplier.name}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  [
                                    if (supplier.mobile.isNotEmpty)
                                      supplier.mobile,
                                    if (supplier.city.isNotEmpty) supplier.city,
                                    if (supplier.state.isNotEmpty)
                                      supplier.state,
                                  ].join(' • '),
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            text: supplier.active ? 'Active' : 'Inactive',
                            color: supplier.active
                                ? AppTheme.green
                                : AppTheme.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _plainMetric(
                            'Amount payable to supplier',
                            money(supplier.openingPayable),
                            supplier.openingPayable > 0
                                ? AppTheme.amber
                                : AppTheme.green,
                          ),
                          _plainMetric(
                            'Advance already paid',
                            money(supplier.supplierCreditBalance),
                            AppTheme.cyan,
                          ),
                          _plainMetric(
                            'Purchases',
                            '${purchases.length}',
                            AppTheme.muted,
                          ),
                        ],
                      ),
                    ],
                  );

                  final actions = Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _supplierMasterDialog(supplier),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit details'),
                      ),
                      OutlinedButton.icon(
                        onPressed: supplier.openingPayable <= 0
                            ? null
                            : () => _paySupplier(supplier),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Pay supplier'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showSupplierRecord(data, supplier),
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('Open record'),
                      ),
                    ],
                  );

                  if (constraints.maxWidth < 900) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        details,
                        const SizedBox(height: 12),
                        actions,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 12),
                      Flexible(child: actions),
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _masterField(
    String label,
    TextEditingController controller, {
    double width = 230,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Future<void> _customerMasterDialog([Customer? customer]) async {
    final app = AppScope.of(context);
    final creating = customer == null;
    final name = TextEditingController(text: customer?.name ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final business = TextEditingController(text: customer?.businessName ?? '');
    final gstin = TextEditingController(text: customer?.gstin ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final state = TextEditingController(text: customer?.state ?? 'Tamil Nadu');
    final stateCode =
        TextEditingController(text: customer?.stateCode ?? '33');
    final discount = TextEditingController(
      text: (customer?.discountPercent ?? 0).toStringAsFixed(1),
    );
    final openingDue = TextEditingController(text: '0');
    final openingAdvance = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(creating ? 'New customer' : 'Edit customer details'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!creating)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10151C),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Text(
                      'Customer ID ${customer.id} • balances are controlled by transactions and cannot be overwritten here.',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _masterField('Customer name *', name, width: 250),
                    _masterField('Mobile number', phone),
                    _masterField('Business name', business, width: 250),
                    _masterField('GSTIN', gstin, width: 250),
                    _masterField('State', state),
                    _masterField('State code', stateCode, width: 150),
                    _masterField(
                      'Default discount %',
                      discount,
                      width: 190,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    if (creating)
                      _masterField(
                        'Opening: customer owes us',
                        openingDue,
                        width: 230,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    if (creating)
                      _masterField(
                        'Opening: customer advance held',
                        openingAdvance,
                        width: 240,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                      ),
                    _masterField(
                      'Billing address',
                      address,
                      width: 500,
                      maxLines: 2,
                    ),
                  ],
                ),
                if (creating) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Opening balances are recorded in the customer ledger. After creation, use payments / advances instead of manually changing balances.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
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
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.save_outlined),
            label: Text(creating ? 'Create customer' : 'Save correction'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer name is required.')),
      );
      return;
    }

    final discountValue =
        (double.tryParse(discount.text.trim()) ?? 0).clamp(0.0, 100.0);
    if (creating) {
      final created = await app.createCustomer(
        name: name.text.trim(),
        phone: phone.text.trim(),
        gstin: gstin.text.trim(),
        businessName: business.text.trim(),
        address: address.text.trim(),
        state: state.text.trim().isEmpty ? 'Tamil Nadu' : state.text.trim(),
        stateCode:
            stateCode.text.trim().isEmpty ? '33' : stateCode.text.trim(),
      );
      created.discountPercent = discountValue.toDouble();
      final due = (double.tryParse(openingDue.text.trim()) ?? 0)
          .clamp(0.0, double.infinity)
          .toDouble();
      final advance = (double.tryParse(openingAdvance.text.trim()) ?? 0)
          .clamp(0.0, double.infinity)
          .toDouble();
      created.creditBalance = due;
      created.advanceBalance = advance;
      if (due > 0) {
        app.data!.ledger.insert(
          0,
          CustomerLedgerEntry(
            id: const Uuid().v4(),
            customerId: created.id,
            createdAt: DateTime.now(),
            type: 'RECEIVABLE',
            amount: due,
            note: 'Opening customer receivable',
          ),
        );
      }
      if (advance > 0) {
        app.data!.ledger.insert(
          0,
          CustomerLedgerEntry(
            id: const Uuid().v4(),
            customerId: created.id,
            createdAt: DateTime.now(),
            type: 'ADVANCE',
            amount: advance,
            note: 'Opening customer advance',
          ),
        );
      }
      await app.persist();
    } else {
      final existing = customer;
      existing.name = name.text.trim();
      existing.phone = phone.text.trim();
      existing.businessName = business.text.trim();
      existing.gstin = gstin.text.trim();
      existing.address = address.text.trim();
      existing.state =
          state.text.trim().isEmpty ? 'Tamil Nadu' : state.text.trim();
      existing.stateCode =
          stateCode.text.trim().isEmpty ? '33' : stateCode.text.trim();
      existing.discountPercent = discountValue.toDouble();
      await app.persist();
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          creating ? 'Customer created in Records.' : 'Customer details updated.',
        ),
      ),
    );
  }

  Future<void> _collectCustomerDue(Customer customer) async {
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
                  Text(
                    'Customer currently owes us ${money(customer.creditBalance)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Amount received'),
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
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => update(() => mode = v ?? 'Cash'),
                    decoration: const InputDecoration(labelText: 'Payment mode'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Transaction / UTR / cheque reference',
                    ),
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
    final confirmed = await confirmAction(
      context,
      title: 'Confirm customer payment',
      message:
          'Customer: ${customer.name}\nReceived: ${money(value)}\nMode: $mode'
          '${reference.text.trim().isEmpty ? '' : '\nReference: ${reference.text.trim()}'}',
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

  Future<void> _supplierMasterDialog([Supplier? supplier]) async {
    final app = AppScope.of(context);
    final creating = supplier == null;
    final suggestedCode =
        'SUP${(app.data!.suppliers.length + 1).toString().padLeft(3, '0')}';
    final code = TextEditingController(text: supplier?.code ?? suggestedCode);
    final name = TextEditingController(text: supplier?.name ?? '');
    final contact = TextEditingController(text: supplier?.contactPerson ?? '');
    final mobile = TextEditingController(text: supplier?.mobile ?? '');
    final altMobile = TextEditingController(text: supplier?.alternateMobile ?? '');
    final whatsapp = TextEditingController(text: supplier?.whatsapp ?? '');
    final email = TextEditingController(text: supplier?.email ?? '');
    final gstin = TextEditingController(text: supplier?.gstin ?? '');
    final pan = TextEditingController(text: supplier?.pan ?? '');
    final category = TextEditingController(text: supplier?.category ?? 'General');
    final items = TextEditingController(text: supplier?.suppliedItems ?? '');
    final address = TextEditingController(text: supplier?.address ?? '');
    final city = TextEditingController(text: supplier?.city ?? '');
    final state = TextEditingController(text: supplier?.state ?? 'Tamil Nadu');
    final pincode = TextEditingController(text: supplier?.pincode ?? '');
    final terms = TextEditingController(text: supplier?.paymentTerms ?? 'Cash');
    final creditDays =
        TextEditingController(text: '${supplier?.creditDays ?? 0}');
    final bankUpi = TextEditingController(text: supplier?.bankUpi ?? '');
    final notes = TextEditingController(text: supplier?.notes ?? '');
    final openingPayable = TextEditingController(text: '0');
    final openingAdvance = TextEditingController(text: '0');
    var active = supplier?.active ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(creating ? 'New supplier' : 'Edit supplier details'),
          content: SizedBox(
            width: 850,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          creating
                              ? 'Supplier master + account opening'
                              : 'Correct supplier master details',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const Text('Active'),
                      Switch(
                        value: active,
                        onChanged: (v) => update(() => active = v),
                      ),
                    ],
                  ),
                  if (!creating)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10151C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Text(
                        'Payable and advance balances are controlled by purchase/payment transactions and are not overwritten during a master correction.',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _masterField('Supplier code *', code, width: 180),
                      _masterField('Supplier name *', name, width: 260),
                      _masterField('Contact person', contact),
                      _masterField('Mobile number', mobile),
                      _masterField('Alternate mobile', altMobile),
                      _masterField('WhatsApp', whatsapp),
                      _masterField('Email', email, width: 270),
                      _masterField('GSTIN', gstin, width: 230),
                      _masterField('PAN', pan, width: 190),
                      _masterField('Category', category),
                      _masterField('Brand / supplied items', items, width: 300),
                      _masterField('City', city),
                      _masterField('State', state),
                      _masterField('Pincode', pincode, width: 160),
                      _masterField('Payment terms', terms, width: 210),
                      _masterField(
                        'Credit days',
                        creditDays,
                        width: 150,
                        keyboardType: TextInputType.number,
                      ),
                      _masterField('Bank / UPI details', bankUpi, width: 300),
                      if (creating)
                        _masterField(
                          'Opening amount payable',
                          openingPayable,
                          width: 220,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      if (creating)
                        _masterField(
                          'Opening supplier advance',
                          openingAdvance,
                          width: 220,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      _masterField(
                        'Billing address',
                        address,
                        width: 500,
                        maxLines: 2,
                      ),
                      _masterField(
                        'Notes',
                        notes,
                        width: 500,
                        maxLines: 2,
                      ),
                    ],
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
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.save_outlined),
              label: Text(creating ? 'Create supplier' : 'Save correction'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty || code.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier code and name are required.')),
      );
      return;
    }
    final duplicate = app.data!.suppliers.any(
      (s) => s.id != supplier?.id &&
          s.code.trim().toLowerCase() == code.text.trim().toLowerCase(),
    );
    if (duplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier code already exists.')),
      );
      return;
    }

    if (creating) {
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
        alternateMobile: altMobile.text.trim(),
        whatsapp: whatsapp.text.trim(),
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
        active: active,
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
    } else {
      final existing = supplier;
      existing.code = code.text.trim();
      existing.name = name.text.trim();
      existing.contactPerson = contact.text.trim();
      existing.mobile = mobile.text.trim();
      existing.alternateMobile = altMobile.text.trim();
      existing.whatsapp = whatsapp.text.trim();
      existing.email = email.text.trim();
      existing.gstin = gstin.text.trim();
      existing.pan = pan.text.trim();
      existing.category =
          category.text.trim().isEmpty ? 'General' : category.text.trim();
      existing.suppliedItems = items.text.trim();
      existing.address = address.text.trim();
      existing.city = city.text.trim();
      existing.state =
          state.text.trim().isEmpty ? 'Tamil Nadu' : state.text.trim();
      existing.pincode = pincode.text.trim();
      existing.paymentTerms =
          terms.text.trim().isEmpty ? 'Cash' : terms.text.trim();
      existing.creditDays = int.tryParse(creditDays.text.trim()) ?? 0;
      existing.bankUpi = bankUpi.text.trim();
      existing.notes = notes.text.trim();
      existing.active = active;
      await app.persist();
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          creating ? 'Supplier created in Records.' : 'Supplier details updated.',
        ),
      ),
    );
  }

  Future<void> _paySupplier(Supplier supplier) async {
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
                  items: const ['Cash', 'UPI', 'Bank Transfer', 'Cheque']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) =>
                      update(() => mode = v ?? 'Bank Transfer'),
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
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (value <= 0) return;
    final confirmed = await confirmAction(
      context,
      title: 'Confirm supplier payment',
      message:
          'Supplier: ${supplier.name}\nPaid: ${money(value)}\nMode: $mode'
          '${reference.text.trim().isEmpty ? '' : '\nReference: ${reference.text.trim()}'}',
      confirmLabel: 'Confirm payment',
      icon: Icons.payments_outlined,
    );
    if (!confirmed) return;
    await AppScope.of(context).recordSupplierPayment(
      supplier,
      value,
      paymentMode: mode,
      reference: reference.text.trim(),
    );
    if (mounted) setState(() {});
  }

  Widget _salesDocuments(AppData data) {
    final q = query.trim().toLowerCase();
    final documents = <_RecordDocument>[];

    for (final sale in data.sales) {
      final customerPhone = data.customers
              .where((customer) => customer.id == sale.customerId)
              .map((customer) => customer.phone)
              .firstOrNull ??
          '';
      final textMatch = q.isEmpty ||
          sale.documentNumber.toLowerCase().contains(q) ||
          sale.customerName.toLowerCase().contains(q) ||
          sale.customerId.toLowerCase().contains(q) ||
          customerPhone.toLowerCase().contains(q) ||
          sale.customerGstin.toLowerCase().contains(q) ||
          sale.paymentMethod.toLowerCase().contains(q) ||
          sale.paymentReference.toLowerCase().contains(q);
      if (!textMatch || !_matchesDate(sale.createdAt)) continue;

      final normalizedType = _saleDisplayType(sale);
      if (documentType != 'All' && normalizedType != documentType) continue;

      final partyType = sale.customerId.isEmpty ? 'Walk-in' : 'Customer';
      if (documentPartyFilter != 'All' && documentPartyFilter != partyType) continue;

      final status = _saleSettlementStatus(sale);
      if (documentStatusFilter != 'All' && documentStatusFilter != status) continue;

      if (documentPaymentModeFilter != 'All' &&
          sale.paymentMethod != documentPaymentModeFilter) {
        continue;
      }
      documents.add(_RecordDocument.sale(sale));
    }

    for (final quote in data.quotations) {
      if (documentType != 'All' && documentType != 'Quotation') continue;
      final textMatch = q.isEmpty ||
          quote.number.toLowerCase().contains(q) ||
          quote.customerName.toLowerCase().contains(q) ||
          quote.customerId.toLowerCase().contains(q) ||
          quote.customerGstin.toLowerCase().contains(q) ||
          quote.status.toLowerCase().contains(q);
      if (!textMatch || !_matchesDate(quote.createdAt)) continue;

      final partyType = quote.customerId.isEmpty ? 'Walk-in' : 'Customer';
      if (documentPartyFilter != 'All' && documentPartyFilter != partyType) continue;
      if (documentStatusFilter != 'All' && documentStatusFilter != quote.status) continue;
      if (documentPaymentModeFilter != 'All') continue;
      documents.add(_RecordDocument.quotation(quote));
    }

    for (final purchase in data.purchases) {
      final label = purchase.sourceType == 'SUPPLIER'
          ? 'Purchase Invoice'
          : purchase.sourceType == 'LOCAL'
              ? 'Local Purchase'
              : 'Own Production';
      if (documentType != 'All' && documentType != label) continue;
      final textMatch = q.isEmpty ||
          purchase.number.toLowerCase().contains(q) ||
          purchase.invoiceNumber.toLowerCase().contains(q) ||
          purchase.supplierName.toLowerCase().contains(q) ||
          purchase.supplierCode.toLowerCase().contains(q) ||
          purchase.sourceName.toLowerCase().contains(q) ||
          purchase.referenceNumber.toLowerCase().contains(q) ||
          purchase.purchaseOrderNumber.toLowerCase().contains(q);
      if (!textMatch || !_matchesDate(purchase.createdAt)) continue;

      final partyType = switch (purchase.sourceType) {
        'LOCAL' => 'Local / Cash',
        'PRODUCTION' => 'Own Production',
        _ => 'Supplier',
      };
      if (documentPartyFilter != 'All' && documentPartyFilter != partyType) continue;

      final status = _purchaseSettlementStatus(purchase);
      if (documentStatusFilter != 'All' && documentStatusFilter != status) continue;
      if (documentPaymentModeFilter != 'All' &&
          purchase.paymentMode != documentPaymentModeFilter) {
        continue;
      }
      documents.add(_RecordDocument.purchase(purchase));
    }

    documents.sort((a, b) => switch (documentSort) {
          'Oldest' => a.createdAt.compareTo(b.createdAt),
          'Highest amount' => b.amount.compareTo(a.amount),
          'Lowest amount' => a.amount.compareTo(b.amount),
          _ => b.createdAt.compareTo(a.createdAt),
        });

    final allDates = <DateTime>[
      ...data.sales.map((e) => e.createdAt),
      ...data.quotations.map((e) => e.createdAt),
      ...data.purchases.map((e) => e.createdAt),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      children: [
        _search(
          hint: 'Search any customer/supplier document, number, party or payment reference',
        ),
        const SizedBox(height: 8),
        _dateFilters(
          allDates,
          leading: [
            _filterDropdown(
              label: 'Document type',
              value: documentType,
              options: const [
                'All',
                'Tax Invoice',
                'Retail Tax Invoice',
                'Bill of Supply',
                'Bill / Receipt',
                'Quotation',
                'Purchase Invoice',
                'Local Purchase',
                'Own Production',
              ],
              onChanged: (value) => setState(() => documentType = value),
              width: 175,
            ),
            _filterDropdown(
              label: 'Party / source',
              value: documentPartyFilter,
              options: const [
                'All',
                'Customer',
                'Walk-in',
                'Supplier',
                'Local / Cash',
                'Own Production',
              ],
              onChanged: (value) => setState(() => documentPartyFilter = value),
              width: 165,
            ),
            _filterDropdown(
              label: 'Status',
              value: documentStatusFilter,
              options: const [
                'All',
                'Paid',
                'Partial',
                'Unpaid',
                'Draft',
                'Sent',
                'Accepted',
                'Converted',
                'Rejected',
                'Expired',
                'Cancelled',
              ],
              onChanged: (value) => setState(() => documentStatusFilter = value),
              width: 140,
            ),
            _filterDropdown(
              label: 'Payment mode',
              value: documentPaymentModeFilter,
              options: _paymentModeOptions(data),
              onChanged: (value) => setState(() => documentPaymentModeFilter = value),
              width: 150,
            ),
            _filterDropdown(
              label: 'Sort',
              value: documentSort,
              options: const ['Newest', 'Oldest', 'Highest amount', 'Lowest amount'],
              onChanged: (value) => setState(() => documentSort = value),
              width: 155,
            ),
          ],
          onResetExtra: () {
            documentType = 'All';
            documentPartyFilter = 'All';
            documentStatusFilter = 'All';
            documentPaymentModeFilter = 'All';
            documentSort = 'Newest';
          },
        ),
        const SizedBox(height: 12),
        if (documents.isEmpty)
          const EmptyState(
            'No matching documents.',
            icon: Icons.receipt_long_outlined,
          ),
        ...documents.map((document) {
          if (document.sale != null) return _saleDocumentCard(data, document.sale!);
          if (document.quotation != null) {
            return _quotationDocumentCard(data, document.quotation!);
          }
          return _purchaseDocumentCard(data, document.purchase!);
        }),
      ],
    );
  }

  Widget _payments(AppData data) {
    final events = <_PaymentEvent>[];

    for (final sale in data.sales) {
      if (sale.amountPaid <= 0) continue;
      events.add(
        _PaymentEvent(
          createdAt: sale.createdAt,
          direction: 'Received',
          party: sale.customerName,
          partyType: sale.customerId.isEmpty ? 'Walk-in' : 'Customer',
          amount: sale.amountPaid,
          mode: sale.paymentMethod,
          reference: sale.paymentReference,
          document: sale.documentNumber,
          detail: 'Billing payment',
        ),
      );
    }

    for (final entry in data.ledger) {
      if (entry.type != 'PAYMENT' && entry.type != 'ADVANCE') continue;
      final customer = data.customers
          .where((c) => c.id == entry.customerId)
          .firstOrNull;
      events.add(
        _PaymentEvent(
          createdAt: entry.createdAt,
          direction: 'Received',
          party: customer?.name ?? entry.customerId,
          partyType: 'Customer',
          amount: entry.amount,
          mode: entry.paymentMode,
          reference: entry.reference,
          document: entry.documentReference,
          detail: entry.type == 'ADVANCE'
              ? 'Customer advance received'
              : 'Customer due collected',
        ),
      );
    }

    for (final entry in data.supplierLedger) {
      if (entry.type != 'PAYMENT' && entry.type != 'ADVANCE') continue;
      final supplier = data.suppliers
          .where((s) => s.id == entry.supplierId)
          .firstOrNull;
      events.add(
        _PaymentEvent(
          createdAt: entry.createdAt,
          direction: 'Paid',
          party: supplier?.name ?? entry.supplierId,
          partyType: 'Supplier',
          amount: entry.amount,
          mode: entry.paymentMode,
          reference: entry.reference,
          document: entry.documentReference,
          detail: entry.type == 'ADVANCE'
              ? 'Supplier advance paid'
              : 'Supplier payment',
        ),
      );
    }

    final q = query.trim().toLowerCase();
    final filtered = events.where((event) {
      final textMatch = q.isEmpty ||
          event.party.toLowerCase().contains(q) ||
          event.mode.toLowerCase().contains(q) ||
          event.reference.toLowerCase().contains(q) ||
          event.document.toLowerCase().contains(q) ||
          event.detail.toLowerCase().contains(q);
      if (!textMatch || !_matchesDate(event.createdAt)) return false;
      if (paymentDirectionFilter != 'All' &&
          event.direction != paymentDirectionFilter) {
        return false;
      }
      if (paymentPartyFilter != 'All' && event.partyType != paymentPartyFilter) {
        return false;
      }
      if (paymentModeFilter != 'All' && event.mode != paymentModeFilter) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => switch (paymentSort) {
          'Oldest' => a.createdAt.compareTo(b.createdAt),
          'Highest amount' => b.amount.compareTo(a.amount),
          'Lowest amount' => a.amount.compareTo(b.amount),
          _ => b.createdAt.compareTo(a.createdAt),
        });

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      children: [
        _search(
          hint:
              'Search party / Cash / UPI / Card / Bank / UTR / cheque / reference',
        ),
        const SizedBox(height: 8),
        _dateFilters(
          events.map((e) => e.createdAt),
          leading: [
            _filterDropdown(
              label: 'Direction',
              value: paymentDirectionFilter,
              options: const ['All', 'Received', 'Paid'],
              onChanged: (value) => setState(() => paymentDirectionFilter = value),
              width: 140,
            ),
            _filterDropdown(
              label: 'Party',
              value: paymentPartyFilter,
              options: const ['All', 'Customer', 'Walk-in', 'Supplier'],
              onChanged: (value) => setState(() => paymentPartyFilter = value),
              width: 140,
            ),
            _filterDropdown(
              label: 'Payment mode',
              value: paymentModeFilter,
              options: _paymentModeOptions(data),
              onChanged: (value) => setState(() => paymentModeFilter = value),
              width: 155,
            ),
            _filterDropdown(
              label: 'Sort',
              value: paymentSort,
              options: const ['Newest', 'Oldest', 'Highest amount', 'Lowest amount'],
              onChanged: (value) => setState(() => paymentSort = value),
              width: 155,
            ),
          ],
          onResetExtra: () {
            paymentDirectionFilter = 'All';
            paymentPartyFilter = 'All';
            paymentModeFilter = 'All';
            paymentSort = 'Newest';
          },
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const EmptyState(
            'No matching payment records.',
            icon: Icons.payments_outlined,
          ),
        ...filtered.map(
          (event) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: event.direction == 'Received'
                    ? const Color(0xFF10251E)
                    : const Color(0xFF28191A),
                child: Icon(
                  event.direction == 'Received'
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  color: event.direction == 'Received'
                      ? AppTheme.green
                      : AppTheme.amber,
                ),
              ),
              title: Text(
                '${event.party} • ${event.direction}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${event.partyType} • ${event.detail}\n'
                '${_dateTime(event.createdAt)} • '
                '${event.mode.isEmpty ? 'Mode not recorded' : event.mode}'
                '${event.reference.isEmpty ? '' : ' • Ref ${event.reference}'}'
                '${event.document.isEmpty ? '' : '\nDocument ${event.document}'}',
              ),
              isThreeLine: true,
              trailing: Text(
                money(event.amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: event.direction == 'Received'
                      ? AppTheme.green
                      : AppTheme.amber,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _purchaseRecords(AppData data) {
    final q = query.trim().toLowerCase();
    final rows = data.purchases.where((purchase) {
      final textMatch = q.isEmpty ||
          purchase.number.toLowerCase().contains(q) ||
          purchase.invoiceNumber.toLowerCase().contains(q) ||
          purchase.purchaseOrderNumber.toLowerCase().contains(q) ||
          purchase.supplierName.toLowerCase().contains(q) ||
          purchase.sourceName.toLowerCase().contains(q) ||
          purchase.paymentMode.toLowerCase().contains(q) ||
          purchase.referenceNumber.toLowerCase().contains(q);
      if (!textMatch) return false;

      final date = purchaseDateBasis == 'Invoice date'
          ? purchase.invoiceDate
          : purchase.createdAt;
      if (!_matchesDate(date)) return false;

      final source = _purchaseSourceLabel(purchase.sourceType);
      if (purchaseSourceFilter != 'All' && purchaseSourceFilter != source) {
        return false;
      }
      final settlement = _purchaseSettlementStatus(purchase);
      if (purchaseSettlementFilter != 'All' &&
          purchaseSettlementFilter != settlement) {
        return false;
      }
      if (purchasePaymentModeFilter != 'All' &&
          purchase.paymentMode != purchasePaymentModeFilter) {
        return false;
      }
      return true;
    }).toList();

    rows.sort((a, b) => switch (purchaseSort) {
          'Oldest' => a.createdAt.compareTo(b.createdAt),
          'Highest amount' => b.total.compareTo(a.total),
          'Lowest amount' => a.total.compareTo(b.total),
          _ => b.createdAt.compareTo(a.createdAt),
        });

    final supplierTotal = data.purchases
        .where((p) => p.sourceType == 'SUPPLIER')
        .fold<double>(0, (sum, p) => sum + p.total);
    final localTotal = data.purchases
        .where((p) => p.sourceType == 'LOCAL')
        .fold<double>(0, (sum, p) => sum + p.total);
    final productionTotal = data.purchases
        .where((p) => p.sourceType == 'PRODUCTION')
        .fold<double>(0, (sum, p) => sum + p.total);

    final dates = purchaseDateBasis == 'Invoice date'
        ? data.purchases.map((p) => p.invoiceDate)
        : data.purchases.map((p) => p.createdAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _filterRecordTile(
              'Supplier purchases',
              money(supplierTotal),
              Icons.local_shipping_outlined,
              AppTheme.cyan,
              selected: purchaseSourceFilter == 'Supplier',
              onTap: () => setState(() {
                purchaseSourceFilter =
                    purchaseSourceFilter == 'Supplier' ? 'All' : 'Supplier';
              }),
            ),
            _filterRecordTile(
              'Local / cash purchases',
              money(localTotal),
              Icons.storefront_outlined,
              AppTheme.amber,
              selected: purchaseSourceFilter == 'Local / Cash',
              onTap: () => setState(() {
                purchaseSourceFilter = purchaseSourceFilter == 'Local / Cash'
                    ? 'All'
                    : 'Local / Cash';
              }),
            ),
            _filterRecordTile(
              'Own production',
              money(productionTotal),
              Icons.factory_outlined,
              AppTheme.purple,
              selected: purchaseSourceFilter == 'Own Production',
              onTap: () => setState(() {
                purchaseSourceFilter = purchaseSourceFilter == 'Own Production'
                    ? 'All'
                    : 'Own Production';
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            ChoiceChip(
              label: const Text('All purchases'),
              selected: purchaseSourceFilter == 'All',
              onSelected: (_) => setState(() => purchaseSourceFilter = 'All'),
            ),
            ChoiceChip(
              label: const Text('Supplier'),
              selected: purchaseSourceFilter == 'Supplier',
              onSelected: (_) => setState(() => purchaseSourceFilter = 'Supplier'),
            ),
            ChoiceChip(
              label: const Text('Local / Cash'),
              selected: purchaseSourceFilter == 'Local / Cash',
              onSelected: (_) => setState(() => purchaseSourceFilter = 'Local / Cash'),
            ),
            ChoiceChip(
              label: const Text('Own Production'),
              selected: purchaseSourceFilter == 'Own Production',
              onSelected: (_) => setState(() => purchaseSourceFilter = 'Own Production'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _search(
          hint:
              'Search purchase no. / supplier invoice / PO / source / payment reference',
        ),
        const SizedBox(height: 8),
        _dateFilters(
          dates,
          leading: [
            _filterDropdown(
              label: 'Source',
              value: purchaseSourceFilter,
              options: const ['All', 'Supplier', 'Local / Cash', 'Own Production'],
              onChanged: (value) => setState(() => purchaseSourceFilter = value),
              width: 155,
            ),
            _filterDropdown(
              label: 'Settlement',
              value: purchaseSettlementFilter,
              options: const ['All', 'Paid', 'Partial', 'Unpaid', 'N/A'],
              onChanged: (value) => setState(() => purchaseSettlementFilter = value),
              width: 135,
            ),
            _filterDropdown(
              label: 'Payment mode',
              value: purchasePaymentModeFilter,
              options: _paymentModeOptions(data),
              onChanged: (value) => setState(() => purchasePaymentModeFilter = value),
              width: 155,
            ),
            _filterDropdown(
              label: 'Date field',
              value: purchaseDateBasis,
              options: const ['Recorded date', 'Invoice date'],
              onChanged: (value) => setState(() => purchaseDateBasis = value),
              width: 150,
            ),
            _filterDropdown(
              label: 'Sort',
              value: purchaseSort,
              options: const ['Newest', 'Oldest', 'Highest amount', 'Lowest amount'],
              onChanged: (value) => setState(() => purchaseSort = value),
              width: 155,
            ),
          ],
          onResetExtra: () {
            purchaseSourceFilter = 'All';
            purchaseSettlementFilter = 'All';
            purchasePaymentModeFilter = 'All';
            purchaseDateBasis = 'Recorded date';
            purchaseSort = 'Newest';
          },
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const EmptyState(
            'No matching purchase records.',
            icon: Icons.shopping_bag_outlined,
          ),
        ...rows.map((purchase) {
          final sourceLabel = switch (purchase.sourceType) {
            'LOCAL' => 'Local / Cash Purchase',
            'PRODUCTION' => 'Own Production',
            _ => 'Supplier Purchase',
          };
          final sourceName = purchase.sourceType == 'SUPPLIER'
              ? purchase.supplierName
              : (purchase.sourceName.isEmpty ? sourceLabel : purchase.sourceName);
          final sourceColor = switch (purchase.sourceType) {
            'LOCAL' => AppTheme.amber,
            'PRODUCTION' => AppTheme.purple,
            _ => AppTheme.cyan,
          };
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final info = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusPill(text: sourceLabel, color: sourceColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${purchase.number} • $sourceName',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          StatusPill(
                            text: _purchaseSettlementStatus(purchase),
                            color: purchase.sourceType == 'PRODUCTION'
                                ? AppTheme.purple
                                : purchase.balanceDue <= 0.005
                                    ? AppTheme.green
                                    : purchase.settledAmount <= 0.005
                                        ? AppTheme.red
                                        : AppTheme.amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_dateTime(purchase.createdAt)} • ${purchase.lines.length} item(s) • ${purchase.paymentMode}',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      if (purchase.sourceType == 'SUPPLIER')
                        Text(
                          'Supplier invoice ${purchase.invoiceNumber.isEmpty ? 'Not recorded' : purchase.invoiceNumber} • PO ${purchase.purchaseOrderNumber.isEmpty ? 'Not recorded' : purchase.purchaseOrderNumber}',
                        ),
                      Text(
                        purchase.sourceType == 'PRODUCTION'
                            ? 'Recorded production cost ${money(purchase.total)} • Stock-in completed'
                            : 'Total ${money(purchase.total)} • Settled ${money(purchase.settledAmount)} • Payable ${money(purchase.balanceDue)}',
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showPurchaseDetails(data, purchase),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('View'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _savePurchasePdf(data, purchase),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Save PDF'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _sharePurchase(data, purchase),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ],
                  );
                  if (constraints.maxWidth < 860) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [info, const SizedBox(height: 10), actions],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: info),
                      const SizedBox(width: 10),
                      actions,
                    ],
                  );
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _inventoryRecords(AppData data) {
    final q = query.trim().toLowerCase();
    final products = data.products.where((product) {
      if (q.isEmpty) return true;
      return product.name.toLowerCase().contains(q) ||
          product.barcode.toLowerCase().contains(q) ||
          product.productCode.toLowerCase().contains(q) ||
          product.category.toLowerCase().contains(q) ||
          product.rackLocation.toLowerCase().contains(q);
    }).toList();
    final lowStock = data.products.where(
      (p) => p.stock <= p.reorderLevel,
    ).length;
    final stockCost = data.products.fold<double>(
      0,
      (sum, p) => sum + p.stock * p.purchasePrice,
    );
    final stockSellingValue = data.products.fold<double>(
      0,
      (sum, p) => sum + p.stock * p.sellingPrice,
    );
    final now = DateTime.now();
    final expiringSoon = data.products.where((p) {
      final expiry = p.expiryDate;
      if (expiry == null || expiry.isBefore(now)) return false;
      return expiry.difference(now).inDays <= 30;
    }).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _recordTile(
              'Current stock cost value',
              money(stockCost),
              Icons.inventory_2_outlined,
              AppTheme.cyan,
            ),
            _recordTile(
              'Current selling value',
              money(stockSellingValue),
              Icons.sell_outlined,
              AppTheme.green,
            ),
            _recordTile(
              'Low / reorder stock',
              '$lowStock',
              Icons.warning_amber_rounded,
              AppTheme.amber,
            ),
            _recordTile(
              'Expiring within 30 days',
              '$expiringSoon',
              Icons.event_busy_outlined,
              AppTheme.red,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _search(
          hint: 'Search product / barcode / SKU / category / rack',
        ),
        const SizedBox(height: 8),
        const Text(
          'Inventory Records shows the current stock snapshot plus recorded purchase and sales activity. A dedicated stock-adjustment / wastage audit trail will be shown here when those transaction types are added.',
          style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          const EmptyState(
            'No matching inventory records.',
            icon: Icons.inventory_2_outlined,
          ),
        ...products.map((product) {
          var received = 0.0;
          var sold = 0.0;
          for (final purchase in data.purchases) {
            for (final line in purchase.lines) {
              if (line.productId == product.id) received += line.stockReceived;
            }
          }
          for (final sale in data.sales) {
            for (final line in sale.lines) {
              if (line.productId == product.id) sold += line.qty;
            }
          }
          final low = product.stock <= product.reorderLevel;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusPill(
                        text: low ? 'Reorder' : 'In stock',
                        color: low ? AppTheme.amber : AppTheme.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.productCode.isEmpty ? 'No SKU' : product.productCode} • ${product.barcode.isEmpty ? 'No barcode' : product.barcode} • ${product.category}',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      _plainMetric('Current stock', product.stockLabel,
                          low ? AppTheme.amber : AppTheme.green),
                      _plainMetric('Recorded stock received',
                          '${received.toStringAsFixed(2)} ${product.unit}', AppTheme.cyan),
                      _plainMetric('Recorded sold',
                          '${sold.toStringAsFixed(2)} ${product.unit}', AppTheme.red),
                      _plainMetric('Cost value',
                          money(product.stock * product.purchasePrice), AppTheme.muted),
                      _plainMetric('Selling value',
                          money(product.stock * product.sellingPrice), AppTheme.green),
                      _plainMetric('Rack / location',
                          product.rackLocation.isEmpty ? 'Not set' : product.rackLocation, AppTheme.muted),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _cashCloseRecords(AppData data) {
    final q = query.trim().toLowerCase();
    final rows = data.cashClosings.where((record) {
      if (q.isEmpty) return true;
      return record.cashier.toLowerCase().contains(q) ||
          record.branch.toLowerCase().contains(q) ||
          record.register.toLowerCase().contains(q) ||
          record.status.toLowerCase().contains(q) ||
          record.discrepancyReason.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shortage = data.cashClosings
        .where((c) => c.variance < 0)
        .fold<double>(0, (sum, c) => sum + c.variance.abs());
    final excess = data.cashClosings
        .where((c) => c.variance > 0)
        .fold<double>(0, (sum, c) => sum + c.variance);

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _recordTile(
              'Cash closes',
              '${data.cashClosings.length}',
              Icons.account_balance_wallet_outlined,
              AppTheme.cyan,
            ),
            _recordTile(
              'Recorded shortage',
              money(shortage),
              Icons.trending_down_rounded,
              AppTheme.red,
            ),
            _recordTile(
              'Recorded excess',
              money(excess),
              Icons.trending_up_rounded,
              AppTheme.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _search(
          hint: 'Search cashier / branch / register / status / reason',
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const EmptyState(
            'No matching cash-close records.',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ...rows.map((record) {
          final varianceColor = record.variance < 0
              ? AppTheme.red
              : record.variance > 0
                  ? AppTheme.green
                  : AppTheme.cyan;
          final varianceLabel = record.variance < 0
              ? 'Shortage'
              : record.variance > 0
                  ? 'Excess'
                  : 'Matched';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${record.branch} • ${record.register}',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusPill(text: varianceLabel, color: varianceColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_dateTime(record.createdAt)} • Cashier ${record.cashier} • ${record.status}',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      _plainMetric('Expected cash', money(record.expectedCash), AppTheme.muted),
                      _plainMetric('Actual cash', money(record.actualCash), AppTheme.cyan),
                      _plainMetric('Variance', money(record.variance), varianceColor),
                      _plainMetric(
                        'Manager approval',
                        record.managerApproved ? 'Approved' : 'Pending / not required',
                        record.managerApproved ? AppTheme.green : AppTheme.muted,
                      ),
                    ],
                  ),
                  if (record.discrepancyReason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${record.discrepancyReason}',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _saleDocumentCard(AppData data, Sale sale) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sale.documentNumber.isEmpty ? sale.id : sale.documentNumber} • ${sale.customerName}',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_saleDisplayType(sale)} • ${_dateTime(sale.createdAt)} • ${sale.status}',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  'Payment: ${sale.paymentMethod}'
                  '${sale.paymentReference.isEmpty ? '' : ' • Ref ${sale.paymentReference}'}',
                ),
                Text(
                  'Total ${money(sale.total)} • Total settled ${money(sale.settledAmount)} • Amount customer owes us ${money(sale.balanceDue)}',
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSaleDetails(data, sale),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveSalePdf(data, sale),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save PDF'),
                ),
                FilledButton.icon(
                  onPressed: () => _shareSale(data, sale),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share / send again'),
                ),
              ],
            );
            if (constraints.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: 10),
                  actions,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 10),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _quotationDocumentCard(AppData data, Quotation quote) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${quote.number} • ${quote.customerName}',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quotation • ${_dateTime(quote.createdAt)} • ${quote.status}',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                Text('Total ${money(quote.total)}'),
              ],
            );
            final actions = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showQuotationDetails(data, quote),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _saveQuotationPdf(data, quote),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save PDF'),
                ),
                if (quote.linkedSaleId.isEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _convertQuotation(data, quote),
                    icon: const Icon(Icons.transform_rounded),
                    label: const Text('Convert to sale'),
                  )
                else
                  const StatusPill(text: 'Converted', color: AppTheme.green, icon: Icons.check_circle_outline_rounded),
                FilledButton.icon(
                  onPressed: () => _shareQuote(data, quote),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share / send again'),
                ),
              ],
            );
            if (constraints.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [info, const SizedBox(height: 10), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 10),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _convertQuotation(AppData data, Quotation quote) async {
    if (quote.linkedSaleId.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This quotation is already linked to a finalized sale.')),
      );
      return;
    }

    final app = AppScope.of(context);
    final business = data.business;
    final customer = data.customers.where((c) => c.id == quote.customerId).firstOrNull;
    final lines = quote.lines
        .map(
          (line) => SaleLine(
            productId: line.productId,
            name: line.name,
            qty: line.qty,
            unitPrice: line.unitPrice,
            unitCost: line.unitCost,
            gstRate: line.gstRate,
            unit: line.unit,
            discountPercent: line.discountPercent,
            discountAmount: line.discountAmount,
            hsnSac: line.hsnSac,
            gstApplicable: business.isRegularGst &&
                line.taxCategory == 'Taxable' &&
                line.gstRate > 0,
            taxCategory: line.taxCategory,
            taxInclusive: line.taxInclusive,
            imageUrl: line.imageUrl,
            note: line.note,
          ),
        )
        .toList();
    final documentType = DocumentRules.resolveSaleDocument(business, lines);
    final total = lines.fold<double>(0, (sum, line) => sum + line.net);

    String paymentMode = 'Cash';
    final paid = TextEditingController(text: total.toStringAsFixed(2));
    final reference = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Convert ${quote.number} to $documentType'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer: ${quote.customerName}'),
                Text('Final sale total: ${money(total)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: paymentMode,
                  items: const ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Credit / unpaid']
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) => update(() {
                    paymentMode = value ?? 'Cash';
                    if (paymentMode == 'Credit / unpaid') paid.text = '0';
                  }),
                  decoration: const InputDecoration(labelText: 'Payment mode'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: paid,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount received now'),
                ),
                const SizedBox(height: 8),
                TextField(controller: reference, decoration: const InputDecoration(labelText: 'Payment reference (optional)')),
                const SizedBox(height: 8),
                const Text(
                  'The quotation remains in Records and will be permanently linked to the new sale. Stock reduces only after this conversion is confirmed.',
                  style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create sale')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final amountPaid = (double.tryParse(paid.text.trim()) ?? 0).clamp(0.0, total).toDouble();
    if (customer == null && amountPaid + 0.005 < total) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create/select a customer ID before converting a quotation to an unpaid/credit sale.')),
      );
      return;
    }
    final status = amountPaid >= total - 0.005
        ? 'Paid'
        : amountPaid <= 0.005
            ? 'Unpaid'
            : 'Partial';
    final sale = await app.completeSale(
      lines: lines,
      payment: paymentMode,
      customer: quote.customerName,
      customerId: quote.customerId,
      customerGstin: customer?.gstin ?? quote.customerGstin,
      documentType: documentType,
      placeOfSupplyStateCode: customer?.stateCode.isNotEmpty == true
          ? customer!.stateCode
          : (quote.customerStateCode.isEmpty ? business.stateCode : quote.customerStateCode),
      discount: 0,
      amountPaid: amountPaid,
      status: status,
      paymentBreakdown: amountPaid > 0 ? {paymentMode: amountPaid} : const {},
      paymentReference: reference.text.trim(),
    );
    quote.status = 'Converted';
    quote.linkedSaleId = sale.id;
    await app.persist();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${quote.number} converted to ${sale.documentNumber}.')),
    );
  }

  void _showCustomerRecord(AppData data, Customer customer) {
    final sales = data.sales
        .where((sale) => sale.customerId == customer.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final quotations = data.quotations
        .where((quote) => quote.customerId == customer.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final ledger = data.ledger
        .where((entry) => entry.customerId == customer.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showDialog<void>(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 6,
        child: AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: AppTheme.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${customer.name} • ${customer.id}'),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * .78,
            height: MediaQuery.of(ctx).size.height * .72,
            child: Column(
              children: [
                const SizedBox(
                  height: 44,
                  child: TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Edit Details'),
                      Tab(text: 'Transactions'),
                      Tab(text: 'Payments'),
                      Tab(text: 'Documents'),
                      Tab(text: 'Ledger'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _customerOverview(customer, sales.length + quotations.length, ledger.length),
                      _customerEditDetails(customer, ctx),
                      _customerTransactions(sales, ledger),
                      _customerPayments(customer, sales, ledger),
                      _customerDocuments(data, sales, quotations),
                      _customerLedgerList(ledger),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _customerOverview(
    Customer customer,
    int documentCount,
    int ledgerCount,
  ) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _recordTile(
              'Customer owes us',
              money(customer.creditBalance),
              Icons.request_quote_outlined,
              customer.creditBalance > 0 ? AppTheme.amber : AppTheme.green,
            ),
            _recordTile(
              'Customer advance available',
              money(customer.advanceBalance),
              Icons.account_balance_wallet_outlined,
              AppTheme.cyan,
            ),
            _recordTile(
              'Sales documents',
              '$documentCount',
              Icons.receipt_long_outlined,
              AppTheme.red,
            ),
            _recordTile(
              'Ledger entries',
              '$ledgerCount',
              Icons.menu_book_outlined,
              AppTheme.purple,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelValue('Mobile', customer.phone),
                _labelValue('GSTIN', customer.gstin),
                _labelValue('Business name', customer.businessName),
                _labelValue('Address', customer.address),
                _labelValue('State', '${customer.state} • ${customer.stateCode}'),
                _labelValue(
                  'Default discount',
                  '${customer.discountPercent.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _customerEditDetails(Customer customer, BuildContext dialogContext) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded, color: AppTheme.cyan),
            title: Text('Master details are edited here; transaction balances remain ledger-controlled.'),
            subtitle: Text('Editing a customer later never rewrites finalized historical documents.'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelValue('Customer ID', customer.id),
                _labelValue('Name', customer.name),
                _labelValue('Mobile', customer.phone),
                _labelValue('GSTIN', customer.gstin),
                _labelValue('Address', customer.address),
                _labelValue('State', '${customer.state} • ${customer.stateCode}'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _customerMasterDialog(customer);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit customer master details'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _customerTransactions(
    List<Sale> sales,
    List<CustomerLedgerEntry> ledger,
  ) {
    final rows = <_TimelineRow>[
      ...sales.map(
        (sale) => _TimelineRow(
          date: sale.createdAt,
          title:
              '${sale.documentType} ${sale.documentNumber} • ${money(sale.total)}',
          subtitle:
              'Payment ${sale.paymentMethod} • Paid ${money(sale.amountPaid)} • Customer owes ${money(sale.balanceDue)}',
          icon: Icons.receipt_long_outlined,
          color: AppTheme.red,
        ),
      ),
      ...ledger.map(
        (entry) => _TimelineRow(
          date: entry.createdAt,
          title: '${_customerLedgerLabel(entry.type)} • ${money(entry.amount)}',
          subtitle:
              '${entry.paymentMode.isEmpty ? 'Accounting entry' : entry.paymentMode}'
              '${entry.reference.isEmpty ? '' : ' • Ref ${entry.reference}'}',
          icon: Icons.account_balance_wallet_outlined,
          color: _ledgerColor(entry.type),
        ),
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (rows.isEmpty) {
      return const EmptyState(
        'No customer transactions yet.',
        icon: Icons.history_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: rows
          .map(
            (row) => Card(
              child: ListTile(
                leading: Icon(row.icon, color: row.color),
                title: Text(
                  row.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('${_dateTime(row.date)}\n${row.subtitle}'),
                isThreeLine: true,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _customerPayments(
    Customer customer,
    List<Sale> sales,
    List<CustomerLedgerEntry> ledger,
  ) {
    final rows = <_PaymentEvent>[
      ...sales.where((sale) => sale.amountPaid > 0).map(
            (sale) => _PaymentEvent(
              createdAt: sale.createdAt,
              direction: 'Received',
              party: customer.name,
              partyType: 'Customer',
              amount: sale.amountPaid,
              mode: sale.paymentMethod,
              reference: sale.paymentReference,
              document: sale.documentNumber,
              detail: 'Billing payment',
            ),
          ),
      ...ledger
          .where((entry) => entry.type == 'PAYMENT' || entry.type == 'ADVANCE')
          .map(
            (entry) => _PaymentEvent(
              createdAt: entry.createdAt,
              direction: 'Received',
              party: customer.name,
              partyType: 'Customer',
              amount: entry.amount,
              mode: entry.paymentMode,
              reference: entry.reference,
              document: entry.documentReference,
              detail: entry.type == 'ADVANCE'
                  ? 'Customer advance received'
                  : 'Customer due collected',
            ),
          ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (rows.isEmpty) {
      return const EmptyState(
        'No customer payment records yet.',
        icon: Icons.payments_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: rows
          .map(
            (event) => Card(
              child: ListTile(
                leading:
                    const Icon(Icons.south_west_rounded, color: AppTheme.green),
                title: Text(
                  '${event.detail} • ${money(event.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${_dateTime(event.createdAt)} • '
                  '${event.mode.isEmpty ? 'Mode not recorded' : event.mode}'
                  '${event.reference.isEmpty ? '' : '\nTransaction / reference: ${event.reference}'}'
                  '${event.document.isEmpty ? '' : '\nDocument: ${event.document}'}',
                ),
                isThreeLine: event.reference.isNotEmpty,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _customerDocuments(
    AppData data,
    List<Sale> sales,
    List<Quotation> quotations,
  ) {
    if (sales.isEmpty && quotations.isEmpty) {
      return const EmptyState(
        'No customer documents yet.',
        icon: Icons.description_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        ...sales.map((sale) => _saleDocumentCard(data, sale)),
        ...quotations.map((quote) => _quotationDocumentCard(data, quote)),
      ],
    );
  }

  Widget _customerLedgerList(List<CustomerLedgerEntry> ledger) {
    if (ledger.isEmpty) {
      return const EmptyState(
        'No ledger entries yet.',
        icon: Icons.menu_book_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: ledger
          .map(
            (entry) => Card(
              child: ListTile(
                leading: Icon(
                  Icons.menu_book_outlined,
                  color: _ledgerColor(entry.type),
                ),
                title: Text(
                  '${_customerLedgerLabel(entry.type)} • ${money(entry.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${_dateTime(entry.createdAt)}'
                  '${entry.paymentMode.isEmpty ? '' : ' • ${entry.paymentMode}'}'
                  '${entry.reference.isEmpty ? '' : '\nTransaction / reference: ${entry.reference}'}'
                  '${entry.documentReference.isEmpty ? '' : '\nDocument: ${entry.documentReference}'}'
                  '${entry.note.isEmpty ? '' : '\n${entry.note}'}',
                ),
                isThreeLine:
                    entry.reference.isNotEmpty || entry.note.isNotEmpty,
              ),
            ),
          )
          .toList(),
    );
  }

  void _showSupplierRecord(AppData data, Supplier supplier) {
    final purchases = data.purchases
        .where((purchase) => purchase.supplierId == supplier.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final returns = data.purchaseReturns
        .where((record) => record.supplierId == supplier.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final ledger = data.supplierLedger
        .where((entry) => entry.supplierId == supplier.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showDialog<void>(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 6,
        child: AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: AppTheme.cyan,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('${supplier.code} • ${supplier.name}')),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(ctx).size.width * .78,
            height: MediaQuery.of(ctx).size.height * .72,
            child: Column(
              children: [
                const SizedBox(
                  height: 44,
                  child: TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Overview'),
                      Tab(text: 'Edit Details'),
                      Tab(text: 'Transactions'),
                      Tab(text: 'Payments'),
                      Tab(text: 'Documents'),
                      Tab(text: 'Ledger'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    children: [
                      _supplierOverview(
                        supplier,
                        purchases.length,
                        ledger.length,
                      ),
                      _supplierEditDetails(supplier, ctx),
                      _supplierTransactions(purchases, returns),
                      _supplierPayments(ledger),
                      _supplierDocuments(data, purchases),
                      _supplierLedgerList(ledger),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _supplierOverview(
    Supplier supplier,
    int purchaseCount,
    int ledgerCount,
  ) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _recordTile(
              'Amount payable to supplier',
              money(supplier.openingPayable),
              Icons.payments_outlined,
              supplier.openingPayable > 0
                  ? AppTheme.amber
                  : AppTheme.green,
            ),
            _recordTile(
              'Advance already paid',
              money(supplier.supplierCreditBalance),
              Icons.account_balance_wallet_outlined,
              AppTheme.cyan,
            ),
            _recordTile(
              'Purchases',
              '$purchaseCount',
              Icons.shopping_cart_outlined,
              AppTheme.red,
            ),
            _recordTile(
              'Ledger entries',
              '$ledgerCount',
              Icons.menu_book_outlined,
              AppTheme.purple,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelValue('Contact person', supplier.contactPerson),
                _labelValue('Mobile', supplier.mobile),
                _labelValue('GSTIN', supplier.gstin),
                _labelValue('Address', supplier.address),
                _labelValue(
                  'Location',
                  [supplier.city, supplier.state]
                      .where((value) => value.isNotEmpty)
                      .join(', '),
                ),
                _labelValue(
                  'Default terms',
                  '${supplier.paymentTerms} • ${supplier.creditDays} credit days',
                ),
                _labelValue('Bank / UPI', supplier.bankUpi),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _supplierEditDetails(Supplier supplier, BuildContext dialogContext) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded, color: AppTheme.cyan),
            title: Text('Supplier master details and account terms are managed here.'),
            subtitle: Text('Finalized purchase documents remain historical snapshots.'),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelValue('Supplier code', supplier.code),
                _labelValue('Name', supplier.name),
                _labelValue('Mobile', supplier.mobile),
                _labelValue('GSTIN', supplier.gstin),
                _labelValue('Address', supplier.address),
                _labelValue('Payment terms', supplier.paymentTerms),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _supplierMasterDialog(supplier);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit supplier master details'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _supplierTransactions(
    List<PurchaseRecord> purchases,
    List<PurchaseReturnRecord> returns,
  ) {
    final rows = <_TimelineRow>[
      ...purchases.map(
        (purchase) => _TimelineRow(
          date: purchase.createdAt,
          title:
              'Purchase ${purchase.number} • ${money(purchase.total)}',
          subtitle:
              'Supplier invoice ${purchase.invoiceNumber} • PO ${purchase.purchaseOrderNumber} • Amount still payable ${money(purchase.balanceDue)}',
          icon: Icons.shopping_cart_outlined,
          color: AppTheme.red,
        ),
      ),
      ...returns.map(
        (record) => _TimelineRow(
          date: record.createdAt,
          title:
              'Purchase return ${record.number} • ${money(record.total)}',
          subtitle: record.reason.isEmpty ? 'Purchase return' : record.reason,
          icon: Icons.assignment_return_outlined,
          color: AppTheme.amber,
        ),
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (rows.isEmpty) {
      return const EmptyState(
        'No supplier transactions yet.',
        icon: Icons.history_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: rows
          .map(
            (row) => Card(
              child: ListTile(
                leading: Icon(row.icon, color: row.color),
                title: Text(
                  row.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('${_dateTime(row.date)}\n${row.subtitle}'),
                isThreeLine: true,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _supplierPayments(List<SupplierLedgerEntry> ledger) {
    final rows = ledger
        .where((entry) => entry.type == 'PAYMENT' || entry.type == 'ADVANCE')
        .toList();

    if (rows.isEmpty) {
      return const EmptyState(
        'No supplier payment records yet.',
        icon: Icons.payments_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: rows
          .map(
            (entry) => Card(
              child: ListTile(
                leading:
                    const Icon(Icons.north_east_rounded, color: AppTheme.amber),
                title: Text(
                  '${entry.type == 'ADVANCE' ? 'Supplier advance paid' : 'Supplier payment'} • ${money(entry.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${_dateTime(entry.createdAt)} • '
                  '${entry.paymentMode.isEmpty ? 'Mode not recorded' : entry.paymentMode}'
                  '${entry.reference.isEmpty ? '' : '\nTransaction / reference: ${entry.reference}'}',
                ),
                isThreeLine: entry.reference.isNotEmpty,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _supplierDocuments(
    AppData data,
    List<PurchaseRecord> purchases,
  ) {
    if (purchases.isEmpty) {
      return const EmptyState(
        'No supplier purchase documents yet.',
        icon: Icons.description_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: purchases
          .map((purchase) => _purchaseDocumentCard(data, purchase))
          .toList(),
    );
  }

  Widget _supplierLedgerList(List<SupplierLedgerEntry> ledger) {
    if (ledger.isEmpty) {
      return const EmptyState(
        'No supplier ledger entries yet.',
        icon: Icons.menu_book_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: ledger
          .map(
            (entry) => Card(
              child: ListTile(
                leading: Icon(
                  Icons.menu_book_outlined,
                  color: _supplierLedgerColor(entry.type),
                ),
                title: Text(
                  '${_supplierLedgerLabel(entry.type)} • ${money(entry.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${_dateTime(entry.createdAt)}'
                  '${entry.paymentMode.isEmpty ? '' : ' • ${entry.paymentMode}'}'
                  '${entry.reference.isEmpty ? '' : '\nTransaction / reference: ${entry.reference}'}'
                  '${entry.documentReference.isEmpty ? '' : '\nDocument: ${entry.documentReference}'}'
                  '${entry.note.isEmpty ? '' : '\n${entry.note}'}',
                ),
                isThreeLine:
                    entry.reference.isNotEmpty || entry.note.isNotEmpty,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _purchaseDocumentCard(AppData data, PurchaseRecord purchase) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sourceLabel = purchase.sourceType == 'SUPPLIER'
                ? 'Purchase Invoice'
                : purchase.sourceType == 'LOCAL'
                    ? 'Local Purchase'
                    : 'Own Production';
            final partyLabel = purchase.sourceType == 'SUPPLIER'
                ? purchase.supplierName
                : (purchase.sourceName.isEmpty ? sourceLabel : purchase.sourceName);
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${purchase.number} • $partyLabel',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  purchase.sourceType == 'SUPPLIER'
                      ? '$sourceLabel • Supplier invoice ${purchase.invoiceNumber} • PO ${purchase.purchaseOrderNumber}'
                      : '$sourceLabel • ${_dateTime(purchase.createdAt)}',
                  style: const TextStyle(color: AppTheme.muted),
                ),
                Text(
                  purchase.sourceType == 'PRODUCTION'
                      ? 'Recorded production cost ${money(purchase.total)} • No supplier payable'
                      : 'Total ${money(purchase.total)} • Paid ${money(purchase.settledAmount)} • Amount still payable ${money(purchase.balanceDue)}',
                ),
              ],
            );
            final actions = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showPurchaseDetails(data, purchase),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _savePurchasePdf(data, purchase),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save PDF'),
                ),
                FilledButton.icon(
                  onPressed: () => _sharePurchase(data, purchase),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share'),
                ),
              ],
            );
            if (constraints.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [info, const SizedBox(height: 10), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 10),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _previewTitle(String text, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        if (subtitle != null && subtitle.isNotEmpty)
          Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 11.5)),
      ],
    );
  }

  Widget _previewSection(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _previewTable({
    required List<String> headers,
    required List<List<String>> rows,
    double minWidth = 860,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: minWidth,
        child: Table(
          border: TableBorder.all(color: AppTheme.border),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFF161C24)),
              children: headers
                  .map(
                    (header) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                      child: Text(
                        header,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  )
                  .toList(),
            ),
            ...rows.map(
              (row) => TableRow(
                children: row
                    .map(
                      (value) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Text(value, style: const TextStyle(fontSize: 11.5)),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewAmountRow(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: bold ? null : AppTheme.muted))),
          Text(
            money(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              fontSize: bold ? 15 : 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showSaleDetails(AppData data, Sale sale) {
    final business = data.business;
    final documentType = DocumentRules.normalizeDocumentType(sale.documentType);
    final displayDocumentType = _saleDisplayType(sale);
    final isTaxInvoice = documentType == DocumentRules.taxInvoice;
    final isBillOfSupply = documentType == DocumentRules.billOfSupply;
    final businessName = sale.businessNameSnapshot.isNotEmpty
        ? sale.businessNameSnapshot
        : business.businessName;
    final businessAddress = sale.businessAddressSnapshot.isNotEmpty
        ? sale.businessAddressSnapshot
        : business.address;
    final businessGstin = sale.businessGstinSnapshot.isNotEmpty
        ? sale.businessGstinSnapshot
        : business.gstin;
    final businessState = sale.businessStateSnapshot.isNotEmpty
        ? sale.businessStateSnapshot
        : business.state;
    final businessStateCode = sale.businessStateCodeSnapshot.isNotEmpty
        ? sale.businessStateCodeSnapshot
        : business.stateCode;
    final gstProfile = sale.gstRegistrationTypeSnapshot.isNotEmpty
        ? sale.gstRegistrationTypeSnapshot
        : business.gstRegistrationType;
    final interstate = sale.placeOfSupplyStateCode.isNotEmpty &&
        sale.placeOfSupplyStateCode != businessStateCode;
    final outputGst = isTaxInvoice ? sale.gst : 0.0;
    final cgst = interstate ? 0.0 : outputGst / 2;
    final sgst = interstate ? 0.0 : outputGst / 2;
    final igst = interstate ? outputGst : 0.0;

    final headers = isTaxInvoice
        ? const ['Item', 'HSN/SAC', 'Qty', 'Rate', 'Discount', 'Taxable', 'GST', 'Amount']
        : isBillOfSupply
            ? const ['Item', 'HSN/SAC', 'Qty', 'Rate', 'Discount', 'Tax class', 'Amount']
            : const ['Item', 'Qty', 'Rate', 'Discount', 'Amount'];
    final rows = sale.lines.map((line) {
      final qty = '${line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 2)} ${line.unit}';
      final discount = line.discountValue <= 0.005
          ? '-'
          : money(line.discountValue);
      if (isTaxInvoice) {
        return [
          line.name,
          line.hsnSac.isEmpty ? '-' : line.hsnSac,
          qty,
          money(line.unitPrice),
          discount,
          money(line.taxableValue),
          line.isOutputTaxable ? '${line.gstRate.toStringAsFixed(1)}%' : line.taxCategory,
          money(line.net),
        ];
      }
      if (isBillOfSupply) {
        return [
          line.name,
          line.hsnSac.isEmpty ? '-' : line.hsnSac,
          qty,
          money(line.unitPrice),
          discount,
          line.taxCategory,
          money(line.net),
        ];
      }
      return [line.name, qty, money(line.unitPrice), discount, money(line.net)];
    }).toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1040,
            maxHeight: MediaQuery.of(ctx).size.height * .90,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _previewTitle(
                        displayDocumentType.toUpperCase(),
                        subtitle: 'Saved original document format • Historical snapshot',
                      ),
                    ),
                    StatusPill(
                      text: _saleSettlementStatus(sale),
                      color: sale.balanceDue <= 0.005
                          ? AppTheme.green
                          : sale.settledAmount <= 0.005
                              ? AppTheme.red
                              : AppTheme.amber,
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final left = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(businessName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                            if (businessAddress.isNotEmpty) Text(businessAddress),
                            if (businessState.isNotEmpty) Text('$businessState • State code $businessStateCode'),
                            if (businessGstin.isNotEmpty) Text('GSTIN: $businessGstin'),
                            if (business.phone.isNotEmpty) Text('Phone: ${business.phone}'),
                          ],
                        );
                        final right = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _labelValue('Document no.', sale.documentNumber.isEmpty ? sale.id : sale.documentNumber),
                            _labelValue('Date / time', _dateTime(sale.createdAt)),
                            _labelValue('GST profile', gstProfile),
                            if (isTaxInvoice) _labelValue('Place of supply code', sale.placeOfSupplyStateCode),
                          ],
                        );
                        if (constraints.maxWidth < 760) {
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 12), right]);
                        }
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 22), Expanded(child: right)]);
                      },
                    ),
                    if (isBillOfSupply) ...[
                      const SizedBox(height: 10),
                      Card(
                        color: const Color(0xFF151A20),
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Text(
                            gstProfile == DocumentRules.composition
                                ? 'Composition Scheme: GST is not collected separately from the customer. Purchase GST, where not creditable, remains part of effective cost.'
                                : 'Bill of Supply: GST is not collected separately on this document.',
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _previewSection(
                      sale.gstBillRequested || sale.customerGstin.isNotEmpty
                          ? 'Bill to'
                          : 'Customer',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _labelValue(
                            sale.gstBillRequested || sale.customerGstin.isNotEmpty ? 'Name' : 'Customer',
                            sale.customerName,
                          ),
                          if (sale.customerId.isNotEmpty) _labelValue('Customer ID', sale.customerId),
                          if (sale.customerGstin.isNotEmpty) _labelValue('GSTIN', sale.customerGstin),
                          if ((sale.gstBillRequested || sale.customerGstin.isNotEmpty) &&
                              sale.customerAddressSnapshot.isNotEmpty)
                            _labelValue('Address', sale.customerAddressSnapshot),
                          if ((sale.gstBillRequested || sale.customerGstin.isNotEmpty) &&
                              sale.customerStateSnapshot.isNotEmpty)
                            _labelValue('State', '${sale.customerStateSnapshot} • ${sale.customerStateCodeSnapshot}'),
                          if (sale.requestedByName.isNotEmpty)
                            _labelValue('Purchased / Requested By', sale.requestedByName),
                          if (sale.requestedByContact.isNotEmpty)
                            _labelValue('Contact', sale.requestedByContact),
                        ],
                      ),
                    ),
                    _previewSection('Items', _previewTable(headers: headers, rows: rows, minWidth: isTaxInvoice ? 980 : 820)),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final payment = _previewSection(
                          'Payment',
                          Column(
                            children: [
                              _labelValue('Payment mode', sale.paymentMethod),
                              _labelValue('Transaction / reference', sale.paymentReference),
                              if (sale.paymentBreakdown.isNotEmpty)
                                _labelValue(
                                  'Split payment',
                                  sale.paymentBreakdown.entries.map((e) => '${e.key}: ${money(e.value)}').join(' • '),
                                ),
                              _labelValue('Status', _saleSettlementStatus(sale)),
                            ],
                          ),
                        );
                        final totals = _previewSection(
                          'Totals',
                          Column(
                            children: [
                              _previewAmountRow('Items total', sale.subtotal),
                              if (sale.discount > 0) _previewAmountRow('Bill discount', -sale.discount),
                              if (isTaxInvoice) ...[
                                _previewAmountRow('Taxable value', sale.taxableValue),
                                if (!interstate) _previewAmountRow('CGST', cgst),
                                if (!interstate) _previewAmountRow('SGST', sgst),
                                if (interstate) _previewAmountRow('IGST', igst),
                              ],
                              const Divider(),
                              _previewAmountRow('Grand total', sale.total, bold: true),
                              _previewAmountRow('Paid at sale', sale.amountPaid),
                              if (sale.laterPaid > 0) _previewAmountRow('Paid later', sale.laterPaid),
                              _previewAmountRow('Total settled', sale.settledAmount),
                              _previewAmountRow(
                                'Balance due',
                                sale.balanceDue,
                                bold: true,
                                color: sale.balanceDue > 0.005 ? AppTheme.amber : AppTheme.green,
                              ),
                            ],
                          ),
                        );
                        if (constraints.maxWidth < 760) return Column(children: [totals, payment]);
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: totals), const SizedBox(width: 10), Expanded(child: payment)]);
                      },
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Finalized historical record. Later changes to customer, product or GST settings do not rewrite this saved transaction.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _saveSalePdf(data, sale),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save PDF'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _shareSale(data, sale),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share / send again'),
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuotationDetails(AppData data, Quotation quote) {
    final business = data.business;
    final businessName = quote.businessNameSnapshot.isNotEmpty
        ? quote.businessNameSnapshot
        : business.businessName;
    final businessAddress = quote.businessAddressSnapshot.isNotEmpty
        ? quote.businessAddressSnapshot
        : business.address;
    final businessGstin = quote.businessGstinSnapshot.isNotEmpty
        ? quote.businessGstinSnapshot
        : business.gstin;
    final rows = quote.lines
        .map(
          (line) => [
            line.name,
            line.hsnSac.isEmpty ? '-' : line.hsnSac,
            '${line.qty.toStringAsFixed(line.qty % 1 == 0 ? 0 : 2)} ${line.unit}',
            money(line.unitPrice),
            line.discountValue <= 0.005 ? '-' : money(line.discountValue),
            line.isOutputTaxable ? '${line.gstRate.toStringAsFixed(1)}%' : line.taxCategory,
            money(line.net),
          ],
        )
        .toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1000, maxHeight: MediaQuery.of(ctx).size.height * .90),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(child: _previewTitle('QUOTATION', subtitle: 'NOT A TAX INVOICE • Saved original quotation')),
                    StatusPill(text: quote.status, color: quote.status == 'Converted' ? AppTheme.green : AppTheme.cyan),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final left = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(businessName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                            if (businessAddress.isNotEmpty) Text(businessAddress),
                            if (businessGstin.isNotEmpty) Text('GSTIN: $businessGstin'),
                          ],
                        );
                        final right = Column(
                          children: [
                            _labelValue('Quotation no.', quote.number),
                            _labelValue('Date', _dateTime(quote.createdAt)),
                            if (quote.validUntil != null) _labelValue('Valid until', _dateOnly(quote.validUntil!)),
                          ],
                        );
                        if (constraints.maxWidth < 760) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 12), right]);
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 22), Expanded(child: right)]);
                      },
                    ),
                    const SizedBox(height: 10),
                    _previewSection(
                      'Customer / offer to',
                      Column(
                        children: [
                          _labelValue('Customer', quote.customerName),
                          if (quote.customerId.isNotEmpty) _labelValue('Customer ID', quote.customerId),
                          if (quote.customerGstin.isNotEmpty) _labelValue('GSTIN', quote.customerGstin),
                          if (quote.customerAddress.isNotEmpty) _labelValue('Address', quote.customerAddress),
                          if (quote.customerState.isNotEmpty) _labelValue('State', '${quote.customerState} • ${quote.customerStateCode}'),
                        ],
                      ),
                    ),
                    _previewSection(
                      'Quoted items',
                      _previewTable(
                        headers: const ['Item', 'HSN/SAC', 'Qty', 'Rate', 'Discount', 'Estimated GST', 'Amount'],
                        rows: rows,
                        minWidth: 900,
                      ),
                    ),
                    _previewSection(
                      'Quotation total',
                      Column(
                        children: [
                          _previewAmountRow('Quoted total', quote.total, bold: true),
                          if (quote.notes.isNotEmpty) ...[
                            const Divider(),
                            _labelValue('Notes / terms', quote.notes),
                          ],
                        ],
                      ),
                    ),
                    const Text(
                      'Quotation only. No inventory reduction, receivable or GST liability is created until conversion to a finalized sale.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _saveQuotationPdf(data, quote),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save PDF'),
                    ),
                    if (quote.linkedSaleId.isEmpty)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _convertQuotation(data, quote);
                        },
                        icon: const Icon(Icons.transform_rounded),
                        label: const Text('Convert to sale'),
                      ),
                    FilledButton.icon(
                      onPressed: () => _shareQuote(data, quote),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share / send again'),
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPurchaseDetails(AppData data, PurchaseRecord purchase) {
    final business = data.business;
    final sourceLabel = switch (purchase.sourceType) {
      'LOCAL' => 'LOCAL / CASH PURCHASE',
      'PRODUCTION' => 'OWN PRODUCTION / STOCK-IN',
      _ => 'SUPPLIER PURCHASE',
    };
    final sourceName = purchase.sourceType == 'SUPPLIER'
        ? purchase.supplierName
        : (purchase.sourceName.isEmpty ? sourceLabel : purchase.sourceName);
    final rows = purchase.lines
        .map(
          (line) => [
            line.productName,
            line.hsnSac.isEmpty ? '-' : line.hsnSac,
            '${line.quantity.toStringAsFixed(2)} + free ${line.freeQuantity.toStringAsFixed(2)} ${line.purchaseUnit}',
            money(line.purchasePricePerUnit),
            line.gstApplicable ? '${line.gstRate.toStringAsFixed(1)}%' : line.taxCategory,
            money(line.inputGst),
            line.itcEligible ? 'Eligible' : 'Cost',
            money(line.supplierInvoiceLineTotal),
          ],
        )
        .toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1040, maxHeight: MediaQuery.of(ctx).size.height * .90),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(child: _previewTitle(sourceLabel, subtitle: 'Saved stock-in / purchase record')),
                    StatusPill(
                      text: _purchaseSettlementStatus(purchase),
                      color: purchase.sourceType == 'PRODUCTION'
                          ? AppTheme.purple
                          : purchase.balanceDue <= 0.005
                              ? AppTheme.green
                              : purchase.settledAmount <= 0.005
                                  ? AppTheme.red
                                  : AppTheme.amber,
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final left = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(business.businessName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                            if (business.address.isNotEmpty) Text(business.address),
                            if (business.gstin.isNotEmpty) Text('GSTIN: ${business.gstin}'),
                          ],
                        );
                        final right = Column(
                          children: [
                            _labelValue('ProfitGPS record no.', purchase.number),
                            _labelValue('Recorded', _dateTime(purchase.createdAt)),
                            _labelValue('Invoice / source date', _dateOnly(purchase.invoiceDate)),
                          ],
                        );
                        if (constraints.maxWidth < 760) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [left, const SizedBox(height: 12), right]);
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 22), Expanded(child: right)]);
                      },
                    ),
                    const SizedBox(height: 10),
                    _previewSection(
                      purchase.sourceType == 'SUPPLIER' ? 'Supplier details' : 'Source details',
                      Column(
                        children: [
                          _labelValue('Source', sourceName),
                          if (purchase.sourceType == 'SUPPLIER') ...[
                            _labelValue('Supplier code', purchase.supplierCode),
                            _labelValue('Supplier invoice', purchase.invoiceNumber),
                            _labelValue('Purchase order', purchase.purchaseOrderNumber),
                          ],
                          _labelValue('Payment terms', purchase.paymentTerms),
                          _labelValue('Payment mode', purchase.paymentMode),
                          _labelValue('Transaction / reference', purchase.referenceNumber),
                        ],
                      ),
                    ),
                    _previewSection(
                      'Items received / created',
                      _previewTable(
                        headers: const ['Item', 'HSN/SAC', 'Qty + Free', 'Purchase rate', 'Input GST', 'GST value', 'ITC', 'Line total'],
                        rows: rows,
                        minWidth: 980,
                      ),
                    ),
                    _previewSection(
                      'Purchase / stock-in totals',
                      Column(
                        children: [
                          _previewAmountRow('Taxable / base value', purchase.subtotal),
                          _previewAmountRow('Input GST', purchase.totalInputGst),
                          _previewAmountRow('Freight / other cost', purchase.freightTotal),
                          if (purchase.supplierDiscountTotal > 0)
                            _previewAmountRow('Supplier discount', -purchase.supplierDiscountTotal),
                          const Divider(),
                          _previewAmountRow(
                            purchase.sourceType == 'PRODUCTION' ? 'Production cost recorded' : 'Total',
                            purchase.total,
                            bold: true,
                          ),
                          if (purchase.sourceType != 'PRODUCTION') ...[
                            _previewAmountRow('Paid', purchase.amountPaid),
                            if (purchase.supplierAdvanceUsed > 0)
                              _previewAmountRow('Supplier advance used', purchase.supplierAdvanceUsed),
                            if (purchase.laterPaid > 0)
                              _previewAmountRow('Paid later', purchase.laterPaid),
                            _previewAmountRow('Settled', purchase.settledAmount),
                            _previewAmountRow(
                              'Payable',
                              purchase.balanceDue,
                              bold: true,
                              color: purchase.balanceDue > 0.005 ? AppTheme.amber : AppTheme.green,
                            ),
                          ],
                          if (purchase.sourceType == 'PRODUCTION')
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'Own production is an internal stock-in record; it does not create a supplier payable.',
                                style: TextStyle(color: AppTheme.muted, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (purchase.note.isNotEmpty) _previewSection('Notes', Text(purchase.note)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _savePurchasePdf(data, purchase),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Save PDF'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _sharePurchase(data, purchase),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSalePdf(AppData data, Sale sale) async {
    final path = await InvoiceService.salePdf(data, sale);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF saved: $path')),
    );
  }

  Future<void> _shareSale(AppData data, Sale sale) async {
    final path = await InvoiceService.salePdf(data, sale);
    await Share.shareXFiles(
      [XFile(path)],
      text: '${_saleDisplayType(sale)} ${sale.documentNumber}',
    );
  }

  Future<void> _saveQuotationPdf(AppData data, Quotation quote) async {
    final path = await InvoiceService.quotationPdf(data, quote);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Quotation PDF saved: $path')),
    );
  }

  Future<void> _shareQuote(AppData data, Quotation quote) async {
    final path = await InvoiceService.quotationPdf(data, quote);
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Quotation ${quote.number}',
    );
  }

  Future<void> _savePurchasePdf(
    AppData data,
    PurchaseRecord purchase,
  ) async {
    final path = await InvoiceService.purchasePdf(data, purchase);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Purchase PDF saved: $path')),
    );
  }

  Future<void> _sharePurchase(
    AppData data,
    PurchaseRecord purchase,
  ) async {
    final path = await InvoiceService.purchasePdf(data, purchase);
    await Share.shareXFiles(
      [XFile(path)],
      text:
          'Purchase ${purchase.number} • Supplier invoice ${purchase.invoiceNumber}',
    );
  }

  Widget _plainMetric(String label, String value, Color color) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
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
    );
  }

  Widget _recordTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: 230,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
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
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    final display = value.trim().isEmpty ? 'Not recorded' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  static String _dateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day-$month-${value.year} $hour:$minute';
  }

  static String _customerLedgerLabel(String type) {
    return switch (type) {
      'RECEIVABLE' => 'Amount customer owes us',
      'PAYMENT' => 'Customer due collected',
      'ADVANCE' => 'Customer advance received',
      'ADVANCE_USED' => 'Customer advance used',
      _ => type,
    };
  }

  static String _supplierLedgerLabel(String type) {
    return switch (type) {
      'PAYABLE' => 'Amount payable to supplier',
      'PAYMENT' => 'Supplier payment',
      'ADVANCE' => 'Supplier advance paid',
      'ADVANCE_USED' => 'Supplier advance used',
      'RETURN' => 'Purchase return adjustment',
      'CREDIT_NOTE' => 'Supplier credit note',
      'DEBIT_NOTE' => 'Supplier debit note',
      _ => type,
    };
  }

  static Color _ledgerColor(String type) {
    return switch (type) {
      'RECEIVABLE' => AppTheme.amber,
      'PAYMENT' => AppTheme.green,
      'ADVANCE' => AppTheme.cyan,
      'ADVANCE_USED' => AppTheme.purple,
      _ => AppTheme.muted,
    };
  }

  static Color _supplierLedgerColor(String type) {
    return switch (type) {
      'PAYABLE' => AppTheme.amber,
      'PAYMENT' => AppTheme.green,
      'ADVANCE' => AppTheme.cyan,
      'ADVANCE_USED' => AppTheme.purple,
      'RETURN' => AppTheme.red,
      _ => AppTheme.muted,
    };
  }
}

class _RecordDocument {
  const _RecordDocument._({
    required this.createdAt,
    required this.amount,
    this.sale,
    this.quotation,
    this.purchase,
  });

  factory _RecordDocument.sale(Sale sale) => _RecordDocument._(
        createdAt: sale.createdAt,
        amount: sale.total,
        sale: sale,
      );

  factory _RecordDocument.quotation(Quotation quotation) => _RecordDocument._(
        createdAt: quotation.createdAt,
        amount: quotation.total,
        quotation: quotation,
      );

  factory _RecordDocument.purchase(PurchaseRecord purchase) => _RecordDocument._(
        createdAt: purchase.createdAt,
        amount: purchase.total,
        purchase: purchase,
      );

  final DateTime createdAt;
  final double amount;
  final Sale? sale;
  final Quotation? quotation;
  final PurchaseRecord? purchase;
}

class _PaymentEvent {
  const _PaymentEvent({
    required this.createdAt,
    required this.direction,
    required this.party,
    required this.partyType,
    required this.amount,
    required this.mode,
    required this.reference,
    required this.document,
    required this.detail,
  });

  final DateTime createdAt;
  final String direction;
  final String party;
  final String partyType;
  final double amount;
  final String mode;
  final String reference;
  final String document;
  final String detail;
}

class _TimelineRow {
  const _TimelineRow({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

extension _RecordsFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
