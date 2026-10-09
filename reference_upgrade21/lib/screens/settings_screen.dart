import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_scope.dart';
import '../core/theme.dart';
import '../services/barcode_scanner_service.dart';
import '../services/business_type_rules.dart';
import '../services/document_rules.dart';
import '../services/gst_lookup_service.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _pickUpiQr() async {
    final app = AppScope.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final dir = await getApplicationSupportDirectory();
    final ext = (picked.extension ?? 'png').toLowerCase();
    final destination = File(
      '${dir.path}${Platform.pathSeparator}profitgps_upi_qr.$ext',
    );

    if (picked.bytes != null) {
      await destination.writeAsBytes(picked.bytes!, flush: true);
    } else if (picked.path != null) {
      await File(picked.path!).copy(destination.path);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected QR image.')),
      );
      return;
    }

    app.data!.business.upiQrPath = destination.path;
    await app.persist();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UPI QR image saved.')),
    );
  }

  Future<void> _removeUpiQr() async {
    final app = AppScope.of(context);
    final b = app.data!.business;
    if (b.upiQrPath.isEmpty) return;
    final ok = await confirmAction(
      context,
      title: 'Remove UPI QR?',
      message: 'The saved QR image will no longer appear during UPI billing.',
      confirmLabel: 'Remove QR',
      icon: Icons.delete_outline_rounded,
      confirmColor: AppTheme.red,
    );
    if (!ok) return;
    final file = File(b.upiQrPath);
    if (await file.exists()) {
      await file.delete();
    }
    b.upiQrPath = '';
    await app.persist();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final b = app.data!.business;
    final qrFile = b.upiQrPath.isEmpty ? null : File(b.upiQrPath);
    final hasQr = qrFile != null && qrFile.existsSync();

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SectionTitle(
          'Settings',
          subtitle:
              'Business identity, GST profile, UPI payment setup and role controls.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Business profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _field('Business / legal name', b.businessName,
                    (v) => b.businessName = v),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: BusinessTypeRules.canonicalType(b.businessType),
                  isExpanded: true,
                  items: BusinessTypeRules.supportedTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: b.activeRole == 'Owner'
                      ? (value) => setState(() {
                            b.businessType = value ?? 'General Retail';
                            if (b.businessType == 'General Retail' && b.enabledRetailModules.isEmpty) {
                              b.enabledRetailModules = List<String>.from(BusinessTypeRules.generalRetailModules);
                            }
                          })
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Business type',
                    prefixIcon: Icon(Icons.storefront_rounded),
                  ),
                ),
                if (BusinessTypeRules.canonicalType(b.businessType) == 'General Retail') ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F171F),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('General Retail departments', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        const Text(
                          'Enable only the departments used by this shop. A supermarket can enable Grocery + Fruits & Vegetables + Dairy + Bakery together.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: BusinessTypeRules.generalRetailModules.map((module) {
                            final selected = b.enabledRetailModules.contains(module);
                            return FilterChip(
                              label: Text(module),
                              selected: selected,
                              onSelected: b.activeRole == 'Owner'
                                  ? (value) => setState(() {
                                        if (module == 'General') return;
                                        if (value) {
                                          if (!b.enabledRetailModules.contains(module)) b.enabledRetailModules.add(module);
                                        } else {
                                          b.enabledRetailModules.remove(module);
                                        }
                                        if (!b.enabledRetailModules.contains('General')) b.enabledRetailModules.add('General');
                                      })
                                  : null,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
                if (b.businessType == 'Other / Custom') ...[
                  const SizedBox(height: 8),
                  _field(
                    'Custom business type',
                    b.customBusinessType,
                    (v) => b.customBusinessType = v,
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111923),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BusinessTypeRules.canonicalType(b.businessType) == 'General Retail'
                            ? 'General Retail • ${b.enabledRetailModules.where((e) => e != 'General').join(' + ')}'
                            : b.businessTypeLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        BusinessTypeRules.description(b.businessType),
                        style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Product forms adapt automatically. Existing products and transactions are never rewritten when business type changes.',
                        style: TextStyle(color: AppTheme.cyan.withValues(alpha: .9), fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: b.gstRegistrationType,
                  items: const [
                    DropdownMenuItem(value: 'Regular GST', child: Text('Regular GST')),
                    DropdownMenuItem(value: 'Composition Scheme', child: Text('Composition Scheme')),
                    DropdownMenuItem(value: 'Not Registered', child: Text('Not GST Registered')),
                  ],
                  onChanged: b.activeRole == 'Owner'
                      ? (value) => setState(() {
                            b.gstRegistrationType = value ?? 'Not Registered';
                          })
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'GST registration status',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111923),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    DocumentRules.taxTreatmentLabel(b),
                    style: const TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700),
                  ),
                ),
                if (b.isGstRegistered) ...[
                  const SizedBox(height: 8),
                  _field('GSTIN', b.gstin, (v) => b.gstin = v),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E151D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GSTIN online lookup',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Saved GSTINs are always fetched locally. For a new GSTIN, ProfitGPS can fetch the registered name/address from a configured verification API.',
                        style: TextStyle(color: AppTheme.muted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: b.gstOnlineLookupEnabled,
                        onChanged: b.activeRole == 'Owner'
                            ? (value) => setState(() => b.gstOnlineLookupEnabled = value)
                            : null,
                        title: const Text('Automatically fetch new GSTIN details'),
                        subtitle: const Text('If lookup is unavailable, manual entry remains available.'),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: b.gstLookupProvider == 'GSTINAPI' ? 'GSTINAPI' : 'GSTVerify',
                        items: const [
                          DropdownMenuItem(value: 'GSTVerify', child: Text('GSTVerify API')),
                          DropdownMenuItem(value: 'GSTINAPI', child: Text('GSTINAPI')),
                        ],
                        onChanged: b.activeRole == 'Owner'
                            ? (value) => setState(() => b.gstLookupProvider = value ?? 'GSTVerify')
                            : null,
                        decoration: const InputDecoration(labelText: 'GST lookup provider'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: b.gstLookupApiKey,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        enabled: b.activeRole == 'Owner',
                        onChanged: (value) => b.gstLookupApiKey = value.trim(),
                        decoration: const InputDecoration(
                          labelText: 'GST lookup API key',
                          prefixIcon: Icon(Icons.key_rounded),
                          helperText: 'Stored locally in this ProfitGPS profile. Do not share this key.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: b.gstin.trim().isEmpty || b.gstLookupApiKey.trim().isEmpty
                              ? null
                              : () async {
                                  final result = await GstLookupService.lookup(b, b.gstin);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result.success
                                            ? 'GST lookup OK: ${result.displayName} • ${result.status.isEmpty ? 'status not returned' : result.status}'
                                            : result.error,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.travel_explore_rounded),
                          label: const Text('Test live lookup'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<bool>(
                  value: b.defaultSaleTaxInclusive,
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Inclusive — selling price already includes GST')),
                    DropdownMenuItem(value: false, child: Text('Exclusive — GST is added to selling price')),
                  ],
                  onChanged: (value) => setState(() => b.defaultSaleTaxInclusive = value ?? true),
                  decoration: const InputDecoration(labelText: 'Default sale tax pricing'),
                ),
                const SizedBox(height: 8),
                _field('Business address', b.address, (v) => b.address = v),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _field('State', b.state, (v) => b.state = v),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _field(
                        'State code',
                        b.stateCode,
                        (v) => b.stateCode = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _field('Phone', b.phone, (v) => b.phone = v),
                const SizedBox(height: 12),
                const Text('Document numbering', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: b.financialYearStartMonth.clamp(1, 12).toInt(),
                  items: List.generate(12, (index) {
                    const names = ['January','February','March','April','May','June','July','August','September','October','November','December'];
                    return DropdownMenuItem(value: index + 1, child: Text(names[index]));
                  }),
                  onChanged: (value) => setState(() => b.financialYearStartMonth = value ?? 4),
                  decoration: const InputDecoration(labelText: 'Financial year starts in'),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(width: 180, child: _field('Tax invoice prefix', b.invoicePrefix, (v) => b.invoicePrefix = v)),
                    SizedBox(width: 180, child: _field('Bill of supply prefix', b.billOfSupplyPrefix, (v) => b.billOfSupplyPrefix = v)),
                    SizedBox(width: 180, child: _field('Bill / receipt prefix', b.billPrefix, (v) => b.billPrefix = v)),
                    SizedBox(width: 180, child: _field('Quotation prefix', b.quotationPrefix, (v) => b.quotationPrefix = v)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Example: ${b.invoicePrefix.trim().isEmpty ? 'INV' : b.invoicePrefix.toUpperCase()}/26-27/000001. Finalized documents keep their original number and tax snapshot even if Settings changes later.',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      b.businessType = BusinessTypeRules.canonicalType(b.businessType);
                      if (b.businessType == 'General Retail' && !b.enabledRetailModules.contains('General')) {
                        b.enabledRetailModules.add('General');
                      }
                      if (b.isGstRegistered && b.gstin.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter GSTIN for a GST-registered business before saving.')),
                        );
                        return;
                      }
                      final ok = await confirmAction(
                        context,
                        title: 'Save business settings?',
                        message:
                            'Save the current business identity and GST profile?',
                        confirmLabel: 'Save settings',
                      );
                      if (!ok) return;
                      await app.persist();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Business settings saved.')),
                      );
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save business settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: BarcodeScannerService.instance,
          builder: (context, _) {
            final scanner = BarcodeScannerService.instance;
            final scannerUrl = scanner.primaryUrl;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppTheme.green,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Barcode scanner',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'One scanner setup is shared by Billing, New Purchase and New Product.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final hid = Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111820),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.bluetooth_rounded,
                                    color: AppTheme.cyan,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'USB / Bluetooth scanner',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  StatusPill(
                                    text: 'HID ready',
                                    color: AppTheme.green,
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pair or plug in a barcode scanner that works as a keyboard. Keep the barcode field focused and scan — no extra driver is required inside ProfitGPS.',
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );

                        final wifi = Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111820),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: scanner.isRunning
                                  ? AppTheme.green.withValues(alpha: .55)
                                  : AppTheme.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.wifi_tethering_rounded,
                                    color: AppTheme.green,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Wi-Fi phone scanner',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: b.wifiPhoneScannerEnabled,
                                    onChanged: (value) async {
                                      if (value) {
                                        final ok = await scanner.start(
                                          preferredPort: b.scannerPort,
                                        );
                                        if (!mounted) return;
                                        setState(() {
                                          b.wifiPhoneScannerEnabled = ok;
                                          if (ok) b.scannerPort = scanner.port;
                                        });
                                        await app.persist();
                                        if (!ok && mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                scanner.lastError.isEmpty
                                                    ? 'Could not start the Wi-Fi phone scanner.'
                                                    : scanner.lastError,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        await scanner.stop();
                                        if (!mounted) return;
                                        setState(() {
                                          b.wifiPhoneScannerEnabled = false;
                                        });
                                        await app.persist();
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                scanner.isRunning
                                    ? 'Listening for phone scans on your local network.'
                                    : 'Turn this on to use your phone as a scanner over the same Wi-Fi network.',
                                style: const TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                              if (scanner.lastError.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  scanner.lastError,
                                  style: const TextStyle(
                                    color: AppTheme.amber,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );

                        if (constraints.maxWidth >= 760) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: hid),
                              const SizedBox(width: 12),
                              Expanded(child: wifi),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            hid,
                            const SizedBox(height: 12),
                            wifi,
                          ],
                        );
                      },
                    ),
                    if (scanner.isRunning && scannerUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D171E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final qr = Container(
                              width: 180,
                              height: 180,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: BarcodeWidget(
                                barcode: Barcode.qrCode(),
                                data: scannerUrl,
                                color: Colors.black,
                                backgroundColor: Colors.white,
                              ),
                            );
                            final details = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Connect phone scanner',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '1. Connect phone and this PC to the same Wi-Fi.\n2. Scan this QR with the phone camera.\n3. On the phone page tap “Take barcode photo” and scan a real product.\n4. Keep the ProfitGPS scanner field open — the barcode is sent to it automatically.',
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SelectableText(
                                  scannerUrl,
                                  style: const TextStyle(
                                    color: AppTheme.cyan,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: scannerUrl),
                                        );
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Phone scanner URL copied.',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy_rounded),
                                      label: const Text('Copy URL'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        scanner.injectCode(
                                          '8901234567890',
                                          client: 'Settings test',
                                        );
                                      },
                                      icon: const Icon(Icons.bolt_rounded),
                                      label: const Text('Send test barcode'),
                                    ),
                                  ],
                                ),
                                if (scanner.lastCode.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.green.withValues(
                                        alpha: .08,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppTheme.green.withValues(
                                          alpha: .35,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Last barcode: ${scanner.lastCode}\nFrom: ${scanner.lastClient} • Total received: ${scanner.scanCount}',
                                      style: const TextStyle(
                                        color: AppTheme.green,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                const Text(
                                  'Windows may ask for network permission the first time. Allow ProfitGPS on Private networks. The phone photo scanner uses an online decoding script; manual/HTTP scanner-app submission still works without it.',
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            );
                            if (constraints.maxWidth >= 760) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  qr,
                                  const SizedBox(width: 18),
                                  Expanded(child: details),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                qr,
                                const SizedBox(height: 14),
                                details,
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: AppTheme.cyan),
                    SizedBox(width: 9),
                    Text(
                      'UPI payment setup',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'The saved QR appears automatically when UPI is selected in Billing.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    final preview = Container(
                      width: 190,
                      height: 190,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: hasQr
                          ? Image.file(qrFile, fit: BoxFit.contain)
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 70,
                                    color: Colors.black45,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No uploaded QR',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                    );
                    final fields = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field(
                          'Shop UPI ID',
                          b.upiId,
                          (v) => b.upiId = v,
                          hint: 'example@bank',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _pickUpiQr,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: Text(hasQr ? 'Replace QR' : 'Upload QR'),
                            ),
                            OutlinedButton.icon(
                              onPressed: hasQr ? _removeUpiQr : null,
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Remove QR'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: b.upiTestMode,
                          title: const Text('UPI auto-confirm test mode'),
                          subtitle: const Text(
                            'For testing the app workflow only. It simulates a successful UPI confirmation and does not contact Axis Bank or any payment provider.',
                          ),
                          onChanged: (v) => setState(() => b.upiTestMode = v),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final ok = await confirmAction(
                                context,
                                title: 'Save UPI settings?',
                                message:
                                    'Save the UPI ID, QR configuration and test-mode setting?',
                                confirmLabel: 'Save UPI settings',
                              );
                              if (!ok) return;
                              await app.persist();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('UPI settings saved.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save UPI settings'),
                          ),
                        ),
                      ],
                    );
                    if (c.maxWidth >= 760) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          preview,
                          const SizedBox(width: 18),
                          Expanded(child: fields),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: preview),
                        const SizedBox(height: 14),
                        fields,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Role & billing privacy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: b.activeRole,
                  items: const [
                    DropdownMenuItem(value: 'Owner', child: Text('Owner mode')),
                    DropdownMenuItem(
                      value: 'Worker',
                      child: Text('Worker / cashier mode'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => b.activeRole = v ?? 'Owner'),
                  decoration: const InputDecoration(labelText: 'Active role'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: b.showProfitInBilling,
                  title: const Text('Show profit during billing'),
                  subtitle: Text(
                    b.activeRole == 'Owner'
                        ? 'Owner can choose whether profit and margin are visible on the billing screen.'
                        : 'Recommended OFF for worker/cashier mode. Purchase cost and profit remain hidden from the customer-facing invoice.',
                  ),
                  onChanged: (v) => setState(() => b.showProfitInBilling = v),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Save role settings?',
                        message:
                            'Save the current role and billing privacy controls?',
                        confirmLabel: 'Save role settings',
                      );
                      if (!ok) return;
                      await app.persist();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Role and privacy settings saved.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Save role settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_off_rounded, color: AppTheme.green),
            title: Text('Offline-first local data'),
            subtitle: Text(
              'Core billing, stock, customers, suppliers and reports stay local. Cloud sync remains optional.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    String? hint,
  }) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: onChanged,
    );
  }
}
