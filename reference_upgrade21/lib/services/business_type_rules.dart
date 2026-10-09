class BusinessFieldDefinition {
  const BusinessFieldDefinition(
    this.key,
    this.label, {
    this.hint = '',
    this.required = false,
  });

  final String key;
  final String label;
  final String hint;
  final bool required;
}

class BusinessProductRule {
  const BusinessProductRule({
    this.fields = const <BusinessFieldDefinition>[],
    this.defaultTracking = const <String, bool>{},
    this.requiredTracking = const <String>{},
    this.preferredUnits = const <String>[],
    this.note = '',
  });

  final List<BusinessFieldDefinition> fields;
  final Map<String, bool> defaultTracking;
  final Set<String> requiredTracking;
  final List<String> preferredUnits;
  final String note;
}

class BusinessTypeRules {
  static const List<String> supportedTypes = [
    'General Retail',
    'Pharmacy / Medical',
    'Auto Spare Parts',
    'Jewellery / Precious Metals',
    'Hardware / Electrical',
    'Electronics / Mobile',
    'Clothing / Footwear',
    'Bakery / Food Production',
    'Wholesale / Distributor',
    'Stationery / Books',
    'Cosmetics / Personal Care',
    'Other / Custom',
  ];

  static const List<String> generalRetailModules = [
    'Grocery / FMCG',
    'Fruits / Vegetables',
    'Dairy',
    'Bakery',
    'Household',
    'Personal Care',
    'Stationery',
    'General',
  ];

  static String canonicalType(String type) {
    if (type == 'Supermarket / Grocery' || type == 'Fruits / Vegetables') {
      return 'General Retail';
    }
    return supportedTypes.contains(type) ? type : 'General Retail';
  }

  static String description(String rawType) {
    final type = canonicalType(rawType);
    switch (type) {
      case 'General Retail':
        return 'One retail profile with optional Grocery/FMCG, Fruits & Vegetables, Dairy, Bakery, Household, Personal Care and Stationery modules. Fields change again by category and subcategory.';
      case 'Pharmacy / Medical':
        return 'Medicine, OTC, surgical/consumable and medical-device rules are separated so device products never inherit medicine-only dosage fields.';
      case 'Auto Spare Parts':
        return 'Part/OEM/vehicle logic for components, with separate lubricant, tyre, battery and accessory rules.';
      case 'Jewellery / Precious Metals':
        return 'Purity, weight, tag/certificate, making-charge and wastage focused product logic for precious-metal stock.';
      case 'Hardware / Electrical':
        return 'Specification, size, rating and unit-driven inventory for hardware, electrical, plumbing, tools, cables, lighting and fasteners.';
      case 'Electronics / Mobile':
        return 'Model/variant/warranty logic with optional serial or IMEI tracking only for products that need per-unit identity.';
      case 'Clothing / Footwear':
        return 'Style, size, colour and variant-driven stock, without forcing apparel fields onto unrelated accessories.';
      case 'Bakery / Food Production':
        return 'Own-production, recipe/production cost, batch, production date, shelf-life and expiry logic where applicable.';
      case 'Wholesale / Distributor':
        return 'Case/box/pack conversions, bulk rates, schemes/free quantity and credit-oriented product handling.';
      case 'Stationery / Books':
        return 'Stationery and book-specific identifiers such as brand, publisher, author and ISBN where relevant.';
      case 'Cosmetics / Personal Care':
        return 'Brand, shade/variant, size/volume and optional batch/expiry rules based on the actual cosmetic category.';
      case 'Other / Custom':
        return 'Common ProfitGPS workflow with configurable attributes and per-product tracking overrides.';
      default:
        return 'Adaptive ProfitGPS business profile.';
    }
  }

