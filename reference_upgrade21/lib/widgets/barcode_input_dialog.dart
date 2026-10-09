import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/theme.dart';
import '../services/barcode_scanner_service.dart';

/// Unified ProfitGPS barcode entry.
///
/// Android: opens the real device camera first. Every Billing/Purchase flow
/// that already calls this helper therefore gets native camera scanning.
/// Windows/desktop: keeps the existing USB/Bluetooth HID + Wi-Fi phone
/// scanner behaviour from Upgrade 21.
Future<String?> showBarcodeInputDialog(
  BuildContext context, {
  required String title,
  required String subtitle,
  String actionLabel = 'Find product',
}) async {
  if (!kIsWeb && Platform.isAndroid) {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _NativeBarcodeScannerPage(title: title),
      ),
    );
    if (scanned != null && scanned.trim().isNotEmpty) {
      return scanned.trim();
    }
  }

  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BarcodeInputDialog(
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
    ),
  );
}

class _NativeBarcodeScannerPage extends StatefulWidget {
  const _NativeBarcodeScannerPage({required this.title});

  final String title;

  @override
  State<_NativeBarcodeScannerPage> createState() =>
      _NativeBarcodeScannerPageState();
}

class _NativeBarcodeScannerPageState extends State<_NativeBarcodeScannerPage> {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: true,
  );
  bool returning = false;

  Future<void> _returnCode(String raw) async {
    final value = raw.trim();
    if (value.isEmpty || returning) return;
    returning = true;
    await scannerController.stop();
    if (mounted) Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: () => scannerController.toggleTorch(),
            icon: const Icon(Icons.flash_on_rounded),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => scannerController.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue?.trim() ?? '';
                if (value.isNotEmpty) {
                  _returnCode(value);
                  break;
                }
              }
            },
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Camera scanner could not start.\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.sizeOf(context).width * .78,
                height: 190,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.cyan, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Point the camera at the barcode / QR / GS1 code.\nProfitGPS will capture it automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text('Enter code manually instead'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeInputDialog extends StatefulWidget {
  const _BarcodeInputDialog({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  final String title;
  final String subtitle;
  final String actionLabel;

  @override
  State<_BarcodeInputDialog> createState() => _BarcodeInputDialogState();
}

class _BarcodeInputDialogState extends State<_BarcodeInputDialog> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  StreamSubscription<String>? subscription;
  String status = 'Waiting for barcode…';
  bool receivedFromPhone = false;

  @override
  void initState() {
    super.initState();
    subscription = BarcodeScannerService.instance.codes.listen((raw) {
      final code = raw.trim();
      if (!mounted || code.isEmpty) return;
      setState(() {
        controller.text = code;
        controller.selection = TextSelection.collapsed(offset: code.length);
        receivedFromPhone = true;
        status = 'Barcode received: $code • Press ${widget.actionLabel}.';
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void submit() {
    final code = controller.text.trim();
    if (code.isEmpty) {
      setState(() => status = 'Scan or enter a barcode first.');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final scanner = BarcodeScannerService.instance;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subtitle, style: const TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Barcode / SKU / product code',
                prefixIcon: Icon(Icons.qr_code_scanner_rounded),
              ),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: receivedFromPhone
                    ? AppTheme.green.withValues(alpha: .08)
                    : const Color(0xFF111820),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: receivedFromPhone
                      ? AppTheme.green.withValues(alpha: .35)
                      : AppTheme.border,
                ),
              ),
              child: Text(
                receivedFromPhone
                    ? status
                    : scanner.isRunning
                        ? 'Wi-Fi phone scanner connected. Scan on the phone; the barcode will appear here.'
                        : 'USB/Bluetooth HID scanners work here like a keyboard. Wi-Fi Phone Scanner can be enabled in Settings.',
                style: TextStyle(
                  color: receivedFromPhone ? AppTheme.green : AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
            if (scanner.isRunning && scanner.primaryUrl.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                'Phone scanner: ${scanner.primaryUrl}',
                style: const TextStyle(color: AppTheme.cyan, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: submit,
          icon: const Icon(Icons.search_rounded),
          label: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
