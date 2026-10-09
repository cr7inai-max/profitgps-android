class Gs1DecodedScan {
  const Gs1DecodedScan({
    required this.raw,
    this.codeType = 'Unknown',
    this.gtin = '',
    this.batchNo = '',
    this.serialNumber = '',
    this.variant = '',
    this.additionalProductId = '',
    this.customerPartNumber = '',
    this.productionDate,
    this.packagingDate,
    this.bestBeforeDate,
    this.expiryDate,
    this.count,
    this.netWeightKg,
    this.fields = const <String, String>{},
  });

  final String raw;
  final String codeType;
  final String gtin;
  final String batchNo;
  final String serialNumber;
  final String variant;
  final String additionalProductId;
  final String customerPartNumber;
  final DateTime? productionDate;
  final DateTime? packagingDate;
  final DateTime? bestBeforeDate;
  final DateTime? expiryDate;
  final double? count;
  final double? netWeightKg;
  final Map<String, String> fields;

  bool get isImei => codeType == 'IMEI';
  bool get isGs1 => codeType.startsWith('GS1');
  bool get hasExtendedData =>
      batchNo.isNotEmpty ||
      serialNumber.isNotEmpty ||
      variant.isNotEmpty ||
      additionalProductId.isNotEmpty ||
      customerPartNumber.isNotEmpty ||
      productionDate != null ||
      packagingDate != null ||
      bestBeforeDate != null ||
      expiryDate != null ||
      count != null ||
      netWeightKg != null;
}

class Gs1ScanParser {
  Gs1ScanParser._();

  static final RegExp _plainGtin = RegExp(r'^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$');
  static final RegExp _plainImei = RegExp(r'^\d{15}$');

  static Gs1DecodedScan decode(String rawInput) {
    var raw = rawInput.trim();
    if (raw.isEmpty) return const Gs1DecodedScan(raw: '');

    if (raw.startsWith(']') && raw.length >= 3) {
      raw = raw.substring(3);
    }

    if (_plainImei.hasMatch(raw) && _validLuhn(raw)) {
      return Gs1DecodedScan(
        raw: rawInput,
        codeType: 'IMEI',
        serialNumber: raw,
        fields: const {'identifierType': 'IMEI'},
      );
    }

    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final digital = _decodeDigitalLink(rawInput, uri);
      if (digital != null) return digital;
    }

    if (raw.contains(RegExp(r'\(\d{2,4}\)'))) {
      final parenthesized = _decodeParenthesized(rawInput, raw);
      if (parenthesized != null) return parenthesized;
    }

    final element = _decodeElementString(rawInput, raw);
    if (element != null) return element;

    if (_plainGtin.hasMatch(raw)) {
      return Gs1DecodedScan(
        raw: rawInput,
        codeType: 'EAN/UPC/GTIN',
        gtin: _normalizeGtin(raw),
        fields: {'GTIN': _normalizeGtin(raw)},
      );
    }