  static List<String> categoriesFor(
    String rawType, {
    List<String>? enabledRetailModules,
  }) {
    final type = canonicalType(rawType);
    switch (type) {
      case 'General Retail':
        final enabled = (enabledRetailModules == null || enabledRetailModules.isEmpty)
            ? generalRetailModules
            : enabledRetailModules;
        final result = <String>[];
        for (final module in generalRetailModules) {
          if (enabled.contains(module)) result.add(module);
        }
        if (!result.contains('General')) result.add('General');
        return result;
      case 'Pharmacy / Medical':
        return [
          'Medicines',
          'OTC / Wellness',
          'Surgical / Consumables',
          'Medical Devices',
          'Baby Care',
          'Personal Care',
          'General',
        ];
      case 'Auto Spare Parts':
        return [
          'Engine / Mechanical',
          'Brakes',
          'Filters',
          'Lubricants / Fluids',
          'Electrical',
          'Battery',
          'Tyres / Wheels',
          'Suspension / Steering',
          'Body / Exterior',
          'Accessories',
          'General',
        ];
      case 'Jewellery / Precious Metals':
        return ['Gold', 'Silver', 'Diamond / Gemstone', 'Platinum', 'Coins / Bars', 'Imitation / Other', 'General'];
      case 'Hardware / Electrical':
        return ['Hardware', 'Electrical', 'Cables / Wires', 'Lighting', 'Plumbing', 'Fasteners', 'Tools', 'Paint / Adhesives', 'General'];
      case 'Electronics / Mobile':
        return ['Mobile Phones', 'Computers / Tablets', 'Accessories', 'Audio', 'Appliances', 'Storage / Components', 'Cables / Chargers', 'General'];
      case 'Clothing / Footwear':
        return ['Apparel', 'Footwear', 'Innerwear', 'Fashion Accessories', 'Bags / Luggage', 'General'];
      case 'Bakery / Food Production':
        return ['Own Production', 'Bread', 'Cakes / Pastry', 'Snacks', 'Prepared Food', 'Beverages', 'Ingredients / Packaging', 'General'];
      case 'Wholesale / Distributor':
        return ['FMCG', 'Food', 'Beverages', 'Household', 'Personal Care', 'Industrial', 'General'];
      case 'Stationery / Books':
        return ['Stationery', 'Books', 'Notebooks', 'Office Supplies', 'School Supplies', 'Art Supplies', 'General'];
      case 'Cosmetics / Personal Care':
        return ['Skin Care', 'Hair Care', 'Makeup', 'Fragrance', 'Personal Care', 'Beauty Tools', 'General'];
      default:
        return ['General', 'Other'];
    }
  }

