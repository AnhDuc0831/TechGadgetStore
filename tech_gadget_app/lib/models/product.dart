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
  final double? discountPrice;
  final double minPrice;
  final double maxPrice;
  final bool inStock;
  final int totalStockQuantity;
  final bool isActive;
  final DateTime? createdAt;
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
    this.discountPrice,
    required this.minPrice,
    required this.maxPrice,
    required this.inStock,
    this.totalStockQuantity = 0,
    this.isActive = true,
    this.createdAt,
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
      discountPrice: json['discountPrice'] != null ? _toDouble(json['discountPrice']) : null,
      minPrice: _toDouble(json['minPrice']),
      maxPrice: _toDouble(json['maxPrice']),
      inStock: json['inStock'] as bool? ?? false,
      totalStockQuantity: json['totalStockQuantity'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
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
  final List<String> images;
  final String specifications;
  final DateTime? updatedAt;
  final List<ProductVariant> variants;

  ProductDetail({
    required super.id,
    required super.name,
    required super.slug,
    super.thumbnailUrl,
    required super.basePrice,
    super.discountPrice,
    required super.minPrice,
    required super.maxPrice,
    required super.inStock,
    super.totalStockQuantity = 0,
    super.isActive = true,
    super.createdAt,
    required super.category,
    required super.brand,
    required super.averageRating,
    required super.reviewCount,
    this.description,
    this.images = const [],
    this.specifications = '{}',
    this.updatedAt,
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
      discountPrice: item.discountPrice,
      minPrice: item.minPrice,
      maxPrice: item.maxPrice,
      inStock: item.inStock,
      totalStockQuantity: item.totalStockQuantity,
      isActive: item.isActive,
      createdAt: item.createdAt,
      category: item.category,
      brand: item.brand,
      averageRating: item.averageRating,
      reviewCount: item.reviewCount,
      description: json['description'] as String?,
      images: (json['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      specifications: json['specifications'] as String? ?? '{}',
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
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

class CreateProductDto {
  final String name;
  final String categoryId;
  final String brandId;
  final double basePrice;
  final double? discountPrice;
  final int stockQuantity;
  final String? sku;
  final String? description;
  final String specifications;
  final bool isActive;

  CreateProductDto({
    required this.name,
    required this.categoryId,
    required this.brandId,
    required this.basePrice,
    this.discountPrice,
    required this.stockQuantity,
    this.sku,
    this.description,
    this.specifications = '{}',
    this.isActive = true,
  });
}

class UpdateProductDto {
  final String name;
  final String categoryId;
  final String brandId;
  final double basePrice;
  final double? discountPrice;
  final int stockQuantity;
  final String? sku;
  final String? description;
  final String specifications;
  final bool isActive;
  final List<String> existingImages;

  UpdateProductDto({
    required this.name,
    required this.categoryId,
    required this.brandId,
    required this.basePrice,
    this.discountPrice,
    required this.stockQuantity,
    this.sku,
    this.description,
    this.specifications = '{}',
    this.isActive = true,
    this.existingImages = const [],
  });
}
