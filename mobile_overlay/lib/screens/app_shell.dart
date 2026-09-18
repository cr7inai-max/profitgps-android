import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/app_scope.dart';
import 'analytics_screen.dart';
import 'billing_screen.dart';
import 'branches_screen.dart';
import 'dashboard_screen.dart';
import 'mobile_home_screen.dart';
import 'employees_screen.dart';
import 'feedback_screen.dart';
import 'records_screen.dart';
import 'products_screen.dart';
import 'purchase_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'smart_tools_screen.dart';
import 'cash_close_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final role = AppScope.of(context).data?.business.activeRole ?? 'Owner';
    final owner = role == 'Owner';
    final items = <(String, IconData, Widget)>[
      if (owner) ('Command Center', Icons.space_dashboard_rounded, const DashboardScreen()),
      ('Billing', Icons.point_of_sale_rounded, BillingScreen(onExit: () => setState(() => index = 0))),
      ('Products', Icons.inventory_2_rounded, const ProductsScreen()),
      if (owner) ('Purchases', Icons.shopping_bag_rounded, const PurchaseScreen()),
      if (owner) ('Analytics', Icons.query_stats_rounded, const AnalyticsScreen()),
      if (owner) ('Profit GPS', Icons.navigation_rounded, const SmartToolsScreen()),
      ('Cash Close', Icons.account_balance_wallet_rounded, const CashCloseScreen()),
      if (owner) ('Branches', Icons.store_mall_directory_rounded, const BranchesScreen()),
      if (owner) ('Employees', Icons.groups_2_rounded, const EmployeesScreen()),
      ('Records', Icons.receipt_long_rounded, const RecordsScreen()),
      ('Feedback', Icons.forum_rounded, const FeedbackScreen()),
      if (owner) ('Reports', Icons.description_rounded, const ReportsScreen()),
      if (owner) ('Settings', Icons.settings_rounded, const SettingsScreen()),
    ];
    if (index >= items.length) index = 0;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 760;
    final extendedSidebar = width >= 1240;

    int findItem(String title) {
      final found = items.indexWhere((e) => e.$1 == title);
      return found < 0 ? 0 : found;
    }

    Future<void> openMore() async {
      final primaryTitles = {'Command Center', 'Billing', 'Purchases', 'Products'};
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppTheme.warmSurface,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('More ProfitGPS', style: TextStyle(color: AppTheme.ink, fontSize: 20, fontWeight: FontWeight.w900)),
                    SizedBox(height: 3),
                    Text('Records, cash close, reports, employees, settings and advanced tools.', style: TextStyle(color: AppTheme.lightMuted, fontSize: 11.5)),
                  ]),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        if (!primaryTitles.contains(items[i].$1))
                          ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(11)), child: Icon(items[i].$2, color: AppTheme.primary)),
                            title: Text(items[i].$1, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w800)),
                            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.lightMuted),
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => index = i);
                            },
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final mobilePrimary = <(String, IconData, int)>[
      ('Home', Icons.home_rounded, findItem('Command Center')),
      ('Billing', Icons.point_of_sale_rounded, findItem('Billing')),
      if (owner) ('Purchase', Icons.shopping_bag_rounded, findItem('Purchases')),
      ('Products', Icons.inventory_2_rounded, findItem('Products')),
    ];
    final currentMobileNav = mobilePrimary.indexWhere((e) => e.$3 == index);
    final mobileChild = items[index].$1 == 'Command Center'
        ? MobileHomeScreen(
            onBilling: () => setState(() => index = findItem('Billing')),
            onPurchase: () => setState(() => index = findItem('Purchases')),
            onProducts: () => setState(() => index = findItem('Products')),
            onRecords: () => setState(() => index = findItem('Records')),
          )
        : items[index].$3;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: mobile
          ? AppBar(
              titleSpacing: 14,
              title: const _BrandMark(compact: false),
              actions: const [Padding(padding: EdgeInsets.only(right: 12), child: _LiveBadge())],
            )
          : null,
      body: mobile
          ? _screenBody(mobileChild, light: items[index].$1 == 'Command Center')
          : Row(
              children: [
                SizedBox(width: extendedSidebar ? 236 : 88, child: _SideMenu(selected: index, items: items, extended: extendedSidebar, onSelect: (value) => setState(() => index = value))),
                Container(width: 1, color: AppTheme.border),
                Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), switchInCurve: Curves.easeOut, switchOutCurve: Curves.easeIn, child: KeyedSubtree(key: ValueKey(index), child: _screenBody(items[index].$3)))),
              ],
            ),
      bottomNavigationBar: mobile
          ? Container(
              decoration: const BoxDecoration(color: AppTheme.midnight, border: Border(top: BorderSide(color: AppTheme.border))),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  for (var i = 0; i < mobilePrimary.length; i++) Expanded(child: _MobileNavItem(label: mobilePrimary[i].$1, icon: mobilePrimary[i].$2, selected: currentMobileNav == i, onTap: () => setState(() => index = mobilePrimary[i].$3))),
                  Expanded(child: _MobileNavItem(label: 'More', icon: Icons.grid_view_rounded, selected: currentMobileNav < 0, onTap: openMore)),
                ]),
              ),
            )
          : null,
    );
  }

  Widget _screenBody(Widget child, {bool light = false}) => Container(
        decoration: light ? const BoxDecoration(color: AppTheme.warmBackground) : const BoxDecoration(gradient: RadialGradient(center: Alignment(0.85, -0.9), radius: 1.1, colors: [Color(0xFF0D2C49), AppTheme.background], stops: [0, 0.62])),
        child: child,
      );
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.selected, required this.items, required this.onSelect, this.extended = true});
  final int selected;
  final List<(String, IconData, Widget)> items;
  final ValueChanged<int> onSelect;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.sidebar,
      padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 10),
      child: Column(children: [
        Padding(padding: EdgeInsets.fromLTRB(extended ? 10 : 0, 22, extended ? 10 : 0, 22), child: _BrandMark(compact: !extended)),
        if (extended) const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Row(children: [_LiveBadge(), Spacer(), Icon(Icons.notifications_none_rounded, size: 18, color: AppTheme.muted)])),
        SizedBox(height: extended ? 18 : 8),
        Expanded(child: ListView.separated(padding: EdgeInsets.zero, itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 5), itemBuilder: (context, i) {
          final active = i == selected;
          return Tooltip(
            message: extended ? '' : items[i].$1,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: extended ? 13 : 0),
                decoration: BoxDecoration(color: active ? const Color(0xFF102E54) : Colors.transparent, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? const Color(0xFF255C9B) : Colors.transparent)),
                child: Row(mainAxisAlignment: extended ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
                  Container(width: 30, height: 30, decoration: BoxDecoration(color: active ? const Color(0xFF173E6C) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: Icon(items[i].$2, size: 19, color: active ? AppTheme.primary : AppTheme.muted)),
                  if (extended) ...[const SizedBox(width: 11), Expanded(child: Text(items[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? Colors.white : const Color(0xFFC1C6CF), fontWeight: active ? FontWeight.w800 : FontWeight.w600, fontSize: 13)))],
                ]),
              ),
            ),
          );
        })),
        Padding(
          padding: const EdgeInsets.only(bottom: 18, top: 10),
          child: extended
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF101319), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
                  child: Row(children: [
                    const CircleAvatar(radius: 17, backgroundColor: Color(0xFF14365C), child: Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((AppScope.of(context).data?.business.businessName.trim().isNotEmpty ?? false) ? AppScope.of(context).data!.business.businessName : (AppScope.of(context).data?.business.businessTypeLabel ?? 'Business'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                      Text(AppScope.of(context).data?.business.activeRole == 'Worker' ? 'Worker mode' : 'Owner mode', style: const TextStyle(color: AppTheme.muted, fontSize: 10.5)),
                    ])),
                    const Icon(Icons.unfold_more_rounded, size: 16, color: AppTheme.muted),
                  ]),
                )
              : const CircleAvatar(radius: 19, backgroundColor: Color(0xFF14365C), child: Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 18)),
        ),
      ]),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start, children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x55246BFE), blurRadius: 18)]), child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 23)),
      if (!compact) ...[
        const SizedBox(width: 11),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PROFIT GPS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.4)), Text('BUSINESS MADE SIMPLE', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 8.8, letterSpacing: 1.0))]),
      ],
    ]);
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFF0F2B2A), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF245746))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, color: AppTheme.green, size: 7), SizedBox(width: 5), Text('LIVE', style: TextStyle(color: AppTheme.green, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8))]),
      );
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: SizedBox(height: 62, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 38, height: 28, decoration: BoxDecoration(color: selected ? AppTheme.primary.withValues(alpha: .18) : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Icon(icon, size: 20, color: selected ? AppTheme.primary : const Color(0xFFAFC0D1))),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFFAFC0D1), fontSize: 9.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
  ])));
}