  static List<String> subcategoriesFor(String rawType, String category) {
    final type = canonicalType(rawType);
    if (type == 'General Retail') {
      switch (category) {
        case 'Grocery / FMCG': return ['Packaged Food', 'Snacks', 'Beverages', 'Staples', 'Frozen / Chilled', 'Other FMCG'];
        case 'Fruits / Vegetables': return ['Loose Fresh Produce', 'Packed Produce', 'Leafy Greens / Herbs', 'Cut / Prepared Produce'];
        case 'Dairy': return ['Milk', 'Curd / Yogurt', 'Paneer / Cheese', 'Butter / Ghee', 'Ice Cream / Frozen Dairy', 'Other Dairy'];
        case 'Bakery': return ['Fresh / Own Bakery', 'Packaged Bakery', 'Bread', 'Cake / Pastry', 'Snacks'];
        case 'Household': return ['Cleaning', 'Kitchen / Home', 'Disposable / Utility', 'Other Household'];
        case 'Personal Care': return ['Oral Care', 'Skin Care', 'Hair Care', 'Bath / Hygiene', 'Other Personal Care'];
        case 'Stationery': return ['Writing', 'Paper / Notebook', 'Office / School', 'Art / Craft', 'Other Stationery'];
      }
    }
    if (type == 'Pharmacy / Medical') {
      switch (category) {
        case 'Medicines': return ['Tablet / Capsule', 'Syrup / Suspension', 'Injection', 'Drops', 'Cream / Ointment / Gel', 'Inhaler', 'Powder / Sachet', 'Other Medicine'];
        case 'OTC / Wellness': return ['OTC Medicine', 'Supplement / Nutrition', 'Health Drink', 'Wellness Product'];
        case 'Surgical / Consumables': return ['Syringe / Needle', 'Gloves / Mask / PPE', 'Dressing / Bandage', 'Catheter / Tubing', 'Test / Lab Consumable', 'Other Consumable'];
        case 'Medical Devices': return ['Diagnostic Device', 'Monitoring Device', 'Durable Medical Equipment', 'Thermometer / Meter', 'Other Device'];
        case 'Baby Care': return ['Baby Food / Nutrition', 'Diaper / Hygiene', 'Baby Skin Care', 'Other Baby Care'];
        case 'Personal Care': return ['Skin / Hair', 'Oral Care', 'Hygiene', 'Other Personal Care'];
      }
    }
    if (type == 'Auto Spare Parts') {
      switch (category) {
        case 'Lubricants / Fluids': return ['Engine Oil', 'Gear / Transmission Oil', 'Brake Fluid', 'Coolant', 'Grease / Other Fluid'];
        case 'Battery': return ['Car Battery', 'Two-Wheeler Battery', 'Commercial Battery'];
        case 'Tyres / Wheels': return ['Tyre', 'Tube', 'Wheel / Rim'];
        case 'Filters': return ['Oil Filter', 'Air Filter', 'Fuel Filter', 'Cabin Filter'];
        case 'Electrical': return ['Sensor', 'Bulb / Lamp', 'Relay / Fuse', 'Starter / Alternator', 'Other Electrical'];
      }
      return ['Vehicle-specific Part', 'Universal Part', 'Kit / Assembly'];
    }
    if (type == 'Jewellery / Precious Metals') {
      return ['Ring', 'Chain / Necklace', 'Bangle / Bracelet', 'Earring', 'Pendant', 'Anklet', 'Coin / Bar', 'Loose Stone', 'Other Ornament'];
    }
    if (type == 'Hardware / Electrical') {
      switch (category) {
        case 'Cables / Wires': return ['Electrical Wire', 'Power Cable', 'Data / Communication Cable', 'Flexible / Other Cable'];
        case 'Lighting': return ['Bulb', 'Tube / Batten', 'Fixture', 'Driver / Accessory'];
        case 'Plumbing': return ['Pipe', 'Fitting', 'Valve / Tap', 'Sanitary Accessory'];
        case 'Fasteners': return ['Screw', 'Bolt / Nut', 'Nail', 'Anchor / Other Fastener'];
        case 'Tools': return ['Hand Tool', 'Power Tool', 'Measuring Tool', 'Accessory'];
      }
      return ['General Item'];
    }
    if (type == 'Electronics / Mobile') {
      switch (category) {
        case 'Mobile Phones': return ['Smartphone', 'Feature Phone'];
        case 'Computers / Tablets': return ['Laptop', 'Desktop', 'Tablet', 'Monitor'];
        case 'Accessories': return ['Case / Cover', 'Earphone / Headset', 'Power Bank', 'Wearable', 'Other Accessory'];
        case 'Storage / Components': return ['SSD / HDD', 'RAM', 'Memory Card', 'Computer Component'];
        case 'Cables / Chargers': return ['Charger / Adapter', 'USB / Data Cable', 'Power Cable', 'Other Cable'];
      }
      return ['General Electronics'];
    }
    if (type == 'Clothing / Footwear') {
      switch (category) {
        case 'Apparel': return ['T-Shirt / Shirt', 'Trouser / Jeans', 'Dress / Kurti', 'Saree / Ethnic', 'Kids Apparel', 'Other Apparel'];
        case 'Footwear': return ['Shoes', 'Sandal / Slipper', 'Formal Footwear', 'Kids Footwear'];
        case 'Innerwear': return ['Top / Vest', 'Bottom', 'Set'];
        case 'Fashion Accessories': return ['Belt', 'Cap / Hat', 'Scarf / Dupatta', 'Wallet', 'Other Accessory'];
      }
    }
    if (type == 'Bakery / Food Production') {
      switch (category) {
        case 'Own Production': return ['Fresh Baked', 'Prepared Food', 'Packaged Own Product'];
        case 'Ingredients / Packaging': return ['Ingredient', 'Packaging Material'];
        case 'Bread': return ['Fresh Bread', 'Packaged Bread'];
        case 'Cakes / Pastry': return ['Cake', 'Pastry', 'Dessert'];
      }
    }
    if (type == 'Stationery / Books' && category == 'Books') {
      return ['Book / Textbook', 'Reference / Exam', 'Novel / General Book', 'Magazine / Periodical'];
    }
    if (type == 'Cosmetics / Personal Care') {
      switch (category) {
        case 'Makeup': return ['Foundation / Base', 'Lip', 'Eye', 'Nail', 'Other Makeup'];
        case 'Fragrance': return ['Perfume', 'Deodorant / Body Spray', 'Attar / Other'];
        case 'Skin Care': return ['Cream / Lotion', 'Serum', 'Cleanser', 'Sunscreen', 'Other Skin Care'];
        case 'Hair Care': return ['Shampoo / Conditioner', 'Oil / Serum', 'Colour / Treatment', 'Other Hair Care'];
      }
    }
    return ['General'];
  }

  static List<String> unitsFor(
    String rawType, {
    String category = '',
    String subcategory = '',
  }) {
    final type = canonicalType(rawType);
    final ruleUnits = ruleFor(type, category, subcategory).preferredUnits;
    final common = <String>['pcs', 'pack', 'box', 'kg', 'g', 'L', 'ml'];
    final extra = switch (type) {
      'General Retail' => <String>['bunch', 'crate', 'bag', 'bottle', 'tray', 'pair', 'set'],
      'Hardware / Electrical' => <String>['m', 'ft', 'roll', 'bundle', 'set', 'pair'],
      'Clothing / Footwear' => <String>['pair', 'set'],
      'Wholesale / Distributor' => <String>['carton', 'case', 'bag', 'bottle', 'bundle'],
      'Bakery / Food Production' => <String>['tray', 'slice', 'portion'],
      'Auto Spare Parts' => <String>['set', 'pair', 'kit', 'bottle'],
      'Jewellery / Precious Metals' => <String>['g', 'mg', 'pcs', 'pair', 'set'],
      _ => <String>[],
    };
    return <String>{...ruleUnits, ...common, ...extra}.toList();
  }

