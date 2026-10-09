import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../services/analytics_engine.dart';
import '../widgets/common.dart';

class SmartToolsScreen extends StatefulWidget {
  const SmartToolsScreen({super.key});

  @override
  State<SmartToolsScreen> createState() => _SmartToolsScreenState();
}

class _SmartToolsScreenState extends State<SmartToolsScreen> {
  double priceDelta = 2;
  double discount = 5;
  final ScrollController insightScroll = ScrollController();

  @override
  void dispose() { insightScroll.dispose(); super.dispose(); }

  void _moveInsights(double delta) {
    if (!insightScroll.hasClients) return;
    insightScroll.animateTo((insightScroll.offset + delta).clamp(0.0, insightScroll.position.maxScrollExtent).toDouble(), duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  Widget _scrollArrow(IconData icon, VoidCallback tap) => Material(color: const Color(0xDD121720), shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: tap, child: Padding(padding: const EdgeInsets.all(7), child: Icon(icon, size: 24, color: Colors.white))));

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data!;
    final insights = AnalyticsEngine.profitGps(data);
    final base = AnalyticsEngine.salesTotal(
      AnalyticsEngine.salesInDays(data, 30),
    );
    final estDemandChange =
        (-priceDelta * 0.012).clamp(-0.25, 0.25).toDouble();
    final simulatedRevenue = base * (1 + estDemandChange) + (priceDelta * 120);
    final scenarioDelta = simulatedRevenue - base;

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 40),
      children: [
        const SectionTitle(
          'Profit GPS Lab',
          subtitle:
              'Decision support that turns business data into prioritized actions and what-if scenarios.',
          trailing: StatusPill(
            text: 'LOCAL ENGINE',
            color: AppTheme.purple,
            icon: Icons.auto_awesome_rounded,
          ),
        ),
        SizedBox(
          height: 222,
          child: Stack(children: [
            Positioned.fill(child: Scrollbar(controller: insightScroll, thumbVisibility: true, trackVisibility: true, scrollbarOrientation: ScrollbarOrientation.bottom, child: ListView.separated(
            controller: insightScroll,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            scrollDirection: Axis.horizontal,
            itemCount: insights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final insight = insights[index];
              final color = insight.kind == 'good'
                  ? AppTheme.green
                  : insight.kind == 'risk'
                      ? AppTheme.red
                      : AppTheme.amber;
              return Container(
                width: 305,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromARGB(35, color.red, color.green, color.blue),
                      AppTheme.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color.fromARGB(
                                28, color.red, color.green, color.blue),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.bolt_rounded,
                              color: color, size: 20),
                        ),
                        const Spacer(),
                        StatusPill(
                          text: insight.kind == 'good' ? 'UPSIDE' : 'ACTION',
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(insight.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(
                      insight.detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFC7CCD4),
                          height: 1.35,
                          fontSize: 12.5),
                    ),
                    const Spacer(),
                    Text(
                      insight.action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ))),
          Positioned(left: 0, top: 78, child: _scrollArrow(Icons.chevron_left_rounded, () => _moveInsights(-330))),
          Positioned(right: 0, top: 78, child: _scrollArrow(Icons.chevron_right_rounded, () => _moveInsights(330))),
        ])),
        const SizedBox(height: 26),
        const SectionTitle(
          'Digital Twin',
          subtitle:
              'Simulate a pricing scenario using the local scenario model before making a real decision.',
        ),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 980;
            final controls = GlassPanel(
              accent: AppTheme.red,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Scenario controls',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 4),
                  const Text(
                    'Change assumptions and see the estimated revenue response.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Average price change',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      StatusPill(
                        text:
                            '${priceDelta >= 0 ? '+' : ''}${money(priceDelta)}',
                        color: priceDelta >= 0 ? AppTheme.green : AppTheme.red,
                      ),
                    ],
                  ),
                  Slider(
                    value: priceDelta,
                    min: -10,
                    max: 10,
                    divisions: 40,
                    onChanged: (value) => setState(() => priceDelta = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Clearance discount',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      StatusPill(
                        text: '${discount.toStringAsFixed(0)}%',
                        color: AppTheme.amber,
                      ),
                    ],
                  ),
                  Slider(
                    value: discount,
                    min: 0,
                    max: 30,
                    divisions: 30,
                    onChanged: (value) => setState(() => discount = value),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This build uses a deliberately simple elasticity model. Production calibration should use each shop’s seasonality, category behavior, stock availability and supplier lead time.',
                    style: TextStyle(
                        color: AppTheme.muted, fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            );
            final output = GlassPanel(
              accent: scenarioDelta >= 0 ? AppTheme.green : AppTheme.red,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Scenario output',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                      StatusPill(
                        text: 'ESTIMATE',
                        color: AppTheme.purple,
                        icon: Icons.science_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text('Estimated 30-day sales',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    money(simulatedRevenue),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 36,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 9),
                  StatusPill(
                    text:
                        '${scenarioDelta >= 0 ? '+' : ''}${money(scenarioDelta)} vs current',
                    color: scenarioDelta >= 0 ? AppTheme.green : AppTheme.red,
                    icon: scenarioDelta >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                  ),
                  const SizedBox(height: 24),
                  _CompareLine(
                    label: 'Current baseline',
                    value: base,
                    max: base > simulatedRevenue ? base : simulatedRevenue,
                    color: AppTheme.cyan,
                  ),
                  const SizedBox(height: 14),
                  _CompareLine(
                    label: 'Scenario estimate',
                    value: simulatedRevenue,
                    max: base > simulatedRevenue ? base : simulatedRevenue,
                    color: scenarioDelta >= 0 ? AppTheme.green : AppTheme.red,
                  ),
                ],
              ),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: controls),
                      const SizedBox(width: 14),
                      Expanded(flex: 5, child: output),
                    ],
                  )
                : Column(
                    children: [
                      controls,
                      const SizedBox(height: 14),
                      output,
                    ],
                  );
          },
        ),
        const SizedBox(height: 26),
        const SectionTitle(
          'Next Best Actions',
          subtitle:
              'The shortlist an owner should look at first — instead of scanning every report.',
        ),
        GlassPanel(
          child: Column(
            children: [
              for (final product
                  in data.products.where((p) => p.stock <= p.reorderLevel).take(5))
                _ActionRow(
                  icon: Icons.shopping_cart_checkout_rounded,
                  color: AppTheme.cyan,
                  title: 'Review ${product.name} reorder',
                  detail:
                      '${product.stockLabel} left; reorder level ${product.reorderLevel} ${product.unit}. Verify supplier lead time and other-branch stock first.',
                ),
              for (final product in data.products
                  .where((p) =>
                      p.expiryDate != null &&
                      p.expiryDate!.isBefore(
                        DateTime.now().add(const Duration(days: 10)),
                      ))
                  .take(5))
                _ActionRow(
                  icon: Icons.timer_rounded,
                  color: AppTheme.red,
                  title: 'Rescue ${product.name} before expiry',
                  detail:
                      'Consider a safe markdown/bundle and pause automatic reorder until sell-through improves.',
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompareLine extends StatelessWidget {
  const _CompareLine({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final double value;
  final double max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: AppTheme.muted, fontSize: 11.5)),
            ),
            Text(money(value),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            color: color,
            backgroundColor: const Color(0xFF242A33),
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Color.fromARGB(28, color.red, color.green, color.blue),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(detail,
                      style: const TextStyle(
                          color: AppTheme.muted,
                          height: 1.35,
                          fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded, color: color, size: 18),
          ],
        ),
      );
}
