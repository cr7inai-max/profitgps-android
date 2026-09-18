from pathlib import Path
import re

# v0.11 mobile visual parity pass: keep the Windows business logic, but use the
# approved light ProfitGPS workspace on phones and simplify the billing flow.
p = Path('lib/screens/billing_screen.dart')
s = p.read_text()
s = s.replace("""    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          OutlinedButton.icon(onPressed: widget.onExit ?? _clearCart, icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back')),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Billing', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), Text('Search, scan or add items, then complete payment.', style: TextStyle(color: AppTheme.muted, fontSize: 12))])),
          if (cart.isNotEmpty) TextButton.icon(onPressed: () { _confirmClearCart(); }, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Clear bill')),
        ]),""", """    final isPhone = MediaQuery.sizeOf(context).width < 760;
    return Padding(
      padding: EdgeInsets.fromLTRB(isPhone ? 12 : 16, isPhone ? 12 : 16, isPhone ? 12 : 16, 12),
      child: Column(children: [
        Row(children: [
          if (!isPhone) ...[
            OutlinedButton.icon(onPressed: widget.onExit ?? _clearCart, icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back')),
            const SizedBox(width: 12),
          ],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isPhone ? 'New Bill' : 'Billing', style: const TextStyle(color: AppTheme.ink, fontSize: 22, fontWeight: FontWeight.w900)), const Text('Search, scan or add items, then complete payment.', style: TextStyle(color: AppTheme.muted, fontSize: 11.5))])),
          if (cart.isNotEmpty) TextButton.icon(onPressed: () { _confirmClearCart(); }, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Clear')),
        ]),""", 1)
s = s.replace("""        return DefaultTabController(length: 2, child: Column(children: [
          Container(decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)), child: const TabBar(tabs: [Tab(icon: Icon(Icons.storefront_rounded), text: 'Products'), Tab(icon: Icon(Icons.shopping_cart_rounded), text: 'Current Bill')])),
          const SizedBox(height: 10),
          Expanded(child: TabBarView(children: [catalog, bill])),
        ]));""", """        return lines.isEmpty ? catalog : bill;""", 1)
s = s.replace("""class _CatalogState extends State<_Catalog> {
  final ScrollController _categoryController = ScrollController();
  final ScrollController _gridController = ScrollController();""", """class _CatalogState extends State<_Catalog> {
  final ScrollController _categoryController = ScrollController();
  final ScrollController _gridController = ScrollController();
  bool _showList = false;""", 1)
s = s.replace('onChanged: (_) => widget.onSearch(),', 'onChanged: (_) { setState(() => _showList = true); widget.onSearch(); },', 1)
s = s.replace('onSelected: (_) => widget.onCategory(e),', 'onSelected: (_) { setState(() => _showList = true); widget.onCategory(e); },', 1)
needle = """            Expanded(
              child: Scrollbar(
                controller: _gridController,
                thumbVisibility: true,
                child: GridView.builder("""
replacement = """            Expanded(
              child: (c.maxWidth < 590 && !_showList && widget.search.text.trim().isEmpty && widget.selectedCategory == 'All')
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.lightCardDecoration(radius: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 58, color: Color(0xFF9FB5CC)),
                          const SizedBox(height: 10),
                          const Text('Ready to Start Billing', style: TextStyle(color: AppTheme.ink, fontSize: 19, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          const Text('Scan a barcode, search for a product or select from the product list.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted, fontSize: 11.5)),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: FilledButton.icon(onPressed: widget.onLookup, icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan Barcode'))),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _showList = true), icon: const Icon(Icons.search_rounded), label: const Text('Search / List'))),
                          ]),
                          const SizedBox(height: 8),
                          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: widget.onManualLine, icon: const Icon(Icons.grid_view_rounded), label: const Text('Quick Item / PLU / Manual'))),
                        ],
                      ),
                    )
                  : Scrollbar(
                controller: _gridController,
                thumbVisibility: true,
                child: GridView.builder("""
if needle in s:
    s = s.replace(needle, replacement, 1)

