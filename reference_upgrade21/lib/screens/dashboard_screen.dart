import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../services/analytics_engine.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data!;
    final today = AnalyticsEngine.salesInDays(data, 1);
    final month = AnalyticsEngine.salesInDays(data, 30);
    final todaySales = AnalyticsEngine.salesTotal(today);
    final todayProfit = AnalyticsEngine.profitTotal(today);
    final monthSales = AnalyticsEngine.salesTotal(month);
    final forecast = AnalyticsEngine.forecastNext30Days(data);
    final lowStock = data.products.where((p) => p.stock <= p.reorderLevel).length;
    final expiring = data.products
        .where((p) =>
            p.expiryDate != null &&
            p.expiryDate!.isBefore(
              DateTime.now().add(const Duration(days: 10)),
            ))
        .length;
    final insights = AnalyticsEngine.profitGps(data);
    final hourly = AnalyticsEngine.salesByHour(data);
    final trend = _dailySales(data, 14);
    final monthProfit = AnalyticsEngine.profitTotal(month);
    final margin = monthSales == 0 ? 0.0 : monthProfit / monthSales;
    final riskAmount = _profitAtRisk(data);

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
      children: [
        _TopHeader(
          billCount: today.length,
          alertCount: lowStock + expiring,
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 980;
            final hero = _HeroPanel(
              todaySales: todaySales,
              todayProfit: todayProfit,
              riskAmount: riskAmount,
              trend: trend,
            );
            final metrics = _MetricGrid(
              monthSales: monthSales,
              forecast: forecast,
              margin: margin,
              billCount: today.length,
              lowStock: lowStock,
              expiring: expiring,
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: hero),
                  const SizedBox(width: 14),
                  Expanded(flex: 5, child: metrics),
                ],
              );
            }
            return Column(
              children: [
                hero,
                const SizedBox(height: 14),
                metrics,
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const SectionTitle(
          'Profit GPS',
          subtitle:
              'What changed, why it matters, and the next best action — without digging through reports.',
          trailing: StatusPill(
            text: 'DECISION ENGINE',
            color: AppTheme.purple,
            icon: Icons.auto_awesome_rounded,
          ),
        ),
        _DashboardInsightStrip(insights: insights),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 1020) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _PeakHourPanel(hourly: hourly),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: _BranchPanel(branches: data.branches),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _PeakHourPanel(hourly: hourly),
                const SizedBox(height: 14),
                _BranchPanel(branches: data.branches),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const SectionTitle(
          'Attention queue',
          subtitle:
              'High-value actions that can protect margin, availability and working capital.',
        ),
        _AttentionQueue(data: data),
      ],
    );
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

  static double _profitAtRisk(AppData data) {
    var value = 0.0;
    final soon = DateTime.now().add(const Duration(days: 10));
    for (final p in data.products) {
      if (p.expiryDate != null && p.expiryDate!.isBefore(soon)) {
        value += p.purchasePrice * p.stock * 0.35;
      }
      if (p.marginPercent < 12) {
        value += math.max(0.0, 12 - p.marginPercent).toDouble() * p.stock;
      }
    }
    return value;
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.billCount, required this.alertCount});
  final int billCount;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Business Command Center',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Your shop, translated into decisions.',
                style: TextStyle(color: AppTheme.muted, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const StatusPill(
          text: 'OFFLINE READY',
          color: AppTheme.green,
          icon: Icons.offline_bolt_rounded,
        ),
        const SizedBox(width: 8),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_none_rounded,
                  color: Color(0xFFDDE1E8), size: 20),
              if (alertCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.todaySales,
    required this.todayProfit,
    required this.riskAmount,
    required this.trend,
  });

  final double todaySales;
  final double todayProfit;
  final double riskAmount;
  final List<double> trend;

  @override
  Widget build(BuildContext context) {
    final profitRate = todaySales == 0 ? 0.0 : todayProfit / todaySales;
    return Container(
      height: 278,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3A1C20)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF211014), Color(0xFF111318), Color(0xFF0E1115)],
          stops: [0, 0.52, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusPill(
                text: 'TODAY',
                color: AppTheme.red,
                icon: Icons.bolt_rounded,
              ),
              const Spacer(),
              Text(
                '${(profitRate * 100).toStringAsFixed(1)}% est. margin',
                style: const TextStyle(
                  color: AppTheme.green,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Sales today',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            money(todaySales),
            style: const TextStyle(
              fontSize: 42,
              height: 1.04,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.7,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SparklineChart(
              values: trend,
              color: AppTheme.red,
              height: 74,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeroMini(
                icon: Icons.savings_outlined,
                label: 'Estimated profit',
                value: money(todayProfit),
                color: AppTheme.green,
              ),
              const SizedBox(width: 12),
              _HeroMini(
                icon: Icons.shield_outlined,
                label: 'Profit at risk',
                value: money(riskAmount),
                color: riskAmount > 0 ? AppTheme.amber : AppTheme.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMini extends StatelessWidget {
  const _HeroMini({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x8A0A0C10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2E36)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.monthSales,
    required this.forecast,
    required this.margin,
    required this.billCount,
    required this.lowStock,
    required this.expiring,
  });

  final double monthSales;
  final double forecast;
  final double margin;
  final int billCount;
  final int lowStock;
  final int expiring;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final oneColumn = c.maxWidth < 440;
        final cardWidth = oneColumn ? c.maxWidth : (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              height: 133,
              child: MetricCard(
                compact: true,
                label: '30-day sales',
                value: money(monthSales),
                delta: '$billCount bills today',
                icon: Icons.stacked_line_chart_rounded,
                accent: AppTheme.cyan,
              ),
            ),
            SizedBox(
              width: cardWidth,
              height: 133,
              child: MetricCard(
                compact: true,
                label: 'Next 30-day forecast',
                value: money(forecast),
                delta: 'Estimate',
                icon: Icons.auto_graph_rounded,
                accent: AppTheme.purple,
              ),
            ),
            SizedBox(
              width: cardWidth,
              height: 133,
              child: MetricCard(
                compact: true,
                label: 'Gross margin signal',
                value: '${(margin * 100).toStringAsFixed(1)}%',
                delta: 'Last 30 days',
                icon: Icons.donut_large_rounded,
                accent: AppTheme.green,
              ),
            ),
            SizedBox(
              width: cardWidth,
              height: 133,
              child: MetricCard(
                compact: true,
                label: 'Inventory alerts',
                value: '${lowStock + expiring}',
                delta: '$lowStock low · $expiring expiry',
                icon: Icons.warning_amber_rounded,
                accent: AppTheme.amber,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final color = insight.kind == 'good'
        ? AppTheme.green
        : insight.kind == 'risk'
            ? AppTheme.red
            : AppTheme.amber;
    final icon = insight.kind == 'good'
        ? Icons.check_circle_outline_rounded
        : insight.kind == 'risk'
            ? Icons.warning_amber_rounded
            : Icons.tips_and_updates_outlined;

    return Container(
      width: 302,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color.fromARGB(28, color.red, color.green, color.blue),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              StatusPill(
                text: insight.kind == 'good' ? 'OPPORTUNITY' : 'ATTENTION',
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            insight.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            insight.detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFC5CAD3),
              height: 1.35,
              fontSize: 12.5,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  insight.action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: color, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeakHourPanel extends StatelessWidget {
  const _PeakHourPanel({required this.hourly});
  final Map<int, double> hourly;

  @override
  Widget build(BuildContext context) {
    final visible = hourly.entries.where((e) => e.key >= 8 && e.key <= 21).toList();
    final maxValue = visible.isEmpty
        ? 1.0
        : visible
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity)
            .toDouble();
    final peak = visible.isEmpty
        ? const MapEntry<int, double>(0, 0)
        : visible.reduce((a, b) => a.value >= b.value ? a : b);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Peak-hour radar',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('When customer traffic is most valuable.',
                        style: TextStyle(
                            color: AppTheme.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              StatusPill(
                text: '${peak.key}:00 PEAK',
                color: AppTheme.red,
                icon: Icons.local_fire_department_rounded,
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 126,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: visible.map((entry) {
                final ratio = entry.value / maxValue;
                final active = entry.key == peak.key;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: math.max(0.08, ratio).toDouble(),
                              widthFactor: 0.72,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppTheme.red
                                      : Color.fromARGB(
                                          105,
                                          AppTheme.red.red,
                                          AppTheme.red.green,
                                          AppTheme.red.blue,
                                        ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          entry.key % 2 == 0 ? '${entry.key}' : '',
                          style: const TextStyle(
                              color: AppTheme.muted, fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.groups_2_outlined, color: AppTheme.cyan, size: 18),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Schedule replenishment before the peak and keep one flexible checkout lane ready.',
                    style: TextStyle(color: Color(0xFFC8CDD5), fontSize: 12),
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

class _BranchPanel extends StatelessWidget {
  const _BranchPanel({required this.branches});
  final List<Branch> branches;

  @override
  Widget build(BuildContext context) {
    final ranked = [...branches]..sort((a, b) => b.profit.compareTo(a.profit));
    final maxProfit = ranked.isEmpty
        ? 1.0
        : ranked.first.profit.abs().clamp(1.0, double.infinity).toDouble();

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Branch leaderboard',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Ranked by current profit contribution.',
                        style: TextStyle(
                            color: AppTheme.muted, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.emoji_events_outlined,
                  color: AppTheme.amber, size: 22),
            ],
          ),
          const SizedBox(height: 18),
          ...ranked.take(4).toList().asMap().entries.map((entry) {
            final branch = entry.value;
            final margin = branch.sales == 0 ? 0 : branch.profit / branch.sales;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == 0
                          ? const Color(0xFF332314)
                          : const Color(0xFF191D24),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${entry.key + 1}',
                      style: TextStyle(
                        color: entry.key == 0 ? AppTheme.amber : AppTheme.muted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(branch.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5)),
                            ),
                            Text(
                              money(branch.profit),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (branch.profit.abs() / maxProfit)
                                .clamp(0.0, 1.0)
                                .toDouble(),
                            minHeight: 6,
                            backgroundColor: const Color(0xFF242A33),
                            color: entry.key == 0
                                ? AppTheme.amber
                                : AppTheme.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(margin * 100).toStringAsFixed(1)}% margin · ${money(branch.sales)} sales',
                          style: const TextStyle(
                              color: AppTheme.muted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AttentionQueue extends StatelessWidget {
  const _AttentionQueue({required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    final alerts = <_ActionItem>[];
    final soon = DateTime.now().add(const Duration(days: 10));

    for (final p in data.products.where((p) => p.stock <= p.reorderLevel)) {
      alerts.add(
        _ActionItem(
          icon: Icons.inventory_2_outlined,
          color: AppTheme.cyan,
          title: '${p.name} may run low',
          detail: '${p.stockLabel} left · reorder level ${p.reorderLevel} ${p.unit}',
          action: 'Check supplier / branch stock',
        ),
      );
    }
    for (final p in data.products.where(
      (p) => p.expiryDate != null && p.expiryDate!.isBefore(soon),
    )) {
      alerts.add(
        _ActionItem(
          icon: Icons.timer_outlined,
          color: AppTheme.red,
          title: '${p.name} needs expiry action',
          detail: 'Current stock ${p.stock} · ${money(p.purchasePrice * p.stock)} cost value',
          action: 'Review markdown / bundle',
        ),
      );
    }

    if (alerts.isEmpty) {
      return const GlassPanel(
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.green),
            SizedBox(width: 10),
            Text('No urgent inventory action in the current local data.'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final itemWidth = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: alerts.take(6).map((item) {
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
                          28,
                          item.color.red,
                          item.color.green,
                          item.color.blue,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(item.detail,
                              style: const TextStyle(
                                  color: AppTheme.muted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.action,
                      style: TextStyle(
                        color: item.color,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String action;
}


class _DashboardInsightStrip extends StatefulWidget {
  const _DashboardInsightStrip({required this.insights});
  final List<Insight> insights;
  @override
  State<_DashboardInsightStrip> createState() => _DashboardInsightStripState();
}

class _DashboardInsightStripState extends State<_DashboardInsightStrip> {
  final ScrollController controller = ScrollController();

  void move(double delta) {
    if (!controller.hasClients) return;
    final target = (controller.offset + delta)
        .clamp(0.0, controller.position.maxScrollExtent)
        .toDouble();
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: Stack(
        children: [
          Positioned.fill(
            child: Scrollbar(
              controller: controller,
              thumbVisibility: true,
              trackVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                scrollDirection: Axis.horizontal,
                itemCount: widget.insights.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: 310,
                  child: _InsightCard(insight: widget.insights[i]),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 78,
            child: _arrow(Icons.chevron_left_rounded, () => move(-330)),
          ),
          Positioned(
            right: 0,
            top: 78,
            child: _arrow(Icons.chevron_right_rounded, () => move(330)),
          ),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback tap) => Material(
        color: const Color(0xDD121720),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: tap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 24, color: Colors.white),
          ),
        ),
      );
}
