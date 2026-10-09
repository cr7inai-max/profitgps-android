import '../models/entities.dart';

class Insight {
  Insight(this.title, this.detail, this.kind, {this.action = ''});
  final String title;
  final String detail;
  final String kind;
  final String action;
}

class AnalyticsEngine {
  static List<Sale> salesInDays(AppData data, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return data.sales.where((s) => s.createdAt.isAfter(cutoff)).toList();
  }

  static double salesTotal(Iterable<Sale> sales) => sales.fold<double>(0.0, (a, b) => a + b.total);
  static double profitTotal(Iterable<Sale> sales) => sales.fold<double>(0.0, (a, b) => a + b.profit);

  static Map<int, double> salesByHour(AppData data, {int days = 30}) {
    final map = {for (var h = 0; h < 24; h++) h: 0.0};
    for (final s in salesInDays(data, days)) {
      map[s.createdAt.hour] = (map[s.createdAt.hour] ?? 0) + s.total;
    }
    return map;
  }

  static List<MapEntry<String, double>> productProfitability(AppData data, {int days = 30}) {
    final map = <String, double>{};
    for (final sale in salesInDays(data, days)) {
      for (final line in sale.lines) {
        map[line.name] = (map[line.name] ?? 0) + line.profit;
      }
    }
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  static double forecastNext30Days(AppData data) {
    final last30 = salesTotal(salesInDays(data, 30));
    final prev30 = data.sales.where((s) {
      final now = DateTime.now();
      return s.createdAt.isAfter(now.subtract(const Duration(days: 60))) && s.createdAt.isBefore(now.subtract(const Duration(days: 30)));
    });
    final previous = salesTotal(prev30);
    if (previous <= 0) return last30;
    final growth = ((last30 - previous) / previous).clamp(-0.25, 0.25).toDouble();
    return last30 * (1 + growth);
  }

  static List<Insight> profitGps(AppData data) {
    final insights = <Insight>[];
    final lowStock = data.products.where((p) => p.stock <= p.reorderLevel).toList();
    if (lowStock.isNotEmpty) {
      insights.add(Insight('Low-stock risk', '${lowStock.length} products are at or below reorder level.', 'risk', action: 'Review reorder list'));
    }
    final expiring = data.products.where((p) => p.expiryDate != null && p.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 10)))).toList();
    if (expiring.isNotEmpty) {
      insights.add(Insight('Expiry rescue', '${expiring.length} products may expire within 10 days.', 'risk', action: 'Bundle or discount before expiry'));
    }
    final lowMargin = data.products.where((p) => p.marginPercent < 12).toList();
    if (lowMargin.isNotEmpty) {
      insights.add(Insight('Margin leak', '${lowMargin.length} products have selling margin below 12%.', 'warning', action: 'Review purchase cost or price'));
    }
    if (data.sales.isNotEmpty) {
      final hourly = salesByHour(data);
      final peak = hourly.entries.reduce((a, b) => a.value >= b.value ? a : b);
      insights.add(Insight('Peak hour', '${peak.key}:00–${(peak.key + 1) % 24}:00 is your strongest hour in the current data.', 'good', action: 'Staff and replenish before peak'));
    }
    if (data.branches.length >= 2) {
      final best = [...data.branches]..sort((a, b) => b.profit.compareTo(a.profit));
      insights.add(Insight('Branch benchmark', '${best.first.name} currently has the highest branch profit.', 'good', action: 'Compare its margin and stock practices'));
    }
    return insights;
  }

  static List<String> stockTransferIdeas(AppData data) {
    final low = data.products.where((p) => p.stock <= p.reorderLevel).toList();
    if (data.branches.length < 2 || low.isEmpty) return ['No stock-transfer recommendation yet. Add branch and inventory data to enable transfer suggestions.'];
    return low.take(3).map((p) => 'Check ${p.name}: ${p.stockLabel} left. Before purchasing, verify excess stock at other branches.').toList();
  }

  static double appraisalProfitImpact(double monthlyRaise) => monthlyRaise * 12;
}
