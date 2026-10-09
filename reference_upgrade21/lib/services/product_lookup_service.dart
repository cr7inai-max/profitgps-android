import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gs1_scan_parser.dart';

class ExternalProductInfo {
  const ExternalProductInfo({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.manufacturer = '',
    this.category = '',
    this.packageSize = '',
    this.imageUrl = '',
    this.source = '',
    this.codeType = '',
    this.hsnSac = '',
    this.mrp = 0,
    this.gstRate = 0,
    this.batchNo = '',
    this.serialNumber = '',
    this.variant = '',
    this.additionalProductId = '',
    this.customerPartNumber = '',
    this.productionDate,
    this.packagingDate,
    this.bestBeforeDate,
    this.expiryDate,
    this.encodedCount,
    this.encodedNetWeightKg,
    this.decodedFields = const <String, String>{},
  });

  final String barcode;
  final String name;
  final String brand;
  final String manufacturer;
  final String category;
  final String packageSize;
  final String imageUrl;
  final String source;
  final String codeType;
  final String hsnSac;
  final double mrp;
  final double gstRate;
  final String batchNo;
  final String serialNumber;
  final String variant;
  final String additionalProductId;
  final String customerPartNumber;
  final DateTime? productionDate;
  final DateTime? packagingDate;
  final DateTime? bestBeforeDate;
  final DateTime? expiryDate;
  final double? encodedCount;
  final double? encodedNetWeightKg;
  final Map<String, String> decodedFields;

  bool get hasUsefulData =>
      name.trim().isNotEmpty ||
      brand.trim().isNotEmpty ||
      manufacturer.trim().isNotEmpty ||
      packageSize.trim().isNotEmpty ||
      imageUrl.trim().isNotEmpty ||
      decodedFields.isNotEmpty ||
      batchNo.isNotEmpty ||
      serialNumber.isNotEmpty ||
      expiryDate != null ||
      productionDate != null ||
      packagingDate != null ||
      bestBeforeDate != null ||
      encodedCount != null ||
      encodedNetWeightKg != null;

  bool get isWebSuggestion => false;
}

/// Trusted barcode enrichment for ProfitGPS.
///
/// Order of resolution:
/// 1. Data encoded directly in the GS1/UDI/IMEI symbol.
/// 2. GS1 India Smart Consumer for Indian (890...) GTINs.
/// 3. GS1 Digital Link / Verified by GS1 for global GTINs.
///
/// No anonymous crowd-sourced barcode catalogue, search-engine guessing or
/// retail-web scraping is used here. The calling screens already check the
/// local ProfitGPS Product Master before reaching this service, so repeat scans
/// remain offline and instant.
class ProductLookupService {
  ProductLookupService._();

  static final ProductLookupService instance = ProductLookupService._();

  final Map<String, ExternalProductInfo?> _cache = <String, ExternalProductInfo?>{};
  String _lastMessage = '';

  String get lastMessage => _lastMessage;

  Future<ExternalProductInfo?> lookup(String rawBarcode) async {
    final raw = rawBarcode.trim();
    if (raw.isEmpty) {
      _lastMessage = 'Enter or scan a barcode.';
      return null;
    }

    final decoded = Gs1ScanParser.decode(raw);

    if (decoded.isImei) {
      _lastMessage =
          'Device identifier recognised. Select or scan the product model, then attach this IMEI to the unit.';
      return ExternalProductInfo(
        barcode: '',
        name: '',
        codeType: decoded.codeType,
        serialNumber: decoded.serialNumber,
        decodedFields: decoded.fields,
        source: 'Encoded device identifier',
      );
    }

    if (_isTrustedHttpUrl(raw)) {
      final pageInfo = await _lookupTrustedUrl(raw);
      if (pageInfo != null && pageInfo.hasUsefulData) {
        _lastMessage = pageInfo.name.isNotEmpty
            ? 'Verified product details found.'
            : 'Trusted barcode data read successfully.';
        return pageInfo;
      }
    }

    if (decoded.gtin.isNotEmpty) {
      final issue = validationIssue(decoded.gtin);
      if (issue != null) {
        _lastMessage = issue;
        return null;
      }

      final master = await _lookupTrustedMaster(decoded.gtin);
      final merged = _mergeDecoded(master, decoded);
      if (master != null && master.name.trim().isNotEmpty) {
        _lastMessage = 'Verified product details found.';
        return merged;
      }
      if (decoded.hasExtendedData || decoded.fields.length > 1) {
        _lastMessage = 'Encoded product data read successfully.';
        return merged;
      }

      _lastMessage = 'Barcode recognised.';
      return ExternalProductInfo(
        barcode: decoded.gtin,
        name: '',
        source: 'Scanned GTIN',
        codeType: decoded.codeType,
        decodedFields: decoded.fields,
      );
    }

    final issue = validationIssue(raw);
    if (issue != null) {
      _lastMessage = issue;
      return null;
    }

    if (_looksLikeHttpUrl(raw)) {
      _lastMessage = 'QR code recognised.';
      return ExternalProductInfo(
        barcode: '',
        name: '',
        source: 'Scanned QR',
        codeType: 'QR',
      );
    }

    _lastMessage = 'Identifier captured.';
    return ExternalProductInfo(
      barcode: raw,
      name: '',
      source: 'Scanned identifier',
      codeType: decoded.codeType.isEmpty ? 'Barcode' : decoded.codeType,
      decodedFields: decoded.fields,
    );
  }

