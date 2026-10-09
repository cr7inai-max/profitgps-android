import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// No test/default PINs. Credentials live in the Android KeyStore-backed
/// secure-storage plugin, not in the business-data JSON or source code.
class SecureAccess {
  static const FlutterSecureStorage store = FlutterSecureStorage();
  static String key(String role, String part) => 'profitgps_auth_v1_' + role.toLowerCase() + '_' + part;

  static Future<bool> hasPin(String role) async =>
      (await store.read(key: key(role, 'digest'))) != null;

  static String _digest(String pin, String salt) {
    List<int> hash = utf8.encode(salt + ':' + pin);
    for (var i = 0; i < 15000; i++) {
      hash = sha256.convert(hash).bytes;
    }
    return base64Url.encode(hash);
  }

  static Future<void> setPin(String role, String pin) async {
    if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) {
      throw const FormatException('Use a numeric PIN with 6 to 12 digits.');
    }
    final rng = Random.secure();
    final salt = base64Url.encode(List<int>.generate(24, (_) => rng.nextInt(256)));
    final digest = _digest(pin, salt);
    await store.write(key: key(role, 'salt'), value: salt);
    await store.write(key: key(role, 'digest'), value: digest);
  }

  static Future<bool> checkPin(String role, String pin) async {
    final salt = await store.read(key: key(role, 'salt'));
    final digest = await store.read(key: key(role, 'digest'));
    if (salt == null || digest == null) return false;
    final candidate = _digest(pin, salt);
    var difference = candidate.length ^ digest.length;
    for (var i = 0; i < candidate.length && i < digest.length; i++) {
      difference |= candidate.codeUnitAt(i) ^ digest.codeUnitAt(i);
    }
    return difference == 0;
  }
}
