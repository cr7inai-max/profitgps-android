import 'dart:io';
import 'package:flutter/material.dart';
import 'core/app_controller.dart';
import 'core/app_scope.dart';
import 'core/theme.dart';
import 'data/local_repository.dart';
import 'screens/login_screen.dart';
import 'services/barcode_scanner_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(LocalRepository());
  await controller.init();
  final scannerSettings = controller.data!.business;
  if (Platform.isWindows && scannerSettings.wifiPhoneScannerEnabled) {
    await BarcodeScannerService.instance.start(
      preferredPort: scannerSettings.scannerPort,
    );
  }
  runApp(ProfitGpsApp(controller: controller));
}

class ProfitGpsApp extends StatelessWidget {
  const ProfitGpsApp({super.key, required this.controller});
  final AppController controller;
  @override Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Profit GPS Billing',
      theme: AppTheme.dark(),
      home: const LoginScreen(),
    ),
  );
}