  static String defaultUnitFor(
    String rawType, {
    String category = '',
    String subcategory = '',
  }) {
    final units = ruleFor(rawType, category, subcategory).preferredUnits;
    if (units.isNotEmpty) return units.first;
    if (canonicalType(rawType) == 'Jewellery / Precious Metals') return 'g';
    return 'pcs';
  }

  static bool shouldDefaultWeighted(
    String rawType,
    String unit, {
    String category = '',
    String subcategory = '',
  }) {
    final tracking = trackingDefaults(rawType, category, subcategory);
    if (tracking['weight'] == true) return true;
    return const {'kg', 'g', 'mg', 'L', 'ml', 'm', 'ft'}.contains(unit) &&
        (category == 'Fruits / Vegetables' || canonicalType(rawType) == 'Jewellery / Precious Metals');
  }

  static BusinessProductRule ruleFor(
    String rawType,
    String category,
    String subcategory,
  ) {
    final type = canonicalType(rawType);

    if (type == 'Pharmacy / Medical') {
      if (category == 'Medicines') {
        return BusinessProductRule(
          fields: const [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('manufacturer', 'Manufacturer', required: true),
            BusinessFieldDefinition('genericName', 'Generic / salt name'),
            BusinessFieldDefinition('strengthComposition', 'Strength / composition', hint: 'e.g. 500 mg / active composition', required: true),
            BusinessFieldDefinition('dosageForm', 'Dosage form', hint: 'Tablet, capsule, syrup, injection, cream...', required: true),
            BusinessFieldDefinition('packageSize', 'Pack size', hint: 'e.g. strip of 10 / 100 ml', required: true),
          ],
          defaultTracking: const {'batch': true, 'expiry': true},
          requiredTracking: const {'batch', 'expiry'},
          preferredUnits: const ['pack', 'pcs'],
          note: 'Medicine rule: batch and expiry are mandatory. Device-only fields stay hidden.',
        );
      }
      if (category == 'Medical Devices') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand', required: true),
            BusinessFieldDefinition('manufacturer', 'Manufacturer'),
            BusinessFieldDefinition('modelNumber', 'Model / version', required: true),
            BusinessFieldDefinition('catalogNumber', 'Catalogue / device code'),
            BusinessFieldDefinition('deviceSize', 'Device size / specification'),
            BusinessFieldDefinition('warranty', 'Warranty'),
          ],
          defaultTracking: {'serial': true},
          preferredUnits: ['pcs'],
          note: 'Medical device rule: no dosage or strength fields. Serial/batch/expiry can be overridden per device.',
        );
      }
      if (category == 'Surgical / Consumables') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('manufacturer', 'Manufacturer'),
            BusinessFieldDefinition('specification', 'Size / specification', required: true),
            BusinessFieldDefinition('packageSize', 'Pack size'),
          ],
          defaultTracking: {'batch': true, 'expiry': true},
          preferredUnits: ['pcs', 'pack', 'box'],
          note: 'Consumables often use batch/expiry, but the product override can turn them off when not applicable.',
        );
      }
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('brand', 'Brand'),
          BusinessFieldDefinition('manufacturer', 'Manufacturer'),
          BusinessFieldDefinition('packageSize', 'Pack size / volume'),
        ],
        defaultTracking: {'batch': true, 'expiry': true},
        preferredUnits: ['pack', 'pcs', 'bottle'],
      );
    }

    if (type == 'General Retail') {
      if (category == 'Fruits / Vegetables') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('variety', 'Variety'),
            BusinessFieldDefinition('grade', 'Grade / quality'),
            BusinessFieldDefinition('sourceType', 'Source / farmer / market'),
            BusinessFieldDefinition('wastagePercent', 'Typical wastage %'),
          ],
          defaultTracking: {'weight': true, 'wastage': true},
          preferredUnits: ['kg', 'g', 'pcs', 'bunch', 'crate'],
          note: 'Fresh produce uses weight/daily-rate/wastage logic. Expiry is not forced unless it is packed produce.',
        );
      }
      if (category == 'Dairy') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('packageSize', 'Pack size / volume', required: true),
          ],
          defaultTracking: {'batch': true, 'expiry': true},
          requiredTracking: {'expiry'},
          preferredUnits: ['pack', 'bottle', 'L', 'ml', 'pcs'],
        );
      }
      if (category == 'Bakery') {
        final own = subcategory == 'Fresh / Own Bakery';
        return BusinessProductRule(
          fields: const [
            BusinessFieldDefinition('brand', 'Brand / line'),
            BusinessFieldDefinition('flavourVariant', 'Flavour / variant'),
            BusinessFieldDefinition('packageSize', 'Pack / portion size'),
            BusinessFieldDefinition('shelfLife', 'Shelf life'),
          ],
          defaultTracking: {'batch': true, 'expiry': true, 'production': own},
          preferredUnits: const ['pcs', 'pack', 'box', 'tray'],
        );
      }
      if (category == 'Grocery / FMCG') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('packageSize', 'Pack size', hint: 'e.g. 1 L, 500 g, 12 pcs', required: true),
            BusinessFieldDefinition('flavourVariant', 'Flavour / variant'),
          ],
          defaultTracking: {'batch': true, 'expiry': true},
          preferredUnits: ['pack', 'pcs', 'box', 'kg', 'g', 'L', 'ml'],
          note: 'Batch/expiry defaults are enabled for packaged FMCG but can be disabled for products where they do not apply.',
        );
      }
      if (category == 'Personal Care') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('packageSize', 'Size / volume'),
            BusinessFieldDefinition('shadeVariant', 'Variant / shade / fragrance'),
          ],
          defaultTracking: {'batch': true, 'expiry': true},
          preferredUnits: ['pcs', 'pack', 'bottle', 'ml', 'g'],
        );
      }
      if (category == 'Stationery') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brandPublisher', 'Brand / publisher'),
            BusinessFieldDefinition('sizeVariant', 'Size / variant'),
          ],
          preferredUnits: ['pcs', 'pack', 'box', 'set'],
        );
      }
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('brand', 'Brand'),
          BusinessFieldDefinition('modelNumber', 'Model / variant'),
          BusinessFieldDefinition('packageSize', 'Pack / size'),
        ],
        preferredUnits: ['pcs', 'pack', 'box'],
      );
    }

    if (type == 'Auto Spare Parts') {
      if (category == 'Lubricants / Fluids') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand', required: true),
            BusinessFieldDefinition('viscosityGrade', 'Grade / viscosity', hint: 'e.g. 5W-30 / DOT 4', required: true),
            BusinessFieldDefinition('packageSize', 'Volume / pack size', required: true),
            BusinessFieldDefinition('specification', 'Specification / approval'),
            BusinessFieldDefinition('vehicleCompatibility', 'Vehicle compatibility'),
          ],
          defaultTracking: {'batch': true},
          preferredUnits: ['L', 'ml', 'bottle', 'pack'],
        );
      }
      if (category == 'Tyres / Wheels') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand', required: true),
            BusinessFieldDefinition('partNumber', 'Part / pattern no.'),
            BusinessFieldDefinition('tyreSize', 'Tyre / wheel size', hint: 'e.g. 195/65 R15', required: true),
            BusinessFieldDefinition('loadSpeedRating', 'Load / speed rating'),
            BusinessFieldDefinition('vehicleCompatibility', 'Vehicle compatibility'),
          ],
          defaultTracking: {'serial': true},
          preferredUnits: ['pcs', 'pair', 'set'],
        );
      }
      if (category == 'Battery') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand', required: true),
            BusinessFieldDefinition('partNumber', 'Model / part number', required: true),
            BusinessFieldDefinition('batteryRating', 'Capacity / voltage', hint: 'e.g. 60Ah 12V', required: true),
            BusinessFieldDefinition('warranty', 'Warranty'),
            BusinessFieldDefinition('vehicleCompatibility', 'Vehicle compatibility'),
          ],
          defaultTracking: {'serial': true},
          preferredUnits: ['pcs'],
        );
      }
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('brand', 'Brand'),
          BusinessFieldDefinition('partNumber', 'Part number', required: true),
          BusinessFieldDefinition('oemReference', 'OEM / OE reference no.'),
          BusinessFieldDefinition('vehicleMake', 'Vehicle make'),
          BusinessFieldDefinition('vehicleModel', 'Vehicle model'),
          BusinessFieldDefinition('vehicleCompatibility', 'Vehicle compatibility / year', required: true),
          BusinessFieldDefinition('warranty', 'Warranty'),
        ],
        preferredUnits: ['pcs', 'set', 'pair', 'kit'],
      );
    }

    if (type == 'Jewellery / Precious Metals') {
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('ornamentType', 'Ornament / item type', required: true),
          BusinessFieldDefinition('metalType', 'Metal type', required: true),
          BusinessFieldDefinition('purity', 'Purity / karat', hint: 'e.g. 22K / 916 / 925', required: true),
          BusinessFieldDefinition('grossWeight', 'Gross weight (g)', required: true),
          BusinessFieldDefinition('stoneWeight', 'Stone weight (g)'),
          BusinessFieldDefinition('netWeight', 'Net metal weight (g)', required: true),
          BusinessFieldDefinition('makingCharge', 'Making charge'),
          BusinessFieldDefinition('wastagePercent', 'Wastage %'),
          BusinessFieldDefinition('tagNumber', 'Tag / item number', required: true),
          BusinessFieldDefinition('certificateNumber', 'Hallmark / certificate no.'),
        ],
        defaultTracking: {'weight': true, 'serial': true},
        requiredTracking: {'weight'},
        preferredUnits: ['g', 'pcs'],
        note: 'Jewellery uses local item/tag identity. Public barcode lookup is not treated as the source of weight, purity or making-charge data.',
      );
    }

    if (type == 'Electronics / Mobile') {
      if (category == 'Mobile Phones') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand', required: true),
            BusinessFieldDefinition('modelNumber', 'Model', required: true),
            BusinessFieldDefinition('storage', 'Storage'),
            BusinessFieldDefinition('ram', 'RAM'),
            BusinessFieldDefinition('color', 'Colour'),
            BusinessFieldDefinition('warranty', 'Warranty'),
          ],
          defaultTracking: {'serial': true, 'variant': true},
          requiredTracking: {'serial'},
          preferredUnits: ['pcs'],
        );
      }
      if (category == 'Accessories' || category == 'Cables / Chargers') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('modelNumber', 'Model / reference'),
            BusinessFieldDefinition('compatibility', 'Compatibility'),
            BusinessFieldDefinition('specification', 'Specification / wattage / connector'),
            BusinessFieldDefinition('warranty', 'Warranty'),
          ],
          preferredUnits: ['pcs', 'pack'],
          note: 'Accessory rule: IMEI/serial is not forced.',
        );
      }
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('brand', 'Brand', required: true),
          BusinessFieldDefinition('modelNumber', 'Model', required: true),
          BusinessFieldDefinition('specification', 'Variant / specification'),
          BusinessFieldDefinition('color', 'Colour'),
          BusinessFieldDefinition('warranty', 'Warranty'),
        ],
        defaultTracking: {'serial': true},
        preferredUnits: ['pcs'],
      );
    }

    if (type == 'Clothing / Footwear') {
      if (category == 'Fashion Accessories' || category == 'Bags / Luggage') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('styleVariant', 'Style / variant', required: true),
            BusinessFieldDefinition('color', 'Colour'),
            BusinessFieldDefinition('material', 'Material'),
            BusinessFieldDefinition('size', 'Size / dimension'),
          ],
          defaultTracking: {'variant': true},
          preferredUnits: ['pcs', 'pair', 'set'],
        );
      }
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('brand', 'Brand'),
          BusinessFieldDefinition('styleVariant', 'Style / design', required: true),
          BusinessFieldDefinition('gender', 'Gender / segment'),
          BusinessFieldDefinition('size', 'Size', required: true),
          BusinessFieldDefinition('color', 'Colour', required: true),
          BusinessFieldDefinition('material', 'Material'),
        ],
        defaultTracking: {'variant': true},
        requiredTracking: {'variant'},
        preferredUnits: ['pcs', 'pair', 'set'],
      );
    }

    if (type == 'Hardware / Electrical') {
      if (category == 'Cables / Wires') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('specification', 'Type / conductor specification', required: true),
            BusinessFieldDefinition('size', 'Gauge / size', hint: 'e.g. 2.5 sq mm', required: true),
            BusinessFieldDefinition('voltageRating', 'Voltage / rating'),
            BusinessFieldDefinition('modelNumber', 'Model / reference'),
          ],
          defaultTracking: {'unitConversion': true},
          preferredUnits: ['m', 'ft', 'roll', 'bundle'],
        );
      }
      if (category == 'Lighting' || category == 'Electrical') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('brand', 'Brand'),
            BusinessFieldDefinition('specification', 'Specification', required: true),
            BusinessFieldDefinition('voltageRating', 'Voltage / wattage / amp rating'),
            BusinessFieldDefinition('size', 'Size'),
            BusinessFieldDefinition('modelNumber', 'Model / reference'),
            BusinessFieldDefinition('warranty', 'Warranty'),
          ],
          preferredUnits: ['pcs', 'box', 'pack'],
        );
      }
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('brand', 'Brand'),
          BusinessFieldDefinition('specification', 'Specification / size', required: true),
          BusinessFieldDefinition('size', 'Size / dimension'),
          BusinessFieldDefinition('modelNumber', 'Model / reference'),
        ],
        preferredUnits: ['pcs', 'box', 'kg', 'm', 'ft', 'roll', 'bundle', 'set'],
      );
    }

    if (type == 'Bakery / Food Production') {
      final ingredient = category == 'Ingredients / Packaging';
      return BusinessProductRule(
        fields: [
          const BusinessFieldDefinition('brand', 'Brand / line'),
          const BusinessFieldDefinition('flavourVariant', 'Flavour / variant'),
          const BusinessFieldDefinition('packageSize', 'Pack / portion size'),
          if (!ingredient) const BusinessFieldDefinition('shelfLife', 'Shelf life', required: true),
          if (!ingredient) const BusinessFieldDefinition('recipeCostRef', 'Recipe / production reference'),
        ],
        defaultTracking: ingredient ? const {} : const {'batch': true, 'expiry': true, 'production': true},
        requiredTracking: ingredient ? const {} : const {'expiry'},
        preferredUnits: ingredient ? const ['kg', 'g', 'L', 'ml', 'pack', 'box'] : const ['pcs', 'pack', 'box', 'tray'],
      );
    }

    if (type == 'Wholesale / Distributor') {
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('brand', 'Brand'),
          BusinessFieldDefinition('packageSize', 'Case / pack size', required: true),
          BusinessFieldDefinition('caseConversion', 'Case → selling-unit conversion', required: true),
          BusinessFieldDefinition('minimumOrderQty', 'MOQ'),
          BusinessFieldDefinition('wholesaleRate', 'Wholesale rate'),
          BusinessFieldDefinition('retailerRate', 'Retailer rate'),
          BusinessFieldDefinition('scheme', 'Scheme / free quantity'),
        ],
        defaultTracking: {'unitConversion': true},
        requiredTracking: {'unitConversion'},
        preferredUnits: ['case', 'carton', 'box', 'pack', 'pcs'],
      );
    }

    if (type == 'Stationery / Books') {
      if (category == 'Books') {
        return const BusinessProductRule(
          fields: [
            BusinessFieldDefinition('bookTitle', 'Book title'),
            BusinessFieldDefinition('author', 'Author'),
            BusinessFieldDefinition('brandPublisher', 'Publisher', required: true),
            BusinessFieldDefinition('isbnModel', 'ISBN / EAN', required: true),
            BusinessFieldDefinition('edition', 'Edition / class / subject'),
          ],
          preferredUnits: ['pcs', 'set'],
        );
      }
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('brandPublisher', 'Brand / publisher'),
          BusinessFieldDefinition('isbnModel', 'Model / item code'),
          BusinessFieldDefinition('sizeVariant', 'Size / variant'),
        ],
        preferredUnits: ['pcs', 'pack', 'box', 'set'],
      );
    }

    if (type == 'Cosmetics / Personal Care') {
      final expiryDefault = category != 'Beauty Tools';
      return BusinessProductRule(
        fields: const [
          BusinessFieldDefinition('brand', 'Brand', required: true),
          BusinessFieldDefinition('shadeVariant', 'Shade / variant / fragrance'),
          BusinessFieldDefinition('packageSize', 'Size / volume'),
          BusinessFieldDefinition('manufacturer', 'Manufacturer'),
        ],
        defaultTracking: {'batch': expiryDefault, 'expiry': expiryDefault},
        preferredUnits: const ['pcs', 'pack', 'bottle', 'ml', 'g'],
      );
    }

    if (type == 'Other / Custom') {
      return const BusinessProductRule(
        fields: [
          BusinessFieldDefinition('attribute1', 'Custom attribute 1'),
          BusinessFieldDefinition('attribute2', 'Custom attribute 2'),
          BusinessFieldDefinition('attribute3', 'Custom attribute 3'),
        ],
        preferredUnits: ['pcs', 'pack', 'box', 'kg', 'g', 'L', 'ml'],
      );
    }

    return const BusinessProductRule(
      fields: [
        BusinessFieldDefinition('brand', 'Brand'),
        BusinessFieldDefinition('variant', 'Variant / model'),
      ],
      preferredUnits: ['pcs'],
    );
  }

  static List<BusinessFieldDefinition> fieldsFor(
    String rawType, {
    String category = 'General',
    String subcategory = '',
  }) => ruleFor(rawType, category, subcategory).fields;

  static Map<String, bool> trackingDefaults(
    String rawType,
    String category,
    String subcategory,
  ) => Map<String, bool>.from(ruleFor(rawType, category, subcategory).defaultTracking);

  static Set<String> requiredTracking(
    String rawType,
    String category,
    String subcategory,
  ) => Set<String>.from(ruleFor(rawType, category, subcategory).requiredTracking);

  static Map<String, bool> resolvedTracking(
    String rawType,
    String category,
    String subcategory,
    Map<String, bool> overrides,
  ) {
    final result = trackingDefaults(rawType, category, subcategory);
    for (final entry in overrides.entries) {
      result[entry.key] = entry.value;
    }
    return result;
  }

  static String displayAttributeLabel(
    String rawType,
    String key, {
    String category = 'General',
    String subcategory = '',
  }) {
    for (final field in fieldsFor(rawType, category: category, subcategory: subcategory)) {
      if (field.key == key) return field.label;
    }
    const known = <String, String>{
      'brand': 'Brand',
      'manufacturer': 'Manufacturer',
      'packageSize': 'Pack size',
      'serialNumber': 'Serial / IMEI',
      'batchNo': 'Batch / lot',
      'variant': 'Variant',
      'grossWeight': 'Gross weight',
      'netWeight': 'Net weight',
      'tagNumber': 'Tag number',
    };
    if (known.containsKey(key)) return known[key]!;
    if (key.isEmpty) return 'Attribute';
    return key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
  }

  static String suggestCategory(
    String rawType,
    String text, {
    List<String>? enabledRetailModules,
  }) {
    final type = canonicalType(rawType);
    final t = text.toLowerCase();
    final categories = categoriesFor(type, enabledRetailModules: enabledRetailModules);
    bool hasAny(List<String> words) => words.any(t.contains);

    String pick(String value) => categories.contains(value) ? value : (categories.contains('General') ? 'General' : categories.first);

    if (type == 'General Retail') {
      if (hasAny(['tomato','onion','potato','banana','apple','vegetable','fruit','spinach','greens'])) return pick('Fruits / Vegetables');
      if (hasAny(['milk','curd','yogurt','paneer','cheese','butter','ghee','ice cream'])) return pick('Dairy');
      if (hasAny(['bread','cake','pastry','bun','cookie','biscuit','bakery'])) return pick('Bakery');
      if (hasAny(['soap','shampoo','toothpaste','lotion','cream','deodorant'])) return pick('Personal Care');
      if (hasAny(['pen','pencil','notebook','stationery','marker','paper'])) return pick('Stationery');
      if (hasAny(['cleaner','detergent','dishwash','broom','mop','household'])) return pick('Household');
      return pick('Grocery / FMCG');
    }
    if (type == 'Pharmacy / Medical') {
      if (hasAny(['monitor','meter','nebulizer','thermometer','oximeter','device','machine'])) return pick('Medical Devices');
      if (hasAny(['syringe','needle','glove','mask','bandage','dressing','catheter'])) return pick('Surgical / Consumables');
      if (hasAny(['tablet','capsule','syrup','injection','ointment','cream','drops','mg','mcg'])) return pick('Medicines');
    }
    if (type == 'Electronics / Mobile') {
      if (hasAny(['iphone','smartphone','mobile phone','handset'])) return pick('Mobile Phones');
      if (hasAny(['charger','adapter','cable','usb'])) return pick('Cables / Chargers');
      if (hasAny(['earphone','headphone','power bank','case','cover'])) return pick('Accessories');
      if (hasAny(['laptop','tablet','desktop','monitor'])) return pick('Computers / Tablets');
    }
    if (type == 'Auto Spare Parts') {
      if (hasAny(['oil','coolant','fluid','grease'])) return pick('Lubricants / Fluids');
      if (hasAny(['tyre','tire','wheel'])) return pick('Tyres / Wheels');
      if (hasAny(['battery'])) return pick('Battery');
      if (hasAny(['filter'])) return pick('Filters');
      if (hasAny(['brake','pad','disc'])) return pick('Brakes');
    }
    return pick('General');
  }

  static String trackingSummary(Map<String, bool> tracking) {
    const labels = <String, String>{
      'batch': 'Batch',
      'expiry': 'Expiry',
      'serial': 'Serial/IMEI',
      'variant': 'Variant',
      'weight': 'Weight',
      'wastage': 'Wastage',
      'production': 'Production',
      'unitConversion': 'Unit conversion',
    };
    final enabled = <String>[];
    for (final entry in labels.entries) {
      if (tracking[entry.key] == true) enabled.add(entry.value);
    }
    return enabled.isEmpty ? 'Standard quantity stock' : enabled.join(' • ');
  }
}