    return Gs1DecodedScan(raw: rawInput, codeType: 'Unknown');
  }

  static Gs1DecodedScan? _decodeDigitalLink(String original, Uri uri) {
    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
    final pairs = <String, String>{};
    for (var i = 0; i + 1 < segments.length; i++) {
      final ai = segments[i];
      if (!_knownAi(ai)) continue;
      pairs[ai] = Uri.decodeComponent(segments[i + 1]);
      i++;
    }
    uri.queryParameters.forEach((key, value) {
      if (_knownAi(key)) pairs[key] = value;
    });
    if (pairs.isEmpty) return null;
    return _fromPairs(original, pairs, 'GS1 Digital Link');
  }

  static Gs1DecodedScan? _decodeParenthesized(String original, String text) {
    final matches = RegExp(r'\((\d{2,4})\)').allMatches(text).toList();
    if (matches.isEmpty) return null;
    final pairs = <String, String>{};
    for (var i = 0; i < matches.length; i++) {
      final ai = matches[i].group(1)!;
      final valueStart = matches[i].end;
      final valueEnd = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final value = text.substring(valueStart, valueEnd).trim();
      if (_knownAi(ai) && value.isNotEmpty) pairs[ai] = value;
    }
    if (pairs.isEmpty) return null;
    return _fromPairs(original, pairs, 'GS1 element string');
  }

  static Gs1DecodedScan? _decodeElementString(String original, String text) {
    final t = text.replaceAll('\u001d', String.fromCharCode(29));
    if (!t.startsWith('01') || t.length < 16) return null;
    final pairs = <String, String>{};
    var index = 0;
    while (index < t.length) {
      final ai = _matchAi(t, index);
      if (ai == null) break;
      index += ai.length;
      final fixed = _fixedLength(ai);
      if (fixed != null) {
        if (index + fixed > t.length) break;
        pairs[ai] = t.substring(index, index + fixed);
        index += fixed;
      } else {
        final max = _maxVariableLength(ai);
        var end = index;
        while (end < t.length && t.codeUnitAt(end) != 29 && end - index < max) {
          end++;
        }
        if (end > index) pairs[ai] = t.substring(index, end);
        index = end < t.length && t.codeUnitAt(end) == 29 ? end + 1 : end;
      }
    }
    if (pairs.isEmpty || !pairs.containsKey('01')) return null;
    return _fromPairs(original, pairs, 'GS1 element string');
  }

  static Gs1DecodedScan _fromPairs(String original, Map<String, String> pairs, String type) {
    final display = <String, String>{};
    void put(String label, String ai) {
      final v = pairs[ai];
      if (v != null && v.isNotEmpty) display[label] = v;
    }

    put('GTIN', '01');
    put('Contained GTIN', '02');
    put('Batch / lot', '10');
    put('Production date', '11');
    put('Packaging date', '13');
    put('Best before', '15');
    put('Expiry date', '17');
    put('Internal variant', '20');
    put('Serial', '21');
    put('Consumer product variant', '22');
    put('Additional product ID', '240');
    put('Customer part no.', '241');
    put('Variable count', '30');
    put('Count of trade items', '37');
    put('Made-to-order variation', '242');
    put('Secondary serial', '250');
    put('Source entity reference', '251');
    put('Price per unit measure', '8005');

    double? weight;
    const measurementLabels = <String, String>{
      '310': 'Net weight (kg)',
      '311': 'Length (m)',
      '312': 'Width (m)',
      '313': 'Depth (m)',
      '314': 'Area (m²)',
      '315': 'Net volume (L)',
      '316': 'Net volume (m³)',
    };
    for (final entry in pairs.entries) {
      final measurementMatch = RegExp(r'^(310|311|312|313|314|315|316)(\d)$').firstMatch(entry.key);
      if (measurementMatch != null) {
        final decimals = int.tryParse(measurementMatch.group(2) ?? '') ?? 0;
        final raw = double.tryParse(entry.value);
        if (raw != null) {
          final value = raw / _pow10(decimals);
          final family = measurementMatch.group(1)!;
          display[measurementLabels[family]!] = value.toString();
          if (family == '310') weight = value;
        }
      }
      final priceMatch = RegExp(r'^392(\d)$').firstMatch(entry.key);
      if (priceMatch != null) {
        final decimals = int.tryParse(priceMatch.group(1) ?? '') ?? 0;
        final raw = double.tryParse(entry.value);
        if (raw != null) display['Price / amount payable'] = (raw / _pow10(decimals)).toString();
      }
      final currencyPriceMatch = RegExp(r'^393(\d)$').firstMatch(entry.key);
      if (currencyPriceMatch != null && entry.value.length >= 4) {
        final decimals = int.tryParse(currencyPriceMatch.group(1) ?? '') ?? 0;
        final currency = entry.value.substring(0, 3);
        final raw = double.tryParse(entry.value.substring(3));
        if (raw != null) display['Price / amount payable'] = '$currency ${(raw / _pow10(decimals)).toString()}';
      }
    }

    return Gs1DecodedScan(
      raw: original,
      codeType: type,
      gtin: _normalizeGtin(pairs['01'] ?? ''),
      batchNo: pairs['10'] ?? '',
      serialNumber: pairs['21'] ?? '',
      variant: (pairs['22'] ?? '').isNotEmpty ? pairs['22']! : (pairs['20'] ?? ''),
      additionalProductId: pairs['240'] ?? '',
      customerPartNumber: pairs['241'] ?? '',
      productionDate: _parseGs1Date(pairs['11']),
      packagingDate: _parseGs1Date(pairs['13']),
      bestBeforeDate: _parseGs1Date(pairs['15']),
      expiryDate: _parseGs1Date(pairs['17']),
      count: double.tryParse((pairs['30'] ?? '').isNotEmpty ? pairs['30']! : (pairs['37'] ?? '')),
      netWeightKg: weight,
      fields: display,
    );
  }

  static String? _matchAi(String text, int start) {
    for (final len in const [4, 3, 2]) {
      if (start + len > text.length) continue;
      final ai = text.substring(start, start + len);
      if (_knownAi(ai)) return ai;
    }
    return null;
  }

  static bool _knownAi(String ai) {
    if (RegExp(r'^(310|311|312|313|314|315|316|392|393)\d$').hasMatch(ai)) return true;
    return const {'01', '02', '10', '11', '13', '15', '17', '20', '21', '22', '30', '37', '240', '241', '242', '250', '251', '8005'}.contains(ai);
  }

  static int? _fixedLength(String ai) {
    if (ai == '01' || ai == '02') return 14;
    if (ai == '20') return 2;
    if (ai == '8005') return 6;
    if (const {'11', '13', '15', '17'}.contains(ai)) return 6;
    if (RegExp(r'^(310|311|312|313|314|315|316)\d$').hasMatch(ai)) return 6;
    return null;
  }

  static int _maxVariableLength(String ai) {
    switch (ai) {
      case '10': return 20;
      case '21': return 20;
      case '22': return 20;
      case '30': return 8;
      case '37': return 8;
      case '240': return 30;
      case '241': return 30;
      case '242': return 6;
      case '250': return 30;
      case '251': return 30;
      default:
        if (RegExp(r'^(392|393)\d$').hasMatch(ai)) return 18;
        return 30;
    }
  }

  static DateTime? _parseGs1Date(String? raw) {
    if (raw == null || !RegExp(r'^\d{6}$').hasMatch(raw)) return null;
    final yy = int.parse(raw.substring(0, 2));
    final month = int.parse(raw.substring(2, 4));
    var day = int.parse(raw.substring(4, 6));
    if (month < 1 || month > 12) return null;
    final year = 2000 + yy;
    if (day == 0) {
      day = DateTime(year, month + 1, 0).day;
    }
    if (day < 1 || day > DateTime(year, month + 1, 0).day) return null;
    return DateTime(year, month, day);
  }

  static String _normalizeGtin(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 14 && digits.startsWith('0')) {
      final ean13 = digits.substring(1);
      if (_validGtin(ean13)) return ean13;
    }
    return digits;
  }

  static bool _validGtin(String code) {
    if (!RegExp(r'^\d+$').hasMatch(code) || code.length < 2) return false;
    var sum = 0;
    for (var i = code.length - 2, pos = 1; i >= 0; i--, pos++) {
      final digit = int.parse(code[i]);
      sum += digit * (pos.isOdd ? 3 : 1);
    }
    final check = (10 - (sum % 10)) % 10;
    return check == int.parse(code[code.length - 1]);
  }

  static bool _validLuhn(String digits) {
    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  static double _pow10(int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}
