import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../services/analytics_engine.dart';
import '../widgets/common.dart';

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data!;
    final branches = [...data.branches]..sort((a, b) => b.profit.compareTo(a.profit));
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SectionTitle('Multi-Shop Control Center', subtitle: 'Compare branches, benchmark profit and detect stock-transfer opportunities.'),
        if (branches.isEmpty)
          const EmptyState(
            'No branches added yet. Single-shop businesses can continue using ProfitGPS normally; add branches only when needed.',
            icon: Icons.store_mall_directory_outlined,
          ),
        ...branches.asMap().entries.map((entry) {
          final branch = entry.value;
          final margin = branch.sales == 0 ? 0.0 : branch.profit / branch.sales * 100;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: LayoutBuilder(builder: (context, c) {
                final narrow = c.maxWidth < 820;
                final identity = Row(children: [
                  CircleAvatar(backgroundColor: entry.key == 0 ? AppTheme.red : const Color(0xFF292D36), child: Text('${entry.key + 1}')),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(branch.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(branch.city, style: const TextStyle(color: AppTheme.muted)),
                  ])),
                ]);
                final metrics = Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _mini('Sales', money(branch.sales)),
                    _mini('Profit', money(branch.profit)),
                    _mini('Margin', '${margin.toStringAsFixed(1)}%'),
                    _mini('Expiry loss', money(branch.expiryLoss)),
                  ],
                );
                if (narrow) return Column(children: [identity, const SizedBox(height: 14), Align(alignment: Alignment.centerRight, child: metrics)]);
                return Row(children: [Expanded(flex: 3, child: identity), const SizedBox(width: 16), Expanded(flex: 5, child: metrics)]);
              }),
            ),
          );
        }),
        const SizedBox(height: 20),
        const SectionTitle('Stock transfer brain'),
        ...AnalyticsEngine.stockTransferIdeas(data).map((idea) => Card(child: ListTile(leading: const Icon(Icons.swap_horiz, color: AppTheme.green), title: Text(idea), subtitle: const Text('Verify real stock at each branch before approving transfer.', style: TextStyle(color: AppTheme.muted))))),
      ],
    );
  }

  Widget _mini(String label, String value) => SizedBox(
        width: 112,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}
