import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import 'product_onboarding_screen.dart';

class BackupImportScreen extends StatefulWidget {
  const BackupImportScreen({super.key});
  @override
  State<BackupImportScreen> createState() => _BackupImportScreenState();
}

class _BackupImportScreenState extends State<BackupImportScreen> {
  bool busy = false;

  Future<File> _buildBackup() async {
    final data = AppScope.of(context).data!;
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}${Platform.pathSeparator}ProfitGPS_Backup_$stamp.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'format': 'ProfitGPS Backup',
      'formatVersion': 1,
      'createdAt': now.toIso8601String(),
      'data': data.toJson(),
    }), flush: true);
    return file;
  }

  Future<void> _shareBackup({required bool drive}) async {
    setState(() => busy = true);
    try {
      final file = await _buildBackup();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        text: drive
            ? 'ProfitGPS backup. Choose Google Drive in the Android share sheet to save it to Drive.'
            : 'ProfitGPS backup. Save this file to your preferred secure location.',
        subject: 'ProfitGPS Backup',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.single;
    String raw;
    if (f.bytes != null) {
      raw = utf8.decode(f.bytes!);
    } else if (f.path != null) {
      raw = await File(f.path!).readAsString();
    } else {
      return;
    }

    Map<String, dynamic> decoded;
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is not a valid ProfitGPS backup file.')));
      return;
    }
    final dataMap = decoded['data'] is Map ? Map<String, dynamic>.from(decoded['data'] as Map) : decoded;
    AppData restored;
    try {
      restored = AppData.fromJson(dataMap);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup data could not be read safely. No data was changed.')));
      return;
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restore this backup?'),
            content: const Text('ProfitGPS will replace the current local working database with the selected backup. The backup itself remains unchanged. Export the current data first if you may need it later.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore backup')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final app = AppScope.of(context);
    app.data = restored;
    await app.persist();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored successfully.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        const Text('Backup & Import', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.ink)),
        const SizedBox(height: 4),
        const Text('Keep business data safe and bring new/existing product data into ProfitGPS without bypassing review.', style: TextStyle(color: AppTheme.lightMuted, fontSize: 12)),
        const SizedBox(height: 16),
        _card(
          icon: Icons.add_to_drive_outlined,
          title: 'Google Drive backup',
          subtitle: 'Creates a complete ProfitGPS JSON backup and opens Android sharing. Choose Google Drive to store it in your Drive.',
          child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : () => _shareBackup(drive: true), icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Backup to Google Drive'))),
        ),
        const SizedBox(height: 10),
        _card(
          icon: Icons.restore_rounded,
          title: 'Restore / import backup',
          subtitle: 'Pick a ProfitGPS backup from Google Drive, Files or another Android storage provider. Restore is confirmed before replacing local data.',
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy ? null : _restore, icon: const Icon(Icons.cloud_download_outlined), label: const Text('Import / Restore Backup'))),
        ),
        const SizedBox(height: 10),
        _card(
          icon: Icons.save_alt_rounded,
          title: 'Export backup',
          subtitle: 'Share or save a complete local backup to Files, email, another drive provider or secure storage.',
          child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: busy ? null : () => _shareBackup(drive: false), icon: const Icon(Icons.ios_share_rounded), label: const Text('Export Backup File'))),
        ),
        const SizedBox(height: 16),
        _card(
          icon: Icons.move_to_inbox_outlined,
          title: 'Product / order / existing-data import',
          subtitle: 'Excel/CSV, purchase invoice, PO/order, supplier catalogue, barcode/QR, manual/local products and existing software migration go through matching and Needs Review before stock is posted.',
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductOnboardingScreen())),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Open Import & Onboarding'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFC9DBFF))),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, color: AppTheme.primary),
            SizedBox(width: 9),
            Expanded(child: Text('Safety: import/onboarding data does not silently overwrite finalized invoices, quotations or historical purchase records. Product matching and review happen before new stock is committed.', style: TextStyle(color: AppTheme.ink, fontSize: 11.5, height: 1.35))),
          ]),
        ),
      ],
    );
  }

  Widget _card({required IconData icon, required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.lightCardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: AppTheme.primary)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900, fontSize: 16))),
        ]),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(color: AppTheme.lightMuted, fontSize: 11.5, height: 1.35)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
