import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/entities.dart';
import 'seed_data.dart';

class LocalRepository {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}profitgps_app_state.json');
  }

  Future<AppData> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return makeSeedData();
      final raw = await file.readAsString();
      final data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      if (data.dataVersion < 16) {
        await _backupPreUpgrade16(file, raw);
      }
      final changed = _migrateForUpgrade16(data);
      if (changed) await save(data);
      return data;
    } catch (_) {
      // Never recreate the old sample/demo database after an error.
      return makeSeedData();
    }
  }

  Future<void> _backupPreUpgrade16(File source, String raw) async {
    try {
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final backup = File(
        '${source.parent.path}${Platform.pathSeparator}profitgps_pre_upgrade16_data_backup_$stamp.json',
      );
      if (!await backup.exists()) {
        await backup.writeAsString(raw, flush: true);
      }
    } catch (_) {
      // Source-code upgrade still has its own rollback. A failed optional data
      // backup must not prevent the app from opening.
    }
  }

  bool _migrateForUpgrade16(AppData data) {
    if (data.dataVersion >= 16) return false;

    // Upgrade 16 is the explicit clean-start release requested during
    // development. All prototype/test operational records are cleared once.
    // Business configuration (GST profile, UPI/scanner/API setup and roles) is
    // kept so the user does not need to reconfigure the app.
    data.products.clear();
    data.customers.clear();
    data.employees.clear();
    data.branches.clear();
    data.sales.clear();
    data.feedback.clear();
    data.ledger.clear();
    data.quotations.clear();
    data.suppliers.clear();
    data.cashClosings.clear();
    data.purchases.clear();
    data.purchaseReturns.clear();
    data.supplierLedger.clear();

    if (data.business.businessName.trim() == 'ProfitGPS Demo Store') {
      data.business.businessName = '';
    }
    if (data.business.businessType.trim().isEmpty) {
      data.business.businessType = 'General Retail';
    }

    data.dataVersion = 16;
    return true;
  }

  Future<void> save(AppData data) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(data.toJson()), flush: true);
  }

  Future<String> exportToFile(AppData data) async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(
      '${dir.path}${Platform.pathSeparator}profitgps_backup_$stamp.json',
    );
    await file.writeAsString(data.prettyJson(), flush: true);
    return file.path;
  }
}
