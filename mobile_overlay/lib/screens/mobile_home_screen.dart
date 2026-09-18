import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../services/analytics_engine.dart';

class MobileHomeScreen extends StatelessWidget {
  const MobileHomeScreen({super.key, required this.onBilling, required this.onPurchase, required this.onProducts, required this.onRecords});
  final VoidCallback onBilling;
  final VoidCallback onPurchase;
  final VoidCallback onProducts;
  final VoidCallback onRecords;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data!;
    final today = AnalyticsEngine.salesInDays(data, 1);
    final todaySales = AnalyticsEngine.salesTotal(today);
    final now = DateTime.now();
    final monthPurchases = data.purchases.where((p) => p.createdAt.isAfter(DateTime(now.year, now.month, 1))).fold<double>(0, (sum, p) => sum + p.total);
    final stockValue = data.products.fold<double>(0, (sum, p) => sum + p.stock * p.purchasePrice);
    final lowStock = data.products.where((p) => p.stock <= p.reorderLevel).length;
    final expiring = data.products.where((p) => p.expiryDate != null && p.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)))).length;
    final businessName = data.business.businessName.trim().isEmpty ? 'Your business' : data.business.businessName.trim();

    return ColoredBox(
      color: AppTheme.warmBackground,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.midnight, Color(0xFF0A2A49)]), boxShadow: const [BoxShadow(color: Color(0x19061A2D), blurRadius: 22, offset: Offset(0, 10))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.trending_up_rounded, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ProfitGPS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)), Text(businessName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFBFD0E2), fontSize: 12))])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: const Color(0x2212A66A), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x5534C98A))), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.offline_bolt_rounded, size: 14, color: AppTheme.emerald), SizedBox(width: 5), Text('Offline ready', style: TextStyle(color: AppTheme.emerald, fontSize: 10, fontWeight: FontWeight.w800))])),
                ]),
                const SizedBox(height: 18),
                const Text('Business at a glance', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('Simple actions. Local-first data. No internet needed for normal billing.', style: TextStyle(color: Color(0xFFBFD0E2), fontSize: 12.5)),
              ]),
            ),
            const SizedBox(height: 14),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.45, crossAxisSpacing: 10, mainAxisSpacing: 10, children: [
              _MetricCard(label: "Today's sales", value: _money(todaySales), icon: Icons.currency_rupee_rounded, accent: AppTheme.emerald),
              _MetricCard(label: 'This month purchases', value: _money(monthPurchases), icon: Icons.shopping_bag_outlined, accent: AppTheme.primary),
              _MetricCard(label: 'Current stock value', value: _money(stockValue), icon: Icons.inventory_2_outlined, accent: AppTheme.gold),
              _MetricCard(label: 'Needs attention', value: '${lowStock + expiring}', detail: '$lowStock low stock • $expiring expiry', icon: Icons.notifications_active_outlined, accent: AppTheme.danger),
            ]),
            const SizedBox(height: 20),
            const _LightHeading('Quick actions', 'Designed for fast shop-floor work'),
            const SizedBox(height: 10),
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.55, crossAxisSpacing: 10, mainAxisSpacing: 10, children: [
              _ActionCard(title: 'New Bill', subtitle: 'Scan, search or select', icon: Icons.point_of_sale_rounded, accent: AppTheme.primary, onTap: onBilling),
              _ActionCard(title: 'Purchase Inward', subtitle: 'Supplier / Local / Own', icon: Icons.add_shopping_cart_rounded, accent: AppTheme.emerald, onTap: onPurchase),
              _ActionCard(title: 'Products', subtitle: 'Stock, barcode, onboarding', icon: Icons.inventory_2_rounded, accent: AppTheme.gold, onTap: onProducts),
              _ActionCard(title: 'Records', subtitle: 'Customers, docs, payments', icon: Icons.receipt_long_rounded, accent: AppTheme.purple, onTap: onRecords),
            ]),
            const SizedBox(height: 20),
            const _LightHeading('Mobile purpose', 'Useful away from the billing counter'),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(14), decoration: AppTheme.lightCardDecoration(), child: const Wrap(spacing: 8, runSpacing: 8, children: [
              _Tag(icon: Icons.qr_code_scanner_rounded, text: 'Barcode scan'),
              _Tag(icon: Icons.add_a_photo_outlined, text: 'Product photo'),
              _Tag(icon: Icons.inventory_outlined, text: 'Stock check'),
              _Tag(icon: Icons.local_shipping_outlined, text: 'On-the-spot purchase'),
              _Tag(icon: Icons.sync_rounded, text: 'Windows sync ready'),
            ])),
          ],
        ),
      ),
    );
  }

  static String _money(double value) => '₹ ${value.round()}';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon, required this.accent, this.detail = ''});
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: AppTheme.lightCardDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: accent)), const Spacer()]),
    const Spacer(),
    Text(label, style: const TextStyle(color: AppTheme.lightMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.ink, fontSize: 18, fontWeight: FontWeight.w900)),
    if (detail.isNotEmpty) Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.lightMuted, fontSize: 9.5)),
  ]));
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.accent, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.all(14), decoration: AppTheme.lightCardDecoration(), child: Row(children: [
    Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: accent)),
    const SizedBox(width: 11),
    Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.lightMuted, fontSize: 10.5))])),
  ])))));
}

class _LightHeading extends StatelessWidget {
  const _LightHeading(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppTheme.ink, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(color: AppTheme.lightMuted, fontSize: 11.5))]);
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppTheme.lightGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.lightBorder)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: AppTheme.primary), const SizedBox(width: 6), Text(text, style: const TextStyle(color: AppTheme.ink, fontSize: 11, fontWeight: FontWeight.w700))]));
}
