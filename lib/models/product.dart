class Product {
  final String name, brand, description, deliveryTime, pid;
  final double basePrice; // Base price (can be overridden by variants)
  final String category;
  final List<String> keywords;
  final List<String> images;
  final int stockQuantity;
  final List<ProductVariant> variants; // List of product variants

  Product({
    required this.name,
    required this.brand,
    required this.images,
    required this.description,
    required this.category,
    required this.basePrice,
    required this.deliveryTime,
    required this.pid,
    required this.keywords,
    required this.stockQuantity,
    this.variants = const [],
  });

  // Get the effective price (variant price if available, otherwise base price)
  double get effectivePrice {
    if (variants.isNotEmpty) {
      // Return the lowest variant price
      return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
    }
    return basePrice;
  }

  // Get price range for display
  String get priceRange {
    if (variants.isEmpty) {
      return '₹${basePrice.toStringAsFixed(2)}';
    }

    final prices = variants.map((v) => v.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    if (minPrice == maxPrice) {
      return '₹${minPrice.toStringAsFixed(2)}';
    }

    return '₹${minPrice.toStringAsFixed(2)} - ₹${maxPrice.toStringAsFixed(2)}';
  }
}

class ProductVariant {
  final String variantId;
  final String name; // e.g., "Red 128GB", "32 inch"
  final double price;
  final int stockQuantity;
  final Map<String, String>
  attributes; // e.g., {"color": "Red", "storage": "128GB"}
  final String? image; // Optional variant-specific image

  ProductVariant({
    required this.variantId,
    required this.name,
    required this.price,
    required this.stockQuantity,
    this.attributes = const {},
    this.image,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      variantId:
          map['variantId']?.toString() ??
          map['Variant_ID']?.toString() ??
          map['VariantID']?.toString() ??
          '',
      name:
          map['name']?.toString() ??
          map['Variant_Name']?.toString() ??
          map['Name']?.toString() ??
          '',
      price: _parsePrice(map['price'] ?? map['Price'] ?? map['Variant_Price']),
      stockQuantity: _parseInt(
        map['stockQuantity'] ??
            map['Stock'] ??
            map['Quantity'] ??
            map['Stock_Quantity'],
      ),
      attributes: map['attributes'] is Map<String, String>
          ? Map<String, String>.from(map['attributes'])
          : _parseAttributes(map),
      image: map['image']?.toString() ?? map['Image']?.toString(),
    );
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    final str = value.toString().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(str) ?? 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  static Map<String, String> _parseAttributes(Map<String, dynamic> map) {
    final attributes = <String, String>{};

    // Common attribute mappings
    if (map['Color'] != null) attributes['Color'] = map['Color'].toString();
    if (map['Size'] != null) attributes['Size'] = map['Size'].toString();
    if (map['Storage'] != null)
      attributes['Storage'] = map['Storage'].toString();
    if (map['Memory'] != null) attributes['Memory'] = map['Memory'].toString();
    if (map['RAM'] != null) attributes['RAM'] = map['RAM'].toString();
    if (map['Screen_Size'] != null)
      attributes['Screen Size'] = map['Screen_Size'].toString();

    // Add any other custom attributes
    for (final entry in map.entries) {
      if (![
        'Variant_ID',
        'VariantID',
        'Parent_ID',
        'ParentID',
        'Variant_Name',
        'Name',
        'Price',
        'Variant_Price',
        'Stock',
        'Quantity',
        'Stock_Quantity',
        'Image',
      ].contains(entry.key)) {
        if (entry.value != null && entry.value.toString().isNotEmpty) {
          attributes[entry.key] = entry.value.toString();
        }
      }
    }

    return attributes;
  }
}
