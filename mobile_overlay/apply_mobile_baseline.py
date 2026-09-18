from pathlib import Path
import shutil
import re

root = Path('.')
overlay = root / 'mobile_overlay' / 'lib'
for src in overlay.rglob('*.dart'):
    rel = src.relative_to(overlay)
    dst = root / 'lib' / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)

for filename in [
    'lib/screens/mobile_home_screen.dart',
    'lib/screens/product_onboarding_screen.dart',
]:
    p = Path(filename)
    s = p.read_text().replace('])))));', ']))));')
    p.write_text(s)

p = Path('lib/widgets/common.dart')
s = p.read_text()
s = s.replace('this.accent = AppTheme.red,', 'this.accent = AppTheme.primary,')
s = s.replace('this.color = AppTheme.red,', 'this.color = AppTheme.primary,')
p.write_text(s)

p = Path('lib/screens/products_screen.dart')
s = p.read_text()
if "import 'product_onboarding_screen.dart';" not in s:
    s = s.replace("import '../widgets/common.dart';", "import '../widgets/common.dart';\nimport 'product_onboarding_screen.dart';")
old = """        SectionTitle(\n          'Products & Inventory',\n          subtitle:\n              '${data.business.businessTypeLabel} profile • Product Master and live inventory. First-time products are created from Purchases → New Purchase; later purchases update the same stock item.',\n        ),"""
new = """        SectionTitle(\n          'Products & Inventory',\n          subtitle:\n              '${data.business.businessTypeLabel} profile • Product Master stays separate from changing purchase, price and stock records.',\n          trailing: FilledButton.icon(\n            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductOnboardingScreen())),\n            icon: const Icon(Icons.add_rounded),\n            label: const Text('Onboard Product'),\n          ),\n        ),"""
if old in s:
    s = s.replace(old, new, 1)
p.write_text(s)

p = Path('lib/screens/purchase_screen.dart')
s = p.read_text()
needle = "  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;\n"
if '_newInternalSku()' not in s and needle in s:
    insert = """  double _d(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;\n\n  String _newInternalSku() {\n    final stamp = DateTime.now().millisecondsSinceEpoch.toString();\n    return 'PG-${stamp.substring(stamp.length - 8)}';\n  }\n\n  String _newInternalEan13() {\n    final stamp = DateTime.now().microsecondsSinceEpoch.toString().padLeft(12, '0');\n    final base = stamp.substring(stamp.length - 12);\n    var sum = 0;\n    for (var i = 0; i < 12; i++) {\n      final digit = int.parse(base[i]);\n      sum += i.isEven ? digit : digit * 3;\n    }\n    final check = (10 - (sum % 10)) % 10;\n    return '$base$check';\n  }\n"""
    s = s.replace(needle, insert, 1)
old = """                              suffixIcon: IconButton(\n                                tooltip: 'Scan barcode',\n                                onPressed: () async {"""
if old in s and 'Generate internal barcode' not in s:
    new = """                              suffixIcon: Row(\n                                mainAxisSize: MainAxisSize.min,\n                                children: [\n                                  IconButton(\n                                    tooltip: 'Generate internal barcode',\n                                    onPressed: () => update(() {\n                                      barcode.text = _newInternalEan13();\n                                      barcodeStatus = 'Internal EAN-13 barcode generated for this shop-defined product.';\n                                    }),\n                                    icon: const Icon(Icons.auto_awesome_rounded),\n                                  ),\n                                  IconButton(\n                                tooltip: 'Scan barcode',\n                                onPressed: () async {"""
    s = s.replace(old, new, 1)
    end_old = """                                },\n                                icon: const Icon(Icons.qr_code_scanner_rounded),\n                              ),\n                            ),"""
    end_new = """                                },\n                                icon: const Icon(Icons.qr_code_scanner_rounded),\n                                  ),\n                                ],\n                              ),\n                            ),"""
    s = s.replace(end_old, end_new, 1)