  Future<ExternalProductInfo?> _lookupTrustedMaster(String rawGtin) async {
    final gtin = _normalizeGtin(rawGtin);
    if (gtin == null) return null;
    if (_cache.containsKey(gtin)) return _cache[gtin];

    final lookups = <Future<ExternalProductInfo?>>[
      if (gtin.startsWith('890')) _lookupGs1IndiaSmartConsumer(gtin),
      if (gtin.startsWith('890')) _lookupGs1IndiaGtinValidation(gtin),
      _lookupGs1DigitalLink(gtin),
      _lookupVerifiedByGs1(gtin),
    ];

    // Run trusted sources together so a slow provider does not make the
    // cashier wait for every other provider in sequence. The first verified
    // product record wins; if all sources return no record, return null.
    final result = await _firstUsefulTrustedResult(lookups);
    _cache[gtin] = result;
    return result;
  }

  Future<ExternalProductInfo?> _firstUsefulTrustedResult(
    List<Future<ExternalProductInfo?>> lookups,
  ) {
    if (lookups.isEmpty) return Future<ExternalProductInfo?>.value(null);
    final completer = Completer<ExternalProductInfo?>();
    var remaining = lookups.length;

    void completedOne(ExternalProductInfo? value) {
      if (!completer.isCompleted && value != null && value.name.trim().isNotEmpty) {
        completer.complete(value);
      }
      remaining -= 1;
      if (remaining == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    for (final lookup in lookups) {
      lookup.then(completedOne).catchError((Object _) {
        completedOne(null);
        return null;
      });
    }
    return completer.future;
  }

  Future<ExternalProductInfo?> _lookupGs1IndiaSmartConsumer(String gtin) async {
    final gtin14 = _toGtin14(gtin);
    final session = _TrustedHttpSession();
    try {
      // GS1 India documents Smart Consumer as a GS1 Digital Link resolver.
      // This route is preferred because it can resolve directly to brand-owner
      // supplied product information without relying on a third-party catalogue.
      final directCandidates = <Uri>[
        Uri.parse('https://smartconsumer.org.in/01/$gtin14'),
        Uri.parse('https://smartconsumer.org.in/gtin/$gtin'),
      ];

      for (final uri in directCandidates) {
        final page = await session.get(uri);
        final parsed = _productFromTrustedPage(
          page,
          expectedGtin: gtin,
          source: 'GS1 India Smart Consumer',
          smartConsumer: true,
        );
        if (parsed != null && parsed.name.isNotEmpty) return parsed;
      }

      // The current Smart Consumer home page exposes a GTIN/EAN/UPC search.
      // Discover the form dynamically so the app is not tied to a private or
      // undocumented endpoint name.
      final home = await session.get(Uri.parse('https://smartconsumer.org.in/index.php/'));
      if (home == null || home.body.isEmpty) return null;

      final form = _discoverSearchForm(home.body, home.finalUri);
      if (form == null) return null;
      final resultPage = await session.submitForm(form, gtin);
      return _productFromTrustedPage(
        resultPage,
        expectedGtin: gtin,
        source: 'GS1 India Smart Consumer',
        smartConsumer: true,
      );
    } finally {
      session.close();
    }
  }

  Future<ExternalProductInfo?> _lookupGs1IndiaGtinValidation(String gtin) async {
    final session = _TrustedHttpSession();
    try {
      // Official GS1 India validation is powered by DataKart. Discover its
      // barcode form rather than depending on a private endpoint name.
      final home = await session.get(
        Uri.parse('https://www.gs1india.org/services/gtin-validation'),
      );
      if (home == null || home.body.isEmpty) return null;

      // Some versions of the page render a result directly from a query
      // parameter. Try the discovered official form first.
      final form = _discoverSearchForm(home.body, home.finalUri);
      if (form != null) {
        final resultPage = await session.submitForm(form, gtin);
        final parsed = _productFromTrustedPage(
          resultPage,
          expectedGtin: gtin,
          source: 'GS1 India DataKart',
          smartConsumer: true,
        );
        if (parsed != null && parsed.name.isNotEmpty) return parsed;
      }

      // Safe GET fallback on the same official GS1 India page. If the site
      // ignores these parameters, validation below simply returns null.
      for (final key in const <String>['gtin', 'barcode']) {
        final page = await session.get(
          home.finalUri.replace(queryParameters: <String, String>{key: gtin}),
        );
        final parsed = _productFromTrustedPage(
          page,
          expectedGtin: gtin,
          source: 'GS1 India DataKart',
          smartConsumer: true,
        );
        if (parsed != null && parsed.name.isNotEmpty) return parsed;
      }
      return null;
    } finally {
      session.close();
    }
  }

  Future<ExternalProductInfo?> _lookupGs1DigitalLink(String gtin) async {
    final session = _TrustedHttpSession();
    try {
      final page = await session.get(
        Uri.parse('https://id.gs1.org/01/${_toGtin14(gtin)}'),
      );
      if (page == null) return null;

      // If GS1 resolver sends the browser to a brand-owner product page, that
      // page commonly exposes schema.org Product / OpenGraph metadata.
      final parsed = _productFromTrustedPage(
        page,
        expectedGtin: gtin,
        source: 'GS1 Digital Link',
      );
      if (parsed != null && parsed.name.isNotEmpty) return parsed;
      return null;
    } finally {
      session.close();
    }
  }

  Future<ExternalProductInfo?> _lookupVerifiedByGs1(String gtin) async {
    final session = _TrustedHttpSession();
    try {
      final uri = Uri.https(
        'www.gs1.org',
        '/services/verified-by-gs1/results',
        <String, String>{'gtin': gtin},
      );
      final page = await session.get(uri);
      return _productFromTrustedPage(
        page,
        expectedGtin: gtin,
        source: 'Verified by GS1',
      );
    } finally {
      session.close();
    }
  }

  Future<ExternalProductInfo?> _lookupTrustedUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return null;
    final session = _TrustedHttpSession();
    try {
      final page = await session.get(uri);
      if (page == null) return null;
      final gtin = _extractGtinFromUri(page.finalUri) ??
          _extractGtinFromText(page.body) ??
          _extractGtinFromUri(uri);
      final parsed = _productFromTrustedPage(
        page,
        expectedGtin: gtin ?? '',
        source: _sourceForTrustedHost(page.finalUri.host),
        smartConsumer: page.finalUri.host.toLowerCase().contains('smartconsumer.org.in'),
      );
      if (parsed != null) return parsed;
      if (gtin != null) return _lookupTrustedMaster(gtin);
      return null;
    } finally {
      session.close();
    }
  }

  ExternalProductInfo _mergeDecoded(
    ExternalProductInfo? base,
    Gs1DecodedScan decoded,
  ) {
    return ExternalProductInfo(
      barcode: decoded.gtin.isNotEmpty ? decoded.gtin : (base?.barcode ?? ''),
      name: base?.name ?? '',
      brand: base?.brand ?? '',
      manufacturer: base?.manufacturer ?? '',
      category: base?.category ?? 'General',
      packageSize: base?.packageSize ?? '',
      imageUrl: base?.imageUrl ?? '',
      source: base == null || base.source.isEmpty
          ? 'Encoded ${decoded.codeType} data'
          : base.source,
      codeType: decoded.codeType,
      hsnSac: base?.hsnSac ?? '',
      mrp: base?.mrp ?? 0,
      gstRate: base?.gstRate ?? 0,
      batchNo: decoded.batchNo,
      serialNumber: decoded.serialNumber,
      variant: decoded.variant,
      additionalProductId: decoded.additionalProductId,
      customerPartNumber: decoded.customerPartNumber,
      productionDate: decoded.productionDate,
      packagingDate: decoded.packagingDate,
      bestBeforeDate: decoded.bestBeforeDate,
      expiryDate: decoded.expiryDate,
      encodedCount: decoded.count,
      encodedNetWeightKg: decoded.netWeightKg,
      decodedFields: decoded.fields,
    );
  }

  ExternalProductInfo? _productFromTrustedPage(
    _FetchedPage? page, {
    required String expectedGtin,
    required String source,
    bool smartConsumer = false,
  }) {
    if (page == null || page.body.trim().isEmpty) return null;
    final lower = page.body.toLowerCase();
    if (lower.contains('page not be found') ||
        lower.contains('barcode is invalid') ||
        lower.contains('daily access limit exceeded') ||
        lower.contains('captcha')) {
      return null;
    }

    final metadata = _extractProductPageMetadata(page.body, page.finalUri);
    final plain = _htmlText(page.body);

    var name = metadata.name;
    var brand = metadata.brand;
    var manufacturer = '';
    var packageSize = metadata.packageSize;
    var category = metadata.category;
    var imageUrl = metadata.imageUrl;

    if (smartConsumer) {
      name = _firstNonEmpty(<Object?>[
        _labelValue(plain, const <String>[
          'Name of the Product',
          'Product Name',
          'Name Of Product',
        ]),
        name,
        _bestHeading(page.body),
      ]);
      brand = _firstNonEmpty(<Object?>[
        _labelValue(plain, const <String>['Brand Name', 'Brand']),
        brand,
      ]);
      manufacturer = _firstNonEmpty(<Object?>[
        _labelValue(plain, const <String>[
          'NAME OF THE MANUFACTURER',
          'Name of the Manufacturer',
          'Manufacturer Name',
          'Company Name',
        ]),
      ]);
      packageSize = _firstNonEmpty(<Object?>[
        _labelValue(plain, const <String>['Net Content', 'Net Weight', 'Pack Size']),
        packageSize,
        _extractPackSize('$name ${metadata.description}'),
      ]);
    }

    if (!_plausibleProductName(name, page.finalUri.host)) return null;

    final pageGtin = _extractGtinFromText(page.body) ??
        _extractGtinFromUri(page.finalUri) ??
        (expectedGtin.isNotEmpty ? expectedGtin : null);
    if (pageGtin == null) return null;

    final normalizedExpected = expectedGtin.isEmpty ? null : _normalizeGtin(expectedGtin);
    final normalizedPage = _normalizeGtin(pageGtin);
    if (normalizedPage == null) return null;
    if (normalizedExpected != null &&
        _toGtin14(normalizedPage) != _toGtin14(normalizedExpected)) {
      return null;
    }

    final mrp = _parseMoney(
      _labelValue(plain, const <String>[
        'Maximum Retail Price',
        'MRP',
      ]),
    );
    final gst = _parsePercent(
      _labelValue(plain, const <String>[
        'Goods and Service Tax',
        'GST Rate',
        'GST',
      ]),
    );
    final hsn = _labelValue(plain, const <String>['HSN Code', 'HSN/SAC', 'HSN']);

    return ExternalProductInfo(
      barcode: normalizedExpected ?? normalizedPage,
      name: name,
      brand: brand,
      manufacturer: manufacturer,
      category: _mapCategory('$category $name'),
      packageSize: packageSize,
      imageUrl: imageUrl,
      source: source,
      codeType: 'GTIN',
      hsnSac: hsn,
      mrp: mrp,
      gstRate: gst,
    );
  }

  _ResolvedPageProduct _extractProductPageMetadata(String html, Uri baseUri) {
    final schema = _schemaProductFromHtml(html);
    if (schema != null) {
      final schemaName = _cleanPageTitle(schema.name, baseUri.host);
      if (_plausibleProductName(schemaName, baseUri.host)) {
        return _ResolvedPageProduct(
          name: schemaName,
          brand: schema.brand,
          category: schema.category,
          packageSize: schema.packageSize.isNotEmpty
              ? schema.packageSize
              : _extractPackSize('${schemaName} ${schema.description}'),
          imageUrl: _absoluteUrl(schema.imageUrl, baseUri),
          description: schema.description,
        );
      }
    }

    final meta = _metaTags(html);
    final rawTitle = _firstNonEmpty(<Object?>[
      meta['og:title'],
      meta['twitter:title'],
      _bestHeading(html),
      _pageTitle(html),
    ]);
    final title = _cleanPageTitle(rawTitle, baseUri.host);
    final description = _firstNonEmpty(<Object?>[
      meta['og:description'],
      meta['twitter:description'],
      meta['description'],
    ]);
    final image = _firstNonEmpty(<Object?>[
      meta['og:image'],
      meta['twitter:image'],
    ]);
    final brand = _firstNonEmpty(<Object?>[
      meta['product:brand'],
      meta['brand'],
    ]);

    return _ResolvedPageProduct(
      name: _plausibleProductName(title, baseUri.host) ? title : '',
      brand: brand,
      category: _firstNonEmpty(<Object?>[
        meta['product:category'],
        meta['category'],
      ]),
      packageSize: _extractPackSize('$title $description'),
      imageUrl: _absoluteUrl(image, baseUri),
      description: description,
    );
  }

  _ResolvedPageProduct? _schemaProductFromHtml(String html) {
    final scripts = RegExp(
      r'''<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>''',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final match in scripts) {
      var raw = (match.group(1) ?? '').trim();
      if (raw.isEmpty) continue;
      raw = _decodeHtmlEntities(raw);
      try {
        final decoded = jsonDecode(raw);
        final product = _findSchemaProduct(decoded);
        if (product == null) continue;
        final name = _schemaText(product['name']);
        if (name.isEmpty) continue;
        final description = _schemaText(product['description']);
        return _ResolvedPageProduct(
          name: name,
          brand: _schemaText(product['brand']),
          category: _schemaText(product['category']),
          packageSize: _firstNonEmpty(<Object?>[
            _schemaText(product['size']),
            _schemaText(product['weight']),
            _schemaText(product['netContent']),
            _extractPackSize('$name $description'),
          ]),
          imageUrl: _schemaImage(product['image']),
          description: description,
        );
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic>? _findSchemaProduct(Object? node) {
    if (node is Map) {
      final mapped = node.map((key, value) => MapEntry(key.toString(), value));
      final type = mapped['@type'];
      final isProduct = type is String
          ? type.toLowerCase() == 'product'
          : type is List
              ? type.any((value) => value.toString().toLowerCase() == 'product')
              : false;
      if (isProduct) return mapped;
      for (final value in mapped.values) {
        final nested = _findSchemaProduct(value);
        if (nested != null) return nested;
      }
    } else if (node is List) {
      for (final value in node) {
        final nested = _findSchemaProduct(value);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  _DiscoveredForm? _discoverSearchForm(String html, Uri baseUri) {
    final forms = RegExp(
      r'<form\b[^>]*>.*?</form>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final match in forms) {
      final formHtml = match.group(0) ?? '';
      final lower = formHtml.toLowerCase();
      if (!lower.contains('gtin') &&
          !lower.contains('ean') &&
          !lower.contains('upc') &&
          !lower.contains('barcode')) {
        continue;
      }

      final startTag = RegExp(r'<form\b[^>]*>', caseSensitive: false)
              .firstMatch(formHtml)
              ?.group(0) ??
          '';
      final attrs = _tagAttributes(startTag);
      final actionRaw = attrs['action']?.trim() ?? '';
      final method = (attrs['method'] ?? 'get').trim().toLowerCase();
      final actionUri = actionRaw.isEmpty
          ? baseUri
          : baseUri.resolve(actionRaw);

      String inputName = '';
      final fields = <String, String>{};
      for (final inputMatch in RegExp(
        r'<input\b[^>]*>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(formHtml)) {
        final inputAttrs = _tagAttributes(inputMatch.group(0) ?? '');
        final name = inputAttrs['name']?.trim() ?? '';
        if (name.isEmpty) continue;
        final type = (inputAttrs['type'] ?? 'text').toLowerCase();
        final placeholder = (inputAttrs['placeholder'] ?? '').toLowerCase();
        final id = (inputAttrs['id'] ?? '').toLowerCase();
        if (type == 'hidden') {
          fields[name] = inputAttrs['value'] ?? '';
          continue;
        }
        if (inputName.isEmpty &&
            (placeholder.contains('gtin') ||
                placeholder.contains('ean') ||
                placeholder.contains('upc') ||
                placeholder.contains('barcode') ||
                name.toLowerCase().contains('gtin') ||
                name.toLowerCase().contains('barcode') ||
                id.contains('gtin') ||
                id.contains('barcode'))) {
          inputName = name;
        }
      }

      if (inputName.isNotEmpty) {
        return _DiscoveredForm(
          action: actionUri,
          method: method == 'post' ? 'post' : 'get',
          inputName: inputName,
          fields: fields,
        );
      }
    }
    return null;
  }

  static Map<String, String> _tagAttributes(String tag) {
    final result = <String, String>{};
    final matches = RegExp(
      r'''([A-Za-z_:.-]+)\s*=\s*["']([^"']*)["']''',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(tag);
    for (final match in matches) {
      result[(match.group(1) ?? '').toLowerCase()] =
          _decodeHtmlEntities(match.group(2) ?? '');
    }
    return result;
  }

  static String _labelValue(String plainText, List<String> labels) {
    for (final label in labels) {
      final escaped = RegExp.escape(label);
      final pattern = RegExp(
        '$escaped\\s*[:\\-]?\\s*(.{1,180}?)(?=\\s{2,}|\\n|Brand Name|Company Name|Product Information|MRP|Maximum Retail Price|Goods and Service Tax|GST|FSSAI|Consumer Care|Net Weight|Net Content|HSN|Batch|Expiry|Manufactured|Marketed|Customer Care|Directions of Use|Warning Statement|Recommendations|Product Images|For Feedback|\\$)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(plainText);
      final value = (match?.group(1) ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value.isNotEmpty && value.length <= 180) return value;
    }
    return '';
  }

  static double _parseMoney(String raw) {
    final match = RegExp(r'(\d[\d,]*(?:\.\d{1,2})?)').firstMatch(raw);
    return double.tryParse((match?.group(1) ?? '').replaceAll(',', '')) ?? 0;
  }

  static double _parsePercent(String raw) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*%?').firstMatch(raw);
    final value = double.tryParse(match?.group(1) ?? '') ?? 0;
    return value >= 0 && value <= 100 ? value : 0;
  }

  static String _bestHeading(String html) {
    for (final tag in const <String>['h1', 'h2', 'h3', 'h4']) {
      final matches = RegExp(
        '<$tag[^>]*>(.*?)</$tag>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(html);
      for (final match in matches) {
        final value = _htmlText(match.group(1) ?? '');
        if (_plausibleProductName(value, '')) return value;
      }
    }
    return '';
  }

  static String _schemaText(Object? value) {
    if (value == null) return '';
    if (value is String || value is num) return value.toString().trim();
    if (value is Map) {
      for (final key in const <String>['name', 'value', '@value']) {
        final text = value[key]?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
    }
    if (value is List) {
      for (final item in value) {
        final text = _schemaText(item);
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  static String _schemaImage(Object? value) {
    if (value is String) return value.trim();
    if (value is List) {
      for (final item in value) {
        final text = _schemaImage(item);
        if (text.isNotEmpty) return text;
      }
    }
    if (value is Map) {
      return _firstNonEmpty(<Object?>[value['url'], value['contentUrl']]);
    }
    return '';
  }

  static Map<String, String> _metaTags(String html) {
    final result = <String, String>{};
    final tags = RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final tagMatch in tags) {
      final tag = tagMatch.group(0) ?? '';
      final attributes = _tagAttributes(tag);
      final key = (attributes['property'] ??
              attributes['name'] ??
              attributes['itemprop'] ??
              '')
          .toLowerCase();
      final content = attributes['content'] ?? '';
      if (key.isNotEmpty && content.isNotEmpty) {
        result[key] = content.trim();
      }
    }
    return result;
  }

  static String _pageTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    return _htmlText(match?.group(1) ?? '');
  }

  static String _cleanPageTitle(String raw, String host) {
    var value = _htmlText(raw).trim();
    if (value.isEmpty) return '';
    final parts = value.split(RegExp(r'\s+[|–—]\s+'));
    if (parts.length > 1 && parts.first.trim().length >= 4) {
      value = parts.first.trim();
    }
    final lower = value.toLowerCase();
    if (lower.startsWith('smart consumer - ') &&
        RegExp(r'^smart consumer - \d+$', caseSensitive: false).hasMatch(value)) {
      return '';
    }
    if (lower == 'smart consumer' || lower == 'verified by gs1') return '';
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _plausibleProductName(String value, String host) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length < 3 || clean.length > 180) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(clean)) return false;
    final lower = clean.toLowerCase();
    const rejected = <String>[
      'smart consumer',
      'verified by gs1',
      'barcode is invalid',
      'page not be found',
      'page not found',
      'access denied',
      'sign in',
      'login',
      'home page',
      'scan barcode',
      'registered office address',
      'experience smart consumer app',
      'product information',
      'company information',
    ];
    if (rejected.any((item) => lower == item || lower.startsWith('$item -'))) {
      return false;
    }
    return true;
  }

  static String _absoluteUrl(String raw, Uri baseUri) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final parsed = Uri.tryParse(value);
    if (parsed == null) return '';
    return (parsed.hasScheme ? parsed : baseUri.resolveUri(parsed)).toString();
  }

  static bool _looksLikeHttpUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
        (uri.scheme.toLowerCase() == 'http' || uri.scheme.toLowerCase() == 'https') &&
        uri.host.isNotEmpty;
  }

  static bool _isTrustedHttpUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !_looksLikeHttpUrl(raw)) return false;
    final host = uri.host.toLowerCase();
    return host == 'smartconsumer.org.in' ||
        host.endsWith('.smartconsumer.org.in') ||
        host == 'id.gs1.org' ||
        host.endsWith('.gs1.org') ||
        host == 'gs1.org';
  }

  static String _sourceForTrustedHost(String host) {
    final lower = host.toLowerCase();
    if (lower.contains('smartconsumer.org.in')) return 'GS1 India Smart Consumer';
    if (lower == 'id.gs1.org') return 'GS1 Digital Link';
    if (lower.endsWith('.gs1.org') || lower == 'gs1.org') return 'Verified by GS1';
    return 'Trusted product source';
  }

  static String? _extractGtinFromUri(Uri uri) {
    for (final key in const <String>['01', 'gtin', 'gtin13', 'gtin14', 'ean', 'upc']) {
      final normalized = _normalizeGtin(uri.queryParameters[key] ?? '');
      if (normalized != null) return normalized;
    }
    final pathMatch = RegExp(r'/01/(\d{8,14})(?:/|$)').firstMatch(uri.path);
    return _normalizeGtin(pathMatch?.group(1) ?? '');
  }

  static String? _extractGtinFromText(String text) {
    final decoded = _decodeHtmlEntities(_safeUriDecode(text));
    final patterns = <RegExp>[
      RegExp(r'/01/(\d{8,14})(?:/|[?#&]|$)'),
      RegExp(r'\(01\)\s*(\d{14})'),
      RegExp(r'Barcode\s*Number\s*\(GTIN\)\s*[:\-]?\s*(\d{8,14})', caseSensitive: false),
      RegExp(r'UNIQUE\s+PRODUCT\s+IDENTIFICATION\s+NUMBER\s*\(GTIN\)\s*(\d{8,14})', caseSensitive: false),
      RegExp(r'''["']gtin(?:8|12|13|14)?["']\s*:\s*["']?(\d{8,14})''', caseSensitive: false),
      RegExp(r'''(?:ean|upc|gtin)[^0-9]{0,20}(\d{8,14})''', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(decoded);
      final normalized = _normalizeGtin(match?.group(1) ?? '');
      if (normalized != null) return normalized;
    }
    return null;
  }

  String? validationIssue(String raw) {
    final code = raw.replaceAll(RegExp(r'\D'), '');
    if (code.isEmpty || !RegExp(r'^\d+$').hasMatch(code)) return null;
    if (const <int>{8, 12, 13, 14}.contains(code.length) &&
        !_validGtinChecksum(code)) {
      return 'Barcode could not be verified. Please scan it again or check the number.';
    }
    return null;
  }

  static String? _normalizeGtin(String raw) {
    final value = raw.replaceAll(RegExp(r'\D'), '');
    if (!const <int>{8, 12, 13, 14}.contains(value.length)) return null;
    return _validGtinChecksum(value) ? value : null;
  }

  static String _toGtin14(String gtin) {
    final digits = gtin.replaceAll(RegExp(r'\D'), '');
    return digits.padLeft(14, '0');
  }

  static bool _validGtinChecksum(String code) {
    if (!RegExp(r'^\d+$').hasMatch(code) || code.length < 2) return false;
    var sum = 0;
    var multiplier = 3;
    for (var i = code.length - 2; i >= 0; i--) {
      sum += int.parse(code[i]) * multiplier;
      multiplier = multiplier == 3 ? 1 : 3;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(code[code.length - 1]);
  }

  static String _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _safeUriDecode(String raw) {
    try {
      return Uri.decodeFull(raw);
    } catch (_) {
      return raw;
    }
  }

  static String _decodeHtmlEntities(String raw) {
    return raw
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'&#(\d+);'), ' ');
  }

  static String _htmlText(String raw) {
    var text = raw
        .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(?:p|div|li|tr|h1|h2|h3|h4|section)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _decodeHtmlEntities(text);
    text = text
        .replaceAll('\r', '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
    return text;
  }

  static String _extractPackSize(String text) {
    final match = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(kg|g|gm|gram|grams|mg|l|litre|liter|ml|millilitre|milliliter|pcs|pieces|count|ct)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return '';
    return '${match.group(1)} ${match.group(2)}'.trim();
  }

  static String _mapCategory(String raw) {
    final value = raw.toLowerCase();
    if (RegExp(r'medicine|drug|tablet|capsule|syrup|pharma|medical').hasMatch(value)) {
      return 'Medicines';
    }
    if (RegExp(r'fruit|vegetable|fresh produce').hasMatch(value)) return 'Fruits & Vegetables';
    if (RegExp(r'milk|dairy|paneer|curd|cheese|butter').hasMatch(value)) return 'Dairy';
    if (RegExp(r'bread|bakery|cake|biscuit|cookie|snack|noodle|food|grocery|beverage|drink').hasMatch(value)) {
      return 'Grocery / FMCG';
    }
    if (RegExp(r'cosmetic|beauty|personal care|shampoo|soap|cream|lotion').hasMatch(value)) {
      return 'Personal Care';
    }
    if (RegExp(r'mobile|phone|electronics|charger|earphone').hasMatch(value)) return 'Electronics';
    if (RegExp(r'auto|vehicle|car|bike|spare|engine oil').hasMatch(value)) return 'Auto Parts';
    if (RegExp(r'shirt|shoe|footwear|clothing|apparel').hasMatch(value)) return 'Clothing / Footwear';
    return 'General';
  }
}

class _TrustedHttpSession {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 7)
    ..autoUncompress = true;
  final Map<String, String> _cookies = <String, String>{};

  Future<_FetchedPage?> get(Uri uri) => _request('GET', uri);

  Future<_FetchedPage?> submitForm(_DiscoveredForm form, String value) async {
    final fields = <String, String>{...form.fields, form.inputName: value};
    if (form.method == 'post') {
      return _request('POST', form.action, fields: fields);
    }
    final query = <String, String>{...form.action.queryParameters, ...fields};
    return _request('GET', form.action.replace(queryParameters: query));
  }

  Future<_FetchedPage?> _request(
    String method,
    Uri uri, {
    Map<String, String>? fields,
    int redirects = 0,
  }) async {
    if (redirects > 8) return null;
    try {
      final HttpClientRequest request = method == 'POST'
          ? await _client.postUrl(uri).timeout(const Duration(seconds: 9))
          : await _client.getUrl(uri).timeout(const Duration(seconds: 9));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ProfitGPS/1.0',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.6',
      );
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-IN,en;q=0.9');
      if (_cookies.isNotEmpty) {
        request.headers.set(
          HttpHeaders.cookieHeader,
          _cookies.entries.map((entry) => '${entry.key}=${entry.value}').join('; '),
        );
      }
      if (method == 'POST' && fields != null) {
        final body = fields.entries
            .map((entry) =>
                '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
            .join('&');
        request.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        request.write(body);
      }

      final response = await request.close().timeout(const Duration(seconds: 12));
      for (final cookie in response.cookies) {
        _cookies[cookie.name] = cookie.value;
      }

      if (response.isRedirect && response.headers.value(HttpHeaders.locationHeader) != null) {
        await response.drain();
        final next = uri.resolve(response.headers.value(HttpHeaders.locationHeader)!);
        final nextMethod = response.statusCode == HttpStatus.temporaryRedirect ||
                response.statusCode == HttpStatus.permanentRedirect
            ? method
            : 'GET';
        return _request(
          nextMethod,
          next,
          fields: nextMethod == 'POST' ? fields : null,
          redirects: redirects + 1,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain();
        return null;
      }

      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
      return _FetchedPage(body: body, finalUri: uri);
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close(force: true);
}

class _FetchedPage {
  const _FetchedPage({required this.body, required this.finalUri});
  final String body;
  final Uri finalUri;
}

class _DiscoveredForm {
  const _DiscoveredForm({
    required this.action,
    required this.method,
    required this.inputName,
    required this.fields,
  });
  final Uri action;
  final String method;
  final String inputName;
  final Map<String, String> fields;
}

class _ResolvedPageProduct {
  const _ResolvedPageProduct({
    this.name = '',
    this.brand = '',
    this.category = '',
    this.packageSize = '',
    this.imageUrl = '',
    this.description = '',
  });

  final String name;
  final String brand;
  final String category;
  final String packageSize;
  final String imageUrl;
  final String description;
}
