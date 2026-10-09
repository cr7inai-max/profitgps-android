import 'dart:convert';
import 'dart:io';

import '../models/entities.dart';

class GstLookupResult {
  const GstLookupResult({
    required this.success,
    required this.gstin,
    this.legalName = '',
    this.tradeName = '',
    this.address = '',
    this.state = '',
    this.stateCode = '',
    this.status = '',
    this.taxpayerType = '',
    this.source = '',
    this.error = '',
  });

  final bool success;
  final String gstin;
  final String legalName;
  final String tradeName;
  final String address;
  final String state;
  final String stateCode;
  final String status;
  final String taxpayerType;
  final String source;
  final String error;

  String get displayName => tradeName.trim().isNotEmpty ? tradeName.trim() : legalName.trim();
  bool get isActive => status.trim().isEmpty || status.trim().toLowerCase() == 'active';
}

class GstLookupService {
  static const Map<String, String> _stateNames = {
    '01': 'Jammu and Kashmir',
    '02': 'Himachal Pradesh',
    '03': 'Punjab',
    '04': 'Chandigarh',
    '05': 'Uttarakhand',
    '06': 'Haryana',
    '07': 'Delhi',
    '08': 'Rajasthan',
    '09': 'Uttar Pradesh',
    '10': 'Bihar',
    '11': 'Sikkim',
    '12': 'Arunachal Pradesh',
    '13': 'Nagaland',
    '14': 'Manipur',
    '15': 'Mizoram',
    '16': 'Tripura',
    '17': 'Meghalaya',
    '18': 'Assam',
    '19': 'West Bengal',
    '20': 'Jharkhand',
    '21': 'Odisha',
    '22': 'Chhattisgarh',
    '23': 'Madhya Pradesh',
    '24': 'Gujarat',
    '25': 'Daman and Diu',
    '26': 'Dadra and Nagar Haveli and Daman and Diu',
    '27': 'Maharashtra',
    '29': 'Karnataka',
    '30': 'Goa',
    '31': 'Lakshadweep',
    '32': 'Kerala',
    '33': 'Tamil Nadu',
    '34': 'Puducherry',
    '35': 'Andaman and Nicobar Islands',
    '36': 'Telangana',
    '37': 'Andhra Pradesh',
    '38': 'Ladakh',
    '97': 'Other Territory',
  };

  static String stateCodeFromGstin(String gstin) {
    final value = gstin.trim().toUpperCase();
    if (value.length < 2) return '';
    final code = value.substring(0, 2);
    return RegExp(r'^\d{2}$').hasMatch(code) ? code : '';
  }

  static String stateNameForCode(String code) => _stateNames[code.trim()] ?? '';

  static bool isValidFormat(String gstin) {
    final v = gstin.trim().toUpperCase();
    return RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$').hasMatch(v);
  }

  static Future<GstLookupResult> lookup(BusinessProfile business, String rawGstin) async {
    final gstin = rawGstin.trim().toUpperCase();
    final code = stateCodeFromGstin(gstin);
    if (!isValidFormat(gstin)) {
      return GstLookupResult(
        success: false,
        gstin: gstin,
        stateCode: code,
        state: stateNameForCode(code),
        error: 'Invalid GSTIN format.',
      );
    }

    final apiKey = business.gstLookupApiKey.trim();
    if (apiKey.isEmpty || !business.gstOnlineLookupEnabled) {
      return GstLookupResult(
        success: false,
        gstin: gstin,
        stateCode: code,
        state: stateNameForCode(code),
        error: 'Online GSTIN lookup is not configured. Add an API key in Settings → Business profile → GSTIN online lookup.',
      );
    }

    final provider = business.gstLookupProvider.trim();
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        late final Uri uri;
        late final String headerName;
        if (provider == 'GSTINAPI') {
          uri = Uri.parse('https://www.gstinapi.in/v1/gstin/$gstin');
          headerName = 'x-api-key';
        } else {
          uri = Uri.parse('https://gstverify.co.in/api/v1/verify/$gstin');
          headerName = 'X-API-Key';
        }

        final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
        request.headers.set(headerName, apiKey);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(const Duration(seconds: 12));
        final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
        Map<String, dynamic> json;
        try {
          json = Map<String, dynamic>.from(jsonDecode(body) as Map);
        } catch (_) {
          return GstLookupResult(
            success: false,
            gstin: gstin,
            stateCode: code,
            state: stateNameForCode(code),
            error: 'GST lookup provider returned an unreadable response (HTTP ${response.statusCode}).',
          );
        }

        if (response.statusCode < 200 || response.statusCode >= 300 || json['success'] == false) {
          final message = json['message']?.toString() ??
              json['error']?.toString() ??
              'GST lookup failed (HTTP ${response.statusCode}).';
          return GstLookupResult(
            success: false,
            gstin: gstin,
            stateCode: code,
            state: stateNameForCode(code),
            error: message,
          );
        }

        final rawData = json['data'];
        final data = rawData is Map ? Map<String, dynamic>.from(rawData) : json;
        String pick(List<String> keys) {
          for (final key in keys) {
            final value = data[key];
            if (value != null && value.toString().trim().isNotEmpty) return value.toString().trim();
          }
          return '';
        }

        final returnedCode = pick(const ['state_code', 'stateCode']);
        final canonicalCode = code.isNotEmpty ? code : returnedCode;
        final returnedState = pick(const ['state', 'state_name', 'stateName']);
        return GstLookupResult(
          success: true,
          gstin: gstin,
          legalName: pick(const ['legal_name', 'legalName', 'lgnm']),
          tradeName: pick(const ['trade_name', 'tradeName', 'tradeNam']),
          address: pick(const ['address', 'registered_address', 'principal_address']),
          state: returnedState.isNotEmpty ? returnedState : stateNameForCode(canonicalCode),
          stateCode: canonicalCode,
          status: pick(const ['status', 'gstin_status', 'sts']),
          taxpayerType: pick(const ['taxpayer_type', 'taxpayerType', 'dty']),
          source: provider == 'GSTINAPI' ? 'GSTINAPI' : 'GSTVerify',
        );
      } finally {
        client.close(force: true);
      }
    } on SocketException {
      return GstLookupResult(
        success: false,
        gstin: gstin,
        stateCode: code,
        state: stateNameForCode(code),
        error: 'No internet connection for GSTIN lookup.',
      );
    } on HttpException catch (e) {
      return GstLookupResult(
        success: false,
        gstin: gstin,
        stateCode: code,
        state: stateNameForCode(code),
        error: 'GST lookup network error: ${e.message}',
      );
    } catch (e) {
      return GstLookupResult(
        success: false,
        gstin: gstin,
        stateCode: code,
        state: stateNameForCode(code),
        error: 'GST lookup failed. ${e.toString()}',
      );
    }
  }
}