old_sku = "decoration: const InputDecoration(labelText: 'Internal SKU / code'),"
if old_sku in s:
    s = s.replace(old_sku, "decoration: InputDecoration(labelText: 'Internal SKU / code', suffixIcon: IconButton(tooltip: 'Generate internal SKU', onPressed: () => update(() => sku.text = _newInternalSku()), icon: const Icon(Icons.auto_awesome_rounded))),", 1)
p.write_text(s)

p = Path('lib/screens/product_onboarding_screen.dart')
s = p.read_text()
po_anchor = "_Method(icon: Icons.description_outlined, title: 'Purchase Invoice', subtitle: 'Stage invoice; verify before stock posting', onTap: () => _stageFile('Purchase Invoice Import', ['pdf', 'csv', 'xlsx', 'xls'])),"
if po_anchor in s and "Purchase Order / PO" not in s:
    s = s.replace(po_anchor, po_anchor + "\n                  _Method(icon: Icons.assignment_outlined, title: 'Purchase Order / PO', subtitle: 'Stage supplier order for matching and review', onTap: () => _stageFile('Purchase Order / PO Import', ['pdf', 'csv', 'xlsx', 'xls'])),")
p.write_text(s)

p = Path('lib/screens/app_shell.dart')
s = p.read_text()
if "import 'mobile_billing_screen.dart';" not in s:
    s = s.replace("import 'mobile_home_screen.dart';", "import 'mobile_home_screen.dart';\nimport 'mobile_billing_screen.dart';\nimport 'corrections_screen.dart';\nimport 'backup_import_screen.dart';")
if "('Corrections'," not in s:
    s = s.replace("      ('Feedback', Icons.forum_rounded, const FeedbackScreen()),", "      ('Feedback', Icons.forum_rounded, const FeedbackScreen()),\n      if (owner) ('Corrections', Icons.edit_note_rounded, const CorrectionsScreen()),\n      if (owner) ('Backup & Import', Icons.cloud_sync_outlined, const BackupImportScreen()),")
old_mobile_child = """    final mobileChild = items[index].$1 == 'Command Center'
        ? MobileHomeScreen(
            onBilling: () => setState(() => index = findItem('Billing')),
            onPurchase: () => setState(() => index = findItem('Purchases')),
            onProducts: () => setState(() => index = findItem('Products')),
            onRecords: () => setState(() => index = findItem('Records')),
          )
        : items[index].$3;"""
new_mobile_child = """    final mobileChild = items[index].$1 == 'Command Center'
        ? MobileHomeScreen(
            onBilling: () => setState(() => index = findItem('Billing')),
            onPurchase: () => setState(() => index = findItem('Purchases')),
            onProducts: () => setState(() => index = findItem('Products')),
            onRecords: () => setState(() => index = findItem('Records')),
          )
        : items[index].$1 == 'Billing'
            ? const MobileBillingScreen()
            : items[index].$3;"""
if old_mobile_child in s:
    s = s.replace(old_mobile_child, new_mobile_child, 1)
s = s.replace("? _screenBody(mobileChild, light: items[index].$1 == 'Command Center')", "? _screenBody(mobileChild, light: true)")
p.write_text(s)

# Compatibility patch for Customer model field name.
p = Path('lib/screens/mobile_billing_screen.dart')
s = p.read_text().replace('customer!.mobile', 'customer!.phone').replace('c.mobile', 'c.phone')
p.write_text(s)

for filename in ['lib/screens/dashboard_screen.dart', 'lib/screens/login_screen.dart', 'lib/screens/reports_screen.dart']:
    p = Path(filename)
    s = p.read_text().replace('AppTheme.red', 'AppTheme.primary')
    if filename.endswith('login_screen.dart'):
        s = s.replace('Color(0xFF351318)', 'Color(0xFF123D6B)')
    p.write_text(s)

p = Path('pubspec.yaml')
s = p.read_text()
s = re.sub(r'^version:\s*[^\n]+', 'version: 0.11.0+11', s, flags=re.M)
p.write_text(s)
