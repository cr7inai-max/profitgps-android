import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../services/analytics_engine.dart';
import '../services/business_type_rules.dart';
import '../widgets/common.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data!;
    final last30 = AnalyticsEngine.salesInDays(data, 30);
    final sales = AnalyticsEngine.salesTotal(last30);
    final profit = AnalyticsEngine.profitTotal(last30);
    final products = AnalyticsEngine.productProfitability(data);
    final forecast = AnalyticsEngine.forecastNext30Days(data);
    final trend = _dailySales(data, 30);
    final forecastDelta = sales == 0 ? 0.0 : (forecast - sales) / sales;

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
      children: [
        const SectionTitle(
          'Analytics Studio',
          subtitle:
              'Profitability, demand signal, product contribution and pricing intelligence in one view.',
          trailing: StatusPill(
            text: '30 DAYS',
            color: AppTheme.cyan,
            icon: Icons.calendar_month_rounded,
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 1050 ? 3 : c.maxWidth >= 650 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              childAspectRatio: 2.35,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                MetricCard(
                  label: '30-day sales',
                  value: money(sales),
                  icon: Icons.stacked_line_chart_rounded,
                  accent: AppTheme.cyan,
                  delta: '${last30.length} bills',
                ),
                MetricCard(
                  label: '30-day profit',
                  value: money(profit),
                  delta: sales == 0
                      ? '0% margin'
                      : '${(profit / sales * 100).toStringAsFixed(1)}% margin',
                  icon: Icons.savings_outlined,
                  accent: AppTheme.green,
                ),
                MetricCard(
                  label: 'Next 30-day estimate',
                  value: money(forecast),
                  delta:
                      '${forecastDelta >= 0 ? '+' : ''}${(forecastDelta * 100).toStringAsFixed(1)}% signal',
                  icon: Icons.auto_graph_rounded,
                  accent: AppTheme.purple,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 980;
            final trendPanel = GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sales momentum',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18)),
                            SizedBox(height: 3),
                            Text('Daily revenue movement over the last 30 days.',
                                style: TextStyle(
                                    color: AppTheme.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      StatusPill(
                        text: 'LOCAL DATA',
                        color: AppTheme.green,
                        icon: Icons.lock_outline_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SparklineChart(
                    values: trend,
                    color: AppTheme.cyan,
                    height: 155,
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Text('30 days ago',
                          style: TextStyle(
                              color: AppTheme.muted, fontSize: 10.5)),
                      Spacer(),
                      Text('Today',
                          style: TextStyle(
                              color: AppTheme.muted, fontSize: 10.5)),
                    ],
                  ),
                ],
              ),
            );
            final mixPanel = _ProfitMixPanel(
              sales: sales,
              profit: profit,
              forecast: forecast,
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: trendPanel),
                      const SizedBox(width: 14),
                      Expanded(flex: 4, child: mixPanel),
                    ],
                  )
                : Column(
                    children: [
                      trendPanel,
                      const SizedBox(height: 14),
                      mixPanel,
                    ],
                  );
          },
        ),
        const SizedBox(height: 26),
        SectionTitle(
          'Business-profile insights',
          subtitle: '${BusinessTypeRules.canonicalType(data.business.businessType)} analytics activated from the same local Product Master.',
        ),
        LayoutBuilder(
          builder: (context, c) {
            final cards = _businessProfileMetrics(data);
            final cols = c.maxWidth >= 1050 ? 3 : c.maxWidth >= 650 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              childAspectRatio: 2.35,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: cards,
            );
          },
        ),
        const SizedBox(height: 26),
        const SectionTitle(
          'Product profitability',
          subtitle: 'Products ranked by profit contribution, not only revenue.',
        ),
        _ProfitabilityPanel(products: products),
        const SizedBox(height: 26),
        const SectionTitle(
          'Pricing intelligence',
          subtitle:
              'Rule-based guidance using purchase cost, current margin, stock and expiry risk.',
        ),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final itemWidth = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: data.products.map((p) {
                final target = (p.purchasePrice * 1.18)
                    .clamp(p.purchasePrice, p.sellingPrice * 1.3)
                    .toDouble();
                final expiring = p.expiryDate != null &&
                    p.expiryDate!.isBefore(
                        DateTime.now().add(const Duration(days: 10)));
                final color = expiring
                    ? AppTheme.red
                    : p.marginPercent < 12
                        ? AppTheme.amber
                        : AppTheme.green;
                return SizedBox(
                  width: itemWidth,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(
                                28, color.red, color.green, color.blue),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            expiring
                                ? Icons.timer_outlined
                                : Icons.price_change_rounded,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 3),
                              Text(
                                expiring
                                    ? 'Near expiry · controlled clearance may protect working capital.'
                                    : 'Margin ${p.marginPercent.toStringAsFixed(1)}% · rule target around ${money(target)}.',
                                style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 11.5,
                                    height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(money(p.sellingPrice),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                            const SizedBox(height: 5),
                            StatusPill(
                              text: expiring ? 'EXPIRY' : 'MARGIN',
                              color: color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  static List<Widget> _businessProfileMetrics(AppData data) {
    final type = BusinessTypeRules.canonicalType(data.business.businessType);
    bool tracks(Product p, String key) {
      final productType = p.businessType.trim().isEmpty ? type : p.businessType;
      return BusinessTypeRules.resolvedTracking(productType, p.category, p.subcategory, p.trackingFlags)[key] == true;
    }

    final now = DateTime.now();
    final nearExpiry = data.products.where((p) =>
        p.expiryDate != null &&
        !p.expiryDate!.isBefore(now) &&
        p.expiryDate!.isBefore(now.add(const Duration(days: 45)))).length;
    final serialUnits = data.products.fold<int>(0, (sum, p) => sum + p.serialNumbers.length);
    final weighted = data.products.where((p) => p.weighted || tracks(p, 'weight')).length;
    final variants = data.products.where((p) => tracks(p, 'variant')).length;
    final conversion = data.products.where((p) => tracks(p, 'unitConversion')).length;
    final batchTracked = data.products.where((p) => tracks(p, 'batch')).length;
    final expiryTracked = data.products.where((p) => tracks(p, 'expiry')).length;
    final productionTracked = data.products.where((p) => tracks(p, 'production')).length;
    final wastageTracked = data.products.where((p) => tracks(p, 'wastage')).length;

    switch (type) {
      case 'Pharmacy / Medical':
        return [
          MetricCard(label: 'Expiry-tracked items', value: '$expiryTracked', delta: '$nearExpiry near expiry ≤45d', icon: Icons.medication_liquid_rounded, accent: AppTheme.amber),
          MetricCard(label: 'Batch-tracked items', value: '$batchTracked', delta: 'medicine / consumable logic', icon: Icons.inventory_2_outlined, accent: AppTheme.cyan),
          MetricCard(label: 'Serialized device units', value: '$serialUnits', delta: 'serial / IMEI available', icon: Icons.qr_code_2_rounded, accent: AppTheme.purple),
        ];
      case 'Jewellery / Precious Metals':
        final weightItems = data.products.where((p) => tracks(p, 'weight')).length;
        final tagged = data.products.where((p) => (p.customAttributes['tagNumber'] ?? '').trim().isNotEmpty).length;
        return [
          MetricCard(label: 'Weight-tracked items', value: '$weightItems', delta: 'purity / weight logic', icon: Icons.scale_rounded, accent: AppTheme.amber),
          MetricCard(label: 'Tagged pieces', value: '$tagged', delta: 'local jewellery identity', icon: Icons.sell_outlined, accent: AppTheme.cyan),
          MetricCard(label: 'High-value stock', value: money(data.products.where((p) => p.sellingPrice >= 100000).fold<double>(0, (s, p) => s + p.stock * p.sellingPrice)), delta: 'items ≥ ₹1,00,000', icon: Icons.workspace_premium_outlined, accent: AppTheme.purple),
        ];
      case 'Electronics / Mobile':
        return [
          MetricCard(label: 'Serial / IMEI units', value: '$serialUnits', delta: 'individual-device stock', icon: Icons.phone_iphone_rounded, accent: AppTheme.cyan),
          MetricCard(label: 'Variant products', value: '$variants', delta: 'model / storage / colour', icon: Icons.tune_rounded, accent: AppTheme.purple),
          MetricCard(label: 'Low stock products', value: '${data.products.where((p) => p.stock <= p.reorderLevel).length}', delta: 'reorder attention', icon: Icons.warning_amber_rounded, accent: AppTheme.amber),
        ];
      case 'Clothing / Footwear':
        return [
          MetricCard(label: 'Variant-tracked styles', value: '$variants', delta: 'size / colour stock', icon: Icons.checkroom_rounded, accent: AppTheme.purple),
          MetricCard(label: 'Low stock variants', value: '${data.products.where((p) => tracks(p, 'variant') && p.stock <= p.reorderLevel).length}', delta: 'size / colour replenishment', icon: Icons.warning_amber_rounded, accent: AppTheme.amber),
          MetricCard(label: 'Active categories', value: '${data.products.map((p) => p.category).toSet().length}', delta: 'local Product Master', icon: Icons.category_outlined, accent: AppTheme.cyan),
        ];
      case 'Auto Spare Parts':
        final compatible = data.products.where((p) => (p.customAttributes['vehicleCompatibility'] ?? '').trim().isNotEmpty).length;
        return [
          MetricCard(label: 'Vehicle-mapped parts', value: '$compatible', delta: 'compatibility captured', icon: Icons.directions_car_rounded, accent: AppTheme.cyan),
          MetricCard(label: 'Serialized units', value: '$serialUnits', delta: 'battery / tyre / tracked parts', icon: Icons.qr_code_2_rounded, accent: AppTheme.purple),
          MetricCard(label: 'Low stock parts', value: '${data.products.where((p) => p.stock <= p.reorderLevel).length}', delta: 'reorder attention', icon: Icons.build_circle_outlined, accent: AppTheme.amber),
        ];
      case 'Hardware / Electrical':
        return [
          MetricCard(label: 'Unit-conversion items', value: '$conversion', delta: 'roll / metre / feet etc.', icon: Icons.straighten_rounded, accent: AppTheme.cyan),
          MetricCard(label: 'Low stock items', value: '${data.products.where((p) => p.stock <= p.reorderLevel).length}', delta: 'reorder attention', icon: Icons.electrical_services_rounded, accent: AppTheme.amber),
          MetricCard(label: 'Active categories', value: '${data.products.map((p) => p.category).toSet().length}', delta: 'specification-driven stock', icon: Icons.category_outlined, accent: AppTheme.purple),
        ];
      case 'Bakery / Food Production':
        return [
          MetricCard(label: 'Production-tracked items', value: '$productionTracked', delta: 'own-production logic', icon: Icons.bakery_dining_rounded, accent: AppTheme.cyan),
          MetricCard(label: 'Near expiry', value: '$nearExpiry', delta: 'next 45 days', icon: Icons.timer_outlined, accent: AppTheme.amber),
          MetricCard(label: 'Batch-tracked items', value: '$batchTracked', delta: 'production / traceability', icon: Icons.inventory_2_outlined, accent: AppTheme.purple),
        ];
      case 'Wholesale / Distributor':
        return [
          MetricCard(label: 'Unit-conversion items', value: '$conversion', delta: 'case → box → piece', icon: Icons.inventory_2_rounded, accent: AppTheme.cyan),
          MetricCard(label: 'Stock units', value: data.products.fold<double>(0, (s, p) => s + p.stock).toStringAsFixed(0), delta: 'all Product Master items', icon: Icons.inventory_rounded, accent: AppTheme.purple),
          MetricCard(label: 'Low stock', value: '${data.products.where((p) => p.stock <= p.reorderLevel).length}', delta: 'replenishment signal', icon: Icons.warning_amber_rounded, accent: AppTheme.amber),
        ];
      case 'General Retail':
        return [
          MetricCard(label: 'Weighted items', value: '$weighted', delta: 'fresh / loose / measure', icon: Icons.scale_rounded, accent: AppTheme.green),
          MetricCard(label: 'Expiry-tracked items', value: '$expiryTracked', delta: '$nearExpiry near expiry ≤45d', icon: Icons.event_busy_outlined, accent: AppTheme.amber),
          MetricCard(label: 'Wastage-tracked items', value: '$wastageTracked', delta: 'fresh-produce logic', icon: Icons.eco_outlined, accent: AppTheme.cyan),
        ];
      default:
        return [
          MetricCard(label: 'Products', value: '${data.products.length}', delta: 'local Product Master', icon: Icons.inventory_2_outlined, accent: AppTheme.cyan),
          MetricCard(label: 'Low stock', value: '${data.products.where((p) => p.stock <= p.reorderLevel).length}', delta: 'reorder attention', icon: Icons.warning_amber_rounded, accent: AppTheme.amber),
          MetricCard(label: 'Tracked serial units', value: '$serialUnits', delta: 'if enabled per product', icon: Icons.qr_code_2_rounded, accent: AppTheme.purple),
        ];
    }
  }

  static List<double> _dailySales(AppData data, int days) {
    final now = DateTime.now();
    final values = <double>[];
    for (var offset = days - 1; offset >= 0; offset--) {
      final day = now.subtract(Duration(days: offset));
      var total = 0.0;
      for (final sale in data.sales) {
        if (sale.createdAt.year == day.year &&
            sale.createdAt.month == day.month &&
            sale.createdAt.day == day.day) {
          total += sale.total;
        }
      }
      values.add(total);
    }
    return values;
  }
}

class _ProfitMixPanel extends StatelessWidget {
  const _ProfitMixPanel({
    required this.sales,
    required this.profit,
    required this.forecast,
  });

  final double sales;
  final double profit;
  final double forecast;

  @override
  Widget build(BuildContext context) {
    final margin = sales == 0 ? 0.0 : profit / sales;
    final forecastRatio = sales == 0 ? 0.0 : forecast / sales;
    return GlassPanel(
      accent: AppTheme.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Performance signal',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
          const Text('A compact read on margin and forecast direction.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              RingMetric(
                value: margin.clamp(0.0, 1.0).toDouble(),
                label: 'margin',
                color: AppTheme.green,
                size: 102,
              ),
              RingMetric(
                value: (forecastRatio / 1.5).clamp(0.0, 1.0).toDouble(),
                label: 'forecast',
                color: AppTheme.purple,
                size: 102,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0F13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppTheme.cyan, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Forecasts are estimates from local history, not guarantees.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfitabilityPanel extends StatelessWidget {
  const _ProfitabilityPanel({required this.products});
  final List<MapEntry<String, double>> products;

  @override
  Widget build(BuildContext context) {
    final maxValue = products.isEmpty
        ? 1.0
        : products.first.value.abs().clamp(1.0, double.infinity).toDouble();
    return GlassPanel(
      child: Column(
        children: products.take(10).toList().asMap().entries.map((entry) {
          final item = entry.value;
          final ratio = (item.value.abs() / maxValue).clamp(0.0, 1.0).toDouble();
          return Padding(
            padding: EdgeInsets.only(bottom: entry.key == 9 ? 0 : 13),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    item.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF242A33),
                      color: item.value >= 0 ? AppTheme.green : AppTheme.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 92,
                  child: Text(
                    money(item.value),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