for old, new in {
    'const Color(0xFF17212D)': 'AppTheme.surface2',
    'const Color(0xFF344253)': 'AppTheme.border',
    'const Color(0xFF0D1117)': 'AppTheme.surface',
    'const Color(0xFF0F151E)': 'AppTheme.surface',
    'const Color(0xFF10151D)': 'AppTheme.surface2',
    'const Color(0xFF121A25)': 'AppTheme.surface2',
    'const Color(0xFF141C27)': 'AppTheme.surface2',
    'const Color(0xFF263241)': 'AppTheme.border',
    'const Color(0xFF111720)': 'AppTheme.surface2',
    'const Color(0xFF10151C)': 'AppTheme.surface2',
    'const Color(0xFF101721)': 'AppTheme.surface2',
    'const Color(0xFF151A22)': 'AppTheme.surface2',
}.items():
    s = s.replace(old, new)
s = s.replace('colors: [Color(0xFF121722), Color(0xFF0B1017)],', 'colors: [AppTheme.surface, AppTheme.surface2],')
s = s.replace('backgroundColor: Color(0xFF22304A)', 'backgroundColor: AppTheme.primarySoft')
s = s.replace('color: strong ? Colors.white : AppTheme.muted,', 'color: strong ? AppTheme.ink : AppTheme.muted,', 1)
s = s.replace('color: strong ? Colors.white : null,', 'color: strong ? AppTheme.ink : null,', 1)
s = s.replace('widget.quotationMode ? AppTheme.purple : AppTheme.red,', 'widget.quotationMode ? AppTheme.purple : AppTheme.primary,', 1)
s = s.replace("? const Color(0xFF2A1115)\n                              : const Color(0xFF0E2A20)", "? const Color(0xFFFFEEF0)\n                              : const Color(0xFFEAF8F2)")
s = s.replace("""                const SizedBox(height: 9),
                _denominationGrid(counts, returnMode: false),
                const SizedBox(height: 9),""", """                const SizedBox(height: 9),
                if (MediaQuery.sizeOf(context).width >= 700)
                  _denominationGrid(counts, returnMode: false)
                else
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Cash details / denominations', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Open only when you want note/coin counting.', style: TextStyle(fontSize: 11, color: AppTheme.muted)),
                    children: [_denominationGrid(counts, returnMode: false)],
                  ),
                const SizedBox(height: 9),""", 1)
s = s.replace("""                  'Credit / Pay Later',
                  'Split'""", """                  'Credit / Pay Later',
                  'Split',
                  'Bank Transfer'""", 1)
s = s.replace("""    if (method == 'UPI' || method == 'Debit/Credit Card') {
      if (payFull) return widget.total;
      return double.tryParse(method == 'UPI' ? upi.text : card.text) ?? 0;
    }""", """    if (method == 'UPI' || method == 'Debit/Credit Card' || method == 'Bank Transfer') {
      if (payFull) return widget.total;
      return double.tryParse(method == 'UPI' ? upi.text : card.text) ?? 0;
    }""", 1)
marker = """              if (method == 'Split') ...["""
insert = """              if (method == 'Bank Transfer') ...[
                const Divider(),
                const Text('Bank transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                TextField(controller: card, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount received', prefixIcon: Icon(Icons.account_balance_rounded))),
                const SizedBox(height: 8),
                TextField(controller: paymentReference, decoration: const InputDecoration(labelText: 'Bank reference / UTR', hintText: 'Recommended')),
              ],
              if (method == 'Split') ...["""
if marker in s:
    s = s.replace(marker, insert, 1)
p.write_text(s)

# Lighten old neutral dark cards in the remaining mobile screens without
# changing semantic blue/navy/green/red brand colors.
neutral_map = {
    'Color(0xFF10151C)': 'AppTheme.surface2',
    'Color(0xFF111820)': 'AppTheme.surface2',
    'Color(0xFF242A33)': 'AppTheme.border',
    'Color(0xFF111720)': 'AppTheme.surface2',
    'Color(0xFF11161D)': 'AppTheme.surface2',
    'Color(0xFF101720)': 'AppTheme.surface2',
    'Color(0xFF151A21)': 'AppTheme.surface2',
    'Color(0xFF111318)': 'AppTheme.surface2',
    'Color(0xFF0E1115)': 'AppTheme.surface2',
    'Color(0xFF2A2E36)': 'AppTheme.border',
    'Color(0xFF0B0E12)': 'AppTheme.surface',
    'Color(0xFF191D24)': 'AppTheme.surface2',
    'Color(0xFF171A20)': 'AppTheme.surface2',
    'Color(0xFF0C0F13)': 'AppTheme.surface',
    'Color(0xFF14212B)': 'AppTheme.surface2',
    'Color(0xFF161C24)': 'AppTheme.surface2',
    'Color(0xFF151A20)': 'AppTheme.surface2',
    'Color(0xFF111923)': 'AppTheme.surface2',
    'Color(0xFF0F171F)': 'AppTheme.surface2',
    'Color(0xFF0E151D)': 'AppTheme.surface2',
    'Color(0xFF0D171E)': 'AppTheme.surface2',
    'Color(0xFF171D26)': 'AppTheme.surface2',
}
for screen in Path('lib/screens').glob('*.dart'):
    if screen.name in {'app_shell.dart', 'mobile_home_screen.dart'}:
        continue
    text = screen.read_text()
    for old, new in neutral_map.items():
        text = text.replace(old, new)
    screen.write_text(text)

