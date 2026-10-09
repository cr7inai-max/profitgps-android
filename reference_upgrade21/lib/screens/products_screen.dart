import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../services/business_type_rules.dart';
import '../widgets/common.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String query = '';
  String categoryFilter = 'All';
  String stockFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data!;
    final categories = <String>{
      'All',
      ...data.products.map((p) => p.category).where((v) => v.trim().isNotEmpty),
    }.toList()
      ..sort((a, b) => a == 'All' ? -1 : b == 'All' ? 1 : a.compareTo(b));
    if (!categories.contains(categoryFilter)) categoryFilter = 'All';

    final products = data.products.where((p) {
      final q = query.trim().toLowerCase();
      final attributeText = [
        p.brand,
        p.manufacturer,
        p.packageSize,
        p.subcategory,
        ...p.serialNumbers,
        ...p.customAttributes.values,
      ].join(' ').toLowerCase();
      final searchMatch = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q) ||
          p.productCode.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q) ||
          attributeText.contains(q);
      final categoryMatch = categoryFilter == 'All' || p.category == categoryFilter;
      final stockMatch = switch (stockFilter) {
        'Low stock' => p.stock <= p.reorderLevel,
        'In stock' => p.stock > 0,
        'Out of stock' => p.stock <= 0,
        'Expiry tracked' => p.expiryDate != null,
        _ => true,
      };
      return searchMatch && categoryMatch && stockMatch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        SectionTitle(
          'Products & Inventory',
          subtitle:
              '${data.business.businessTypeLabel} profile • Product Master and live inventory. First-time products are created from Purchases → New Purchase; later purchases update the same stock item.',
        ),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search name / code / barcode / category / business-specific details',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                value: categoryFilter,
                isExpanded: true,
                items: categories
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => categoryFilter = v ?? 'All'),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                value: stockFilter,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All stock')),
                  DropdownMenuItem(value: 'In stock', child: Text('In stock')),
                  DropdownMenuItem(value: 'Low stock', child: Text('Low stock / reorder')),
                  DropdownMenuItem(value: 'Out of stock', child: Text('Out of stock')),
                  DropdownMenuItem(value: 'Expiry tracked', child: Text('Expiry tracked')),
                ],
                onChanged: (v) => setState(() => stockFilter = v ?? 'All'),
                decoration: const InputDecoration(labelText: 'Stock filter'),
              ),
            ),
            StatusPill(
              text: '${products.length} shown',
              color: AppTheme.cyan,
              icon: Icons.filter_alt_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (data.products.isEmpty)
          const EmptyState(
            'No products yet. Add the first real stock through Purchases → New Purchase. ProfitGPS no longer inserts demo products.',
            icon: Icons.inventory_2_outlined,
          )
        else if (products.isEmpty)
          const EmptyState(
            'No products match the current search or filters.',
            icon: Icons.filter_alt_off_outlined,
          )
        else
          ...products.map(
            (p) => _ProductCard(
              product: p,
              businessType: data.business.businessType,
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.businessType});
  final Product product;
  final String businessType;

  List<String> get detailBits {
    final values = <String>[];
    if (product.brand.trim().isNotEmpty) values.add('Brand: ${product.brand.trim()}');
    if (product.manufacturer.trim().isNotEmpty) values.add('Manufacturer: ${product.manufacturer.trim()}');
    if (product.packageSize.trim().isNotEmpty) values.add('Pack: ${product.packageSize.trim()}');
    for (final entry in product.customAttributes.entries) {
      if (entry.value.trim().isEmpty) continue;
      values.add('${BusinessTypeRules.displayAttributeLabel(product.businessType.isEmpty ? businessType : product.businessType, entry.key, category: product.category, subcategory: product.subcategory)}: ${entry.value.trim()}');
    }
    final type = product.businessType.isEmpty ? businessType : product.businessType;
    final tracking = BusinessTypeRules.resolvedTracking(type, product.category, product.subcategory, product.trackingFlags);
    final trackingText = BusinessTypeRules.trackingSummary(tracking);
    if (trackingText != 'Standard quantity stock') values.add(trackingText);
    if (product.serialNumbers.isNotEmpty) values.add('Available serials: ${product.serialNumbers.length}');
    return values;
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 820;
              final details = detailBits;
              final identity = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: narrow ? 56 : 112,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF171A20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: product.barcode.isEmpty
                        ? Icon(
                            product.weighted ? Icons.scale_rounded : Icons.qr_code_2,
                            color: product.weighted ? AppTheme.green : AppTheme.muted,
                          )
                        : BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: product.barcode,
                            drawText: false,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${product.productCode.isEmpty ? 'No SKU' : product.productCode} • ${product.category}${product.subcategory.isEmpty ? '' : ' / ${product.subcategory}'} • ${product.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            details.take(4).join(' • '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.cyan, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
              final metrics = Wrap(
                alignment: WrapAlignment.end,
                spacing: 14,
                runSpacing: 8,
                children: [
                  _Info(label: 'Price', value: '${money(product.sellingPrice)}/${product.unit}'),
                  _Info(
                    label: 'Default disc.',
                    value: product.defaultDiscountPercent > 0
                        ? '${product.defaultDiscountPercent.toStringAsFixed(1)}%'
                        : money(product.defaultDiscountAmount),
                  ),
                  _Info(
                    label: 'Net profit',
                    value: money(product.defaultProfit),
                    color: product.defaultProfit < 0 ? AppTheme.red : AppTheme.green,
                  ),
                  _Info(label: 'Tax class', value: product.taxCategory),
                  _Info(
                    label: 'GST',
                    value: product.gstApplicable
                        ? '${product.gstRate.toStringAsFixed(product.gstRate % 1 == 0 ? 0 : 2)}%'
                        : 'Not applicable',
                  ),
                  _Info(label: 'Stock', value: product.stockLabel),
                ],
              );
              return narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [identity, const SizedBox(height: 12), metrics],
                    )
                  : Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 16),
                        Flexible(flex: 2, child: metrics),
                      ],
                    );
            },
          ),
        ),
      );
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 125,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
            Text(
              value,
              maxLines: 2,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      );
}
