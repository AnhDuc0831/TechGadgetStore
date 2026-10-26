double _toDouble(dynamic value) => (value as num?)?.toDouble() ?? 0;

class Category {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.imageUrl,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class Brand {
  final String id;
  final String name;
  final String? logoUrl;

  Brand({required this.id, required this.name, this.logoUrl});

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

class ProductListItem {
  final String id;
  final String name;
  final String slug;
  final String? thumbnailUrl;
  final double basePrice;
  final double minPrice;
  final double maxPrice;
  final bool inStock;
  final Category category;
  final Brand brand;
  final double averageRating;
  final int reviewCount;

  ProductListItem({
    required this.id,
    required this.name,
    required this.slug,
    this.thumbnailUrl,
    required this.basePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.inStock,
    required this.category,
    required this.brand,
    required this.averageRating,
    required this.reviewCount,
  });

  bool get hasPriceRange => maxPrice > minPrice;

  factory ProductListItem.fromJson(Map<String, dynamic> json) {
    return ProductListItem(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      basePrice: _toDouble(json['basePrice']),
      minPrice: _toDouble(json['minPrice']),
      maxPrice: _toDouble(json['maxPrice']),
      inStock: json['inStock'] as bool? ?? false,
      category: Category.fromJson(json['category'] as Map<String, dynamic>),
      brand: Brand.fromJson(json['brand'] as Map<String, dynamic>),
      averageRating: _toDouble(json['averageRating']),
      reviewCount: json['reviewCount'] as int? ?? 0,
    );
  }
}

class ProductVariant {
  final String id;
  final String sku;
  final Map<String, String> attributes;
  final double priceAdjustment;
  final double finalPrice;
  final int stockQuantity;
  final bool inStock;

  ProductVariant({
    required this.id,
    required this.sku,
    required this.attributes,
    required this.priceAdjustment,
    required this.finalPrice,
    required this.stockQuantity,
    required this.inStock,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'] as Map<String, dynamic>? ?? {};
    return ProductVariant(
      id: json['id'] as String,
      sku: json['sku'] as String,
      attributes: rawAttributes.map((key, value) => MapEntry(key, value.toString())),
      priceAdjustment: _toDouble(json['priceAdjustment']),
      finalPrice: _toDouble(json['finalPrice']),
      stockQuantity: json['stockQuantity'] as int? ?? 0,
      inStock: json['inStock'] as bool? ?? false,
    );
  }
}

class ProductDetail extends ProductListItem {
  final String? description;
  final List<ProductVariant> variants;

  ProductDetail({
    required super.id,
    required super.name,
    required super.slug,
    super.thumbnailUrl,
    required super.basePrice,
    required super.minPrice,
    required super.maxPrice,
    required super.inStock,
    required super.category,
    required super.brand,
    required super.averageRating,
    required super.reviewCount,
    this.description,
    required this.variants,
  });

  /// Các nhóm thuộc tính và giá trị (giữ thứ tự xuất hiện), vd: {Color: [Black, Blue], Storage: [128GB, 256GB]}
  Map<String, List<String>> get attributeOptions {
    final options = <String, List<String>>{};
    for (final variant in variants) {
      variant.attributes.forEach((key, value) {
        final values = options.putIfAbsent(key, () => []);
        if (!values.contains(value)) values.add(value);
      });
    }
    return options;
  }

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final item = ProductListItem.fromJson(json);
    return ProductDetail(
      id: item.id,
      name: item.name,
      slug: item.slug,
      thumbnailUrl: item.thumbnailUrl,
      basePrice: item.basePrice,
      minPrice: item.minPrice,
      maxPrice: item.maxPrice,
      inStock: item.inStock,
      category: item.category,
      brand: item.brand,
      averageRating: item.averageRating,
      reviewCount: item.reviewCount,
      description: json['description'] as String?,
      variants: (json['variants'] as List<dynamic>? ?? [])
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PagedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PagedResult(
      items: (json['items'] as List<dynamic>)
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      totalCount: json['totalCount'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}