# v0.11 is the first screenshot-first mobile parity pass.
p = Path('pubspec.yaml')
s = p.read_text()
s = re.sub(r'^version:\s*[^\n]+', 'version: 0.11.0+11', s, flags=re.M)
p.write_text(s)

# Mobile shell: keep the approved navy framing, but use the Windows-like light
# workspace and place corrections/backup behind More instead of adding clutter.
p = Path('lib/screens/app_shell.dart')
s = p.read_text()
if "import 'corrections_screen.dart';" not in s:
    s = s.replace("import 'cash_close_screen.dart';", "import 'cash_close_screen.dart';\nimport 'corrections_screen.dart';\nimport 'backup_import_screen.dart';")
s = s.replace("      ('Records', Icons.receipt_long_rounded, const RecordsScreen()),\n      ('Feedback', Icons.forum_rounded, const FeedbackScreen()),", "      ('Records', Icons.receipt_long_rounded, const RecordsScreen()),\n      if (owner) ('Edit / Correct', Icons.edit_note_rounded, const CorrectionsScreen()),\n      if (owner) ('Backup & Import', Icons.cloud_sync_outlined, const BackupImportScreen()),\n      ('Feedback', Icons.forum_rounded, const FeedbackScreen()),")
s = s.replace("'Records, cash close, reports, employees, settings and advanced tools.'", "'Records, corrections, backup/import, cash close, reports and settings.'")
s = s.replace("? _screenBody(mobileChild, light: items[index].$1 == 'Command Center')", "? _screenBody(mobileChild, light: true)")
s = s.replace("actions: const [Padding(padding: EdgeInsets.only(right: 12), child: _LiveBadge())],", "actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded, color: Colors.white)), const Padding(padding: EdgeInsets.only(right: 12), child: CircleAvatar(radius: 17, backgroundColor: AppTheme.primary, child: Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))],")
old_brand = """      Container(width: 38, height: 38, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x55246BFE), blurRadius: 18)]), child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 23)),
      if (!compact) ...[
        const SizedBox(width: 11),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('PROFIT GPS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.4)), Text('BUSINESS MADE SIMPLE', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 8.8, letterSpacing: 1.0))]),
      ],"""
new_brand = """      Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF0A3155), borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xFF365675))), child: Stack(alignment: Alignment.center, children: [const Icon(Icons.circle_outlined, color: AppTheme.gold, size: 25), Transform.rotate(angle: .55, child: Container(width: 15, height: 6, decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(6)))), const Text('P', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))])),
      if (!compact) ...[
        const SizedBox(width: 9),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ProfitGPS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: .1)), Text('Business Made Simple', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 8.5, letterSpacing: .25))]),
      ],"""
if old_brand in s:
    s = s.replace(old_brand, new_brand, 1)
p.write_text(s)

# Product onboarding gets a dedicated PO/order upload option in addition to
# purchase invoice, Excel/CSV, catalogue/migration, barcode and manual/local.
p = Path('lib/screens/product_onboarding_screen.dart')
s = p.read_text()
po_anchor = "                    _Method(icon: Icons.description_outlined, title: 'Purchase Invoice', subtitle: 'Stage invoice; verify before stock posting', onTap: () => _stageFile('Purchase Invoice Import', ['pdf', 'csv', 'xlsx', 'xls'])),\n"
if po_anchor in s and "title: 'PO / Order'" not in s:
    s = s.replace(po_anchor, po_anchor + "                    _Method(icon: Icons.assignment_outlined, title: 'PO / Order', subtitle: 'Purchase order or supplier order import', onTap: () => _stageFile('Purchase Order / Order Import', ['pdf', 'csv', 'xlsx', 'xls', 'json'])),\n", 1)
p.write_text(s)
