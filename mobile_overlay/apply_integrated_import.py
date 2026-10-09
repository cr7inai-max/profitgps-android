from pathlib import Path

def modify(path, changes):
    p = Path(path)
    text = p.read_text()
    for old, new in changes:
        if old not in text:
            raise RuntimeError(f"Required source anchor missing in {path}: {old[:110]}")
        text = text.replace(old, new, 1)
    p.write_text(text)

# Keep imported rows in the same encrypted-device-local business JSON lifecycle,
# but outside data.products until explicit approval. Backups use AppData.toJson().
modify('lib/models/entities.dart', [
    ("    List<SupplierLedgerEntry>? supplierLedger,\n    BusinessProfile? business,",
     "    List<SupplierLedgerEntry>? supplierLedger,\n    List<Map<String, dynamic>>? pendingInventory,\n    BusinessProfile? business,"),
    ("        supplierLedger = supplierLedger ?? [],\n        business = business ?? BusinessProfile();",
     "        supplierLedger = supplierLedger ?? [],\n        pendingInventory = pendingInventory ?? <Map<String, dynamic>>[],\n        business = business ?? BusinessProfile();"),
    ("  List<SupplierLedgerEntry> supplierLedger;\n  BusinessProfile business;",
     "  List<SupplierLedgerEntry> supplierLedger;\n  List<Map<String, dynamic>> pendingInventory;\n  BusinessProfile business;"),
    ("    'supplierLedger': supplierLedger.map((e) => e.toJson()).toList(),",
     "    'supplierLedger': supplierLedger.map((e) => e.toJson()).toList(),\n    'pendingInventory': pendingInventory,"),
    ("    supplierLedger: (j['supplierLedger'] as List? ?? []).map((e) => SupplierLedgerEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),",
     "    supplierLedger: (j['supplierLedger'] as List? ?? []).map((e) => SupplierLedgerEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),\n    pendingInventory: (j['pendingInventory'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),"),
])

p = Path('lib/screens/app_shell.dart')
s = p.read_text()
if "import 'inventory_import_screen.dart';" not in s:
    s = "import 'inventory_import_screen.dart';\n" + s
if "import 'security_settings_screen.dart';" not in s:
    s = "import 'security_settings_screen.dart';\n" + s
needle = "      ('Products', Icons.inventory_2_rounded, const ProductsScreen()),"
if needle not in s:
    raise RuntimeError('AppShell products entry not found')
s = s.replace(needle, needle + "\n      if (owner) ('Inventory Import', Icons.upload_file_rounded, const InventoryImportScreen()),", 1)
s = s.replace(needle, needle + "\n      if (owner) ('Access Security', Icons.security_rounded, const SecuritySettingsScreen()),", 1)

# Keep the substantial Windows billing engine: no simplified MobileBillingScreen
# with forced full-payment calculations. The existing billing screen has an
# adapted phone layout; purchases and records still use their original engines.
s = s.replace("""        : items[index].$1 == 'Billing'
            ? const MobileBillingScreen()
            : items[index].$3;""", """        : items[index].$3;""")
p.write_text(s)

p = Path('pubspec.yaml')
s = p.read_text()
if '  excel:' not in s:
    s = s.replace('  file_picker:', '  excel: ^4.0.6\n  file_picker:', 1)
if '  flutter_secure_storage:' not in s:
    s = s.replace('  file_picker:', '  flutter_secure_storage: ^9.2.4\n  file_picker:', 1)
if "version: 0.11.0+11" in s:
    s = s.replace("version: 0.11.0+11", "version: 0.13.0+13")
p.write_text(s)
print('Applied integrated import, staging, backup persistence and original billing engine.')
